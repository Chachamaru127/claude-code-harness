#!/usr/bin/env bash
# build-host-plugin-dist.sh
# Build host-specific install packages with normalized in-package manifest paths.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/host-registry.sh
source "${SCRIPT_DIR}/lib/host-registry.sh"
HOST_REGISTRY_PATH="${ROOT_DIR}/hosts/registry.json"

HOST=""
OUT_DIR=""

usage() {
  local hosts
  hosts="$(host_registry_dist_hosts 2>/dev/null | tr '\n' '|' | sed 's/|$//')"
  [ -n "$hosts" ] || hosts="claude|codex|cursor|grok"
  cat <<EOF
Usage: build-host-plugin-dist.sh --host ${hosts} --out <directory>

Generates a host-specific distribution package. Output directory is created or
replaced. Generated packages must not reference sibling paths with '..'.
Allowed --host values come from hosts/registry.json (dist_host).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --out)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [ -z "$HOST" ] || [ -z "$OUT_DIR" ]; then
  usage
  exit 2
fi

if ! host_registry_is_dist_host "$HOST"; then
  echo "invalid --host: $HOST (not in hosts/registry.json dist_host list)" >&2
  usage
  exit 2
fi

if [ -e "$OUT_DIR" ]; then
  rm -rf "$OUT_DIR"
fi
mkdir -p "$OUT_DIR"

copy_tree() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
}

copy_runtime_helpers() {
  local dst_root="$1"
  mkdir -p "${dst_root}/scripts/lib" "${dst_root}/hosts"
  for script in \
    build-host-plugin-dist.sh \
    calculate-effort.sh \
    codex-companion.sh \
    codex-review-app-server-proxy.mjs \
    codex-primary-environment-guard.sh \
    cursor-companion.sh \
    model-routing.sh \
    resolve-impl-backend.sh \
    set-impl-backend.sh \
    setup-cursor.sh \
    setup-grok.sh; do
    if [ -f "${ROOT_DIR}/scripts/${script}" ]; then
      cp "${ROOT_DIR}/scripts/${script}" "${dst_root}/scripts/${script}"
      chmod +x "${dst_root}/scripts/${script}" 2>/dev/null || true
    fi
  done
  if [ -f "${ROOT_DIR}/scripts/lib/host-registry.sh" ]; then
    cp "${ROOT_DIR}/scripts/lib/host-registry.sh" "${dst_root}/scripts/lib/host-registry.sh"
  fi
  if [ -f "${ROOT_DIR}/scripts/lib/orchestration-ledger.sh" ]; then
    cp "${ROOT_DIR}/scripts/lib/orchestration-ledger.sh" "${dst_root}/scripts/lib/orchestration-ledger.sh"
  fi
  if [ -f "${ROOT_DIR}/hosts/registry.json" ]; then
    cp "${ROOT_DIR}/hosts/registry.json" "${dst_root}/hosts/registry.json"
  fi
}

copy_workflow_runtime_sources() {
  local dst_root="$1"
  # Work, loop, and advisor helpers load each other dynamically. Package their
  # source tree and reusable templates instead of a shallow entrypoint list.
  # Runtime state, reports, test fixtures, dependencies, and symlinks are not
  # distribution inputs. Cursor/Grok retain their existing helper selection.
  node - "$ROOT_DIR" "$dst_root" <<'NODE'
const fs = require('fs');
const path = require('path');
const [sourceRoot, destinationRoot] = process.argv.slice(2);
const excludedDirectories = new Set(['node_modules', '__pycache__', 'sandbox-test', 'evidence', 'out', 'reports', 'dist']);
const scriptExtensions = new Set(['.sh', '.js', '.mjs', '.py']);
const templateExtensions = new Set(['.template', '.json', '.yaml', '.yml', '.sh', '.md']);
const hiddenTemplateNames = new Set(['.claude-code-harness.config.yaml.template', '.claude-code-harness-version.template']);

function copySources(relative) {
  const source = path.join(sourceRoot, relative);
  for (const entry of fs.readdirSync(source, {withFileTypes: true})) {
    const child = path.join(relative, entry.name);
    if (entry.isDirectory()) {
      if (!entry.name.startsWith('.') && !excludedDirectories.has(entry.name)) copySources(child);
      continue;
    }
    if (!entry.isFile()) continue;
    const extension = path.extname(entry.name);
    const parts = child.split(path.sep);
    if (entry.name.startsWith('.') && !(parts[0] === 'templates' && hiddenTemplateNames.has(entry.name))) continue;
    const allowed = parts[0] === 'templates'
      ? templateExtensions.has(extension)
      : scriptExtensions.has(extension) || (parts[1] === 'lib' && ['.json', '.txt'].includes(extension));
    if (!allowed) continue;
    const destination = path.join(destinationRoot, child);
    fs.mkdirSync(path.dirname(destination), {recursive: true});
    fs.copyFileSync(path.join(sourceRoot, child), destination);
    fs.chmodSync(destination, fs.statSync(path.join(sourceRoot, child)).mode & 0o777);
  }
}

copySources('scripts');
copySources('templates');
NODE
}

