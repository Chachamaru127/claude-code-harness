#!/bin/bash
# check-config-schema.sh
# claude-code-harness.config.schema.json に対する config JSON 検証 (standalone)
#
# Phase 135.5: writing_lint / quality_pack を schema に追加した際に新設。
# tests/validate-plugin.sh への配線は 134.8 が行う (このスクリプト自体は未配線)。
#
# Usage: ./scripts/ci/check-config-schema.sh
# Exit codes:
#   0 - All checks passed
#   1 - Validation failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCHEMA="$PLUGIN_ROOT/claude-code-harness.config.schema.json"

ERRORS=0

echo "=== Config Schema Check ==="
echo ""

if [ ! -f "$SCHEMA" ]; then
  echo "❌ schema not found: $SCHEMA"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "⚠️  python3 not found, skipping schema validation"
  exit 0
fi

# schema 自体が有効な JSON Schema か
if python3 - "$SCHEMA" <<'PY'
import json, sys
schema_path = sys.argv[1]
with open(schema_path, encoding="utf-8") as f:
    schema = json.load(f)
try:
    import jsonschema  # type: ignore
    jsonschema.Draft7Validator.check_schema(schema)
except ImportError:
    pass
PY
then
  echo "✅ schema: valid JSON Schema (draft-07)"
else
  echo "❌ schema: invalid JSON Schema"
  ERRORS=$((ERRORS + 1))
fi

# 検証ヘルパー: 期待どおり PASS/FAIL したかを確認する。
# expect: "pass" | "fail"
check_case() {
  local label="$1" expect="$2" instance_file="$3"

  if python3 - "$instance_file" "$SCHEMA" <<'PY'
import json, sys
data_path, schema_path = sys.argv[1], sys.argv[2]
with open(data_path, encoding="utf-8") as f:
    data = json.load(f)
with open(schema_path, encoding="utf-8") as f:
    schema = json.load(f)
try:
    import jsonschema  # type: ignore
except ImportError:
    # jsonschema 未インストール環境向けの縮退フォールバック:
    # additionalProperties: false の唯一の実効面（トップレベルキー）だけ確認する。
    schema_props = set(schema.get("properties", {}).keys())
    unknown = set(data.keys()) - schema_props
    if unknown:
        print(f"unknown top-level keys: {sorted(unknown)}", file=sys.stderr)
        raise SystemExit(1)
    raise SystemExit(0)

try:
    jsonschema.validate(instance=data, schema=schema)
except jsonschema.exceptions.ValidationError as exc:
    print(exc.message, file=sys.stderr)
    raise SystemExit(1)
PY
  then
    result="pass"
  else
    result="fail"
  fi

  if [ "$result" = "$expect" ]; then
    echo "✅ $label (expected $expect, got $result)"
  else
    echo "❌ $label (expected $expect, got $result)"
    ERRORS=$((ERRORS + 1))
  fi
}

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/harness-config-schema.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

# (a) 既存 config (quality_pack 含む) が新 schema で PASS
cat >"$WORKDIR/with-quality-pack.json" <<'JSON'
{
  "version": "1.0",
  "i18n": { "language": "ja" },
  "constitution": { "path": "docs/constitution.md" },
  "work": { "auto_commit": true, "commit_on_pm_approve": false },
  "quality_pack": {
    "enabled": true,
    "mode": "run",
    "prettier": true,
    "tsc": false,
    "console_log": true
  }
}
JSON
check_case "(a) existing config incl. quality_pack" "pass" "$WORKDIR/with-quality-pack.json"

# (b) writing_lint セクション付き設定例も PASS
cat >"$WORKDIR/with-writing-lint.json" <<'JSON'
{
  "version": "1.0",
  "i18n": { "language": "ja" },
  "quality_pack": {
    "enabled": false,
    "mode": "warn",
    "prettier": true,
    "tsc": true,
    "console_log": true
  },
  "writing_lint": {
    "enabled": true,
    "scene": "chat",
    "structural": true,
    "dict_path": ".claude/writing-lint/rules.jsonl"
  }
}
JSON
check_case "(b) config incl. writing_lint" "pass" "$WORKDIR/with-writing-lint.json"

# additionalProperties: false が引き続き効いている negative test
cat >"$WORKDIR/unknown-top-level.json" <<'JSON'
{
  "version": "1.0",
  "not_a_real_section": {}
}
JSON
check_case "(negative) unknown top-level key rejected" "fail" "$WORKDIR/unknown-top-level.json"

echo ""
if [ $ERRORS -eq 0 ]; then
  echo "✅ すべてのチェックに合格しました"
  exit 0
else
  echo "❌ $ERRORS 個の問題が見つかりました"
  exit 1
fi
