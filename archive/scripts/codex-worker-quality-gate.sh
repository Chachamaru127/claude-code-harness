#!/usr/bin/env bash
#
# codex-worker-quality-gate.sh
# Orchestrator による Worker 成果物の品質検証
#
# Usage:
#   ./scripts/codex-worker-quality-gate.sh --worktree PATH [--skip-gate GATE --reason TEXT]
#

set -euo pipefail

# スクリプトディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリ読み込み
# shellcheck source=lib/codex-worker-common.sh
source "$SCRIPT_DIR/lib/codex-worker-common.sh"

# ============================================
# ローカル設定
# ============================================
GATE_SKIP_LOG=".claude/state/gate-skips.log"
AGENTS_SUMMARY_PATTERN='AGENTS_SUMMARY:[[:space:]]*(.+?)[[:space:]]*\|[[:space:]]*HASH:([A-Fa-f0-9]{8})'

# スキップログ記録
log_skip() {
    local gate="$1"
    local reason="$2"
    local user="${USER:-unknown}"

    mkdir -p "$(dirname "$GATE_SKIP_LOG")"
    printf '%s\t%s\t%s\t%s\n' "$(now_utc)" "$gate" "$reason" "$user" >> "$GATE_SKIP_LOG"
}

# diff の起点を解決（デフォルトブランチの merge-base、なければ HEAD~1、最後は HEAD）
resolve_diff_base() {
    local worktree="$1"
    local default_branch
    default_branch=$(get_default_branch)

    local diff_base
    diff_base=$(cd "$worktree" && git merge-base HEAD "origin/$default_branch" 2>/dev/null || git rev-parse HEAD~1 2>/dev/null || echo "")

    if [[ -z "$diff_base" ]]; then
        diff_base=$(cd "$worktree" && git rev-parse HEAD 2>/dev/null || echo "")
    fi

    echo "$diff_base"
}

# 指定範囲の追加行を取得（改行でそのまま返す）
collect_added_lines() {
    local worktree="$1"
    local diff_base="$2"

    cd "$worktree" && git diff "$diff_base"..HEAD --unified=0 -- \
        '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' \
        '*.sh' '*.md' '*.json' '*.yaml' '*.yml' '*.toml' \
        '*.py' '*.go' '*.rs' '*.txt' 2>/dev/null | grep '^+' | grep -v '^+++ ' || true
}

# 指定範囲の変更ファイルを取得
collect_changed_files() {
    local worktree="$1"
    local diff_base="$2"

    cd "$worktree" && git diff --name-only "$diff_base"..HEAD -- \
        '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' \
        '*.sh' '*.md' '*.json' '*.yaml' '*.yml' '*.toml' \
        '*.py' '*.go' '*.rs' '*.txt' 2>/dev/null || true
}

# Gate 1: 証跡検証
gate_evidence() {
    local worktree="$1"
    local output_file="$2"

    log_gate "Gate 1: 証跡検証 (evidence)"

    # AGENTS.md のハッシュ計算
    local agents_file="$worktree/AGENTS.md"
    if [[ ! -f "$agents_file" ]]; then
        echo '{"status": "critical", "details": "AGENTS.md not found"}' > "$output_file"
        return 2  # Critical: AGENTS.md 必須
    fi

    # ハッシュ計算（engine と完全同一: BOM除去、CR除去、SHA256先頭8文字）
    local expected_hash
    expected_hash=$(calculate_file_hash "$agents_file" 8)

    # Worker 出力から AGENTS_SUMMARY を検索
    # 1. Worker 出力ログ（優先）
    # 2. 最新のコミットメッセージ（フォールバック）
    local worker_output_log="$worktree/.claude/state/worker-output.log"
    local search_content=""
    local found_in_log=false

    if [[ -f "$worker_output_log" ]]; then
        search_content=$(cat "$worker_output_log")
        if echo "$search_content" | grep -qE "$AGENTS_SUMMARY_PATTERN"; then
            found_in_log=true
        fi
    fi

    # ログで未検出の場合はコミットメッセージをフォールバック検索
    if [[ "$found_in_log" == "false" ]]; then
        local commit_msg
        commit_msg=$(cd "$worktree" && git log -1 --pretty=%B 2>/dev/null || echo "")
        if echo "$commit_msg" | grep -qE "$AGENTS_SUMMARY_PATTERN"; then
            search_content="$commit_msg"
        fi
    fi

    # パターンマッチ（AGENTS_SUMMARY 行からのみ HASH を抽出）
    if echo "$search_content" | grep -qE "$AGENTS_SUMMARY_PATTERN"; then
        local found_hash
        # AGENTS_SUMMARY を含む行からのみ HASH を抽出（無関係な HASH を拾わない）
        found_hash=$(echo "$search_content" | grep -E 'AGENTS_SUMMARY' | grep -oE 'HASH:[A-Fa-f0-9]{8}' | head -1 | cut -d: -f2)

        if [[ "${found_hash,,}" == "${expected_hash,,}" ]]; then
            echo '{"status": "passed", "details": "証跡確認OK"}' > "$output_file"
            return 0
        else
            echo "{\"status\": \"failed\", \"details\": \"ハッシュ不一致: expected=$expected_hash, found=$found_hash\"}" > "$output_file"
            return 1  # High: ハッシュ不一致は再試行可能
        fi
    else
        echo '{"status": "critical", "details": "AGENTS_SUMMARY 証跡が見つかりません（即失敗）"}' > "$output_file"
        return 2  # Critical: 証跡欠落は即失敗
    fi
}

