#!/usr/bin/env bash
# scripts/render-html.sh
# Phase 65.1.1 - HTML template renderer (mustache-style) + data binding via jq
#
# Usage:
#   render-html.sh --template <name> --data <json_path|-> --out <output_path>
#
# Syntax:
#   {{var}}                       … references a top-level scalar in data
#   {{#section}}...{{/section}}   … iterates over data[section] (array);
#                                   {{key}} inside the block references item fields
#
# Input JSON uses the html-render-input.v1 schema (kind / project / generated_at / sections)
# as the canonical form, but in MVP mode accepts any parseable JSON (soft validation).
# Fields present in the template but absent from data expand to empty string (jq // "" fallback).
# Fields present in data but absent from the template are ignored.
#
# Template location: templates/html/<name>.html.template
# Output HTML is self-contained (no server, no JS framework); CSS is expected to be inline.
# Claude Harness brand colors (off-white #FAFAFA / near-black #0F0F0F / harness-orange #F58A4A)
# are available for use in templates.

set -euo pipefail

# awk returns byte offsets, but bash's ${var:offset:length} is locale-dependent and
# counts UTF-8 multi-byte sequences as single characters. To reconcile both, fix to
# byte-level processing (LC_ALL=C). Since the output HTML is a transparent byte copy,
# UTF-8 content is preserved correctly.
export LC_ALL=C

