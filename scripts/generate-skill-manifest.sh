#!/usr/bin/env bash
# generate-skill-manifest.sh
# Converts skill frontmatter in the repo into machine-readable JSON.

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/generate-skill-manifest.sh [--output PATH]
EOF
  exit 1
}

OUTPUT_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

node - "$OUTPUT_FILE" <<'NODE'
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

process.stdout.on('error', (error) => {
  if (error.code === 'EPIPE') process.exit(0);
  throw error;
});

const [outputFile] = process.argv.slice(2);
const repoRoot = process.cwd();
const roots = ['skills', 'skills-codex', 'codex/.codex/skills', 'opencode/skills'];
const officialRuntimeFields = [
  'name',
  'description',
  'description-en',
  'description-ja',
  'allowed-tools',
  'argument-hint',
  'user-invocable',
  'disable-model-invocation',
  'context',
  'effort',
];
const designMetadataFields = [
  'kind',
  'purpose',
  'trigger',
  'shape',
  'role',
  'base',
  'pair',
  'owner',
  'since',
  'deprecated_in',
  'replaces',
];
const coreWorkflowSkillNames = new Set([
  'harness-plan',
  'harness-work',
  'harness-review',
  'harness-loop',
  'breezing',
  'harness-sync',
  'harness-setup',
  'harness-release',
  'harness-release-internal',
]);
const coreContract = {
  document: 'docs/architecture/hokage-core.md',
  capability_matrix_document: 'docs/tool-capability-matrix.md',
  capability_matrix_anchor: 'Capability Status',
  capabilities: [
    'skill_loading',
    'bootstrap_notice',
    'prompt_routing',
    'pre_use_guard',
    'post_use_gate',
    'review_artifact',
    'memory_bridge',
  ],
};

function walk(dirPath, entries) {
  if (!fs.existsSync(dirPath)) return;
  for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules') continue;
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath, entries);
    } else if (entry.isFile() && entry.name === 'SKILL.md') {
      entries.push(fullPath);
    }
  }
}

function parseScalar(value) {
  const trimmed = value.trim();
  if (trimmed === 'true') return true;
  if (trimmed === 'false') return false;
  if (/^-?\d+(?:\.\d+)?$/.test(trimmed)) return Number(trimmed);
  if ((trimmed.startsWith('[') && trimmed.endsWith(']')) || (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
    try {
      return JSON.parse(trimmed);
    } catch {
      return trimmed;
    }
  }
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function parseFrontmatter(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const lines = raw.split(/\r?\n/);
  if (lines[0] !== '---') return null;

  const frontmatter = {};
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i];
    if (line === '---') break;
    const match = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!match) continue;
    const [, key, value] = match;
    frontmatter[key] = parseScalar(value);
  }
  return frontmatter;
}

function parseDoNotUseFor(frontmatter) {
  const candidates = [
    frontmatter['description-en'],
    frontmatter['description-ja'],
    frontmatter.description,
  ].filter(Boolean);

  for (const candidate of candidates) {
    const englishMatch = String(candidate).match(/Do NOT (?:use|load) for:\s*(.+)$/i);
    if (englishMatch) {
      return englishMatch[1]
        .split(',')
        .map((item) => item.trim().replace(/^(and|or)\s+/i, '').replace(/[.。]+$/g, ''))
        .filter(Boolean);
    }

    const japaneseMatch = String(candidate).match(/。([^。]+)には使わない。?$/);
    if (japaneseMatch) {
      return japaneseMatch[1]
        .split('・')
        .map((item) => item.trim().replace(/[.。]+$/g, ''))
        .filter(Boolean);
    }
  }

  return [];
}

function rootNameFor(relativePath) {
  for (const root of roots) {
    const normalized = `${root}/`;
    if (relativePath.startsWith(normalized)) return root;
  }
  return 'unknown';
}

const skillFiles = [];
let usedGitIndex = false;
try {
  const output = execFileSync('git', ['-C', repoRoot, 'ls-files', '-z', '--', ...roots], {
    encoding: 'buffer',
    stdio: ['ignore', 'pipe', 'ignore'],
  }).toString('utf8');
  for (const relativePath of output.split('\0')) {
    if (!relativePath.endsWith('/SKILL.md')) continue;
    skillFiles.push(path.join(repoRoot, relativePath));
  }
  usedGitIndex = skillFiles.length > 0;
} catch {
  usedGitIndex = false;
}

if (!usedGitIndex) {
  for (const root of roots) {
    walk(path.join(repoRoot, root), skillFiles);
  }
}

const skills = skillFiles
  .map((filePath) => {
    const frontmatter = parseFrontmatter(filePath);
    if (!frontmatter) return null;

    const relativePath = path.relative(repoRoot, filePath).split(path.sep).join('/');
    const directory = path.dirname(relativePath).split(path.sep).join('/');
    const surface = rootNameFor(relativePath);
    const officialRuntime = {};
    for (const field of officialRuntimeFields) {
      officialRuntime[field] = Object.prototype.hasOwnProperty.call(frontmatter, field) ? frontmatter[field] : null;
    }
    const harnessMetadata = {};
    for (const field of designMetadataFields) {
      harnessMetadata[field] = Object.prototype.hasOwnProperty.call(frontmatter, field) ? frontmatter[field] : null;
    }
    const entry = {
      path: relativePath,
      directory,
      surface,
      name: frontmatter.name || path.basename(path.dirname(filePath)),
      description: frontmatter.description || null,
      description_en: frontmatter['description-en'] || null,
      description_ja: frontmatter['description-ja'] || null,
      allowed_tools: Array.isArray(frontmatter['allowed-tools']) ? frontmatter['allowed-tools'] : [],
      argument_hint: frontmatter['argument-hint'] || null,
      context: frontmatter.context || null,
      effort: frontmatter.effort || null,
      user_invocable: typeof frontmatter['user-invocable'] === 'boolean' ? frontmatter['user-invocable'] : null,
      disable_model_invocation: typeof frontmatter['disable-model-invocation'] === 'boolean' ? frontmatter['disable-model-invocation'] : null,
      do_not_use_for: parseDoNotUseFor(frontmatter),
      official_runtime: officialRuntime,
      harness_metadata: harnessMetadata,
      core_contract_document: null,
      capability_matrix_document: null,
    };

    for (const field of designMetadataFields) {
      entry[field] = harnessMetadata[field];
    }

    if (coreWorkflowSkillNames.has(entry.name) && entry.kind === 'workflow') {
      entry.core_contract_document = coreContract.document;
      entry.capability_matrix_document = coreContract.capability_matrix_document;
    }

    return entry;
  })
  .filter(Boolean)
  .sort((a, b) => a.path.localeCompare(b.path));

const surfaceIndex = new Map();
for (const skill of skills) {
  const surfaces = surfaceIndex.get(skill.name) || new Set();
  surfaces.add(skill.surface);
  surfaceIndex.set(skill.name, surfaces);
}

for (const skill of skills) {
  skill.related_surfaces = Array.from(surfaceIndex.get(skill.name) || []).sort();
}

const manifest = {
  schema_version: 'skill-manifest.v1',
  generated_at: new Date().toISOString(),
  repo_root: repoRoot,
  roots,
  official_runtime_fields: officialRuntimeFields,
  harness_metadata_fields: designMetadataFields,
  core_contract: coreContract,
  skill_count: skills.length,
  skills,
};

const output = `${JSON.stringify(manifest, null, 2)}\n`;
if (outputFile) {
  fs.mkdirSync(path.dirname(outputFile), { recursive: true });
  fs.writeFileSync(outputFile, output);
}
process.stdout.write(output);
NODE
