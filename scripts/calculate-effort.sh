#!/bin/bash
# calculate-effort.sh
# Plans.md からタスク情報を読み取り、effort レベルを計算して stdout に出力する。
#
# Usage:
#   bash scripts/calculate-effort.sh "タスク説明またはタスクID"
#   echo "タスク説明" | bash scripts/calculate-effort.sh
#
# Output: low / medium / high（stdout）
#
# スコアリング基準:
#   ファイル変更候補が 4+ → +2
#   依存タスクが 2+ → +1
#   キーワード（refactor, migration, security, cross-cutting）→ +1
#   DoD に複数条件（2+ 件）→ +1
#
# スコア: 0-2 → low, 3-4 → medium, 5+ → high

set -euo pipefail

# 引数または stdin からタスク説明を取得
TASK_INPUT=""
if [ $# -gt 0 ]; then
  TASK_INPUT="$*"
elif [ ! -t 0 ]; then
  # stdin からの入力（パイプ）
  TASK_INPUT="$(cat)"
fi

if [ -z "$TASK_INPUT" ]; then
  # 入力なし → フォールバック
  echo "medium"
  exit 0
fi

# スコア初期化
SCORE=0

# Plans.md のパスを解決（git root → PROJECT_ROOT → cwd の順にフォールバック）
_GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
PLANS_MD="${PROJECT_ROOT:-${_GIT_ROOT:-$(pwd)}}/Plans.md"

# タスク情報を Plans.md から抽出する
# v2 フォーマット想定: | Task | 内容 | DoD | Depends | Status |
TASK_CONTENT=""
TASK_DOD=""
TASK_DEPENDS=""

if [ -f "$PLANS_MD" ]; then
  # タスクIDパターン（#123, 34.2.2, #34.2.2 形式）での検索
  TASK_ID_PATTERN=""
  if grep -qE '^#?[0-9]+(\.[0-9]+)*$' <<<"$TASK_INPUT"; then
    TASK_ID_PATTERN=$(echo "$TASK_INPUT" | tr -d '#')
    # テーブル行をパース: | 番号 | 内容 | DoD | Depends | Status |
    TASK_ROW=$(grep -E "^\|[[:space:]]*${TASK_ID_PATTERN}[[:space:]]*\|" "$PLANS_MD" 2>/dev/null || true)
    if [ -n "$TASK_ROW" ]; then
      # パイプ区切りで列を抽出
      TASK_CONTENT=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')
      TASK_DOD=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4}')
      TASK_DEPENDS=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $5); print $5}')
    fi
  fi

  # タスクIDで見つからない場合、説明文でキーワード検索
  if [ -z "$TASK_CONTENT" ]; then
    # Plans.md 内でタスク説明に近い行を抽出（テーブル行）
    TASK_ROW=$(grep -iF "$(echo "$TASK_INPUT" | cut -c1-50)" "$PLANS_MD" 2>/dev/null | grep "^|" | head -1 || true)
    if [ -n "$TASK_ROW" ]; then
      TASK_CONTENT=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')
      TASK_DOD=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4}')
      TASK_DEPENDS=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $5); print $5}')
    fi
  fi
fi

# Plans.md から取得できなかった場合、タスク入力自体を解析対象にする
if [ -z "$TASK_CONTENT" ]; then
  TASK_CONTENT="$TASK_INPUT"
fi

# 解析対象テキスト（タスク内容 + DoD + 入力テキストを結合）
ANALYSIS_TEXT="${TASK_CONTENT} ${TASK_DOD} ${TASK_INPUT}"

# ---- スコアリング ----

# 1. ファイル変更候補が 4+ → +2
# タスク説明中のファイル参照（.ts .js .sh .json .md .go .py .rb .tsx .jsx）を数える
FILE_REFS=$(echo "$ANALYSIS_TEXT" | { grep -oE '[a-zA-Z0-9_/-]+\.(ts|tsx|js|jsx|sh|json|md|go|py|rb|css|scss|yaml|yml)' || true; } | wc -l | tr -d '[:space:]')
if [ "${FILE_REFS:-0}" -ge 4 ]; then
  SCORE=$((SCORE + 2))
fi

# 2. 依存タスクが 2+ → +1
if [ -n "$TASK_DEPENDS" ]; then
  # Depends 列に含まれる依存タスク数（dotted ID: 34.1.1, 単純 ID: #123, カンマ区切り等）
  # dotted ID を先にカウントし、残りを単純数値 ID としてカウント
  DEP_COUNT=$(echo "$TASK_DEPENDS" | { grep -oE '#?[0-9]+(\.[0-9]+)+' || true; } | wc -l | tr -d '[:space:]')
  SIMPLE_COUNT=$(echo "$TASK_DEPENDS" | sed -E 's/#?[0-9]+(\.[0-9]+)+//g' | { grep -oE '#?[0-9]+' || true; } | wc -l | tr -d '[:space:]')
  DEP_COUNT=$((DEP_COUNT + SIMPLE_COUNT))
  if [ "${DEP_COUNT:-0}" -ge 2 ]; then
    SCORE=$((SCORE + 1))
  fi
fi

# 3. キーワードチェック → +1（1件以上マッチで加算、重複なし）
KEYWORDS="refactor migration security cross-cutting リファクタ 移行 認証 セキュリティ 横断"
KEYWORD_MATCH=0
for kw in $KEYWORDS; do
  if grep -qi "$kw" 2>/dev/null <<<"$ANALYSIS_TEXT"; then
    KEYWORD_MATCH=1
    break
  fi
done
SCORE=$((SCORE + KEYWORD_MATCH))

# 4. DoD に複数条件（2+ 件）→ +1
if [ -n "$TASK_DOD" ]; then
  # セミコロン・読点・カンマで区切られた条件数を数える（区切り文字の数 + 1 が条件数）
  DOD_DELIMITERS=$(echo "$TASK_DOD" | { grep -oE '[;、,]' || true; } | wc -l | tr -d '[:space:]')
  DOD_TOTAL=$(( DOD_DELIMITERS + 1 ))
  if [ "${DOD_TOTAL:-1}" -ge 2 ]; then
    SCORE=$((SCORE + 1))
  fi
fi

# ---- effort 判定 ----
if [ "$SCORE" -ge 5 ]; then
  echo "high"
elif [ "$SCORE" -ge 3 ]; then
  echo "medium"
else
  echo "low"
fi
