#!/usr/bin/env bash
# Assert hosts/registry.json is SSOT for public tier rows and known scripts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/lib/host-registry.sh
source "${ROOT_DIR}/scripts/lib/host-registry.sh"
HOST_REGISTRY_PATH="${ROOT_DIR}/hosts/registry.json"

fail() {
  echo "test-host-registry: FAIL: $1" >&2
  exit 1
}

[ -f "$HOST_REGISTRY_PATH" ] || fail "missing hosts/registry.json"

# Required core ids for Phase 111
for id in claude codex cursor grok; do
  host_registry_require_id "$id" || fail "registry missing ${id}"
done

# Grok floor membership (Phase 111.5 codec HostGrok)
grok_floor="$(host_registry_field grok floor_member)"
[ "$grok_floor" = "true" ] || fail "grok floor_member must be true (got ${grok_floor})"

# Claude must be supported + floor member
[ "$(host_registry_field claude tier)" = "supported" ] || fail "claude tier must be supported"
[ "$(host_registry_field claude floor_member)" = "true" ] || fail "claude floor_member must be true"

# Public docs must match registry display_name + tier
PUBLIC_DOCS=(
  "${ROOT_DIR}/README.md"
  "${ROOT_DIR}/README_ja.md"
  "${ROOT_DIR}/docs/tool-capability-matrix.md"
  "${ROOT_DIR}/docs/onboarding/index.md"
)

while IFS=$'\t' read -r display tier; do
  [ -n "$display" ] || continue
  # Table row shape: | Display | `tier` |
  needle="| ${display} | \`${tier}\` |"
  for doc in "${PUBLIC_DOCS[@]}"; do
    [ -f "$doc" ] || fail "missing ${doc}"
    grep -Fq "$needle" "$doc" || fail "missing tier row '${needle}' in ${doc}"
  done
done < <(host_registry_tier_rows)

# Setup scripts listed in registry must exist when non-null
for id in $(host_registry_ids); do
  setup="$(host_registry_field "$id" setup_script || true)"
  if [ -n "$setup" ] && [ "$setup" != "null" ]; then
    [ -f "${ROOT_DIR}/${setup}" ] || fail "setup_script missing for ${id}: ${setup}"
  fi
  dist="$(host_registry_field "$id" dist_host || true)"
  if [ -n "$dist" ] && [ "$dist" != "null" ]; then
    host_registry_is_dist_host "$dist" || fail "dist_host ${dist} not in dist list"
  fi
  routing="$(host_registry_field "$id" routing_host || true)"
  if [ -n "$routing" ] && [ "$routing" != "null" ]; then
    host_registry_is_routing_host "$routing" || fail "routing_host ${routing} not in routing list"
  fi
  adapter="$(host_registry_field "$id" smoke.adapter || true)"
  if [ -n "$adapter" ] && [ "$adapter" != "null" ]; then
    # adapter may be path only
    [ -f "${ROOT_DIR}/${adapter}" ] || fail "adapter smoke missing for ${id}: ${adapter}"
  fi
done

# model-routing and dist builder must accept every routing/dist host
while IFS= read -r h; do
  bash "${ROOT_DIR}/scripts/model-routing.sh" --host "$h" --role worker --field model >/dev/null \
    || fail "model-routing rejects registry routing host ${h}"
done < <(host_registry_routing_hosts)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
while IFS= read -r h; do
  bash "${ROOT_DIR}/scripts/build-host-plugin-dist.sh" --host "$h" --out "${TMP}/${h}" >/dev/null \
    || fail "build-host-plugin-dist rejects registry dist host ${h}"
done < <(host_registry_dist_hosts)

# Admission doc exists (111.1.4)
[ -f "${ROOT_DIR}/docs/onboarding/host-admission.md" ] \
  || fail "missing docs/onboarding/host-admission.md"

echo "test-host-registry: ok"
