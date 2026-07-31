#!/usr/bin/env bash
# Phase 108.5 / Task 126.5 — plan-time preapproval schemas + secret-read bridge.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_V1="${ROOT_DIR}/templates/schemas/plan-preapproval.v1.json"
SCHEMA_V2="${ROOT_DIR}/templates/schemas/plan-preapproval.v2.json"
SCRIPT="${ROOT_DIR}/scripts/plan-preapproval.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

pass() { echo "✓ $1"; }
fail() { echo "✗ $1" >&2; exit 1; }

[ -f "${SCHEMA_V1}" ] || fail "schema missing: ${SCHEMA_V1}"
[ -f "${SCHEMA_V2}" ] || fail "schema missing: ${SCHEMA_V2}"
[ -x "${SCRIPT}" ] || fail "script missing or not executable: ${SCRIPT}"

grep -q "## 事前確認" "${ROOT_DIR}/skills/harness-plan/SKILL.md" \
  || fail "harness-plan must generate a preapproval section"
grep -q "事項: <secret-read / external-send / destructive の具体操作>" "${ROOT_DIR}/skills/harness-plan/SKILL.md" \
  || fail "harness-plan must pin the preapproval item format"
grep -q "確認は plan 承認時の 1 回のみ" "${ROOT_DIR}/skills/harness-plan/SKILL.md" \
  || fail "harness-plan must state approval happens once at plan approval"
grep -q 'plan-preapproval.v2' "${ROOT_DIR}/skills/harness-plan/SKILL.md" \
  || fail "harness-plan must write plan-preapproval.v2"
grep -q "work 中の宣言済み事項起因.*AskUserQuestion.*ゼロ" "${ROOT_DIR}/skills/harness-work/SKILL.md" \
  || fail "harness-work must prohibit AskUserQuestion for declared items"
grep -q 'active-task.json' "${ROOT_DIR}/skills/harness-work/SKILL.md" \
  && grep -q 'タスク終了時.*削除' "${ROOT_DIR}/skills/harness-work/SKILL.md" \
  || fail "harness-work must create and clean up active-task.json"
grep -q "記録に無い未計画の secret-read / 外部送信 / 破壊的操作は従来どおり runtime floor / ask で停止" "${ROOT_DIR}/skills/breezing/SKILL.md" \
  || fail "breezing must preserve undeclared floor/ask behavior"
grep -q 'active-task.json' "${ROOT_DIR}/skills/breezing/SKILL.md" \
  && grep -q 'task 終了時.*削除' "${ROOT_DIR}/skills/breezing/SKILL.md" \
  || fail "breezing must create and clean up active-task.json"
grep -q "HARNESS_RUNTIME_FLOOR_SECRET_ALLOW" "${ROOT_DIR}/docs/sandbox-allowlist-recipe.md" \
  && grep -q "plan-time 事前確認" "${ROOT_DIR}/docs/sandbox-allowlist-recipe.md" \
  || fail "docs must mention migration from broad env allow to plan-time preapproval"
pass "skill/docs preapproval contract text is present"

STATE="${TMP_DIR}/plan-preapprovals.json"
cat >"${STATE}" <<'JSON'
{
  "schema_version": "plan-preapproval.v2",
  "approved_at": "2026-07-07T09:30:00Z",
  "approvals": [
    {
      "item": "Read local dotenv for integration smoke",
      "reason": "DoD command needs a local token presence check without printing values",
      "scope": {"phase": "108", "task": "108.5"},
      "operations": ["secret-read"],
      "paths": [".env.integration"],
      "commands": ["grep -q API_TOKEN .env.integration"],
      "decision": "approved",
      "approved_at": "2026-07-07T09:30:00Z",
      "expires_at": "2999-07-07T10:30:00Z"
    },
    {
      "item": "Read undeclared production env",
      "reason": "Should not be reflected because it was denied",
      "scope": {"phase": "108", "task": "108.5"},
      "operations": ["secret-read"],
      "paths": [".env.production"],
      "decision": "denied",
      "approved_at": "2026-07-07T09:31:00Z",
      "expires_at": "2999-07-07T10:31:00Z",
      "max_uses": 3,
      "uses": 1
    },
    {
      "item": "Read a different task env",
      "reason": "Must not cross the task scope",
      "scope": {"phase": "126", "task": "126.6"},
      "operations": ["secret-read"],
      "paths": [".env.other-task"],
      "decision": "approved",
      "approved_at": "2026-07-07T09:32:00Z",
      "expires_at": "2999-07-07T10:32:00Z"
    }
  ]
}
JSON

