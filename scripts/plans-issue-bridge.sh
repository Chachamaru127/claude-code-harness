#!/usr/bin/env bash
# plans-issue-bridge.sh
# Generates a dry-run payload for GitHub Issue integration from Plans.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage: scripts/plans-issue-bridge.sh [--plans PATH|--plan NAME] [--format json|markdown] [--team-mode] [--output PATH]
EOF
  exit 1
}

PLANS_FILE="Plans.md"
PLANS_FILE_EXPLICIT="false"
PLAN_NAME=""
FORMAT="json"
TEAM_MODE="false"
OUTPUT_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --plans)
      if [ $# -lt 2 ] || [[ "${2:-}" == --* ]]; then
        echo "--plans requires a path" >&2
        exit 1
      fi
      PLANS_FILE="${2:-}"
      PLANS_FILE_EXPLICIT="true"
      shift 2
      ;;
    --plan)
      if [ $# -lt 2 ] || [[ "${2:-}" == --* ]]; then
        echo "--plan requires a plan name" >&2
        exit 1
      fi
      PLAN_NAME="${2:-}"
      shift 2
      ;;
    --format)
      if [ $# -lt 2 ] || [[ "${2:-}" == --* ]]; then
        echo "--format requires json or markdown" >&2
        exit 1
      fi
      FORMAT="${2:-}"
      shift 2
      ;;
    --team-mode)
      TEAM_MODE="true"
      shift
      ;;
    --no-team-mode)
      TEAM_MODE="false"
      shift
      ;;
    --output)
      if [ $# -lt 2 ] || [[ "${2:-}" == --* ]]; then
        echo "--output requires a path" >&2
        exit 1
      fi
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [ -z "$PLANS_FILE" ] || [ "$PLANS_FILE" = "Plans.md" ]; then
        PLANS_FILE="$1"
        PLANS_FILE_EXPLICIT="true"
        shift
      else
        usage
      fi
      ;;
  esac
done

if [ -n "$PLAN_NAME" ]; then
  if [ "$PLANS_FILE_EXPLICIT" = "true" ]; then
    echo "--plan cannot be combined with --plans or a positional Plans file" >&2
    exit 1
  fi
  PLANS_FILE="$(PROJECT_ROOT="$(pwd)" bash "${SCRIPT_DIR}/plan-registry.sh" path "$PLAN_NAME")"
fi

if [ ! -f "$PLANS_FILE" ]; then
  echo "Plans file not found: $PLANS_FILE" >&2
  exit 2
fi

node - "$PLANS_FILE" "$FORMAT" "$TEAM_MODE" "$OUTPUT_FILE" <<'NODE'
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

process.stdout.on('error', (error) => {
  if (error.code === 'EPIPE') process.exit(0);
  throw error;
});

const [plansFile, format, teamModeFlag, outputFile] = process.argv.slice(2);
const teamMode = teamModeFlag === 'true';

function readText(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function repoNameFrom(plansPath) {
  try {
    const gitRoot = execSync('git rev-parse --show-toplevel', {
      cwd: path.dirname(plansPath),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    if (gitRoot) return path.basename(gitRoot);
  } catch {
    // fall back to the directory name that contains Plans.md
  }
  return path.basename(path.resolve(path.dirname(plansPath)));
}

function splitDepends(value) {
  if (!value || value === '-') return [];
  return value.split(',').map((item) => item.trim()).filter(Boolean);
}

function parsePlans(markdown) {
  const lines = markdown.split(/\r?\n/);
  const phases = [];
  const tasks = [];
  let currentPhase = null;

  for (const line of lines) {
    const phaseMatch = line.match(/^##\s+Phase\s+([^:]+):\s*(.*)$/);
    if (phaseMatch) {
      currentPhase = {
        id: phaseMatch[1].trim(),
        title: phaseMatch[2].trim(),
      };
      phases.push({ ...currentPhase, tasks: [] });
      continue;
    }

    const trimmed = line.trim();
    if (!trimmed.startsWith('|')) continue;
    if (/^\|[\s-]+\|/.test(trimmed)) continue;

    const cells = trimmed.slice(1, -1).split('|').map((cell) => cell.trim());
    if (cells.length < 5) continue;

    const [taskId, content, dod, depends, status] = cells;
    if (!/^\d+(?:\.\d+)*(?:-spike)?$/.test(taskId)) continue;

    const task = {
      id: taskId,
      content,
      dod,
      depends,
      depends_on: splitDepends(depends),
      status,
      phase: currentPhase ? { ...currentPhase } : null,
    };

    tasks.push(task);
    if (phases.length > 0) {
      phases[phases.length - 1].tasks.push(task);
    }
  }

  return { phases, tasks };
}

function countStatuses(tasks) {
  const counts = {};
  for (const task of tasks) {
    counts[task.status] = (counts[task.status] || 0) + 1;
  }
  return counts;
}

function escapeCell(value) {
  return String(value ?? '').replace(/\|/g, '\\|');
}

function renderTable(rows) {
  const header = ['Task', 'Content', 'DoD', 'Depends', 'Status'];
  const body = [header, ...rows.map((row) => [
    row.id,
    row.content,
    row.dod,
    row.depends,
    row.status,
  ])];
  return [
    `| ${body[0].map(escapeCell).join(' | ')} |`,
    `|${body[0].map(() => '---').join('|')}|`,
    ...body.slice(1).map((row) => `| ${row.map(escapeCell).join(' | ')} |`),
  ].join('\n');
}

function buildReport(plansPath, teamModeEnabled) {
  const repoName = repoNameFrom(plansPath);
  const markdown = readText(plansPath);
  const parsed = parsePlans(markdown);
  const summary = {
    phase_count: parsed.phases.length,
    task_count: parsed.tasks.length,
    status_counts: countStatuses(parsed.tasks),
  };

  const subIssues = parsed.tasks.map((task) => ({
    title: `${task.id} ${task.content}`,
    body: [
      `Task: ${task.id}`,
      `Phase: ${task.phase ? `${task.phase.id}: ${task.phase.title}` : 'unassigned'}`,
      `DoD: ${task.dod}`,
      `Depends: ${task.depends}`,
      `Status: ${task.status}`,
      '',
      'This is a dry-run payload. Plans.md remains the source of truth.',
    ].join('\n'),
    labels: ['harness-plan', `phase-${(task.phase && String(task.phase.id).split('.')[0]) || 'unassigned'}`],
    depends_on: task.depends_on,
    phase: task.phase,
    task_id: task.id,
    status: task.status,
  }));

  const trackingIssue = {
    title: `Plans.md tracking issue: ${repoName}`,
    body: [
      '# Plans.md tracking issue dry-run',
      '',
      `- Repo: ${repoName}`,
      `- Plans file: ${path.relative(process.cwd(), plansPath)}`,
      `- Team mode: ${teamModeEnabled ? 'enabled' : 'disabled (opt-in required)'}`,
      `- Sub-issues: ${subIssues.length}`,
      '',
      '## Phase overview',
      ...parsed.phases.map((phase) => `- ${phase.id}: ${phase.title} (${phase.tasks.length} tasks)`),
      '',
      '## Task snapshot',
      renderTable(parsed.tasks),
      '',
      'Plans.md is the source of truth. This payload is preview-only and does not mutate the plan.',
    ].join('\n'),
    labels: ['harness-plan', 'plans-sync', teamModeEnabled ? 'team-mode' : 'solo-preview'],
    state: 'dry-run',
  };

  return {
    schema_version: 'plans-issue-bridge.v1',
    generated_at: new Date().toISOString(),
    source: {
      repo_name: repoName,
      plans_file: path.resolve(plansPath),
    },
    team_mode: {
      enabled: teamModeEnabled,
      opt_in_required: true,
    },
    tracking_issue: trackingIssue,
    phases: parsed.phases,
    sub_issues: subIssues,
    summary,
  };
}

function renderMarkdown(report) {
  const lines = [
    '# Plans.md issue bridge dry-run',
    '',
    `- Repo: ${report.source.repo_name}`,
    `- Plans file: ${report.source.plans_file}`,
    `- Team mode: ${report.team_mode.enabled ? 'enabled' : 'disabled (opt-in required)'}`,
    `- Tracking issue: ${report.tracking_issue.title}`,
    `- Sub-issues: ${report.sub_issues.length}`,
    '',
    '## Summary',
    `- Phases: ${report.summary.phase_count}`,
    `- Tasks: ${report.summary.task_count}`,
    `- Status counts: ${Object.entries(report.summary.status_counts).map(([k, v]) => `${k}=${v}`).join(', ') || 'none'}`,
    '',
    '## Tracking issue body',
    report.tracking_issue.body,
    '',
    '## Sub-issues',
  ];

  for (const subIssue of report.sub_issues) {
    lines.push(`- ${subIssue.title}`);
    lines.push(`  - Depends: ${subIssue.depends_on.length > 0 ? subIssue.depends_on.join(', ') : '-'}`);
    lines.push(`  - Status: ${subIssue.status}`);
  }

  lines.push('');
  lines.push('Plans.md remains the source of truth.');
  return `${lines.join('\n')}\n`;
}

const report = buildReport(plansFile, teamMode);
const output = format === 'markdown'
  ? renderMarkdown(report)
  : `${JSON.stringify(report, null, 2)}\n`;

if (outputFile) {
  fs.mkdirSync(path.dirname(outputFile), { recursive: true });
  fs.writeFileSync(outputFile, output);
}

process.stdout.write(output);
NODE
