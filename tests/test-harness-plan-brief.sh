#!/bin/bash
# tests/test-harness-plan-brief.sh
# Phase 65.1.2 - harness-plan-brief skill の機械検証
#
# 検証観点:
#   1. SKILL.md が存在し、frontmatter が skill-editing.md 規約準拠
#   2. SKILL.md が `mcp__harness__harness_mem_search` を project enforcement で呼ぶよう指示
#   3. SKILL.md が cross-project search を禁止 (`strict_project: true` を要求)
#   4. JSON Schema が valid な JSON Schema として parse 可能
#   5. fixture が JSON Schema validator で valid (Python jsonschema 優先 → 構造的 jq fallback)
#   6. render-html.sh で plan-brief.html.template が正常 render できる
#   7. plan-brief-open.sh が BROWSER=true で skip し path だけ stdout 出力する
#   8. plan-brief-open.sh が存在しないパスで exit 2 を返す

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SKILL_PATH="$ROOT_DIR/skills/harness-plan-brief/SKILL.md"
SCHEMA_PATH="$ROOT_DIR/skills/harness-plan-brief/schemas/plan-brief-context.v1.schema.json"
TEMPLATE_PATH="$ROOT_DIR/templates/html/plan-brief.html.template"
RENDER_SCRIPT="$ROOT_DIR/scripts/render-html.sh"
OPEN_SCRIPT="$ROOT_DIR/scripts/plan-brief-open.sh"
FIXTURE_PATH="$ROOT_DIR/tests/fixtures/plan-brief-e2e/sample-context.json"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() {
  PASS=$((PASS + 1))
  echo "✓ $1"
}

fail() {
  FAIL=$((FAIL + 1))
  FAIL_MESSAGES+=("$1")
  echo "✗ $1" >&2
}

# ---- 1. SKILL.md frontmatter ----

if [[ ! -f "$SKILL_PATH" ]]; then
  fail "SKILL.md not found: $SKILL_PATH"
else
  pass "SKILL.md exists"

  # frontmatter line range (between two `---` markers at top)
  FM_END_LINE="$(awk '/^---$/{c++; if(c==2 && NR>1){print NR; exit}}' "$SKILL_PATH")"
  if [[ -z "$FM_END_LINE" ]]; then
    fail "SKILL.md frontmatter has no closing '---' marker"
  else
    FM_CONTENT="$(sed -n "1,${FM_END_LINE}p" "$SKILL_PATH")"
    for required in "name: harness-plan-brief" "user-invocable: true" "argument-hint:" "allowed-tools:" "description:"; do
      if grep -Fq -- "$required" <<< "$FM_CONTENT"; then
        pass "SKILL.md frontmatter has '$required'"
      else
        fail "SKILL.md frontmatter missing '$required'"
      fi
    done
  fi
fi

# ---- 2. project enforcement instructions ----

if [[ -f "$SKILL_PATH" ]]; then
  if grep -qE 'mcp__harness__harness_mem_search' "$SKILL_PATH"; then
    pass "SKILL.md references mcp__harness__harness_mem_search"
  else
    fail "SKILL.md does not reference mcp__harness__harness_mem_search (DoD b)"
  fi

  if grep -qE 'project: *<?PROJECT|project: *<current|basename.+git rev-parse' "$SKILL_PATH"; then
    pass "SKILL.md instructs project parameter enforcement"
  else
    fail "SKILL.md does not instruct project parameter enforcement (DoD b)"
  fi

  if grep -qE 'strict_project:[[:space:]]*true' "$SKILL_PATH"; then
    pass "SKILL.md instructs strict_project: true"
  else
    fail "SKILL.md does not instruct strict_project: true (DoD c)"
  fi
fi

  if grep -Fq "plan_readiness" "$SKILL_PATH" && \
     grep -Fq "DoD 明確度" "$SKILL_PATH" && \
     grep -Fq "依存解決率" "$SKILL_PATH" && \
     grep -Fq 'options` / `risks` / `acceptance_criteria` は常に 1 件以上生成' "$SKILL_PATH"; then
    pass "SKILL.md documents plan_readiness and non-empty Plan Brief sections (Phase 105.3)"
  else
    fail "SKILL.md missing plan_readiness / non-empty generation instructions (Phase 105.3)"
  fi

# ---- 3. NO cross-project search ----

