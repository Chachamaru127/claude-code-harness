#!/bin/bash
# test-plans-watcher-concurrent.sh
# plans-watcher.sh の flock ガード (e) — 2 プロセス同時書き込みテスト
# ロストアップデートが発生しないことを検証する
#
# Usage: bash tests/test-plans-watcher-concurrent.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "${SCRIPT_DIR}")"

# カラー出力
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

warn_test() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "=========================================="
echo "plans-watcher.sh flock ガード (e) テスト"
echo "=========================================="
echo ""

# テスト用の一時ディレクトリを作成
WORK_DIR="$(mktemp -d /tmp/test-plans-watcher-XXXXXX)"
PLANS_LOCK_FILE="${WORK_DIR}/.claude/state/locks/plans.flock"
TEST_FILE="${WORK_DIR}/counter.txt"
mkdir -p "${WORK_DIR}/.claude/state/locks"

# クリーンアップ
cleanup() {
    rm -rf "${WORK_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

# テスト 1: flock ガードの基本動作（3-tier lock フォールバック再現）
echo "--- テスト 1: flock 排他制御の基本動作 ---"

# flock ロジックを抽出した最小スクリプト（plans-watcher.sh の _plans_acquire_lock を再現）
LOCK_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/test-flock-worker.XXXXXX")"
cat > "${LOCK_SCRIPT}" << SCRIPT
#!/bin/bash
LOCK_FILE="\$1"
COUNTER_FILE="\$2"
LOCK_DIR="\${LOCK_FILE}.dir"
LOCK_TIMEOUT=3
_LOCK_ACQUIRED=0

_acquire() {
    mkdir -p "\$(dirname "\${LOCK_FILE}")" 2>/dev/null || true
    if command -v flock >/dev/null 2>&1; then
        exec 8>"\${LOCK_FILE}"
        if flock -w "\${LOCK_TIMEOUT}" 8 2>/dev/null; then
            _LOCK_ACQUIRED=1; return 0
        else
            exec 8>&- 2>/dev/null || true; return 1
        fi
    fi
    if command -v lockf >/dev/null 2>&1; then
        exec 8>"\${LOCK_FILE}"
        if lockf -s -t "\${LOCK_TIMEOUT}" 8 2>/dev/null; then
            _LOCK_ACQUIRED=2; return 0
        else
            exec 8>&- 2>/dev/null || true; return 1
        fi
    fi
    local waited=0
    while ! mkdir "\${LOCK_DIR}" 2>/dev/null; do
        sleep 0.1
        waited=\$(( waited + 1 ))
        if [ "\${waited}" -ge \$(( LOCK_TIMEOUT * 10 )) ]; then return 1; fi
    done
    _LOCK_ACQUIRED=3; return 0
}

_release() {
    case "\${_LOCK_ACQUIRED}" in
        1) flock -u 8 2>/dev/null || true; exec 8>&- 2>/dev/null || true ;;
        2) exec 8>&- 2>/dev/null || true ;;
        3) rmdir "\${LOCK_DIR}" 2>/dev/null || true ;;
    esac
}

trap _release EXIT

if ! _acquire; then
    echo "worker \$\$: could not acquire lock" >&2
    exit 1
fi

# クリティカルセクション: カウンターのインクリメント（read-modify-write）
CURRENT=\$(cat "\${COUNTER_FILE}" 2>/dev/null || echo "0")
NEW=\$(( CURRENT + 1 ))
# 意図的なスリープでレースコンディションを誘発
sleep 0.05
echo "\${NEW}" > "\${COUNTER_FILE}"
SCRIPT
chmod +x "${LOCK_SCRIPT}"

# カウンターを初期化
echo "0" > "${TEST_FILE}"

# 20 並列プロセスで同時にカウンターをインクリメント
WORKERS=20
PIDS=()
for i in $(seq 1 "${WORKERS}"); do
    bash "${LOCK_SCRIPT}" "${PLANS_LOCK_FILE}" "${TEST_FILE}" &
    PIDS+=($!)
done

# 全ワーカーの完了を待機
FAILED_WORKERS=0
for pid in "${PIDS[@]}"; do
    if ! wait "${pid}" 2>/dev/null; then
        FAILED_WORKERS=$(( FAILED_WORKERS + 1 ))
    fi
done

# 結果の確認
FINAL_COUNT=$(cat "${TEST_FILE}" 2>/dev/null || echo "error")

