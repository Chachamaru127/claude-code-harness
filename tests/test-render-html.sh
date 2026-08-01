#!/bin/bash
# test-render-html.sh
# Phase 65.1.1 - HTML rendering infrastructure の機械検証
#
# DoD:
#   (a) scripts/render-html.sh が --template / --data / --out の 3 引数で動作
#   (b) templates/html/test-fixture.html.template が {{title}} と
#       {{#sections}}{{name}}{{/sections}} を展開できる
#   (c) 4 ケース (正常 / 空 sections / 不正 JSON / 存在しないテンプレート) を機械検証
#   (d) 出力 HTML は lynx -dump で読める text 構造を持つ (lynx 不在時は HTML 構造で fallback)
#   (e) CSS palette が Claude Harness ブランド (#FAFAFA / #0F0F0F / #F58A4A) を使用
#
# Usage: ./tests/test-render-html.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/render-html.sh"
TEMPLATE_DIR="$PROJECT_ROOT/templates/html"

PASS=0
FAIL=0

pass() {
  echo "  [PASS] $1"
  PASS=$(( PASS + 1 ))
}

fail() {
  echo "  [FAIL] $1"
  FAIL=$(( FAIL + 1 ))
}

# 一時作業領域 (テスト終了時に必ず削除)
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-render-html.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== render-html.sh / test-fixture.html.template の機械検証 ==="
echo ""

# ---- 前提: スクリプトとテンプレートが存在する ----
echo "--- 前提条件 ---"
if [ -x "$SCRIPT" ]; then
  pass "scripts/render-html.sh が実行可能"
else
  fail "scripts/render-html.sh が見つからないか実行可能ではない"
fi

if [ -f "$TEMPLATE_DIR/test-fixture.html.template" ]; then
  pass "templates/html/test-fixture.html.template が存在する"
else
  fail "templates/html/test-fixture.html.template が存在しない"
fi

# テンプレート自身が Claude Harness palette を含むこと (DoD (e))
if [ -f "$TEMPLATE_DIR/test-fixture.html.template" ]; then
  for hex in "#FAFAFA" "#0F0F0F" "#F58A4A"; do
    if grep -qi "$hex" "$TEMPLATE_DIR/test-fixture.html.template"; then
      pass "テンプレートに Claude Harness palette カラー $hex が含まれる"
    else
      fail "テンプレートに Claude Harness palette カラー $hex が含まれない"
    fi
  done
fi
echo ""

# 検査用 helper: lynx が無い場合は HTML 構造チェックで fallback
verify_text_readable() {
  local label="$1"
  local html_path="$2"
  local must_contain="$3"

  if ! [ -f "$html_path" ]; then
    fail "$label: 出力ファイルが存在しないため text 構造を検証できない"
    return
  fi

  if command -v lynx >/dev/null 2>&1; then
    local dump
    dump="$(lynx -dump -nolist "$html_path" 2>/dev/null || true)"
    if grep -q "$must_contain" <<<"$dump"; then
      pass "$label: lynx -dump で '$must_contain' が読める"
    else
      fail "$label: lynx -dump で '$must_contain' が読めない"
    fi
  else
    # lynx 不在時は HTML 構造の sanity check で代替
    if grep -qi '<html' "$html_path" \
      && grep -qi '</html>' "$html_path" \
      && grep -qi '<body' "$html_path" \
      && grep -q "$must_contain" "$html_path"; then
      pass "$label: HTML 構造健全 + '$must_contain' を含む (lynx 不在のため fallback)"
    else
      fail "$label: HTML 構造または期待文字列 '$must_contain' が欠落 (lynx 不在 fallback)"
    fi
  fi
}

# ---- Case 1: 正常 (title + sections 2 件) ----
echo "--- Case 1: 正常データ ---"
CASE1_DATA="$TMP_DIR/case1.json"
CASE1_OUT="$TMP_DIR/case1.html"
cat > "$CASE1_DATA" <<'JSON'
{
  "kind": "plan-brief",
  "project": "test-render-html",
  "generated_at": "2026-05-09T00:00:00Z",
  "title": "Plan Brief Test",
  "sections": [
    {"name": "Section Alpha"},
    {"name": "Section Beta"}
  ]
}
JSON

actual_exit=0
"$SCRIPT" --template test-fixture --data "$CASE1_DATA" --out "$CASE1_OUT" >/dev/null 2>"$TMP_DIR/case1.err" \
  || actual_exit=$?

if [ "$actual_exit" -eq 0 ]; then
  pass "Case 1: exit 0"
else
  fail "Case 1: exit 0 を期待したが $actual_exit (stderr: $(cat "$TMP_DIR/case1.err"))"
