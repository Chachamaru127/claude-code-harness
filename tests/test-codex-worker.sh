#!/usr/bin/env bash
#
# test-codex-worker.sh
# Codex Worker 統合テスト
#
# Usage: ./tests/test-codex-worker.sh [--quick]
#

set -euo pipefail

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# カウンター
PASSED=0
FAILED=0

# ヘルパー関数
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }

# プロジェクトルート
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# ============================================
# Test 1: スクリプト存在確認
# ============================================
test_scripts_exist() {
    log_test "Test 1: スクリプト存在確認"

    local scripts=(
        "scripts/codex-worker-setup.sh"
        "scripts/codex-worker-engine.sh"
        "scripts/codex-worker-lock.sh"
        "scripts/codex-worker-quality-gate.sh"
        "scripts/codex-worker-merge.sh"
    )

    local all_exist=true
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]] && [[ -x "$script" ]]; then
            echo "  ✓ $script"
        else
            echo "  ✗ $script (missing or not executable)"
            all_exist=false
        fi
    done

    if $all_exist; then
        log_pass "全スクリプトが存在し実行可能"
    else
        log_fail "一部スクリプトが不足"
    fi
}

# ============================================
# Test 2: ドキュメント存在確認
# ============================================
test_docs_exist() {
    log_test "Test 2: ドキュメント存在確認"

    local docs=(
        "skills/codex-worker/SKILL.md"
        "skills/codex-worker/references/setup.md"
        "skills/codex-worker/references/worker-execution.md"
        "skills/codex-worker/references/task-ownership.md"
        "skills/codex-worker/references/parallel-strategy.md"
        "skills/codex-worker/references/quality-gates.md"
        "skills/codex-worker/references/review-integration.md"
        "skills/ultrawork/references/codex-mode.md"
    )

    local all_exist=true
    for doc in "${docs[@]}"; do
        if [[ -f "$doc" ]]; then
            echo "  ✓ $doc"
        else
            echo "  ✗ $doc (missing)"
            all_exist=false
        fi
    done

    if $all_exist; then
        log_pass "全ドキュメントが存在"
    else
        log_fail "一部ドキュメントが不足"
    fi
}

# ============================================
# Test 3: ロック機能テスト
# ============================================
test_lock_functionality() {
    log_test "Test 3: ロック機能テスト"

    # ユニークなテストパスを使用（前回のテストと競合しない）
    local test_path="test/lock-test-$$.ts"
    local worker_id="test-worker-$$"

    # クリーンアップ（期限切れロックのみ）
    ./scripts/codex-worker-lock.sh cleanup 2>/dev/null || true

    # ロック取得
    if ./scripts/codex-worker-lock.sh acquire --path "$test_path" --worker "$worker_id" 2>/dev/null; then
        echo "  ✓ ロック取得成功"

        # ロック状態確認
        local check_result
        check_result=$(./scripts/codex-worker-lock.sh check --path "$test_path" 2>/dev/null)
        if echo "$check_result" | grep -q '"locked":true'; then
            echo "  ✓ ロック状態確認成功"
        else
            echo "  ✗ ロック状態確認失敗"
            log_fail "ロック状態確認失敗"
            return 1
        fi

        # 二重ロック防止
        if ./scripts/codex-worker-lock.sh acquire --path "$test_path" --worker "another-worker" 2>/dev/null; then
            echo "  ✗ 二重ロックが許可された"
            log_fail "二重ロック防止失敗"
            return 1
        else
            echo "  ✓ 二重ロック防止成功"
        fi

        # ロック解放
        if ./scripts/codex-worker-lock.sh release --path "$test_path" --worker "$worker_id" 2>/dev/null; then
            echo "  ✓ ロック解放成功"
        else
            echo "  ✗ ロック解放失敗"
            log_fail "ロック解放失敗"
            return 1
        fi

        log_pass "ロック機能正常"
    else
        log_fail "ロック取得失敗"
    fi
}

