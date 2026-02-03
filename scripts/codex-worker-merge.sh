#!/usr/bin/env bash
#
# codex-worker-merge.sh
# Worker 成果物のマージ統合
#
# Usage:
#   ./scripts/codex-worker-merge.sh --worktree PATH --target-branch BRANCH [--squash] [--dry-run]
#

set -euo pipefail

# スクリプトディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 共通ライブラリ読み込み
# shellcheck source=lib/codex-worker-common.sh
source "$SCRIPT_DIR/lib/codex-worker-common.sh"

# Plans.md 更新
# Note: CWD 依存排除のため repo root からの絶対パスを使用
update_plans() {
    local task_pattern="$1"
    local repo_root
    repo_root=$(get_repo_root) || return 1
    local plans_file="$repo_root/Plans.md"

    if [[ ! -f "$plans_file" ]]; then
        log_warn "Plans.md が見つかりません: $plans_file"
        return 1
    fi

    # cc:WIP → cc:done, [ ] → [x]
    if grep -q "$task_pattern" "$plans_file"; then
        sed -i.bak "s/\(.*$task_pattern.*\)cc:WIP/\1cc:done/" "$plans_file"
        sed -i.bak "s/\(.*$task_pattern.*\)\[ \]/\1[x]/" "$plans_file"
        rm -f "$plans_file.bak"
        log_info "Plans.md 更新: $task_pattern → cc:done"
        return 0
    fi

    return 1
}

# cherry-pick マージ
do_cherry_pick() {
    local commit_hash="$1"
    local dry_run="$2"

    log_merge "cherry-pick: $commit_hash"

    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY-RUN] git cherry-pick $commit_hash"
        return 0
    fi

    if git cherry-pick "$commit_hash" 2>/dev/null; then
        return 0
    else
        # 競合発生
        git cherry-pick --abort 2>/dev/null || true
        return 1
    fi
}

# squash マージ
do_squash_merge() {
    local worktree="$1"
    local dry_run="$2"

    # worktree のブランチ名を取得
    local branch_name
    branch_name=$(cd "$worktree" && git branch --show-current)

    log_merge "squash merge: $branch_name"

    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY-RUN] git merge --squash $branch_name"
        return 0
    fi

    if git merge --squash "$branch_name" 2>/dev/null; then
        git commit -m "feat: Worker 成果物のマージ ($branch_name)"
        return 0
    else
        git merge --abort 2>/dev/null || true
        return 1
    fi
}