copy_hook_script_closure() {
  local dst_root="$1"
  local hooks_file="$2"
  local rel_path

  [ -f "${ROOT_DIR}/${hooks_file}" ] || return 0

  while IFS= read -r rel_path; do
    [ -n "$rel_path" ] || continue
    if [ -f "${ROOT_DIR}/${rel_path}" ]; then
      mkdir -p "$(dirname "${dst_root}/${rel_path}")"
      cp "${ROOT_DIR}/${rel_path}" "${dst_root}/${rel_path}"
      chmod +x "${dst_root}/${rel_path}" 2>/dev/null || true
    fi
  done < <(grep -Eoh 'scripts/[A-Za-z0-9_./-]+\.sh' "${ROOT_DIR}/${hooks_file}" | sort -u)
}

write_normalized_manifest() {
  local host="$1"
  local src_manifest="$2"
  local dst_manifest="$3"
  node - "$host" "$src_manifest" "$dst_manifest" <<'NODE'
const fs = require("fs");
const [host, srcPath, dstPath] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(srcPath, "utf8"));

if (host === "claude") {
  manifest.skills = ["./skills/"];
  if (manifest.outputStyles) {
    manifest.outputStyles = "./output-styles/";
  }
} else if (host === "codex") {
  manifest.skills = "./skills/";
  manifest.interface = manifest.interface || {};
  manifest.interface.displayName = "Claude Code Harness for Codex";
} else if (host === "cursor") {
  manifest.skills = "./skills/";
  manifest.agents = "./agents/";
  manifest.interface = manifest.interface || {};
  manifest.interface.displayName = "Claude Code Harness for Cursor";
} else if (host === "grok") {
  manifest.skills = "./skills/";
  manifest.interface = manifest.interface || {};
  manifest.interface.displayName = "Claude Code Harness for Grok";
}

const serialized = JSON.stringify(manifest, null, 2) + "\n";
if (serialized.includes('"../')) {
  console.error("normalized manifest still contains .. paths");
  process.exit(1);
}
fs.mkdirSync(require("path").dirname(dstPath), { recursive: true });
fs.writeFileSync(dstPath, serialized);
NODE
}

write_generated_cursor_manifest() {
  local dst_manifest="$1"
  local version="0.0.0"
  if [ -f "${ROOT_DIR}/VERSION" ]; then
    version="$(cat "${ROOT_DIR}/VERSION")"
  elif [ -f "${ROOT_DIR}/.codex-plugin/plugin.json" ]; then
    version="$(node -e 'console.log(require(process.argv[1]).version || "0.0.0")' "${ROOT_DIR}/.codex-plugin/plugin.json")"
  fi
  node - "$dst_manifest" "$version" <<'NODE'
const fs = require("fs");
const [dstPath, version] = process.argv.slice(2);
const manifest = {
  name: "harness",
  version,
  description: "Candidate Cursor adapter for Claude Code Harness Plan, Work, Review, and Release workflows.",
  author: {
    name: "Chachamaru",
    url: "https://github.com/Chachamaru127"
  },
  homepage: "https://github.com/Chachamaru127/claude-code-harness",
  repository: "https://github.com/Chachamaru127/claude-code-harness",
  license: "MIT",
  keywords: ["cursor", "skills", "workflow", "plan-work-review", "harness"],
  skills: "./skills/",
  agents: "./agents/",
  interface: {
    displayName: "Claude Code Harness for Cursor",
    shortDescription: "Candidate Harness workflow adapter for Cursor",
    longDescription: "Use Claude Code Harness skills in Cursor for evidence-backed planning, implementation, review, release, setup, sync, and team execution workflows.",
    developerName: "Chachamaru",
    category: "Coding",
    capabilities: ["Read", "Write", "Interactive"],
    defaultPrompt: [
      "Use harness-plan to plan this change.",
      "Use harness-work to execute the next Plans.md task."
    ],
    websiteURL: "https://github.com/Chachamaru127/claude-code-harness",
    privacyPolicyURL: "https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement",
    termsOfServiceURL: "https://docs.github.com/en/site-policy/github-terms/github-terms-of-service",
    brandColor: "#FF4500",
    screenshots: []
  }
};
fs.mkdirSync(require("path").dirname(dstPath), { recursive: true });
fs.writeFileSync(dstPath, JSON.stringify(manifest, null, 2) + "\n");
NODE
}

