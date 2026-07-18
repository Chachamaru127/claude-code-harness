#!/usr/bin/env bash
# host-registry.sh — read hosts/registry.json (multi-host SSOT).
# Source this file; do not execute. Requires node (already used by dist builder).
#
# Usage:
#   SCRIPT_DIR=...; # shellcheck source=host-registry.sh
#   source "$ROOT/scripts/lib/host-registry.sh"
#   host_registry_ids
#   host_registry_field grok tier
#   host_registry_routing_hosts   # space-separated
#   host_registry_dist_hosts
#   host_registry_require_id cursor

if [ -n "${HOST_REGISTRY_SH_LOADED:-}" ]; then
  return 0 2>/dev/null || true
fi
HOST_REGISTRY_SH_LOADED=1

_host_registry_root() {
  if [ -n "${HARNESS_PROJECT_ROOT:-}" ]; then
    printf '%s\n' "$HARNESS_PROJECT_ROOT"
    return 0
  fi
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  printf '%s\n' "$here"
}

HOST_REGISTRY_PATH="${HOST_REGISTRY_PATH:-$(_host_registry_root)/hosts/registry.json}"

_host_registry_node() {
  if ! command -v node >/dev/null 2>&1; then
    echo "host-registry: node is required to read ${HOST_REGISTRY_PATH}" >&2
    return 1
  fi
  if [ ! -f "$HOST_REGISTRY_PATH" ]; then
    echo "host-registry: missing ${HOST_REGISTRY_PATH}" >&2
    return 1
  fi
  node - "$HOST_REGISTRY_PATH" "$@" <<'NODE'
const fs = require("fs");
const path = process.argv[2];
const cmd = process.argv[3];
const arg = process.argv[4];
const arg2 = process.argv[5];
const reg = JSON.parse(fs.readFileSync(path, "utf8"));
const hosts = reg.hosts || [];

function fail(msg) {
  console.error(msg);
  process.exit(1);
}

switch (cmd) {
  case "ids":
    hosts.forEach((h) => console.log(h.id));
    break;
  case "routing-hosts":
    hosts
      .filter((h) => h.routing_host)
      .forEach((h) => console.log(h.routing_host));
    break;
  case "dist-hosts":
    hosts
      .filter((h) => h.dist_host)
      .forEach((h) => console.log(h.dist_host));
    break;
  case "field": {
    const h = hosts.find((x) => x.id === arg);
    if (!h) fail(`unknown host id: ${arg}`);
    const keys = arg2.split(".");
    let v = h;
    for (const k of keys) {
      if (v == null) break;
      v = v[k];
    }
    if (v === undefined || v === null) {
      process.exit(0);
    }
    if (typeof v === "object") {
      console.log(JSON.stringify(v));
    } else {
      console.log(String(v));
    }
    break;
  }
  case "require": {
    if (!hosts.some((h) => h.id === arg)) fail(`unknown host id: ${arg}`);
    break;
  }
  case "json":
    console.log(JSON.stringify(reg));
    break;
  case "adapter-smokes":
    // lines: id\tlabel\tcommand
    for (const h of hosts) {
      const sm = h.smoke || {};
      if (sm.adapter) {
        console.log(`${h.id}\tadapter\t${sm.adapter}`);
      }
      if (sm.setup_check) {
        console.log(`${h.id}\tsetup_check\t${sm.setup_check}`);
      }
    }
    break;
  case "tier-rows":
    // display_name|tier for public tables
    for (const h of hosts) {
      console.log(`${h.display_name}\t${h.tier}`);
    }
    break;
  default:
    fail(`unknown host-registry command: ${cmd}`);
}
NODE
}

host_registry_ids() {
  _host_registry_node ids
}

host_registry_routing_hosts() {
  _host_registry_node routing-hosts
}

host_registry_dist_hosts() {
  _host_registry_node dist-hosts
}

host_registry_field() {
  local id="$1"
  local field="$2"
  _host_registry_node field "$id" "$field"
}

host_registry_require_id() {
  _host_registry_node require "$1"
}

host_registry_adapter_smokes() {
  _host_registry_node adapter-smokes
}

host_registry_tier_rows() {
  _host_registry_node tier-rows
}

host_registry_is_routing_host() {
  local want="$1"
  local h
  while IFS= read -r h; do
    [ "$h" = "$want" ] && return 0
  done < <(host_registry_routing_hosts)
  return 1
}

host_registry_is_dist_host() {
  local want="$1"
  local h
  while IFS= read -r h; do
    [ "$h" = "$want" ] && return 0
  done < <(host_registry_dist_hosts)
  return 1
}
