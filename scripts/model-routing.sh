#!/usr/bin/env bash
# Resolve Harness model/effort routing from a small role-tier contract.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/host-registry.sh
source "${SCRIPT_DIR}/lib/host-registry.sh"
HOST_REGISTRY_PATH="$(cd "${SCRIPT_DIR}/.." && pwd)/hosts/registry.json"

HOST="codex"
TIER=""
ROLE=""
FIELD=""
FORMAT="json"

usage() {
  local hosts
  hosts="$(host_registry_routing_hosts 2>/dev/null | tr '\n' '|' | sed 's/|$//')"
  [ -n "$hosts" ] || hosts="codex|claude|cursor|grok"
  cat <<EOF
Usage:
  scripts/model-routing.sh --host ${hosts} --tier TIER [--format json|args|env] [--field model|effort]
  scripts/model-routing.sh --host ${hosts} --role ROLE [--format json|args|env] [--field model|effort]

Tiers: lite, standard, deep, review, advisor, release, long-context, spark
Roles: explorer, worker, reviewer, advisor, plan, release, operator, long-context
Allowed --host values come from hosts/registry.json (routing_host).
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --host=*) HOST="${1#*=}"; shift ;;
    --tier) TIER="${2:-}"; shift 2 ;;
    --tier=*) TIER="${1#*=}"; shift ;;
    --role) ROLE="${2:-}"; shift 2 ;;
    --role=*) ROLE="${1#*=}"; shift ;;
    --field) FIELD="${2:-}"; shift 2 ;;
    --field=*) FIELD="${1#*=}"; shift ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --format=*) FORMAT="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

role_to_tier() {
  case "$1" in
    explorer|reader|search|lite) printf 'lite\n' ;;
    worker|implementer|setup|standard) printf 'standard\n' ;;
    plan|planner|architect|deep) printf 'deep\n' ;;
    reviewer|review|adversarial-review) printf 'review\n' ;;
    advisor) printf 'advisor\n' ;;
    release|closeout) printf 'release\n' ;;
    operator) printf 'standard\n' ;;
    long-context|long_context) printf 'long-context\n' ;;
    spark) printf 'spark\n' ;;
    *) echo "ERROR: unknown role: $1" >&2; exit 2 ;;
  esac
}

if [ -z "$TIER" ]; then
  if [ -n "$ROLE" ]; then
    TIER="$(role_to_tier "$ROLE")"
  else
    TIER="standard"
  fi
fi

if ! host_registry_is_routing_host "$HOST"; then
  echo "ERROR: unsupported host: $HOST (not in hosts/registry.json routing_host list)" >&2
  exit 2
fi

# Brain opt-in: HARNESS_BRAIN_MODEL switches the claude-host brain tiers
# (deep/advisor) only. codex/cursor/grok catalogs are host-side and stay untouched.
CLAUDE_BRAIN_MODEL="claude-opus-4-8"
case "${HARNESS_BRAIN_MODEL:-opus}" in
  opus) ;;
  fable) CLAUDE_BRAIN_MODEL="claude-fable-5" ;;
  *) echo "ERROR: unknown HARNESS_BRAIN_MODEL: ${HARNESS_BRAIN_MODEL} (use opus|fable)" >&2; exit 2 ;;
esac

MODEL=""
EFFORT=""

if [ "$HOST" = "codex" ]; then
  case "$TIER" in
    lite) MODEL="gpt-5.4-mini"; EFFORT="low" ;;
    standard) MODEL="gpt-5.5"; EFFORT="medium" ;;
    deep) MODEL="gpt-5.5"; EFFORT="high" ;;
    review|advisor) MODEL="gpt-5.5"; EFFORT="xhigh" ;;
    release|long-context) MODEL="gpt-5.5"; EFFORT="high" ;;
    spark) MODEL="gpt-5.3-codex-spark"; EFFORT="low" ;;
    *) echo "ERROR: unknown codex tier: $TIER" >&2; exit 2 ;;
  esac
