#!/bin/bash
# session-list.sh
# アクティブセッション一覧を表示（canonical: harness session list）
#
# 使用方法:
#   ./session-list.sh
#
# 出力: 共有 live-sessions チームビュー（label / task / since / elapsed）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HARNESS="${ROOT}/bin/harness"

if [ -x "${HARNESS}" ]; then
  exec "${HARNESS}" session list "$@"
fi

if command -v harness >/dev/null 2>&1; then
  exec harness session list "$@"
fi

echo "session-list: harness binary not found (expected ${HARNESS})" >&2
exit 1