# メイン処理
main() {
    check_dependencies

    local worktree=""
    local target_branch=""
    local squash=false
    local dry_run=false
    local force=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --worktree)
                if [[ -z "${2:-}" ]]; then
                    log_error "--worktree には値が必要です"
                    exit 1
                fi
                worktree="$2"; shift 2 ;;
            --target-branch)
                if [[ -z "${2:-}" ]]; then
                    log_error "--target-branch には値が必要です"
                    exit 1
                fi
                target_branch="$2"; shift 2 ;;
            --squash) squash=true; shift ;;
            --dry-run) dry_run=true; shift ;;
            --force) force=true; shift ;;
            -h|--help) usage; exit 0 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # デフォルトブランチの取得
    if [[ -z "$target_branch" ]]; then
        target_branch=$(get_default_branch)
    fi

    # 必須パラメータチェック
    if [[ -z "$worktree" ]]; then
        log_error "--worktree は必須です"
        exit 1
    fi

    if [[ ! -d "$worktree" ]]; then
        log_error "Worktree が存在しません: $worktree"
        exit 1
    fi

    # Security: 同一リポジトリの worktree か検証（共通関数を使用）
    if ! validate_worktree_path "$worktree"; then
        exit 1
    fi

    # Quality: worktree の作業ツリーがクリーンか確認
    local worktree_status
    worktree_status=$(cd "$worktree" && git status --porcelain 2>/dev/null)
    if [[ -n "$worktree_status" ]]; then
        log_warn "worktree に未コミットの変更があります:"
        echo "$worktree_status" | head -5
        if [[ "$force" != "true" ]]; then
            log_error "未コミットの変更があるため中断します。--force でスキップ可能"
            echo '{"status": "blocked", "reason": "uncommitted_changes"}'
            exit 1
        fi
        log_warn "⚠️ 未コミットの変更を無視してマージを続行"
    fi

    # Security: 品質ゲート通過確認（中央管理のゲート結果を検証）
    local require_gate_pass
    require_gate_pass=$(get_config "require_gate_pass_for_merge")

    if [[ "$require_gate_pass" == "true" ]]; then
        # verify_gate_result は worktree の HEAD コミットに対応するゲート結果を検証
        # Worker が改ざんできない中央管理の結果ファイルを参照
        if ! verify_gate_result "$worktree"; then
            log_error "品質ゲートを通過してからマージしてください"
            log_error "--force オプションでスキップ可能ですが推奨しません"

            if [[ "$force" != "true" ]]; then
                echo '{"status": "blocked", "reason": "gate_not_passed"}'
                exit 1
            fi
            log_warn "⚠️ 品質ゲート未通過でマージを強制実行"
        fi
    fi

    # worktree の最新コミット取得
    local commit_hash
    commit_hash=$(cd "$worktree" && git log -1 --format="%H")

    if [[ -z "$commit_hash" ]]; then
        log_error "コミットが見つかりません"
        echo '{"status": "failed", "commit_hash": null, "conflicts": [], "plans_updated": false}'
        exit 1
    fi

    log_info "Worker コミット: $commit_hash"

    # 現在のブランチを確認
    local current_branch
    current_branch=$(git branch --show-current)

    # ターゲットブランチの検証
    if ! git check-ref-format --branch "$target_branch" 2>/dev/null; then
        log_error "無効なブランチ名: $target_branch"
        echo '{"status": "failed", "commit_hash": null, "conflicts": ["invalid branch name"], "plans_updated": false}'
        exit 1
    fi

    # ターゲットブランチに切り替え
    if [[ "$current_branch" != "$target_branch" ]]; then
        if [[ "$dry_run" == "false" ]]; then
            git switch "$target_branch"
        else
            log_info "[DRY-RUN] git switch $target_branch"
        fi
    fi

    # マージ実行
    local merge_status="merged"
    local conflicts=()

    if [[ "$squash" == "true" ]]; then
        if ! do_squash_merge "$worktree" "$dry_run"; then
            merge_status="conflict"
            conflicts+=("squash merge failed")
        fi
    else
        if ! do_cherry_pick "$commit_hash" "$dry_run"; then
            merge_status="conflict"
            conflicts+=("cherry-pick failed")
        fi
    fi

    # Plans.md 更新
    local plans_updated=false
    if [[ "$merge_status" == "merged" ]] && [[ "$dry_run" == "false" ]]; then
        # worktree 名からタスク ID を推測（worker-1 → task-1 など）
        local worker_id
        worker_id=$(basename "$worktree" | sed 's/worker-//')

        if update_plans "task-$worker_id\|Task $worker_id" 2>/dev/null; then
            plans_updated=true
        fi
    fi

    # 結果出力
    local conflicts_json
    conflicts_json=$(printf '%s\n' "${conflicts[@]:-}" | jq -R -s -c 'split("\n") | map(select(length > 0))')

    local result
    result=$(jq -n \
        --arg status "$merge_status" \
        --arg commit_hash "$commit_hash" \
        --argjson conflicts "$conflicts_json" \
        --argjson plans_updated "$plans_updated" \
        '{
            status: $status,
            commit_hash: $commit_hash,
            conflicts: $conflicts,
            plans_updated: $plans_updated
        }')

    echo "$result"

    # 元のブランチに戻る（マージ後）
    if [[ "$dry_run" == "false" ]] && [[ -n "$current_branch" ]] && [[ "$current_branch" != "$target_branch" ]]; then
        git switch "$current_branch" 2>/dev/null || log_warn "元のブランチに戻れませんでした: $current_branch"
    fi

    # 終了コード
    if [[ "$merge_status" == "merged" ]]; then
        exit 0
    else
        exit 1
    fi
}

# 使用方法
usage() {
    cat << EOF
Usage: $0 --worktree PATH [OPTIONS]

Options:
  --worktree PATH         Worker の worktree パス（必須）
  --target-branch BRANCH  マージ先ブランチ（デフォルト: main）
  --squash                squash merge を使用
  --dry-run               実際にマージせず確認のみ
  --force                 品質ゲート未通過でも強制マージ（非推奨）
  -h, --help              ヘルプ表示

Examples:
  $0 --worktree ../worktrees/worker-1
  $0 --worktree ../worktrees/worker-1 --target-branch develop
  $0 --worktree ../worktrees/worker-1 --squash
  $0 --worktree ../worktrees/worker-1 --dry-run
  $0 --worktree ../worktrees/worker-1 --force  # 品質ゲートスキップ（注意）
EOF
}

main "$@"