# Gate 2: 構造チェック
gate_structure() {
    local worktree="$1"
    local output_file="$2"

    log_gate "Gate 2: 構造チェック (structure)"

    local lint_result=0
    local type_result=0
    local details=""

    # package.json が存在しない場合はスキップ扱い
    if [[ ! -f "$worktree/package.json" ]]; then
        echo '{"status": "passed", "details": "package.json なし（スキップ）"}' > "$output_file"
        return 0
    fi

    # Quality: パッケージマネージャを自動検出
    local pm
    pm=$(detect_package_manager "$worktree")
    local pm_run
    pm_run=$(get_pm_run_command "$pm")
    log_info "パッケージマネージャ検出: $pm"

    # jq で scripts キーを正確に判定
    # lint チェック
    if jq -e '.scripts.lint' "$worktree/package.json" > /dev/null 2>&1; then
        if ! (cd "$worktree" && $pm_run lint --silent 2>&1); then
            lint_result=1
            details="lint エラー"
        fi
    fi

    # type-check
    if jq -e '.scripts["type-check"]' "$worktree/package.json" > /dev/null 2>&1; then
        if ! (cd "$worktree" && $pm_run type-check --silent 2>&1); then
            type_result=1
            details="${details:+$details, }type エラー"
        fi
    fi

    if [[ $lint_result -eq 0 ]] && [[ $type_result -eq 0 ]]; then
        echo '{"status": "passed", "details": "構造チェックOK"}' > "$output_file"
        return 0
    else
        echo "{\"status\": \"failed\", \"details\": \"$details\"}" > "$output_file"
        return 1
    fi
}

