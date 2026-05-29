#!/usr/bin/env bash
# build-host-plugin-dist.sh
# Build host-specific install packages with normalized in-package manifest paths.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

HOST=""
OUT_DIR=""

usage() {
  cat <<'EOF'
Usage: build-host-plugin-dist.sh --host claude|codex|cursor --out <directory>

Generates a host-specific distribution package. Output directory is created or
replaced. Generated packages must not reference sibling paths with '..'.
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

case "$HOST" in
  claude|codex|cursor) ;;
  *)
    echo "invalid --host: $HOST" >&2
    exit 2
    ;;
esac

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

build_claude() {
  copy_tree "${ROOT_DIR}/.claude-plugin" "${OUT_DIR}/.claude-plugin"
  write_normalized_manifest "claude" "${ROOT_DIR}/.claude-plugin/plugin.json" "${OUT_DIR}/.claude-plugin/plugin.json"
  copy_tree "${ROOT_DIR}/skills" "${OUT_DIR}/skills"
  copy_tree "${ROOT_DIR}/agents" "${OUT_DIR}/agents"
  copy_tree "${ROOT_DIR}/hooks" "${OUT_DIR}/hooks"
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
  write_normalized_manifest "cursor" "${ROOT_DIR}/.cursor-plugin/plugin.json" "${OUT_DIR}/.cursor-plugin/plugin.json"
  copy_tree "${ROOT_DIR}/skills" "${OUT_DIR}/skills"
  normalize_cursor_skill_invocation "${OUT_DIR}/skills"
  copy_tree "${ROOT_DIR}/.cursor/agents" "${OUT_DIR}/agents"
  mkdir -p "${OUT_DIR}/.cursor"
  cp "${ROOT_DIR}/.cursor/AGENTS.md" "${OUT_DIR}/.cursor/AGENTS.md"
}

case "$HOST" in
  claude) build_claude ;;
  codex) build_codex ;;
  cursor) build_cursor ;;
esac

echo "built ${HOST} dist at ${OUT_DIR}" >&2
