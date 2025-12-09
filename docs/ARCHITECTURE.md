# cursor-cc-plugins v3 Architecture

> **Version**: 3.0
> **Last Updated**: 2025-12-09

This document describes the internal architecture of cursor-cc-plugins v3, which introduces a 3-layer Skill / Workflow / Profile separation.

---

## Overview

cursor-cc-plugins v3 uses a modular architecture with three main layers:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Profile Layer                                 │
│  (cursor-pm.yaml, claude-worker.yaml)                                │
│  - Defines which client uses which workflows                         │
│  - Specifies skill category permissions                              │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ references
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       Workflow Layer                                 │
│  (init.yaml, plan.yaml, work.yaml, review.yaml, etc.)               │
│  - Defines phase sequences                                           │
│  - Orchestrates skills in steps                                      │
│  - Handles conditions and error recovery                             │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ uses
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Skill Layer                                   │
│  (SKILL.md files with SkillPort-compatible frontmatter)             │
│  - Self-contained knowledge units                                    │
│  - Reusable across workflows                                         │
│  - Shareable via SkillPort MCP server                               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
plugins/cursor-cc-plugins/
├── skills/                     # Skill definitions (SKILL.md)
│   ├── core/                   # Core skills (always loaded)
│   │   ├── ccp-core-general-principles/
│   │   │   └── SKILL.md        # Safety principles (alwaysApply: true)
│   │   ├── ccp-core-read-repo-context/
│   │   │   └── SKILL.md        # Repository context reading
│   │   └── ccp-core-diff-aware-editing/
│   │       └── SKILL.md        # Minimal diff editing (alwaysApply: true)
│   ├── pm/                     # PM-specific skills
│   │   ├── ccp-init-requirements/
│   │   ├── ccp-plan-feature/
│   │   └── ccp-plan-review/
│   ├── worker/                 # Worker-specific skills
│   │   ├── ccp-work-impl-feature/
│   │   ├── ccp-work-write-tests/
│   │   └── ccp-review-changes/
│   └── ci/                     # CI-specific skills
│       ├── ccp-ci-analyze-failures/
│       └── ccp-ci-fix-failing-tests/
├── workflows/                  # Workflow definitions (YAML)
│   └── default/                # Default workflow set
│       ├── init.yaml
│       ├── plan.yaml
│       ├── work.yaml
│       ├── review.yaml
│       ├── sync-status.yaml
│       └── start-task.yaml
├── profiles/                   # Profile definitions (YAML)
│   ├── cursor-pm.yaml          # Cursor (PM) profile
│   └── claude-worker.yaml      # Claude Code (Worker) profile
├── generators/                 # Code generators (future)
├── commands/                   # Slash commands (existing)
└── agents/                     # Agent definitions (existing)
```

---

## Layer Details

### 1. Skill Layer

Skills are self-contained knowledge units stored as `SKILL.md` files with SkillPort-compatible frontmatter.

#### SKILL.md Format

```markdown
---
name: ccp-example-skill
description: "Brief description of what this skill does"
metadata:
  skillport:
    category: core|pm|worker|ci
    tags: [tag1, tag2, tag3]
    alwaysApply: true|false
---

# Skill Title

Detailed content and instructions...
```

#### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique skill identifier (ccp-{category}-{name}) |
| `description` | Yes | Brief description (shown in SkillPort) |
| `metadata.skillport.category` | Yes | Skill category: core, pm, worker, ci |
| `metadata.skillport.tags` | Yes | Searchable tags |
| `metadata.skillport.alwaysApply` | No | If true, always applied (default: false) |

#### Skill Categories

| Category | Purpose | Used By |
|----------|---------|---------|
| `core` | Base principles, safety rules | Both Cursor and Claude Code |
| `pm` | Requirements, planning, review | Cursor (PM) |
| `worker` | Implementation, testing | Claude Code (Worker) |
| `ci` | CI failure analysis and fixes | Claude Code (Worker) |

### 2. Workflow Layer

Workflows define phase sequences using YAML configuration.

#### Workflow YAML Format

```yaml
phase: init|plan|work|review|sync-status|start-task
description: "What this workflow does"