write_generated_cursor_agent() {
  local role="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  case "$role" in
    worker)
      cat >"$dst" <<'EOF'
---
name: worker
description: Scoped implementation worker for a single Plans.md task in Cursor.
model: composer-2.5-fast
readonly: false
---

# Worker (Cursor adapter)

Implement one assigned Plans.md task. Run focused validation. Return changed
files, commands run, and blockers. Do not spawn subagents; return
`advisor-request.v1` when policy requires Advisor input.
EOF
      ;;
    reviewer)
      cat >"$dst" <<'EOF'
---
name: reviewer
description: Read-only reviewer for diffs, risk, and missing tests in Cursor.
model: composer-2.5-fast
readonly: true
---

# Reviewer (Cursor adapter)

Review evidence-first. Report prioritized findings with file references. Do not
edit files. Emit structured review output compatible with harness-review.
EOF
      ;;
    advisor)
      cat >"$dst" <<'EOF'
---
name: advisor
description: Non-executing advisor for advisor-request.v1 in Cursor.
model: claude-fable-5
readonly: true
---

# Advisor (Cursor adapter)

Return `advisor-response.v1` only. Decisions: PLAN / CORRECTION / STOP.
No code edits, no shell, no user-facing prose.
EOF
      ;;
  esac
}

write_generated_grok_manifest() {
  local dst_manifest="$1"
  local version="0.0.0"
  if [ -f "${ROOT_DIR}/VERSION" ]; then
    version="$(cat "${ROOT_DIR}/VERSION")"
  elif [ -f "${ROOT_DIR}/.grok-plugin/plugin.json" ]; then
    version="$(node -e 'console.log(require(process.argv[1]).version || "0.0.0")' "${ROOT_DIR}/.grok-plugin/plugin.json")"
  fi
  node - "$dst_manifest" "$version" <<'NODE'
const fs = require("fs");
const [dstPath, version] = process.argv.slice(2);
const manifest = {
  name: "harness",
  version,
  description: "Internal-compatible Grok adapter for Claude Code Harness Plan, Work, Review, and Release workflows.",
  author: {
    name: "Chachamaru",
    url: "https://github.com/Chachamaru127"
  },
  homepage: "https://github.com/Chachamaru127/claude-code-harness",
  repository: "https://github.com/Chachamaru127/claude-code-harness",
  license: "MIT",
  keywords: ["grok", "skills", "workflow", "plan-work-review", "harness"],
  skills: "./skills/",
  interface: {
    displayName: "Claude Code Harness for Grok",
    shortDescription: "Internal-compatible Harness workflow adapter for Grok",
    longDescription: "Use Claude Code Harness skills in Grok for evidence-backed planning, implementation, review, release, setup, sync, and team execution workflows. This is an internal-compatible adapter route; live H1-H8 workflow smoke is required before any public top-tier claim.",
    developerName: "Chachamaru",
    category: "Coding",
    capabilities: ["Read", "Write", "Interactive"],
    defaultPrompt: [
      "Use harness-plan to plan this change.",
      "Use harness-work to execute the next Plans.md task."
    ],
    websiteURL: "https://github.com/Chachamaru127/claude-code-harness",
    privacyPolicyURL: "https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement",
    termsOfServiceURL: "https://docs.github.com/en/site-policy/github-terms/github-terms-of-service",
    brandColor: "#FF4500",
    screenshots: []
  }
};
fs.mkdirSync(require("path").dirname(dstPath), { recursive: true });
fs.writeFileSync(dstPath, JSON.stringify(manifest, null, 2) + "\n");
NODE
}