elif [ "$HOST" = "cursor" ]; then
  case "$TIER" in
    lite) MODEL="composer-2-fast"; EFFORT="low" ;;
    standard) MODEL="composer-2.5-fast"; EFFORT="medium" ;;
    deep|advisor) MODEL="claude-opus-4-8-thinking-xhigh"; EFFORT="xhigh" ;;
    review) MODEL="composer-2.5-fast"; EFFORT="xhigh" ;;
    release) MODEL="composer-2.5-fast"; EFFORT="high" ;;
    long-context) MODEL="gemini-3.1-pro"; EFFORT="high" ;;
    spark) echo "ERROR: spark tier is codex-only" >&2; exit 2 ;;
    *) echo "ERROR: unknown cursor tier: $TIER" >&2; exit 2 ;;
  esac
elif [ "$HOST" = "grok" ]; then
  # Grok catalog (observed 2026-07-09 on CLI 0.2.93): grok-4.5, grok-composer-2.5-fast.
  # Keep model IDs only here — skills must not hardcode them.
  case "$TIER" in
    lite) MODEL="grok-composer-2.5-fast"; EFFORT="low" ;;
    standard) MODEL="grok-composer-2.5-fast"; EFFORT="medium" ;;
    deep|advisor) MODEL="grok-4.5"; EFFORT="high" ;;
    review) MODEL="grok-4.5"; EFFORT="high" ;;
    release) MODEL="grok-4.5"; EFFORT="high" ;;
    long-context) MODEL="grok-4.5"; EFFORT="high" ;;
    spark) echo "ERROR: spark tier is codex-only" >&2; exit 2 ;;
    *) echo "ERROR: unknown grok tier: $TIER" >&2; exit 2 ;;
  esac
else
  case "$TIER" in
    lite) MODEL="claude-haiku-4-5"; EFFORT="low" ;;
    standard) MODEL="claude-sonnet-5"; EFFORT="medium" ;;
    deep|advisor) MODEL="$CLAUDE_BRAIN_MODEL"; EFFORT="xhigh" ;;
    review) MODEL="claude-sonnet-5"; EFFORT="xhigh" ;;
    release) MODEL="claude-sonnet-5"; EFFORT="high" ;;
    long-context) MODEL="sonnet[1m]"; EFFORT="high" ;;
    spark) echo "ERROR: spark tier is codex-only" >&2; exit 2 ;;
    *) echo "ERROR: unknown claude tier: $TIER" >&2; exit 2 ;;
  esac
fi

case "$FIELD" in
  "") ;;
  model) printf '%s\n' "$MODEL"; exit 0 ;;
  effort) printf '%s\n' "$EFFORT"; exit 0 ;;
  *) echo "ERROR: unsupported field: $FIELD" >&2; exit 2 ;;
esac

case "$FORMAT" in
  json)
    printf '{"host":"%s","tier":"%s","model":"%s","effort":"%s"}\n' "$HOST" "$TIER" "$MODEL" "$EFFORT"
    ;;
  args)
    if [ "$HOST" = "codex" ]; then
      printf '%s\n' "--model" "$MODEL" "-c" "model_reasoning_effort=\"$EFFORT\""
    elif [ "$HOST" = "cursor" ] || [ "$HOST" = "grok" ]; then
      printf '%s\n' "--model" "$MODEL"
    else
      printf '%s\n' "--model" "$MODEL" "--effort" "$EFFORT"
    fi
    ;;
  env)
    if [ "$HOST" = "codex" ]; then
      printf 'CODEX_MODEL=%s\nCODEX_EFFORT=%s\n' "$MODEL" "$EFFORT"
    elif [ "$HOST" = "cursor" ]; then
      printf 'CURSOR_MODEL=%s\nCURSOR_EFFORT=%s\n' "$MODEL" "$EFFORT"
    elif [ "$HOST" = "grok" ]; then
      printf 'GROK_MODEL=%s\nGROK_EFFORT=%s\n' "$MODEL" "$EFFORT"
    else
      printf 'CLAUDE_MODEL=%s\nCLAUDE_EFFORT=%s\n' "$MODEL" "$EFFORT"
    fi
    ;;
  *) echo "ERROR: unsupported format: $FORMAT" >&2; exit 2 ;;
esac