usage() {
  cat <<USAGE >&2
Usage: $0 --template <name> --data <json_path|-> --out <output_path>

Arguments:
  --template <name>       Template basename (without the .html.template extension);
                          reads from templates/html/<name>.html.template
  --data <json_path|->    JSON data file (use - to read from stdin)
  --out <output_path>     Destination for the output HTML
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
  echo "ERROR: one or more of --template / --data / --out is not specified" >&2
  usage
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found. Please install jq." >&2
  exit 5
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_PATH="$PLUGIN_ROOT/templates/html/${TEMPLATE_NAME}.html.template"

if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "ERROR: template not found: $TEMPLATE_PATH" >&2
  exit 3
fi

# Save JSON data to a normalized file (- means stdin; otherwise use that file)
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

# --- Internal functions ---

# Returns position info for the first {{#tag}}...{{/tag}} found in the template.
# Output: "<open_offset> <open_len> <block_len> <tag_name>" or empty string (if not found).
#   open_offset … 0-based byte offset where {{#tag}} begins
#   open_len    … length of "{{#tag}}" itself
#   block_len   … length of the block between {{#tag}} and {{/tag}}
#   tag_name    … the tag identifier
find_first_section() {
  local content="$1"
  printf '%s' "$content" | awk '
    # BSD awk interprets RS="\0" as empty string (= paragraph mode) and strips leading newlines,
    # so set RS to a sentinel string that will never appear in input (effectively one record until EOF).
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

# Returns position info for the first {{var}} found in the template.
# Output: "<offset> <length> <var_name>" or empty string.
find_first_var() {
  local content="$1"
  printf '%s' "$content" | awk '
    # BSD awk interprets RS="\0" as empty string (= paragraph mode) and strips leading newlines,
    # so set RS to a sentinel string that will never appear in input (effectively one record until EOF).
    BEGIN { RS = "__RENDER_HTML_AWK_RS_SENTINEL_NEVER_OCCURS__"; }
    {
      if (match($0, /\{\{[a-zA-Z_][a-zA-Z_0-9]*\}\}/)) {
        printf "%d %d %s", RSTART - 1, RLENGTH, substr($0, RSTART + 2, RLENGTH - 4)
      }
    }
  '
}

# Get a top-level var from data_file as a string (empty string if not present)
lookup_top_var() {
  local var="$1"
  jq -r --arg k "$var" '.[$k] // "" | tostring' "$DATA_FILE"
}

# Get a var from an item (JSON) inside a section as a string
lookup_item_var() {
  local item_json="$1"
  local var="$2"
  printf '%s' "$item_json" | jq -r --arg k "$var" '.[$k] // "" | tostring'
}

# Escape sentinel to prevent double expansion. By replacing `{` from data values with SENTINEL,
# any `{{...}}` inside those values will not match the awk patterns in either stage 1 or 2.
# After all expansion is complete, SENTINEL is restored back to `{` to recover the original text.
#
# A 3-byte sequence (SOH + STX + ETX) is used to make the probability of it appearing in
# data values virtually zero. A single-byte sentinel could cause incorrect restoration in
SENTINEL_OPEN_BRACE=$'\x01\x02\x03'

escape_val_for_embed() {
  # Replace `{` in data values with SENTINEL (prevents double expansion)
  local v="$1"
  printf '%s' "${v//\{/$SENTINEL_OPEN_BRACE}"
}

# Render a block with one item: replace each {{var}} in the block with item.var.
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

# --- Stage 1: expand section blocks ---
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
  # 5 is the fixed 5-character overhead of the close marker `{{/<tag>}}` excluding the tag (`{{/` + `}}`)
  suffix_off=$((open_off + open_len + block_len + ${#tag_name} + 5))
  suffix="${TEMPLATE_CONTENT:$suffix_off}"

  # Treat data[tag_name] as empty array when it is not an array (or is absent)
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

# --- Stage 2: expand top-level {{var}} (escape {{...}} inside values to prevent re-expansion) ---
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

# All expansion complete — restore SENTINEL back to `{` to recover the original text.
# In bash 3.2, writing `\{` as the replacement in `${var//SEARCH/REPLACE}` inserts a literal
# backslash, so pass the literal `{` via a variable.
LITERAL_OPEN_BRACE="{"
TEMPLATE_CONTENT="${TEMPLATE_CONTENT//$SENTINEL_OPEN_BRACE/$LITERAL_OPEN_BRACE}"

# --- Layer 2/3 Redaction (Phase 65.3.4 / D43) + Phase 65.3.6 audit ---
# When --with-redaction is enabled, apply 3 sequential stages immediately before HTML output:
#   Layer 2a: redact-by-dictionary.sh (literal proper nouns)
#   Layer 2b: redact-by-ner.sh (Japanese tokenizer)
#   Layer 3 : final scan (detect runs of 5+ katakana characters as residue)
# If Layer 3 detects residue, **do not write HTML and exit 1**; output detected tokens to stderr.
# Phase 65.3.6: when --audit-group is specified, append to audit log + display redaction
# summary at the bottom of the HTML.
DICT_COUNT=0
NER_COUNT=0
PASSED_FINAL_SCAN="true"
if [[ "$WITH_REDACTION" == "true" ]]; then
  REDACTION_LOG="$TMP_DIR/redaction.log"
  : > "$REDACTION_LOG"
  DICT_LOG="$TMP_DIR/dict.log"
  NER_LOG="$TMP_DIR/ner.log"

  # Layer 2a: dict (use --client-dict path when specified; otherwise use the default SSOT)
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
    # Write "failed" to the audit log before aborting (handles the Plans.md DoD e
    # "final scan failure" case)
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

  # --- Display redaction summary at the bottom of HTML (Plans.md §65.3.6 DoD d) ---
  # Insert footer just before </body>. If </body> is absent, append at the end.
  AUDIT_FOOTER="<div class=\"audit-summary\" style=\"margin-top:2em;padding:0.6em 0.8em;border-top:1px solid #ccc;font-size:0.85em;color:#666;\">redacted: dict ${DICT_COUNT} + NER ${NER_COUNT}</div>"
  # bash parameter substitution: '/' in the pattern is only a separator for the first occurrence;
  # subsequent '/' are literal. Writing '<\/body>' in the replacement produces a literal '<\/body>',
  # so always use '</body>' (no backslash).
  if printf '%s' "$TEMPLATE_CONTENT" | grep -q "</body>"; then
    BODY_CLOSE_TAG="</body>"
    TEMPLATE_CONTENT="${TEMPLATE_CONTENT/${BODY_CLOSE_TAG}/${AUDIT_FOOTER}${BODY_CLOSE_TAG}}"
  else
    TEMPLATE_CONTENT="${TEMPLATE_CONTENT}${AUDIT_FOOTER}"
  fi

  # --- Append to audit log (only when --audit-group is specified) ---
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

# --- Output ---
OUT_DIR="$(dirname "$OUT_PATH")"
mkdir -p "$OUT_DIR"
printf '%s' "$TEMPLATE_CONTENT" > "$OUT_PATH"

# Ensure trailing newline (preserved if template already has one; otherwise add one for cleaner diffs)
if [[ "${TEMPLATE_CONTENT: -1}" != $'\n' ]]; then
  printf '\n' >> "$OUT_PATH"
fi

exit 0
