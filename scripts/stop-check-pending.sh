#!/bin/bash
# stop-check-pending.sh
# Stop 時に未解消の pending-skills をチェックして警告
#
# Usage: Stop hook から自動実行（type: command）
# Input: stdin JSON (Claude Code hooks)
# Output: 人間向けテキスト警告（stdoutに直接出力）

set +e

STATE_DIR=".claude/state"
PENDING_DIR="${STATE_DIR}/pending-skills"

# pending ディレクトリが無ければ何も出力せず終了
if [ ! -d "$PENDING_DIR" ]; then
  exit 0
fi

# pending ファイルをチェック
PENDING_FILES=$(ls "$PENDING_DIR"/*.pending 2>/dev/null || true)

if [ -z "$PENDING_FILES" ]; then
  exit 0
fi

# 未解消の pending がある場合
PENDING_COMMANDS=""
for f in $PENDING_FILES; do
  CMD_NAME=$(basename "$f" .pending)
  PENDING_COMMANDS="${PENDING_COMMANDS}${CMD_NAME}, "
done
PENDING_COMMANDS=$(echo "$PENDING_COMMANDS" | sed 's/, $//')

# pending をクリア（警告済み）
rm -f "$PENDING_DIR"/*.pending 2>/dev/null || true

# 人間向けテキスト警告を stdout に出力
cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  品質ゲート未実行の警告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

以下のコマンドが実行されましたが、対応するSkillが呼び出されませんでした:
  → ${PENDING_COMMANDS}

これにより以下の問題が発生する可能性があります:
  1. 使用統計の欠損: Skills の使用履歴が記録されていません
  2. 品質ガードレール未実行: レビュー・検証スキルが適用されていない可能性

推奨: 手動で /harness-review を実行して品質チェックを行ってください。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

exit 0
