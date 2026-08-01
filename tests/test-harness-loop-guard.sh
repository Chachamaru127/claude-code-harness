#!/bin/bash
# test-harness-loop-guard.sh
# harness-loop の冪等性ガード (a) 多重起動防止ロックのテスト
#
# Usage: bash tests/test-harness-loop-guard.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "${SCRIPT_DIR}")"
LOCK_FILE="${PLUGIN_ROOT}/.claude/state/locks/loop-session.lock"

# カラー出力
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass_test() {
    echo -e "${GREEN}✓${NC} $1"
    PASS_COUNT=$(( PASS_COUNT + 1 ))
}

fail_test() {
    echo -e "${RED}✗${NC} $1"
    FAIL_COUNT=$(( FAIL_COUNT + 1 ))
}

echo "=========================================="
echo "harness-loop 冪等性ガード (a) テスト"
echo "=========================================="
echo ""

# クリーンアップ: テスト開始前に lock ファイルを削除
cleanup() {
    rm -f "${LOCK_FILE}" 2>/dev/null || true
}
trap cleanup EXIT
cleanup

# テスト用の擬似 harness-loop 起動スクリプト（flow.md の Step 0 を再現）
MOCK_LOOP_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/test-harness-loop.XXXXXX")"
cat > "${MOCK_LOOP_SCRIPT}" << 'SCRIPT'
#!/bin/bash
# flow.md Step 0 の多重起動防止ロックを再現
LOCK_FILE="$1"
mkdir -p "$(dirname "${LOCK_FILE}")"

if [ -f "${LOCK_FILE}" ]; then
    echo "harness-loop: already running" >&2
    exit 1
fi

SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
printf '{"pid":%d,"session_id":"%s","started_at":"%s","args":"%s"}\n' \
    "$$" "${SESSION_ID}" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "test" \
    > "${LOCK_FILE}"

cleanup_loop_lock() {
    rm -f "${LOCK_FILE}" 2>/dev/null || true
}
trap cleanup_loop_lock EXIT INT TERM

# ロック保持中の処理（テスト用: 0.5秒スリープ）
sleep 0.5
exit 0
SCRIPT
chmod +x "${MOCK_LOOP_SCRIPT}"

# テスト 1: 初回起動は成功すること
echo "--- テスト 1: 初回起動 ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" &
FIRST_PID=$!
sleep 0.1  # lock ファイルが作成されるまで少し待機

if [ -f "${LOCK_FILE}" ]; then
    pass_test "初回起動: lock ファイルが作成されました"
else
    fail_test "初回起動: lock ファイルが作成されませんでした"
fi

# テスト 2: 2 回目の起動は already running エラーになること
echo "--- テスト 2: 多重起動防止 ---"
SECOND_OUTPUT="$(bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" 2>&1 || true)"
if grep -q "already running" <<<"${SECOND_OUTPUT}"; then
    pass_test "2 回目の起動: 'already running' エラーが返されました"
else
    fail_test "2 回目の起動: 'already running' エラーが返されませんでした（出力: ${SECOND_OUTPUT}）"
fi

# テスト 3: 2 回目の起動は exit code 1 で終了すること
echo "--- テスト 3: 多重起動時の exit code ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" 2>/dev/null
EXIT_CODE=$?
if [ "${EXIT_CODE}" -eq 1 ]; then
    pass_test "2 回目の起動: exit code 1 で終了しました"
else
    fail_test "2 回目の起動: exit code が ${EXIT_CODE} でした（期待: 1）"
fi

# 1 回目が終了するまで待機
wait "${FIRST_PID}" 2>/dev/null || true

# テスト 4: 正常終了後 lock ファイルが削除されること
echo "--- テスト 4: 正常終了後の lock 削除 ---"
if [ ! -f "${LOCK_FILE}" ]; then
    pass_test "正常終了後: lock ファイルが削除されました"
else
    fail_test "正常終了後: lock ファイルが残っています"
fi

# テスト 5: lock ファイル削除後に再起動できること
echo "--- テスト 5: lock 削除後の再起動 ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" &
THIRD_PID=$!
sleep 0.1

if [ -f "${LOCK_FILE}" ]; then
    pass_test "再起動: lock ファイルが作成されました（再利用可能）"
else
    fail_test "再起動: lock ファイルが作成されませんでした"
fi
wait "${THIRD_PID}" 2>/dev/null || true

# テスト 6: lock ファイルの内容が正しい JSON であること
echo "--- テスト 6: lock ファイルの JSON 形式 ---"
bash "${MOCK_LOOP_SCRIPT}" "${LOCK_FILE}" &
FOURTH_PID=$!
sleep 0.1

if [ -f "${LOCK_FILE}" ]; then
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import json; json.load(open('${LOCK_FILE}'))" 2>/dev/null; then
            pass_test "lock ファイルの内容が有効な JSON です"
            # pid, session_id, started_at, args の各フィールドを確認
            for field in pid session_id started_at args; do
                if python3 -c "import json; d=json.load(open('${LOCK_FILE}')); assert '${field}' in d" 2>/dev/null; then
                    pass_test "lock ファイルに '${field}' フィールドがあります"
                else
                    fail_test "lock ファイルに '${field}' フィールドがありません"
                fi
            done
        else
            fail_test "lock ファイルの内容が有効な JSON ではありません"
        fi
    else
        pass_test "python3 が利用不可のため JSON 検証をスキップします"
    fi
fi
wait "${FOURTH_PID}" 2>/dev/null || true

# クリーンアップ
rm -f "${MOCK_LOOP_SCRIPT}" 2>/dev/null || true

echo ""
echo "=========================================="
echo "テスト結果サマリー"
echo "=========================================="
echo -e "${GREEN}合格:${NC} ${PASS_COUNT}"
echo -e "${RED}失敗:${NC} ${FAIL_COUNT}"
echo ""

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}✓ 全テスト合格${NC}"
    exit 0
else
    echo -e "${RED}✗ ${FAIL_COUNT} 件のテストが失敗しました${NC}"
    exit 1
fi