# Gate 3: テスト
gate_test() {
    local worktree="$1"
    local output_file="$2"

    log_gate "Gate 3: テスト (test)"

    # 改ざん検出パターン（追加行用）
    # Critical: 明確な改ざん — テスト無効化パターン
    local tamper_critical_patterns=(
        # JS/TS skip 化
        'it\.skip\s*\('
        'test\.skip\s*\('
        'describe\.skip\s*\('
        'xit\s*\('
        'xdescribe\s*\('
        # .only 化（他テストが実行されなくなる）
        '(it|test|describe)\.only\s*\('
        'fit\s*\('
        'fdescribe\s*\('
        # Python skip 化
        '@pytest\.mark\.skip'
        '@unittest\.skip'
        'self\.skipTest\s*\('
    )
    # Warning: 正当な理由がある場合もあるが要注意
    local tamper_warn_patterns=(
        'eslint-disable'
        '@ts-ignore'
        '@ts-expect-error'
        '@ts-nocheck'
    )

    # 削除行用パターン（アサーション削除検出）
    local tamper_remove_patterns=(
        'expect\s*\('
        'assert\s*\('
        '\.should\s*\('
        '\.to\.\w+'
        'self\.assert'
    )

    # 差分ベースの改ざん検出（デフォルトブランチからの全変更）
    local default_branch
    default_branch=$(get_default_branch)
    local merge_base
    merge_base=$(cd "$worktree" && git merge-base HEAD "origin/$default_branch" 2>/dev/null || git rev-parse HEAD~1 2>/dev/null || echo "")

    if [[ -n "$merge_base" ]]; then
        # 追加行の検出（+で始まる行、+++ ヘッダのみ除外）
        # Python テストファイル（test_*.py, *_test.py）も対象に含む
        local added_lines
        added_lines=$(cd "$worktree" && git diff "$merge_base"..HEAD --unified=0 -- '*.ts' '*.tsx' '*.js' '*.jsx' '*.spec.*' '*.test.*' '*.py' 2>/dev/null | grep '^+' | grep -v '^+++ ' || echo "")

        # Critical パターン検出（skip 系 - 明確な改ざん）
        for pattern in "${tamper_critical_patterns[@]}"; do
            if echo "$added_lines" | grep -qE "$pattern"; then
                echo "{\"status\": \"critical\", \"details\": \"改ざん検出: 追加行に '$pattern' パターン\"}" > "$output_file"
                return 2  # Critical: 改ざん検出
            fi
        done

        # Warning パターン検出（eslint-disable - 正当な場合もある）
        for pattern in "${tamper_warn_patterns[@]}"; do
            if echo "$added_lines" | grep -qE "$pattern"; then
                log_warn "要確認: 追加行に '$pattern' パターン（改ざんの可能性）"
                # Warning として記録するが、Critical ではない
            fi
        done

        # 削除行の検出（-で始まる行）- テストファイルのみ
        local removed_lines
        removed_lines=$(cd "$worktree" && git diff "$merge_base"..HEAD --unified=0 -- '*.spec.*' '*.test.*' 'test_*.py' '*_test.py' 2>/dev/null | grep '^-' | grep -v '^---' || echo "")

        for pattern in "${tamper_remove_patterns[@]}"; do
            local removed_count
            removed_count=$(echo "$removed_lines" | grep -cE "$pattern" 2>/dev/null || echo 0)

            if [[ "$removed_count" -gt 2 ]]; then
                echo "{\"status\": \"critical\", \"details\": \"改ざん検出: テストから '$pattern' が $removed_count 件削除\"}" > "$output_file"
                return 2  # Critical: アサーション大量削除
            fi
        done

        # Catch-all assertion 検出（常に成功する無意味なアサーション）
        # expect(true).toBe(true), expect(1).toBe(1) 等
        if echo "$added_lines" | grep -qE 'expect\((true|false|1|0|null|undefined)\)\.(toBe|toEqual|toStrictEqual)\((true|false|1|0|null|undefined)\)'; then
            log_warn "要確認: catch-all assertion 検出（expect(true).toBe(true) 等）"
        fi
        # 定数に対する弱いアサーション: expect(false).toBeFalsy() 等
        if echo "$added_lines" | grep -qE 'expect\((true|false|null|undefined|0)\)\.(toBeUndefined|toBeNull|toBeFalsy|toBeTruthy)\(\)'; then
            log_warn "要確認: 定数に対する弱いアサーション検出"
        fi

        # タイムアウト値の大幅引き上げ検出（≥30000ms）
        local timeout_hit
        timeout_hit=$(echo "$added_lines" | grep -E 'jest\.setTimeout\(|jasmine\.DEFAULT_TIMEOUT_INTERVAL|[[:space:]]timeout[[:space:]]*:' | grep -oE '[0-9]+' | awk '$1 >= 30000 {found=1} END {print found+0}' 2>/dev/null || echo 0)
        if [[ "${timeout_hit:-0}" -gt 0 ]]; then
            log_warn "要確認: タイムアウト値の大幅引き上げ検出（≥30000ms）"
        fi

        # 設定ファイルの緩和検出（lint/CI/TypeScript strict）
        local config_diff
        config_diff=$(cd "$worktree" && git diff "$merge_base"..HEAD --unified=0 -- '.eslintrc*' 'eslint.config.*' 'tsconfig.json' 'tsconfig.*.json' 'biome.json' 'jest.config.*' 'vitest.config.*' '.github/workflows/*.yml' '.github/workflows/*.yaml' 2>/dev/null | grep '^+' | grep -v '^+++ ' || echo "")
        if [[ -n "$config_diff" ]]; then
            # lint ルール無効化
            if echo "$config_diff" | grep -qE '"off"|:[[:space:]]*0'; then
                log_warn "要確認: 設定ファイルで lint ルール無効化を検出"
            fi
            # CI continue-on-error
            if echo "$config_diff" | grep -qE 'continue-on-error:[[:space:]]*true'; then
                log_warn "要確認: CI の continue-on-error 追加を検出"
            fi
            # TypeScript strict モード緩和
            if echo "$config_diff" | grep -qE '"strict"[[:space:]]*:[[:space:]]*false|"noImplicitAny"[[:space:]]*:[[:space:]]*false'; then
                echo '{"status": "critical", "details": "改ざん検出: TypeScript strict モードの緩和"}' > "$output_file"
                return 2
            fi
        fi
    fi

    # テスト実行（パッケージマネージャ自動検出）
    if [[ -f "$worktree/package.json" ]]; then
        if jq -e '.scripts.test' "$worktree/package.json" > /dev/null 2>&1; then
            local pm
            pm=$(detect_package_manager "$worktree")
            local pm_run
            pm_run=$(get_pm_run_command "$pm")

            if ! (cd "$worktree" && $pm_run test 2>&1); then
                echo '{"status": "failed", "details": "テスト失敗"}' > "$output_file"
                return 1
            fi
        fi
    fi

    echo '{"status": "passed", "details": "テストOK"}' > "$output_file"
    return 0
}

