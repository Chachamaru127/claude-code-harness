#!/usr/bin/env bash
# scripts/render-html.sh
# Phase 65.1.1 - HTML template renderer (mustache 風) + jq によるデータバインド
#
# Usage:
#   render-html.sh --template <name> --data <json_path|-> --out <output_path>
#
# 構文:
#   {{var}}                       … data の top-level scalar を参照
#   {{#section}}...{{/section}}   … data[section] (配列) で iterate し、
#                                   ブロック内の {{key}} は item の field を参照
#
# 入力 JSON は html-render-input.v1 schema (kind / project / generated_at / sections)
# が canonical だが、MVP では「parseable な JSON であれば accept」する soft validation。
# テンプレートに書かれていない field は無視され、書かれていて data に欠ける field は
# 空文字に展開される (jq の // "" で fallback)。
#
# テンプレート格納先: templates/html/<name>.html.template
# 出力 HTML は単独で開ける (no server, no JS framework)、CSS は inline 想定。
# Claude Harness ブランド (off-white #FAFAFA / near-black #0F0F0F / harness-orange #F58A4A)
# をテンプレート側で利用する。

set -euo pipefail

# awk は byte offset を返すが、bash の ${var:offset:length} は locale 依存で
# UTF-8 multi-byte を 1 文字と数える。両者を整合させるため byte 単位 (LC_ALL=C) に固定。
# 出力 HTML はバイト列を透過コピーするだけなので、UTF-8 は正しく保たれる。
export LC_ALL=C

usage() {
  cat <<USAGE >&2
Usage: $0 --template <name> --data <json_path|-> --out <output_path>

Arguments:
  --template <name>       テンプレート basename (拡張子 .html.template を除く)
                          templates/html/<name>.html.template を読みに行く
  --data <json_path|->    JSON データファイル (- で stdin から読む)
  --out <output_path>     出力 HTML の destination
USAGE
  exit 2
}

TEMPLATE_NAME=""
DATA_PATH=""
OUT_PATH=""
WITH_REDACTION="false"
CLIENT_DICT_PATH=""
AUDIT_GROUP=""
AUDIT_MEMBERS=""
AUDIT_QUERY_HASH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)         TEMPLATE_NAME="${2:-}"; shift 2 ;;
    --data)             DATA_PATH="${2:-}";     shift 2 ;;
    --out)              OUT_PATH="${2:-}";      shift 2 ;;
    --with-redaction)   WITH_REDACTION="true";  shift 1 ;;
    --client-dict)      CLIENT_DICT_PATH="${2:-}"; shift 2 ;;
    --audit-group)      AUDIT_GROUP="${2:-}";   shift 2 ;;
    --audit-members)    AUDIT_MEMBERS="${2:-}"; shift 2 ;;
    --audit-query-hash) AUDIT_QUERY_HASH="${2:-}"; shift 2 ;;
    -h|--help)          usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

if [[ -z "$TEMPLATE_NAME" || -z "$DATA_PATH" || -z "$OUT_PATH" ]]; then
  echo "ERROR: --template / --data / --out のいずれかが未指定です" >&2
  usage
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq が見つかりません。jq をインストールしてください。" >&2
  exit 5
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_PATH="$PLUGIN_ROOT/templates/html/${TEMPLATE_NAME}.html.template"

if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "ERROR: template not found: $TEMPLATE_PATH" >&2
  exit 3
fi

# JSON データを normalized なファイルに保存 (- は stdin、それ以外はそのファイル)
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/render-html.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
DATA_FILE="$TMP_DIR/data.json"

if [[ "$DATA_PATH" == "-" ]]; then
  cat > "$DATA_FILE"
else
  if [[ ! -f "$DATA_PATH" ]]; then
    echo "ERROR: data file not found: $DATA_PATH" >&2
    exit 3
  fi
  cp "$DATA_PATH" "$DATA_FILE"
fi

if ! jq -e '.' "$DATA_FILE" >/dev/null 2>&1; then
  echo "ERROR: invalid JSON in data file (jq failed to parse)" >&2
  exit 4
fi

# --- 内部関数 ---