steps:
  - id: step-name
    skill: ccp-skill-name        # Reference to skill
    input:
      files: [file1.md, file2.json]
      context_from: [git_status, repo_tree]
    output:
      variables: [var1, var2]
      update_files: [Plans.md]
    mode: required|optional
    condition: "variable_name"   # Optional condition
    parallel: true|false         # Run in parallel with other steps

on_success:
  message: |
    Success message template with {{variables}}

on_error:
  message: |
    Error message template
```

#### Step Configuration

| Field | Description |
|-------|-------------|
| `id` | Unique step identifier |
| `skill` | Referenced skill name |
| `input` | Input configuration (files, context, variables) |
| `output` | Output configuration (variables, file updates) |
| `mode` | `required` = must succeed, `optional` = can fail |
| `condition` | Variable condition for step execution |
| `parallel` | Run concurrently with other parallel steps |

### 3. Profile Layer

Profiles define client-specific configurations.

#### Profile YAML Format

```yaml
id: profile-name
client: cursor|claude-code
description: "Profile description"

roles:
  - phase: init
    workflow: default
    description: "What this role does"

skills:
  categories:
    include: [core, pm]
    exclude: [worker, ci]

markers:
  todo: "cc:TODO"
  wip: "cc:WIP"
  done: "cc:完了"

constraints:
  no_production_deploy: true
  allow_staging_deploy: true

handoff:
  to_pm: "/handoff-to-cursor"
  from_pm: "/start-task"

output_style:
  vibecoder_friendly: true
  include_technical_details: false
```

---

## SkillPort Integration

cursor-cc-plugins v3 integrates with [SkillPort](https://github.com/Chachamaru127/skillport) for skill sharing between Cursor and Claude Code.

### Pattern A: External Tool (Recommended)

SkillPort acts as an MCP server that reads SKILL.md files from the `skills/` directory:

```
┌───────────────┐     MCP     ┌────────────────┐     reads     ┌──────────────┐
│    Cursor     │ ◄─────────► │   SkillPort    │ ◄───────────► │  skills/     │
│    (Client)   │             │   (MCP Server) │               │  SKILL.md    │
└───────────────┘             └────────────────┘               └──────────────┘
                                                                      ▲
                                                               reads  │
                                                               ┌──────┴───────┐
                                                               │  Claude Code │
                                                               │  (local)     │
                                                               └──────────────┘
```

### Cursor MCP Configuration

Add to `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "ccp-skills": {
      "command": "uvx",
      "args": ["skillport"],
      "env": {
        "SKILLPORT_SKILLS_DIR": "/absolute/path/to/cursor-cc-plugins/skills",
        "SKILLPORT_ENABLED_CATEGORIES": "core,pm,worker,ci"
      }
    }
  }
}
```

### How It Works

1. **SkillPort reads SKILL.md files** from the configured directory
2. **Skills are exposed as MCP tools** to Cursor
3. **Claude Code reads skills locally** from the same directory
4. **Both agents share the same skill definitions**

### Claude Code Configuration

Claude Code reads skills directly from the filesystem. No additional configuration needed if the plugin is installed.

---

## Backward Compatibility

v3 maintains full backward compatibility with existing commands:

| v1 Command | v3 Behavior |
|------------|-------------|
| `/init` | Triggers `init.yaml` workflow |
| `/plan` | Triggers `plan.yaml` workflow |
| `/work` | Triggers `work.yaml` workflow |
| `/review` | Triggers `review.yaml` workflow |
| `/sync-status` | Triggers `sync-status.yaml` workflow |
| `/start-task` | Triggers `start-task.yaml` workflow |

### Simple Mode vs Advanced Mode

| Mode | Description | Configuration |
|------|-------------|---------------|
| Simple | Use as before (no changes needed) | Default |
| Advanced | Customize workflows and skills | Edit YAML files |

---

## Extending Skills

### Creating a New Skill

1. Create directory: `skills/{category}/{skill-name}/`
2. Create `SKILL.md` with proper frontmatter
3. Add content following the format

Example:

```markdown
---
name: ccp-custom-my-skill
description: "Description of my custom skill"
metadata:
  skillport:
    category: worker
    tags: [custom, example]
    alwaysApply: false