"${SCRIPT}" validate "${STATE}" >/dev/null
pass "plan-preapproval.v2 fixture validates"

python3 - "${SCHEMA_V2}" <<'PY'
import json
import sys

schema = json.load(open(sys.argv[1], encoding="utf-8"))
assert schema["$schema"] == "http://json-schema.org/draft-07/schema#"
assert schema["properties"]["schema_version"]["const"] == "plan-preapproval.v2"
approval = schema["properties"]["approvals"]["items"]
assert "expires_at" in approval["required"]
assert approval["properties"]["max_uses"]["default"] == 10
assert approval["properties"]["uses"]["default"] == 0
assert approval["additionalProperties"] is False
PY
pass "plan-preapproval.v2 schema pins expiry and usage defaults"

INVALID_V2="${TMP_DIR}/invalid-v2.json"
python3 - "${STATE}" "${INVALID_V2}" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
del data["approvals"][0]["expires_at"]
with open(sys.argv[2], "w", encoding="utf-8") as f:
    json.dump(data, f)
PY
if "${SCRIPT}" validate "${INVALID_V2}" >/dev/null 2>&1; then
  fail "v2 approval without expires_at must fail validation"
fi
pass "plan-preapproval.v2 rejects missing expires_at"

STATE_V1="${TMP_DIR}/plan-preapprovals-v1.json"
python3 - "${STATE}" "${STATE_V1}" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
data["schema_version"] = "plan-preapproval.v1"
for approval in data["approvals"]:
    approval.pop("expires_at", None)
    approval.pop("max_uses", None)
    approval.pop("uses", None)
with open(sys.argv[2], "w", encoding="utf-8") as f:
    json.dump(data, f)
PY
"${SCRIPT}" validate "${STATE_V1}" >/dev/null
pass "plan-preapproval.v1 remains readable"

PROJECT="${TMP_DIR}/project"
mkdir -p "${PROJECT}/.claude/state"
cp "${STATE}" "${PROJECT}/.claude/state/plan-preapprovals.json"
cat >"${PROJECT}/.claude/state/active-task.json" <<'JSON'
{"phase": "108", "task": "108.5"}
JSON

"${SCRIPT}" apply-secret-allow "${PROJECT}" >/dev/null
CONFIG="${PROJECT}/.claude-code-harness.config.json"
[ -f "${CONFIG}" ] || fail "project config was not created"

python3 - "${CONFIG}" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
allow = data.get("runtimefloor", {}).get("secretAllow", [])
if ".env.integration" not in allow:
    raise SystemExit("approved path was not reflected into runtimefloor.secretAllow")
if ".env.production" in allow:
    raise SystemExit("denied path leaked into runtimefloor.secretAllow")
if ".env.other-task" in allow:
    raise SystemExit("different-task path leaked into runtimefloor.secretAllow")
PY
pass "approved same-scope secret-read path reflected; denied and other-task paths excluded"

ENV_PROJECT="${TMP_DIR}/env-project"
mkdir -p "${ENV_PROJECT}/.claude/state"
cp "${STATE_V1}" "${ENV_PROJECT}/.claude/state/plan-preapprovals.json"
HARNESS_ACTIVE_PHASE=108 HARNESS_ACTIVE_TASK=108.5 \
  "${SCRIPT}" apply-secret-allow "${ENV_PROJECT}" >/dev/null
python3 - "${ENV_PROJECT}/.claude-code-harness.config.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
allow = data.get("runtimefloor", {}).get("secretAllow", [])
assert ".env.integration" in allow
assert ".env.other-task" not in allow
PY
pass "apply-secret-allow supports v1 and environment scope fallback"

(
  cd "${ROOT_DIR}/go"
  GOCACHE="${TMP_DIR}/go-build" go test ./internal/runtimefloor -run 'TestCheckSecretRead_ConfigAllowlistedPathPasses|TestCheckSecretRead_UnsetEnvKeepsDenyByDefault' -count=1
) >/dev/null
pass "runtimefloor config bridge allows declared path and keeps deny-by-default"