# テンプレート内で「最初に見つかる {{#tag}}...{{/tag}}」の位置情報を返す。
# 出力: "<open_offset> <open_len> <block_len> <tag_name>" または空文字 (見つからない場合)。
#   open_offset … {{#tag}} が始まる 0-based byte offset
#   open_len    … "{{#tag}}" 自体の長さ
#   block_len   … {{#tag}} と {{/tag}} の間の block 部分の長さ
#   tag_name    … tag の識別子
find_first_section() {
  local content="$1"
  printf '%s' "$content" | awk '
    # BSD awk は RS="\0" を空文字 (= paragraph mode) に解釈し leading newline を消すので、
    # 入力に絶対現れないセンチネル文字列を RS に置く (実質 EOF まで 1 record)。
    BEGIN { RS = "__RENDER_HTML_AWK_RS_SENTINEL_NEVER_OCCURS__"; }
    {
      if (match($0, /\{\{#[a-zA-Z_][a-zA-Z_0-9]*\}\}/)) {
        open_start = RSTART
        open_len = RLENGTH
        tag = substr($0, RSTART + 3, RLENGTH - 5)
        rest = substr($0, RSTART + RLENGTH)
        close_marker = "{{/" tag "}}"
        cp = index(rest, close_marker)
        if (cp > 0) {
          printf "%d %d %d %s", open_start - 1, open_len, cp - 1, tag
        }
      }
    }
  '
}

# テンプレート内で「最初に見つかる {{var}}」の位置情報を返す。
# 出力: "<offset> <length> <var_name>" または空文字。
find_first_var() {
  local content="$1"
  printf '%s' "$content" | awk '
    # BSD awk は RS="\0" を空文字 (= paragraph mode) に解釈し leading newline を消すので、
    # 入力に絶対現れないセンチネル文字列を RS に置く (実質 EOF まで 1 record)。
    BEGIN { RS = "__RENDER_HTML_AWK_RS_SENTINEL_NEVER_OCCURS__"; }
    {
      if (match($0, /\{\{[a-zA-Z_][a-zA-Z_0-9]*\}\}/)) {
        printf "%d %d %s", RSTART - 1, RLENGTH, substr($0, RSTART + 2, RLENGTH - 4)
      }
    }
  '
}

# data_file の top-level の var を文字列で取得 (存在しなければ空文字)
lookup_top_var() {
  local var="$1"
  jq -r --arg k "$var" '.[$k] // "" | tostring' "$DATA_FILE"
}

# section 内の item (JSON) から var を文字列で取得
lookup_item_var() {
  local item_json="$1"
  local var="$2"
  printf '%s' "$item_json" | jq -r --arg k "$var" '.[$k] // "" | tostring'
}

# 二重展開防止用の escape sentinel。data 値由来の `{` を SENTINEL に置換しておくと、
# その値の中に `{{...}}` が含まれていても段階1/2 のどちらの awk pattern にもマッチしない。
# 全展開が完了した後に SENTINEL を `{` に戻して原文を復元する。
#
# 3 バイト列 (SOH + STX + ETX) を採用し、データ値内に既存する確率を実用上ゼロに抑える。
# 1 バイト sentinel だと JSON が `` を含む場合に最終復元で誤変換が起きうるため避ける。
SENTINEL_OPEN_BRACE=$'\x01\x02\x03'

escape_val_for_embed() {
  # data 値内の `{` を SENTINEL に置換 (二重展開防止)
  local v="$1"
  printf '%s' "${v//\{/$SENTINEL_OPEN_BRACE}"
}

# block を 1 item で render: ブロック内の各 {{var}} を item.var で置換。
render_block_with_item() {
  local block="$1"
  local item_json="$2"

  local rendered="$block"
  while :; do
    local info
    info="$(find_first_var "$rendered")"
    [[ -z "$info" ]] && break

    local off len var
    off="$(echo "$info" | awk '{print $1}')"
    len="$(echo "$info" | awk '{print $2}')"
    var="$(echo "$info" | awk '{print $3}')"

    local val val_safe
    val="$(lookup_item_var "$item_json" "$var")"
    val_safe="$(escape_val_for_embed "$val")"

    rendered="${rendered:0:off}${val_safe}${rendered:$((off + len))}"
  done

  printf '%s' "$rendered"
}

# --- 段階1: section blocks を展開 ---
TEMPLATE_CONTENT="$(cat "$TEMPLATE_PATH")"

while :; do
  info="$(find_first_section "$TEMPLATE_CONTENT")"
  [[ -z "$info" ]] && break

  open_off="$(echo "$info" | awk '{print $1}')"
  open_len="$(echo "$info" | awk '{print $2}')"
  block_len="$(echo "$info" | awk '{print $3}')"
  tag_name="$(echo "$info" | awk '{print $4}')"

  prefix="${TEMPLATE_CONTENT:0:open_off}"
  block="${TEMPLATE_CONTENT:$((open_off + open_len)):block_len}"
  # 5 は close marker `{{/<tag>}}` のうち tag を除いた固定 5 文字 (`{{/` + `}}`)
  suffix_off=$((open_off + open_len + block_len + ${#tag_name} + 5))
  suffix="${TEMPLATE_CONTENT:$suffix_off}"

  # data[tag_name] が配列でない (または欠落) ときは空配列扱い
  items_count="$(jq -r --arg t "$tag_name" '
    if (.[$t] | type) == "array" then (.[$t] | length) else 0 end
  ' "$DATA_FILE")"

  rendered_section=""
  if [[ "$items_count" -gt 0 ]]; then
    for ((i = 0; i < items_count; i++)); do
      item_json="$(jq -c --arg t "$tag_name" --argjson i "$i" '.[$t][$i]' "$DATA_FILE")"
      rendered_block="$(render_block_with_item "$block" "$item_json")"
      rendered_section="${rendered_section}${rendered_block}"
    done
  fi

  TEMPLATE_CONTENT="${prefix}${rendered_section}${suffix}"
done

# --- 段階2: top-level {{var}} を展開 (val 内の {{...}} は escape して再展開を防ぐ) ---
while :; do
  info="$(find_first_var "$TEMPLATE_CONTENT")"
  [[ -z "$info" ]] && break

  off="$(echo "$info" | awk '{print $1}')"
  len="$(echo "$info" | awk '{print $2}')"
  var="$(echo "$info" | awk '{print $3}')"

  val="$(lookup_top_var "$var")"
  val_safe="$(escape_val_for_embed "$val")"

  TEMPLATE_CONTENT="${TEMPLATE_CONTENT:0:off}${val_safe}${TEMPLATE_CONTENT:$((off + len))}"
done

# 全展開完了 — SENTINEL を `{` に復元して原文を取り戻す。
# bash 3.2 の `${var//SEARCH/REPLACE}` で `\{` を replacement に書くと
# backslash がリテラル挿入されるため、リテラル `{` を変数経由で渡す。
LITERAL_OPEN_BRACE="{"
TEMPLATE_CONTENT="${TEMPLATE_CONTENT//$SENTINEL_OPEN_BRACE/$LITERAL_OPEN_BRACE}"

# --- Layer 2/3 Redaction (Phase 65.3.4 / D43) + Phase 65.3.6 audit ---
# --with-redaction 有効時、HTML 出力直前に 3 段順次:
#   Layer 2a: redact-by-dictionary.sh (literal 固有名詞)
#   Layer 2b: redact-by-ner.sh (Japanese tokenizer)
#   Layer 3 : final scan (カタカナ 5 文字以上連続を残骸として検出)
# Layer 3 で検出時は HTML を**書かず exit 1**、stderr に detected token を出力。
# Phase 65.3.6: --audit-group 指定時は監査ログ append + HTML 末尾に redaction
# サマリ表示。
DICT_COUNT=0
NER_COUNT=0
PASSED_FINAL_SCAN="true"
if [[ "$WITH_REDACTION" == "true" ]]; then
  REDACTION_LOG="$TMP_DIR/redaction.log"
  : > "$REDACTION_LOG"
  DICT_LOG="$TMP_DIR/dict.log"
  NER_LOG="$TMP_DIR/ner.log"

  # Layer 2a: dict (--client-dict 指定時はそれを、なければ default SSOT)
  if [[ -n "$CLIENT_DICT_PATH" ]]; then
    TEMPLATE_CONTENT="$(printf '%s' "$TEMPLATE_CONTENT" | bash "$SCRIPT_DIR/redact-by-dictionary.sh" --stdin --dict "$CLIENT_DICT_PATH" 2>"$DICT_LOG" || true)"
  else
    TEMPLATE_CONTENT="$(printf '%s' "$TEMPLATE_CONTENT" | bash "$SCRIPT_DIR/redact-by-dictionary.sh" --stdin 2>"$DICT_LOG" || true)"
  fi
  cat "$DICT_LOG" >> "$REDACTION_LOG"

  # parse "redacted: N tokens" from dict stderr
  if grep -q "redacted:" "$DICT_LOG" 2>/dev/null; then
    DICT_COUNT="$(awk '/redacted:/ {print $2}' "$DICT_LOG" | head -1)"
    DICT_COUNT="${DICT_COUNT:-0}"
  fi

  # Layer 2b: NER
  TEMPLATE_CONTENT="$(printf '%s' "$TEMPLATE_CONTENT" | bash "$SCRIPT_DIR/redact-by-ner.sh" --stdin 2>"$NER_LOG" || true)"
  cat "$NER_LOG" >> "$REDACTION_LOG"

  # parse "redacted: N entities" from NER stderr
  if grep -q "redacted:" "$NER_LOG" 2>/dev/null; then
    NER_COUNT="$(awk '/redacted:/ {print $2}' "$NER_LOG" | head -1)"
    NER_COUNT="${NER_COUNT:-0}"
  fi

  # Layer 3: final scan
  set +e
  printf '%s' "$TEMPLATE_CONTENT" | python3 "$SCRIPT_DIR/final-scan-redaction.py"
  FINAL_SCAN_EXIT=$?
  set -e

  if [[ $FINAL_SCAN_EXIT -ne 0 ]]; then
    PASSED_FINAL_SCAN="false"
    # 監査ログには「failed」を残してから abort する (Plans.md DoD e の
    # 「final scan 失敗」ケース対応)
    if [[ -n "$AUDIT_GROUP" && -n "$AUDIT_QUERY_HASH" ]]; then
      bash "$SCRIPT_DIR/cross-project-audit-log.sh" \
        --group "$AUDIT_GROUP" \
        --members "${AUDIT_MEMBERS:-}" \
        --query-hash "$AUDIT_QUERY_HASH" \
        --dict-count "$DICT_COUNT" \
        --ner-count "$NER_COUNT" \
        --passed-final-scan "false" 2>>"$REDACTION_LOG" || true
    fi
    echo "ERROR: Layer 3 final scan detected residue (HTML generation aborted)" >&2
    exit 1
  fi

  # --- HTML 末尾に redaction サマリを表示 (Plans.md §65.3.6 DoD d) ---
  # </body> の直前に footer を挿入。</body> がない場合は末尾に append。
  AUDIT_FOOTER="<div class=\"audit-summary\" style=\"margin-top:2em;padding:0.6em 0.8em;border-top:1px solid #ccc;font-size:0.85em;color:#666;\">redacted: dict ${DICT_COUNT} 件 + NER ${NER_COUNT} 件</div>"
  # bash parameter substitution: pattern の '/' は最初の 1 つのみ separator、
  # 以降は literal。replacement 内の '<\/body>' は literal な「<\/body>」になるので
  # 必ず '</body>' (backslash なし) を書く。
  # herestring を使う (パイプにしない)。`printf ... | grep -q` は grep が最初の一致で
  # 終了してパイプを閉じるため、printf の残りの write が EPIPE になり、pipefail が
  # それをパイプライン全体の失敗に昇格させる。今は </body> がテンプレート末尾にあり
  # grep が全量を読むので顕在化しないが、前方に </body> が現れると footer 挿入が
  # 黙って append 側に落ちる。
  if grep -q "</body>" <<<"$TEMPLATE_CONTENT"; then
    BODY_CLOSE_TAG="</body>"
    TEMPLATE_CONTENT="${TEMPLATE_CONTENT/${BODY_CLOSE_TAG}/${AUDIT_FOOTER}${BODY_CLOSE_TAG}}"
  else
    TEMPLATE_CONTENT="${TEMPLATE_CONTENT}${AUDIT_FOOTER}"
  fi

  # --- audit log append (--audit-group 指定時のみ) ---
  if [[ -n "$AUDIT_GROUP" && -n "$AUDIT_QUERY_HASH" ]]; then
    bash "$SCRIPT_DIR/cross-project-audit-log.sh" \
      --group "$AUDIT_GROUP" \
      --members "${AUDIT_MEMBERS:-}" \
      --query-hash "$AUDIT_QUERY_HASH" \
      --dict-count "$DICT_COUNT" \
      --ner-count "$NER_COUNT" \
      --passed-final-scan "$PASSED_FINAL_SCAN" 2>>"$REDACTION_LOG" || true
  fi
fi

# --- 出力 ---
OUT_DIR="$(dirname "$OUT_PATH")"
mkdir -p "$OUT_DIR"
printf '%s' "$TEMPLATE_CONTENT" > "$OUT_PATH"

# 末尾改行を保証 (テンプレートに改行があればそのまま、無ければ 1 行追加で diff を見やすく)
if [[ "${TEMPLATE_CONTENT: -1}" != $'\n' ]]; then
  printf '\n' >> "$OUT_PATH"
fi

exit 0