build_claude() {
  copy_tree "${ROOT_DIR}/.claude-plugin" "${OUT_DIR}/.claude-plugin"
  write_normalized_manifest "claude" "${ROOT_DIR}/.claude-plugin/plugin.json" "${OUT_DIR}/.claude-plugin/plugin.json"
  copy_tree "${ROOT_DIR}/skills" "${OUT_DIR}/skills"
  # Claude-host Breezing uses the same companion/reviewer transport as Codex;
  # ship the complete helper closure rather than a proxy without its caller.
  copy_runtime_helpers "${OUT_DIR}"
  copy_workflow_runtime_sources "${OUT_DIR}"
  copy_tree "${ROOT_DIR}/agents" "${OUT_DIR}/agents"
  copy_tree "${ROOT_DIR}/hooks" "${OUT_DIR}/hooks"
  copy_hook_script_closure "${OUT_DIR}" ".claude-plugin/hooks.json"
  copy_hook_script_closure "${OUT_DIR}" "hooks/hooks.json"
  copy_tree "${ROOT_DIR}/output-styles" "${OUT_DIR}/output-styles"
  mkdir -p "${OUT_DIR}/bin"
  for bin in harness harness-darwin-amd64 harness-darwin-arm64 harness-linux-amd64 harness-windows-amd64.exe; do
    if [ -f "${ROOT_DIR}/bin/${bin}" ]; then
      cp "${ROOT_DIR}/bin/${bin}" "${OUT_DIR}/bin/${bin}"
    fi
  done
  cp "${ROOT_DIR}/VERSION" "${OUT_DIR}/VERSION"
}

build_codex() {
  mkdir -p "${OUT_DIR}/.codex-plugin"
  write_normalized_manifest "codex" "${ROOT_DIR}/.codex-plugin/plugin.json" "${OUT_DIR}/.codex-plugin/plugin.json"
  copy_tree "${ROOT_DIR}/codex/.codex/skills" "${OUT_DIR}/skills"
  # Codex's native worker/reviewer profiles are managed artifacts generated
  # from hosts.toml. A dist without them silently falls back to generic routes,
  # so treat the profiles as required rather than an optional mirror.
  local agents_dir="${ROOT_DIR}/codex/.codex/agents"
  if [ ! -d "${agents_dir}" ]; then
    echo "missing generated Codex agent profiles: ${agents_dir} (run harness gen)" >&2
    exit 1
  fi
  for profile in worker.toml reviewer.toml; do
    if [ ! -f "${agents_dir}/${profile}" ]; then
      echo "missing generated Codex agent profile: ${agents_dir}/${profile} (run harness gen)" >&2
      exit 1
    fi
  done
  copy_tree "${agents_dir}" "${OUT_DIR}/agents"
  copy_tree "${ROOT_DIR}/skills" "${OUT_DIR}/cursor-skills"

  # Codex skills call bundled Harness helpers through HARNESS_PLUGIN_ROOT.
  # Include workflow helper dependencies and templates as well as the shared
  # host setup helpers, including cursor:setup which builds the Cursor pack.
  copy_runtime_helpers "${OUT_DIR}"
  copy_workflow_runtime_sources "${OUT_DIR}"

  # codex-companion.sh performs worktree fingerprint capture before and after
  # every task. Ship the launcher and all supported platform binaries so the
  # generated package remains executable outside the source checkout.
  mkdir -p "${OUT_DIR}/bin"
  for bin in harness harness-darwin-amd64 harness-darwin-arm64 harness-linux-amd64 harness-windows-amd64.exe; do
    if [ -f "${ROOT_DIR}/bin/${bin}" ]; then
      cp "${ROOT_DIR}/bin/${bin}" "${OUT_DIR}/bin/${bin}"
    fi
  done
  cp "${ROOT_DIR}/VERSION" "${OUT_DIR}/VERSION"
}

normalize_cursor_skill_invocation() {
  # Cursor does not surface skills flagged `user-invocable: true` (Claude Code
  # slash-only convention). Normalize them to `false` so the Cursor adapter
  # registers the workflow skills as Agent-Decides skills invokable via
  # `/skill-name`. Only the frontmatter line is rewritten.
  local skills_dir="$1"
  node - "$skills_dir" <<'NODE'
const fs = require("fs");
const path = require("path");
const root = process.argv[2];

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full);
    } else if (entry.name === "SKILL.md") {
      const text = fs.readFileSync(full, "utf8");
      const next = text.replace(/^user-invocable:[ \t]*true[ \t]*$/m, "user-invocable: false");
      if (next !== text) {
        fs.writeFileSync(full, next);
      }
    }
  }
}

if (fs.existsSync(root)) {
  walk(root);
}
NODE
}