---

# My Custom Skill

Instructions for the skill...
```

### Best Practices

1. **Use clear naming**: `ccp-{category}-{descriptive-name}`
2. **Write good descriptions**: Used for SkillPort search
3. **Choose appropriate tags**: Help with discovery
4. **Use alwaysApply sparingly**: Only for essential rules

---

## Customizing Workflows

### Modifying Existing Workflows

1. Copy `workflows/default/{workflow}.yaml` to customize
2. Edit steps, add/remove skills
3. Test with dry-run mode first

### Creating Custom Workflows

1. Create new directory: `workflows/custom/`
2. Add workflow YAML files
3. Reference in profile: `workflow: custom`

---

## Plans.md Markers

Both profiles use Plans.md for shared state:

| Marker | Meaning | Set By |
|--------|---------|--------|
| `cursor:依頼中` | Task assigned by PM | Cursor |
| `cc:TODO` | Not started | Claude Code |
| `cc:WIP` | Work in progress | Claude Code |
| `cc:完了` | Completed | Claude Code |
| `cursor:確認済` | Verified by PM | Cursor |

---

## Error Recovery

### Automatic Recovery

Workflows include automatic error recovery:

```yaml
error_recovery:
  max_retries: 3
  escalate_to: cursor-pm
```

### Escalation

After max retries, Claude Code escalates to Cursor with:
- Error description
- Attempted fixes
- Recommended actions

---

## Concrete Example: Tracing /init Workflow

This section shows exactly how a workflow calls skills, so you can understand and extend them.

### Step 1: User runs /init

```
User: "I want to build a blog app"
```

### Step 2: Workflow YAML is loaded

**File**: `workflows/default/init.yaml`

```yaml
phase: init
description: "プロジェクトを初期化し、開発ワークフローをセットアップする"

steps:
  - id: read-context
    skill: ccp-core-read-repo-context  # ← This skill is called
    input:
      files:
        - README.md
        - package.json
    mode: required
```

### Step 3: Skill is executed

**File**: `skills/core/ccp-core-read-repo-context/SKILL.md`

```markdown
---
name: ccp-core-read-repo-context
description: "リポジトリのコンテキストを読み取り理解する"
metadata:
  skillport:
    category: core
---

# Read Repository Context

リポジトリの構造とコンテキストを把握するためのスキル。

## 実行手順

### Step 1: 基本構造の把握
- ls -la
- find . -maxdepth 2 -type d
- cat README.md
...
```

### Step 4: What happens in the conversation

```
Claude Code: (ccp-core-read-repo-context executing)
"プロジェクトを確認しています...

📁 現在のディレクトリ: 空のフォルダ
📝 README.md: なし
📦 package.json: なし

→ 新規プロジェクトとして初期化します"

Claude Code: (ccp-init-requirements executing)
"🎯 どんなものを作りたいですか？"
```

### Complete Skill Chain for /init

| Step | Skill | File Location |
|------|-------|---------------|
| 1 | ccp-core-read-repo-context | `skills/core/ccp-core-read-repo-context/SKILL.md` |
| 2 | ccp-init-requirements | `skills/pm/ccp-init-requirements/SKILL.md` |
| 3 | ccp-project-scaffolder | `skills/core/ccp-project-scaffolder/SKILL.md` |
| 4 | ccp-generate-workflow-files | `skills/core/ccp-generate-workflow-files/SKILL.md` |
| 5 | ccp-plan-review | `skills/pm/ccp-plan-review/SKILL.md` |
| 6 | ccp-vibecoder-guide | `skills/core/ccp-vibecoder-guide/SKILL.md` |

### Adding Your Own Skill

1. Create: `skills/worker/ccp-my-custom-skill/SKILL.md`
2. Add frontmatter with `name`, `description`, `metadata.skillport.category`
3. Reference in workflow: `skill: ccp-my-custom-skill`

---

## Related Documents

- [Admin Guide](ADMIN_GUIDE.md) - Team deployment and configuration
- [Limitations](LIMITATIONS.md) - Known limitations and workarounds
- [Contributing](../CONTRIBUTING.md) - How to contribute