if [[ -f "$SKILL_PATH" ]]; then
  # cross-project な instruction が肯定的に書かれていないことを確認。
  # 「cross-project」という語そのものは禁止文脈で使われていれば OK。
  # 検出ルール: 「cross-project search を呼び出す」「cross-project search を実行する」のような
  # 肯定表現は NG。「cross-project search を呼ばない / 行わない / 禁止」は OK。
  if grep -qE 'cross-project' "$SKILL_PATH"; then
    if grep -qE 'cross-project[^.]*(行わ|呼ばない|禁止|しない|opt-in|Phase 65.3)' "$SKILL_PATH"; then
      pass "SKILL.md mentions cross-project only in restricted context"
    else
      fail "SKILL.md mentions cross-project without explicit prohibition (DoD c)"
    fi
  else
    pass "SKILL.md does not mention cross-project at all"
  fi
fi

# ---- 4. JSON Schema parse ----

if [[ ! -f "$SCHEMA_PATH" ]]; then
  fail "JSON Schema not found: $SCHEMA_PATH"
else
  if jq -e '.' "$SCHEMA_PATH" >/dev/null 2>&1; then
    pass "JSON Schema is parseable"
  else
    fail "JSON Schema is not valid JSON"
  fi

  # Required top-level fields per Plans.md spec
  for req in "user_request" "my_understanding" "options" "risks" "acceptance_criteria" "confidence" "related_decisions" "similar_past_plans"; do
    if jq -e --arg k "$req" '.required | index($k)' "$SCHEMA_PATH" >/dev/null 2>&1; then
      pass "Schema requires field '$req'"
    else
      fail "Schema missing required field '$req' (Plans.md spec)"
    fi
  done

  if jq -e '.properties.confidence.type == "integer" and .properties.confidence.minimum == 0 and .properties.confidence.maximum == 100' "$SCHEMA_PATH" >/dev/null 2>&1; then
    pass "Schema confidence is integer 0-100"
  else
    fail "Schema confidence does not enforce integer 0-100"
  fi
fi

# ---- 5. fixture validates against schema ----

if [[ ! -f "$FIXTURE_PATH" ]]; then
  fail "Fixture not found: $FIXTURE_PATH"
else
  if jq -e '.' "$FIXTURE_PATH" >/dev/null 2>&1; then
    pass "Fixture is valid JSON"
  else
    fail "Fixture is not valid JSON"
  fi

  # Try Python jsonschema (preferred), fall back to structural jq check
  validated=0
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "
import json, sys
try:
    import jsonschema
except ImportError:
    sys.exit(2)
with open('$SCHEMA_PATH') as f: schema = json.load(f)
with open('$FIXTURE_PATH') as f: data  = json.load(f)
try:
    jsonschema.validate(data, schema)
    print('PYTHON_JSONSCHEMA_OK')
except jsonschema.ValidationError as e:
    print(f'PYTHON_JSONSCHEMA_FAIL: {e.message}')
    sys.exit(1)
" 2>/dev/null | grep -q "PYTHON_JSONSCHEMA_OK"; then
      pass "Fixture validates against schema (Python jsonschema)"
      validated=1
    fi
  fi

  if [[ "$validated" -eq 0 ]]; then
    # Structural jq fallback
    schema_ok=1
    for req in "user_request" "my_understanding" "options" "risks" "acceptance_criteria" "confidence" "related_decisions" "similar_past_plans" "project" "generated_at"; do
      if ! jq -e --arg k "$req" 'has($k)' "$FIXTURE_PATH" >/dev/null 2>&1; then
        schema_ok=0
        fail "Fixture missing required field '$req' (structural fallback)"
      fi
    done
    if jq -e '.confidence | (type == "number" and . >= 0 and . <= 100)' "$FIXTURE_PATH" >/dev/null 2>&1; then
      :
    else
      schema_ok=0
      fail "Fixture confidence not in 0-100 range"
    fi
    if jq -e '.schema == "plan-brief-context.v1"' "$FIXTURE_PATH" >/dev/null 2>&1; then
      :
    else
      schema_ok=0
      fail "Fixture schema field is not 'plan-brief-context.v1'"
    fi
    if [[ "$schema_ok" -eq 1 ]]; then
      pass "Fixture passes structural validation (jq fallback; install python3 jsonschema for full validation)"
    fi
  fi