build_cursor() {
  mkdir -p "${OUT_DIR}/.cursor-plugin"
  if [ -f "${ROOT_DIR}/.cursor-plugin/plugin.json" ]; then
    write_normalized_manifest "cursor" "${ROOT_DIR}/.cursor-plugin/plugin.json" "${OUT_DIR}/.cursor-plugin/plugin.json"
  else
    write_generated_cursor_manifest "${OUT_DIR}/.cursor-plugin/plugin.json"
  fi
  local cursor_skill_source="${ROOT_DIR}/skills"
  if [ -d "${ROOT_DIR}/cursor-skills" ]; then
    cursor_skill_source="${ROOT_DIR}/cursor-skills"
  fi
  copy_tree "${cursor_skill_source}" "${OUT_DIR}/skills"
  normalize_cursor_skill_invocation "${OUT_DIR}/skills"
  copy_runtime_helpers "${OUT_DIR}"
  if [ -d "${ROOT_DIR}/.cursor/agents" ]; then
    copy_tree "${ROOT_DIR}/.cursor/agents" "${OUT_DIR}/agents"
  else
    write_generated_cursor_agent worker "${OUT_DIR}/agents/worker.md"
    write_generated_cursor_agent reviewer "${OUT_DIR}/agents/reviewer.md"
    write_generated_cursor_agent advisor "${OUT_DIR}/agents/advisor.md"
  fi
  mkdir -p "${OUT_DIR}/.cursor"
  if [ -f "${ROOT_DIR}/.cursor/AGENTS.md" ]; then
    cp "${ROOT_DIR}/.cursor/AGENTS.md" "${OUT_DIR}/.cursor/AGENTS.md"
  else
    cat >"${OUT_DIR}/.cursor/AGENTS.md" <<'EOF'
# AGENTS.md — Cursor Bootstrap Route (Candidate)

Use harness-plan for planning, harness-work for implementation,
harness-review for review, and breezing for multi-task execution.
EOF
  fi
}

build_grok() {
  mkdir -p "${OUT_DIR}/.grok-plugin"
  if [ -f "${ROOT_DIR}/.grok-plugin/plugin.json" ]; then
    write_normalized_manifest "grok" "${ROOT_DIR}/.grok-plugin/plugin.json" "${OUT_DIR}/.grok-plugin/plugin.json"
  else
    write_generated_grok_manifest "${OUT_DIR}/.grok-plugin/plugin.json"
  fi
  copy_tree "${ROOT_DIR}/skills" "${OUT_DIR}/skills"
  copy_runtime_helpers "${OUT_DIR}"
  # 133.8: the grok dist shipped without hooks/ entirely, so the policy engine
  # was never reachable from grok even though `--host grok` returns a decision
  # byte-identical to `--host claude`. grok reads the Claude hook layout
  # (`Harness Compatibility → claude → hooks on`), which is `hooks/hooks.json`.
  #
  # Shipping hooks/ alone is not enough. Its commands go through the valid_root
  # bootstrap, which only accepts a directory holding BOTH `bin/harness` and a
  # `.claude-plugin/plugin.json` naming this plugin. Without them the wrapper
  # finds no valid root inside the dist and exits 0 — the guardrail silently
  # does not run for anyone who installed only the grok package. So the grok
  # dist carries the same closure the claude dist does.
  copy_tree "${ROOT_DIR}/hooks" "${OUT_DIR}/hooks"
  copy_tree "${ROOT_DIR}/.claude-plugin" "${OUT_DIR}/.claude-plugin"
  copy_hook_script_closure "${OUT_DIR}" "hooks/hooks.json"
  mkdir -p "${OUT_DIR}/bin"
  for bin in harness harness-darwin-amd64 harness-darwin-arm64 harness-linux-amd64 harness-windows-amd64.exe; do
    if [ -f "${ROOT_DIR}/bin/${bin}" ]; then
      cp "${ROOT_DIR}/bin/${bin}" "${OUT_DIR}/bin/${bin}"
    fi
  done
  mkdir -p "${OUT_DIR}/.grok"
  if [ -f "${ROOT_DIR}/.grok/AGENTS.md" ]; then
    cp "${ROOT_DIR}/.grok/AGENTS.md" "${OUT_DIR}/.grok/AGENTS.md"
  else
    cat >"${OUT_DIR}/.grok/AGENTS.md" <<'EOF'
# AGENTS.md — Grok Bootstrap Route (Candidate)

Use harness-plan for planning, harness-work for implementation,
harness-review for review, and breezing for multi-task execution.
EOF
  fi
  if [ -f "${ROOT_DIR}/VERSION" ]; then
    cp "${ROOT_DIR}/VERSION" "${OUT_DIR}/VERSION"
  fi
}

case "$HOST" in
  claude) build_claude ;;
  codex) build_codex ;;
  cursor) build_cursor ;;
  grok) build_grok ;;
esac

echo "built ${HOST} dist at ${OUT_DIR}" >&2
