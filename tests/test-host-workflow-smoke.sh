#!/usr/bin/env bash
# Multi-host workflow smoke (Phase 111.2).
# Default: structural H4 (install package + materialize plan artifact from skill).
# Optional live CLI: set HARNESS_<HOST>_WORKFLOW_SMOKE_LIVE=1 (may call models).
# Hard fail when CLI missing: HARNESS_<HOST>_WORKFLOW_SMOKE_REQUIRED=1
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/host-smoke-lib.sh
source "${ROOT_DIR}/tests/lib/host-smoke-lib.sh"
# shellcheck source=../scripts/lib/host-registry.sh
source "${ROOT_DIR}/scripts/lib/host-registry.sh"
HOST_REGISTRY_PATH="${ROOT_DIR}/hosts/registry.json"

HOST="${1:-}"
if [ "${1:-}" = "--host" ]; then
  HOST="${2:-}"
fi
if [ -z "$HOST" ]; then
  echo "Usage: test-host-workflow-smoke.sh --host claude|codex|cursor|grok" >&2
  exit 2
fi

host_registry_require_id "$HOST" || {
  echo "unknown host: ${HOST}" >&2
  exit 2
}

required_var="HARNESS_$(printf '%s' "$HOST" | tr '[:lower:]' '[:upper:]')_WORKFLOW_SMOKE_REQUIRED"
live_var="HARNESS_$(printf '%s' "$HOST" | tr '[:lower:]' '[:upper:]')_WORKFLOW_SMOKE_LIVE"
REQUIRED="${!required_var:-0}"
LIVE="${!live_var:-0}"

EVIDENCE_DIR="${HARNESS_WORKFLOW_SMOKE_OUT:-${ROOT_DIR}/out/workflow-smoke/${HOST}}"
mkdir -p "$EVIDENCE_DIR"
LOG="${EVIDENCE_DIR}/run.log"
: >"$LOG"

log() { echo "$*" | tee -a "$LOG"; }

DIST_TMP="$(mktemp -d)"
trap 'rm -rf "$DIST_TMP"' EXIT

log "=== workflow smoke host=${HOST} required=${REQUIRED} live=${LIVE} ==="

# Build host dist when registered
if host_registry_is_dist_host "$HOST"; then
  bash "${ROOT_DIR}/scripts/build-host-plugin-dist.sh" --host "$HOST" --out "${DIST_TMP}/dist" >>"$LOG" 2>&1 \
    || { [ "$REQUIRED" = "1" ] && exit 1; log "WARN: dist build failed"; exit 0; }
  assert_install_layout "${DIST_TMP}/dist" "$HOST"
  assert_core_skills_visible "${DIST_TMP}/dist/skills"
  SKILL_MD="${DIST_TMP}/dist/skills/harness-plan/SKILL.md"
else
  SKILL_MD="${ROOT_DIR}/skills/harness-plan/SKILL.md"
  assert_skill_visible "${ROOT_DIR}/skills" harness-plan
fi

ARTIFACT="${EVIDENCE_DIR}/plan-artifact.md"
write_plan_artifact_from_skill "$SKILL_MD" "$ARTIFACT" "$HOST"
log "plan artifact: ${ARTIFACT}"

# Host-specific install --check when available
case "$HOST" in
  cursor)
    HOME_TMP="$(mktemp -d)"
    HOME="$HOME_TMP" HARNESS_CURSOR_DIST="${DIST_TMP}/dist" \
      bash "${ROOT_DIR}/scripts/setup-cursor.sh" --check >>"$LOG" 2>&1 \
      || { [ "$REQUIRED" = "1" ] && exit 1; log "WARN: setup-cursor --check failed"; }
    rm -rf "$HOME_TMP"
    ;;
  grok)
    HOME_TMP="$(mktemp -d)"
    HOME="$HOME_TMP" HARNESS_GROK_DIST="${DIST_TMP}/dist" \
      bash "${ROOT_DIR}/scripts/setup-grok.sh" --check >>"$LOG" 2>&1 \
      || { [ "$REQUIRED" = "1" ] && exit 1; log "WARN: setup-grok --check failed"; }
    # Discovery evidence without live model: plugin validate if CLI present
    if command -v grok >/dev/null 2>&1; then
      if grok plugin validate "${DIST_TMP}/dist" >>"$LOG" 2>&1; then
        log "grok plugin validate ok"
      else
        [ "$REQUIRED" = "1" ] && exit 1
        log "WARN: grok plugin validate failed"
      fi
    else
      [ "$REQUIRED" = "1" ] && { log "FAIL: grok CLI required"; exit 1; }
      log "WARN: grok CLI absent; structural path only"
    fi
    rm -rf "$HOME_TMP"
    ;;
  codex)
    if [ -f "${ROOT_DIR}/tests/test-codex-plugin-adapter.sh" ]; then
      # Install/plugin smoke is the Codex-required path today (may need network).
      if HARNESS_CODEX_PLUGIN_SMOKE_REQUIRED="${REQUIRED}" \
        bash "${ROOT_DIR}/tests/test-codex-plugin-adapter.sh" >>"$LOG" 2>&1; then
        log "codex plugin adapter smoke ok"
      else
        [ "$REQUIRED" = "1" ] && exit 1
        log "WARN: codex plugin adapter smoke failed/skipped"
      fi
    fi
    ;;
  claude)
    [ -f "${ROOT_DIR}/skills/harness-plan/SKILL.md" ] || exit 1
    log "claude structural skill path ok"
    ;;
esac

# Live model path (optional; not required for structural H4 green)
if [ "$LIVE" = "1" ]; then
  log "LIVE mode requested — host-specific CLI plan invocation is operator/CI opt-in"
  case "$HOST" in
    grok)
      if command -v grok >/dev/null 2>&1; then
        log "live grok: use operator session to run /harness-plan (not automated here)"
      fi
      ;;
    codex)
      if command -v codex >/dev/null 2>&1; then
        log "live codex: use codex exec with \$harness-plan (not automated here)"
      fi
      ;;
    cursor)
      if command -v cursor-agent >/dev/null 2>&1; then
        log "live cursor-agent: use ask mode with harness-plan (not automated here)"
      fi
      ;;
  esac
fi

log "test-host-workflow-smoke: ok host=${HOST}"
echo "test-host-workflow-smoke: ok (${HOST})"