fi

if [ -f "$CASE1_OUT" ]; then
  pass "Case 1: 出力 HTML が生成された"

  if grep -q "Plan Brief Test" "$CASE1_OUT"; then
    pass "Case 1: {{title}} が 'Plan Brief Test' に展開された"
  else
    fail "Case 1: {{title}} 展開が確認できない"
  fi

  if grep -q "Section Alpha" "$CASE1_OUT" && grep -q "Section Beta" "$CASE1_OUT"; then
    pass "Case 1: {{#sections}}{{name}}{{/sections}} が 2 件展開された"
  else
    fail "Case 1: sections 展開が確認できない"
  fi

  # 残骸 mustache マーカーが無いこと
  if grep -qE '\{\{[^}]+\}\}' "$CASE1_OUT"; then
    fail "Case 1: 残った {{...}} マーカーが検出された"
  else
    pass "Case 1: 未展開の {{...}} 残骸なし"
  fi

  verify_text_readable "Case 1" "$CASE1_OUT" "Plan Brief Test"
else
  fail "Case 1: 出力 HTML が生成されない"
fi
echo ""

# ---- Case 2: 空 sections ----
echo "--- Case 2: 空 sections ---"
CASE2_DATA="$TMP_DIR/case2.json"
CASE2_OUT="$TMP_DIR/case2.html"
cat > "$CASE2_DATA" <<'JSON'
{
  "kind": "plan-brief",
  "project": "test-render-html",
  "generated_at": "2026-05-09T00:00:00Z",
  "title": "Empty Sections Page",
  "sections": []
}
JSON

actual_exit=0
"$SCRIPT" --template test-fixture --data "$CASE2_DATA" --out "$CASE2_OUT" >/dev/null 2>"$TMP_DIR/case2.err" \
  || actual_exit=$?

if [ "$actual_exit" -eq 0 ]; then
  pass "Case 2: exit 0 (空 sections は正常系)"
else
  fail "Case 2: exit 0 を期待したが $actual_exit"
fi

if [ -f "$CASE2_OUT" ]; then
  if grep -q "Empty Sections Page" "$CASE2_OUT"; then
    pass "Case 2: title は展開された"
  else
    fail "Case 2: title 展開なし"
  fi

  # セクションブロックが完全に除去 (Section Alpha 等は含まれない)
  if grep -q "Section Alpha" "$CASE2_OUT" || grep -q "Section Beta" "$CASE2_OUT"; then
    fail "Case 2: 空 sections なのに前回の item 文字列が出ている"
  else
    pass "Case 2: 空配列で section item が出力されない"
  fi

  if grep -qE '\{\{[^}]+\}\}' "$CASE2_OUT"; then
    fail "Case 2: 残った {{...}} マーカーが検出された"
  else
    pass "Case 2: 未展開の {{...}} 残骸なし"
  fi
else
  fail "Case 2: 出力 HTML が生成されない"
fi
echo ""

# ---- Case 3: 不正 JSON ----
echo "--- Case 3: 不正 JSON ---"
CASE3_DATA="$TMP_DIR/case3.json"
CASE3_OUT="$TMP_DIR/case3.html"
echo "{not valid json" > "$CASE3_DATA"

actual_exit=0
"$SCRIPT" --template test-fixture --data "$CASE3_DATA" --out "$CASE3_OUT" >/dev/null 2>"$TMP_DIR/case3.err" \
  || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  pass "Case 3: 不正 JSON で non-zero exit ($actual_exit)"
else
  fail "Case 3: 不正 JSON でも exit 0 になっている"
fi

if [ -f "$CASE3_OUT" ]; then
  fail "Case 3: 不正 JSON なのに出力ファイルが生成された"
else
  pass "Case 3: 出力ファイル非生成 (失敗時の副作用なし)"
fi
echo ""

# ---- Case 4: 存在しないテンプレート ----
echo "--- Case 4: 存在しないテンプレート ---"
CASE4_DATA="$TMP_DIR/case4.json"
CASE4_OUT="$TMP_DIR/case4.html"
echo '{"title":"x","sections":[]}' > "$CASE4_DATA"

actual_exit=0
"$SCRIPT" --template definitely-does-not-exist-xyz --data "$CASE4_DATA" --out "$CASE4_OUT" \
  >/dev/null 2>"$TMP_DIR/case4.err" || actual_exit=$?

if [ "$actual_exit" -ne 0 ]; then
  pass "Case 4: 存在しないテンプレートで non-zero exit ($actual_exit)"
else
  fail "Case 4: 存在しないテンプレートでも exit 0"
fi