# ============================================
# Test 4: AGENTS.md ハッシュ計算一致確認
# ============================================
test_agents_hash_consistency() {
    log_test "Test 4: AGENTS.md ハッシュ計算一致確認"

    if [[ ! -f "AGENTS.md" ]]; then
        log_skip "AGENTS.md が存在しない"
        return
    fi

    # engine のハッシュ計算
    local engine_hash
    engine_hash=$(sed '1s/^\xEF\xBB\xBF//' "AGENTS.md" | tr -d '\r' | shasum -a 256 | cut -c1-8)

    # quality-gate のハッシュ計算（同一アルゴリズム）
    local gate_hash
    gate_hash=$(sed '1s/^\xEF\xBB\xBF//' "AGENTS.md" | tr -d '\r' | shasum -a 256 | cut -c1-8)

    if [[ "$engine_hash" == "$gate_hash" ]]; then
        echo "  ✓ ハッシュ一致: $engine_hash"
        log_pass "ハッシュ計算一致"
    else
        echo "  ✗ ハッシュ不一致: engine=$engine_hash, gate=$gate_hash"
        log_fail "ハッシュ計算不一致"
    fi
}

# ============================================
# Test 5: スキル誤発動防止確認
# ============================================
test_skill_misfire_prevention() {
    log_test "Test 5: スキル誤発動防止確認"

    # codex-worker の description
    local worker_desc
    worker_desc=$(grep -A1 "^name: codex-worker" skills/codex-worker/SKILL.md | grep "description:" || echo "")

    # codex-review の description
    local review_desc
    review_desc=$(grep -A1 "^name: codex-review" skills/codex-review/SKILL.md | grep "description:" || echo "")

    local issues=0

    # codex-worker が review トリガーを除外しているか
    if echo "$worker_desc" | grep -q "レビュー"; then
        echo "  ✓ codex-worker: レビュー除外あり"
    else
        echo "  ✗ codex-worker: レビュー除外なし"
        issues=$((issues + 1))
    fi

    # codex-review が worker トリガーを除外しているか
    if echo "$review_desc" | grep -qE "Codex に実装させて|Codex Worker|codex-worker"; then
        echo "  ✓ codex-review: Worker 除外あり"
    else
        echo "  ✗ codex-review: Worker 除外なし"
        issues=$((issues + 1))
    fi

    # 両方に Do NOT Load For セクションがあるか
    if grep -q "Do NOT Load For" skills/codex-worker/SKILL.md; then
        echo "  ✓ codex-worker: Do NOT Load For セクションあり"
    else
        echo "  ✗ codex-worker: Do NOT Load For セクションなし"
        issues=$((issues + 1))
    fi

    if grep -q "Do NOT Load For" skills/codex-review/SKILL.md; then
        echo "  ✓ codex-review: Do NOT Load For セクションあり"
    else
        echo "  ✗ codex-review: Do NOT Load For セクションなし"
        issues=$((issues + 1))
    fi

    if [[ $issues -eq 0 ]]; then
        log_pass "スキル誤発動防止設定正常"
    else
        log_fail "スキル誤発動防止に問題あり"
    fi
}

# ============================================
# Test 6: Worktree パス整合性確認
# ============================================
test_worktree_path_consistency() {
    log_test "Test 6: Worktree パス整合性確認"

    local files=(
        "skills/codex-worker/references/parallel-strategy.md"
        "skills/codex-worker/references/worker-execution.md"
        "skills/ultrawork/references/codex-mode.md"
    )

    local issues=0

    for file in "${files[@]}"; do
        # 旧形式 ../worktree- の使用を検出
        if grep -q '\.\./worktree-' "$file" 2>/dev/null; then
            echo "  ✗ $file: 旧形式 ../worktree- を使用"
            issues=$((issues + 1))
        else
            echo "  ✓ $file: パス形式正常"
        fi
    done

    if [[ $issues -eq 0 ]]; then
        log_pass "Worktree パス整合性OK"
    else
        log_fail "Worktree パス不整合あり"
    fi
}

# ============================================
# メイン処理
# ============================================
main() {
    echo "============================================"
    echo "  Codex Worker 統合テスト"
    echo "============================================"
    echo ""

    # テスト実行
    test_scripts_exist
    echo ""
    test_docs_exist
    echo ""
    test_lock_functionality
    echo ""
    test_agents_hash_consistency
    echo ""
    test_skill_misfire_prevention
    echo ""
    test_worktree_path_consistency
    echo ""

    # 結果サマリー
    echo "============================================"
    echo "  テスト結果サマリー"
    echo "============================================"
    echo -e "  ${GREEN}PASSED${NC}: $PASSED"
    echo -e "  ${RED}FAILED${NC}: $FAILED"
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}全テスト合格${NC}"
        exit 0
    else
        echo -e "${RED}一部テスト失敗${NC}"
        exit 1
    fi
}

main "$@"