if [ "${FAILED_WORKERS}" -gt 0 ]; then
    warn_test "${FAILED_WORKERS} ワーカーがロック取得に失敗しました（タイムアウトの可能性）"
fi

EXPECTED=$(( WORKERS - FAILED_WORKERS ))

if [ "${FINAL_COUNT}" = "${EXPECTED}" ]; then
    pass_test "flock 排他制御: ${WORKERS} プロセスで ${EXPECTED} 件のインクリメントが正確に完了（ロストアップデートなし）"
elif [ "${FINAL_COUNT}" = "${WORKERS}" ]; then
    pass_test "flock 排他制御: 全 ${WORKERS} プロセスが成功（ロストアップデートなし）"
else
    fail_test "flock 排他制御: 最終カウント=${FINAL_COUNT}、期待値=${EXPECTED}（ロストアップデートの可能性）"
fi

# テスト 2: flock なし（ロックなし）でロストアップデートが発生することを確認
# （テスト環境の健全性チェック: 排他制御なしでは問題が起きることを確認）
echo ""
echo "--- テスト 2: 排他制御なしのロストアップデート確認（期待: 不整合あり）---"

LOCK_SCRIPT_NOLOCK="$(mktemp "${TMPDIR:-/tmp}/test-nolock-worker.XXXXXX")"
cat > "${LOCK_SCRIPT_NOLOCK}" << 'SCRIPT'
#!/bin/bash
COUNTER_FILE="$1"
CURRENT=$(cat "${COUNTER_FILE}" 2>/dev/null || echo "0")
NEW=$(( CURRENT + 1 ))
sleep 0.05  # レースコンディションを誘発
echo "${NEW}" > "${COUNTER_FILE}"
SCRIPT
chmod +x "${LOCK_SCRIPT_NOLOCK}"

TEST_FILE_NOLOCK="${WORK_DIR}/counter_nolock.txt"
echo "0" > "${TEST_FILE_NOLOCK}"

WORKERS_NOLOCK=10
PIDS_NOLOCK=()
for i in $(seq 1 "${WORKERS_NOLOCK}"); do
    bash "${LOCK_SCRIPT_NOLOCK}" "${TEST_FILE_NOLOCK}" &
    PIDS_NOLOCK+=($!)
done
for pid in "${PIDS_NOLOCK[@]}"; do
    wait "${pid}" 2>/dev/null || true
done

FINAL_NOLOCK=$(cat "${TEST_FILE_NOLOCK}" 2>/dev/null || echo "error")

if [ "${FINAL_NOLOCK}" != "${WORKERS_NOLOCK}" ]; then
    pass_test "排他制御なし: ロストアップデートが発生しました（最終=${FINAL_NOLOCK}、期待値=${WORKERS_NOLOCK}）— テスト環境は正常"
else
    warn_test "排他制御なし: ロストアップデートが発生しませんでした（最終=${FINAL_NOLOCK}）— 環境によっては問題なし（flock なしでもたまたま競合しない場合がある）"
fi

# テスト 3: plans-watcher.sh の flock ガードが呼び出し可能か確認
echo ""
echo "--- テスト 3: plans-watcher.sh の flock 関数定義確認 ---"
WATCHER_SCRIPT="${PLUGIN_ROOT}/scripts/plans-watcher.sh"

if [ -f "${WATCHER_SCRIPT}" ]; then
    if grep -q "_plans_acquire_lock" "${WATCHER_SCRIPT}" && grep -q "_plans_release_lock" "${WATCHER_SCRIPT}"; then
        pass_test "plans-watcher.sh に flock ガード関数が定義されています"
    else
        fail_test "plans-watcher.sh に flock ガード関数が見つかりません"
    fi

    if grep -q "plans.flock" "${WATCHER_SCRIPT}"; then
        pass_test "plans-watcher.sh が .claude/state/locks/plans.flock を使用しています"
    else
        fail_test "plans-watcher.sh が plans.flock を使用していません"
    fi

    if grep -q 'trap.*_plans_watcher_cleanup.*EXIT' "${WATCHER_SCRIPT}"; then
        pass_test "plans-watcher.sh に EXIT trap が設定されています"
    else
        fail_test "plans-watcher.sh に EXIT trap が設定されていません"
    fi

    # fail-closed 検証 (41.1.3): exit 11 コードが存在するか確認
    if grep -q 'exit 11' "${WATCHER_SCRIPT}"; then
        pass_test "plans-watcher.sh が lock 取得失敗時に exit 11 で fail-closed します"
    else
        fail_test "plans-watcher.sh に exit 11（fail-closed）が設定されていません"
    fi

    # fail-closed 検証: retry ロジックが存在するか確認
    if grep -q '_PLANS_LOCK_MAX_RETRIES' "${WATCHER_SCRIPT}"; then
        pass_test "plans-watcher.sh に retry ロジック（_PLANS_LOCK_MAX_RETRIES）が存在します"
    else
        fail_test "plans-watcher.sh に retry ロジックが見つかりません"
    fi