if [ -f "$CASE4_OUT" ]; then
  fail "Case 4: 存在しないテンプレートなのに出力ファイルが生成された"
else
  pass "Case 4: 出力ファイル非生成"
fi
echo ""

# ---- Case 5: データ値に {{...}} を含む — 二重展開してはいけない ----
echo "--- Case 5: 値に {{var}} 文字列が含まれる場合の二重展開回避 ---"
CASE5_DATA="$TMP_DIR/case5.json"
CASE5_OUT="$TMP_DIR/case5.html"
cat > "$CASE5_DATA" <<'JSON'
{
  "kind": "plan-brief",
  "project": "test-render-html",
  "generated_at": "2026-05-09T00:00:00Z",
  "title": "Literal {{title}} Should Stay Literal",
  "sections": [
    {"name": "{{title}} should NOT recurse"},
    {"name": "Plain section"}
  ]
}
JSON

actual_exit=0
"$SCRIPT" --template test-fixture --data "$CASE5_DATA" --out "$CASE5_OUT" >/dev/null 2>"$TMP_DIR/case5.err" \
  || actual_exit=$?

if [ "$actual_exit" -eq 0 ]; then
  pass "Case 5: exit 0"
else
  fail "Case 5: exit 0 を期待したが $actual_exit"
fi

if [ -f "$CASE5_OUT" ]; then
  # title 自身に {{title}} という literal が含まれており、出力にもそのまま残っているべき
  if grep -q "Literal {{title}} Should Stay Literal" "$CASE5_OUT"; then
    pass "Case 5: title 内 literal '{{title}}' が再帰展開されずに保持された"
  else
    fail "Case 5: title 内 literal '{{title}}' が消失または再帰展開された"
  fi

  if grep -q "{{title}} should NOT recurse" "$CASE5_OUT"; then
    pass "Case 5: section value 内 literal '{{title}}' が再帰展開されずに保持された"
  else
    fail "Case 5: section value 内 literal '{{title}}' が消失または再帰展開された"
  fi

  if grep -q "Plain section" "$CASE5_OUT"; then
    pass "Case 5: 通常 section も同時に展開された (regression なし)"
  else
    fail "Case 5: 通常 section の展開が失敗"
  fi
else
  fail "Case 5: 出力 HTML が生成されない"
fi
echo ""

# ---- Case 6: 値に制御文字 \x01 を含む — sentinel 衝突回避の検証 ----
echo "--- Case 6: data 値に制御文字 \\x01 を含む場合の sentinel 衝突回避 ---"
CASE6_DATA="$TMP_DIR/case6.json"
CASE6_OUT="$TMP_DIR/case6.html"
# JSON  = ASCII SOH (0x01)。3 バイト sentinel ならデータ値の \x01 と衝突しない。
# value: "alpha[SOH]beta" を流して、出力にも \x01 がそのまま残ること、
# かつ `{` が誤って混入していないことを検証する。
printf '{"title": "alpha\\u0001beta", "sections": []}' > "$CASE6_DATA"

actual_exit=0
"$SCRIPT" --template test-fixture --data "$CASE6_DATA" --out "$CASE6_OUT" >/dev/null 2>"$TMP_DIR/case6.err" \
  || actual_exit=$?

if [ "$actual_exit" -eq 0 ]; then
  pass "Case 6: exit 0"
else
  fail "Case 6: exit 0 を期待したが $actual_exit"
fi

if [ -f "$CASE6_OUT" ]; then
  # title 内の \x01 byte が保持されているか (= sentinel 衝突で `{` に化けていないこと)
  if grep -F "alpha"$'\x01'"beta" "$CASE6_OUT" >/dev/null 2>&1; then
    pass "Case 6: data 値内の \\x01 byte が保持された (sentinel 衝突なし)"
  else
    fail "Case 6: data 値内の \\x01 が誤変換された可能性 (sentinel 衝突)"
  fi

  # 誤って `{` に化けていないこと (alpha{beta が出力に出ていないこと)
  if grep -F "alpha{beta" "$CASE6_OUT" >/dev/null 2>&1; then
    fail "Case 6: data 値内の \\x01 が `{` に誤変換された (sentinel 衝突発生)"
  else
    pass "Case 6: 誤変換 'alpha{beta' は出力に存在しない"
  fi
else
  fail "Case 6: 出力 HTML が生成されない"
fi
echo ""

# ---- 結果 ----
TOTAL=$(( PASS + FAIL ))
echo "=== 結果: $PASS/$TOTAL PASS ==="
if [ "$FAIL" -gt 0 ]; then
  echo "FAILED: $FAIL テストが失敗しました"
  exit 1
fi
echo "All tests passed."
exit 0