# Gate 4: Hardening parity
gate_hardening() {
    local worktree="$1"
    local output_file="$2"

    log_gate "Gate 4: hardening parity"

    local codex_state_dir="$worktree/.claude/state/codex-worker"
    local base_instructions_file="$codex_state_dir/base-instructions.txt"
    local prompt_file="$codex_state_dir/prompt.txt"
    local contract_file="$codex_state_dir/hardening-contract.txt"
    local marker="HARNESS_HARDENING_CONTRACT_V1"

    local status="passed"
    local violations=()

    # 1. Injected contract artifact の確認
    local contract_files=(
        "$base_instructions_file"
        "$prompt_file"
        "$contract_file"
    )

    for file in "${contract_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            violations+=("Hardening contract artifact missing: $file")
            status="critical"
            continue
        fi

        if ! grep -Fq "$marker" "$file" 2>/dev/null; then
            violations+=("Hardening contract marker missing: $file")
            status="critical"
        fi
    done

    # 2. Diff ベースの hardening 違反チェック
    local diff_base
    diff_base=$(resolve_diff_base "$worktree")

    if [[ -n "$diff_base" ]]; then
        local changed_files
        local added_lines
        changed_files=$(collect_changed_files "$worktree" "$diff_base")
        added_lines=$(collect_added_lines "$worktree" "$diff_base")

        # 2-1. bypass flags
        if echo "$added_lines" | grep -qE -- '--no-verify|--no-gpg-sign'; then
            violations+=("Added lines contain bypass flags: --no-verify or --no-gpg-sign")
            [[ "$status" == "passed" ]] && status="failed"
        fi

        # 2-2. protected branch reset
        if echo "$added_lines" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
            if echo "$added_lines" | grep -qE '(origin/)?(main|master)'; then
                violations+=("Added lines contain protected hard reset command against main/master")
                [[ "$status" == "passed" ]] && status="failed"
            fi
        fi

        # 2-3. protected files
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            case "$file" in
                package.json|Dockerfile|docker-compose.yml|schema.prisma|wrangler.toml|index.html|.github/workflows/*.yml|.github/workflows/*.yaml)
                    violations+=("Protected file changed: $file")
                    [[ "$status" == "passed" ]] && status="failed"
                    ;;
            esac
        done <<< "$changed_files"

        # 2-4. secrets / credentials
        if echo "$added_lines" | grep -qE '(api[_-]?key|secret[_-]?key|auth[_-]?token|access[_-]?token|password|credential|private[_-]?key)[[:space:]]*[:=]'; then
            violations+=("Added lines contain hardcoded secret-like assignment")
            [[ "$status" == "passed" ]] && status="failed"
        fi

        if echo "$added_lines" | grep -qE '(postgres://|mysql://|mongodb://|redis://|amqp://|DATABASE_URL|REDIS_URL)'; then
            violations+=("Added lines contain hardcoded service/database connection string")
            [[ "$status" == "passed" ]] && status="failed"
        fi

        if echo "$added_lines" | grep -qE '(192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)'; then
            violations+=("Added lines contain private IP address")
            [[ "$status" == "passed" ]] && status="failed"
        fi
    else
        violations+=("Hardening diff base could not be resolved")
        status="critical"
    fi

    local violations_json='[]'
    if [[ ${#violations[@]} -gt 0 ]]; then
        violations_json=$(printf '%s\n' "${violations[@]}" | jq -R . | jq -s '.')
    fi

    local details="hardening parity OK"
    case "$status" in
        critical) details="hardening contract missing or invalid" ;;
        failed) details="hardening violations detected" ;;
    esac

    jq -n \
        --arg status "$status" \
        --arg details "$details" \
        --arg marker "$marker" \
        --argjson violations "$violations_json" \
        '{
            status: $status,
            details: $details,
            marker: $marker,
            violations: $violations
        }' > "$output_file"

    case "$status" in
        passed) return 0 ;;
        failed) return 1 ;;
        critical) return 2 ;;
    esac
}

# メイン処理
main() {
    check_dependencies

    local worktree=""
    local skip_gates=()
    local skip_reason=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --worktree)
                if [[ -z "${2:-}" ]]; then
                    log_error "--worktree には値が必要です"
                    exit 1
                fi
                worktree="$2"; shift 2 ;;
            --skip-gate)
                if [[ -z "${2:-}" ]]; then
                    log_error "--skip-gate には値が必要です"
                    exit 1
                fi
                skip_gates+=("$2"); shift 2 ;;
            --reason)
                if [[ -z "${2:-}" ]]; then
                    log_error "--reason には値が必要です"
                    exit 1
                fi
                skip_reason="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # 必須パラメータチェック
    if [[ -z "$worktree" ]]; then
        log_error "--worktree は必須です"
        exit 1
    fi

    if [[ ! -d "$worktree" ]]; then
        log_error "Worktree が存在しません: $worktree"
        exit 1
    fi

    # Security: 同一リポジトリの worktree か検証
    if ! validate_worktree_path "$worktree"; then
        exit 1
    fi

    # スキップ時は理由必須
    if [[ ${#skip_gates[@]} -gt 0 ]] && [[ -z "$skip_reason" ]]; then
        log_error "--skip-gate 使用時は --reason が必須です"
        exit 1
    fi

    # Security: スキップ許可リストの確認（デフォルトは拒否）
    if [[ ${#skip_gates[@]} -gt 0 ]]; then
        local allowlist
        allowlist=$(get_config "gate_skip_allowlist")

        # 許可リストが空または [] の場合、全てのスキップを拒否
        if [[ -z "$allowlist" || "$allowlist" == "[]" || "$allowlist" == "null" ]]; then
            log_error "Gate スキップは許可されていません（allowlist が空）"
            log_error "スキップを許可するには設定ファイルの gate_skip_allowlist を編集してください"
            exit 1
        fi

        for gate in "${skip_gates[@]}"; do
            # 許可リストに含まれるか確認
            if ! echo "$allowlist" | jq -e --arg g "$gate" 'index($g) != null' >/dev/null 2>&1; then
                log_error "Gate '$gate' は許可リストに含まれていません"
                log_error "許可されたゲート: $allowlist"
                exit 1
            fi
            log_warn "Gate '$gate' をスキップ: $skip_reason (user=${USER:-unknown})"
        done
    fi

    # 一時ディレクトリ
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    # 結果格納
    local overall_status="passed"
    local gates_json="{}"
    local skipped_json="[]"
    local errors_json="[]"

    # Gate 1: 証跡検証
    if [[ " ${skip_gates[*]} " =~ " evidence " ]]; then
        log_warn "Gate 1 (evidence) をスキップ"
        log_skip "evidence" "$skip_reason"
        skipped_json=$(echo "$skipped_json" | jq '. + ["evidence"]')
        gates_json=$(echo "$gates_json" | jq --arg reason "$skip_reason" '.evidence = {"status": "skipped", "details": $reason}')
    else
        local evidence_exit_code=0
        gate_evidence "$worktree" "$tmp_dir/evidence.json" || evidence_exit_code=$?

        if [[ $evidence_exit_code -eq 0 ]]; then
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/evidence.json" '.evidence = $g[0]')
        elif [[ $evidence_exit_code -eq 2 ]]; then
            # Critical: 証跡欠落
            overall_status="critical"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/evidence.json" '.evidence = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["CRITICAL: 証跡欠落"]')
        else
            overall_status="failed"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/evidence.json" '.evidence = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["Gate 1 failed: ハッシュ不一致"]')
        fi
    fi

    # Gate 2: 構造チェック
    if [[ " ${skip_gates[*]} " =~ " structure " ]]; then
        log_warn "Gate 2 (structure) をスキップ"
        log_skip "structure" "$skip_reason"
        skipped_json=$(echo "$skipped_json" | jq '. + ["structure"]')
        gates_json=$(echo "$gates_json" | jq --arg reason "$skip_reason" '.structure = {"status": "skipped", "details": $reason}')
    else
        if gate_structure "$worktree" "$tmp_dir/structure.json"; then
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/structure.json" '.structure = $g[0]')
        else
            overall_status="failed"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/structure.json" '.structure = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["Gate 2 failed"]')
        fi
    fi

    # Gate 3: テスト
    if [[ " ${skip_gates[*]} " =~ " test " ]]; then
        log_warn "Gate 3 (test) をスキップ"
        log_skip "test" "$skip_reason"
        skipped_json=$(echo "$skipped_json" | jq '. + ["test"]')
        gates_json=$(echo "$gates_json" | jq --arg reason "$skip_reason" '.test = {"status": "skipped", "details": $reason}')
    else
        local test_exit_code=0
        gate_test "$worktree" "$tmp_dir/test.json" || test_exit_code=$?

        if [[ $test_exit_code -eq 0 ]]; then
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/test.json" '.test = $g[0]')
        elif [[ $test_exit_code -eq 2 ]]; then
            # Critical: 改ざん検出
            overall_status="critical"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/test.json" '.test = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["CRITICAL: 改ざん検出"]')
        else
            overall_status="failed"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/test.json" '.test = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["Gate 3 failed"]')
        fi
    fi

    # Gate 4: Hardening parity
    if [[ " ${skip_gates[*]} " =~ " hardening " ]]; then
        log_warn "Gate 4 (hardening) をスキップ"
        log_skip "hardening" "$skip_reason"
        skipped_json=$(echo "$skipped_json" | jq '. + ["hardening"]')
        gates_json=$(echo "$gates_json" | jq --arg reason "$skip_reason" '.hardening = {"status": "skipped", "details": $reason}')
    else
        local hardening_exit_code=0
        gate_hardening "$worktree" "$tmp_dir/hardening.json" || hardening_exit_code=$?

        if [[ $hardening_exit_code -eq 0 ]]; then
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/hardening.json" '.hardening = $g[0]')
        elif [[ $hardening_exit_code -eq 2 ]]; then
            overall_status="critical"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/hardening.json" '.hardening = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["CRITICAL: hardening contract missing or invalid"]')
            while IFS= read -r violation; do
                [[ -z "$violation" ]] && continue
                errors_json=$(echo "$errors_json" | jq --arg v "$violation" '. + [$v]')
            done < <(jq -r '.violations[]' "$tmp_dir/hardening.json" 2>/dev/null || true)
        else
            overall_status="failed"
            gates_json=$(echo "$gates_json" | jq --slurpfile g "$tmp_dir/hardening.json" '.hardening = $g[0]')
            errors_json=$(echo "$errors_json" | jq '. + ["Gate 4 failed: hardening violations"]')
            while IFS= read -r violation; do
                [[ -z "$violation" ]] && continue
                errors_json=$(echo "$errors_json" | jq --arg v "$violation" '. + [$v]')
            done < <(jq -r '.violations[]' "$tmp_dir/hardening.json" 2>/dev/null || true)
        fi
    fi

    # 最終結果出力
    local result
    result=$(jq -n \
        --arg status "$overall_status" \
        --argjson gates "$gates_json" \
        --argjson skipped "$skipped_json" \
        --argjson errors "$errors_json" \
        '{
            status: $status,
            gates: $gates,
            skipped: $skipped,
            errors: $errors
        }')

    # Security: ゲート結果を中央管理（worktree 外に保存）
    local details_summary
    details_summary=$(echo "$result" | jq -c '.errors')
    save_gate_result "$worktree" "$overall_status" "$details_summary"

    echo "$result"

    # 終了コード
    case "$overall_status" in
        passed) exit 0 ;;
        failed) exit 1 ;;
        critical) exit 2 ;;
    esac
}

# 使用方法
usage() {
    cat << EOF
Usage: $0 --worktree PATH [OPTIONS]

Options:
  --worktree PATH       検査対象の worktree（必須）
  --skip-gate GATE      特定ゲートをスキップ (evidence, structure, test, hardening)
  --reason TEXT         スキップ理由（--skip-gate と併用、必須）
  -h, --help            ヘルプ表示

Gates:
  evidence   - AGENTS_SUMMARY 証跡検証
  structure  - lint, type-check
  test       - テスト実行、改ざん検出
  hardening  - Codex parity hardening（contract, bypass flags, protected files, secrets）

Examples:
  $0 --worktree ../worktrees/worker-1
  $0 --worktree ../worktrees/worker-1 --skip-gate test --reason "テスト環境未構築"
EOF
}

main "$@"