fi

# ---- 6. render-html.sh generates HTML from template ----

if [[ ! -x "$RENDER_SCRIPT" ]]; then
  fail "render-html.sh not executable: $RENDER_SCRIPT"
elif [[ ! -f "$TEMPLATE_PATH" ]]; then
  fail "Template not found: $TEMPLATE_PATH"
else
  TMP_OUT="$(mktemp "${TMPDIR:-/tmp}/plan-brief-test.XXXXXX")"
  trap 'rm -f "$TMP_OUT"' EXIT
  if bash "$RENDER_SCRIPT" --template plan-brief --data "$FIXTURE_PATH" --out "$TMP_OUT" 2>/dev/null; then
    pass "render-html.sh succeeds with plan-brief template + fixture"

    # Sanity: output contains expected fixture values
    if grep -q "発注者向けに進行管理 HTML を出してほしい" "$TMP_OUT"; then
      pass "Rendered HTML contains user_request"
    else
      fail "Rendered HTML missing user_request"
    fi

    if grep -q "Option A: Plans.md を直接 grep して HTML 化" "$TMP_OUT"; then
      pass "Rendered HTML iterates options[]"
    else
      fail "Rendered HTML did not iterate options[]"
    fi

    if grep -q "scope-creep" "$TMP_OUT"; then
      pass "Rendered HTML iterates risks[]"
    else
      fail "Rendered HTML did not iterate risks[]"
    fi

    if grep -q "78" "$TMP_OUT"; then
      pass "Rendered HTML shows confidence value"
    else
      fail "Rendered HTML missing confidence value"
    fi

    # Untemplated tags should be fully resolved
    if grep -qE '\{\{[a-zA-Z]' "$TMP_OUT"; then
      fail "Rendered HTML still contains unresolved {{...}} tags"
    else
      pass "All {{...}} tags resolved in rendered HTML"
    fi
  else
    fail "render-html.sh failed for plan-brief template"
  fi
fi

# ---- 7. plan-brief-open.sh BROWSER=true skip ----

if [[ ! -x "$OPEN_SCRIPT" ]]; then
  fail "plan-brief-open.sh not executable: $OPEN_SCRIPT"
else
  TMP_HTML="$(mktemp "${TMPDIR:-/tmp}/plan-brief-open-test.XXXXXX")"
  echo "<html></html>" > "$TMP_HTML"

  OPEN_OUT="$(BROWSER=true bash "$OPEN_SCRIPT" "$TMP_HTML" 2>/dev/null || true)"
  if [[ "$OPEN_OUT" == "$TMP_HTML" || "$OPEN_OUT" == "$(cd "$(dirname "$TMP_HTML")" && pwd)/$(basename "$TMP_HTML")" ]]; then
    pass "plan-brief-open.sh skips open with BROWSER=true and outputs path"
  else
    fail "plan-brief-open.sh BROWSER=true output unexpected: '$OPEN_OUT'"
  fi

  # PLAN_BRIEF_NO_OPEN=1 should also skip
  OPEN_OUT2="$(PLAN_BRIEF_NO_OPEN=1 bash "$OPEN_SCRIPT" "$TMP_HTML" 2>/dev/null || true)"
  if [[ "$OPEN_OUT2" == "$TMP_HTML" || "$OPEN_OUT2" == "$(cd "$(dirname "$TMP_HTML")" && pwd)/$(basename "$TMP_HTML")" ]]; then
    pass "plan-brief-open.sh skips open with PLAN_BRIEF_NO_OPEN=1"
  else
    fail "plan-brief-open.sh PLAN_BRIEF_NO_OPEN=1 output unexpected: '$OPEN_OUT2'"
  fi

  rm -f "$TMP_HTML"

  # ---- 8. plan-brief-open.sh missing file ----
  set +e
  bash "$OPEN_SCRIPT" /nonexistent/never-exists.html >/dev/null 2>&1
  exit_code=$?
  set -e
  if [[ "$exit_code" -eq 2 ]]; then
    pass "plan-brief-open.sh exits 2 on missing file"
  else
    fail "plan-brief-open.sh did not exit 2 on missing file (got $exit_code)"
  fi
fi

# ---- Summary ----

echo ""
echo "============================================"
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "FAIL details:" >&2
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi
echo "All assertions passed."
exit 0