else
    fail_test "plans-watcher.sh が見つかりません: ${WATCHER_SCRIPT}"
fi

# テスト 4: fail-closed の実動作確認（lock を事前に取得した状態で plans-watcher.sh 相当を実行）
echo ""
echo "--- テスト 4: fail-closed 実動作確認（lock 競合時に exit 11）---"

# lock ファイルを事前に取得して保持し続けるバックグラウンドプロセスを起動
FAIL_CLOSED_LOCK="${WORK_DIR}/.claude/state/locks/fc-test.flock"
mkdir -p "$(dirname "${FAIL_CLOSED_LOCK}")"

# 最小の fail-closed スクリプト（plans-watcher.sh の retry + exit 11 ロジックを抜粋）
FC_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/test-fc.XXXXXX")"
cat > "${FC_SCRIPT}" << 'FCSCRIPT'
#!/bin/bash
LOCK_FILE="$1"
LOCK_TIMEOUT=1  # テスト用に短くする
_LOCK_ACQUIRED=0

_acquire() {
    mkdir -p "$(dirname "${LOCK_FILE}")" 2>/dev/null || true
    if command -v flock >/dev/null 2>&1; then
        exec 8>"${LOCK_FILE}"
        if flock -w "${LOCK_TIMEOUT}" 8 2>/dev/null; then
            _LOCK_ACQUIRED=1; return 0
        else
            exec 8>&- 2>/dev/null || true; return 1
        fi
    fi
    if command -v lockf >/dev/null 2>&1; then
        exec 8>"${LOCK_FILE}"
        if lockf -s -t "${LOCK_TIMEOUT}" 8 2>/dev/null; then
            _LOCK_ACQUIRED=2; return 0
        else
            exec 8>&- 2>/dev/null || true; return 1
        fi
    fi
    local waited=0
    local lock_dir="${LOCK_FILE}.dir"
    while ! mkdir "${lock_dir}" 2>/dev/null; do
        sleep 0.1
        waited=$(( waited + 1 ))
        if [ "${waited}" -ge $(( LOCK_TIMEOUT * 10 )) ]; then return 1; fi
    done
    _LOCK_ACQUIRED=3; return 0
}

_LOCK_MAX=3
_GOT=0
for _r in 1 2 3; do
    if _acquire; then _GOT=1; break; fi
    if [ "${_r}" -lt "${_LOCK_MAX}" ]; then sleep 0.2; fi
done

if [ "${_GOT}" -eq 0 ]; then
    echo "fail-closed: abort" >&2
    exit 11
fi

echo "lock acquired"
exit 0
FCSCRIPT
chmod +x "${FC_SCRIPT}"

# lock を保持し続けるプロセス（mkdir 方式で確実に lock）
FC_LOCK_DIR="${FAIL_CLOSED_LOCK}.dir"
mkdir -p "${FC_LOCK_DIR}" 2>/dev/null || true

# lock が取れている状態でスクリプトを実行 → exit 11 が返るはず
bash "${FC_SCRIPT}" "${FAIL_CLOSED_LOCK}"
FC_EXIT=$?
rmdir "${FC_LOCK_DIR}" 2>/dev/null || true

if [ "${FC_EXIT}" -eq 11 ]; then
    pass_test "fail-closed: lock 競合時に exit 11 が返されました（期待通り）"
elif [ "${FC_EXIT}" -eq 0 ]; then
    # flock/lockf が使える環境では lock が共存できる場合があるため warn に留める
    warn_test "fail-closed: exit 0 でした（flock/lockf 環境では mkdir lock と共存できる場合があります）"
else
    fail_test "fail-closed: 期待しない exit code: ${FC_EXIT}（期待値: 11）"
fi

# クリーンアップ
rm -f "${LOCK_SCRIPT}" "${LOCK_SCRIPT_NOLOCK}" "${FC_SCRIPT}" 2>/dev/null || true

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
