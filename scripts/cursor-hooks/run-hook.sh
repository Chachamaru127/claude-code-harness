#!/bin/bash
# Cursor Hook Wrapper - Node.js v24 stdin evaluation workaround
#
# このスクリプトは stdin を Node.js に渡す際に、
# Node.js が TypeScript として自動評価しないようにします。

set -e

# 引数チェック
if [ $# -ne 1 ]; then
    echo "Usage: $0 <hook-script.js>" >&2
    exit 1
fi

HOOK_SCRIPT="$1"

# stdin を Node.js にパイプ（eval させずに）
exec node "$HOOK_SCRIPT"
