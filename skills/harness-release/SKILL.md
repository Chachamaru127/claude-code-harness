---
name: harness-release
description: "Generic release automation for projects using Keep a Changelog + GitHub. Single confirmation gate then end-to-end automation: bump detection, CHANGELOG promotion, tag, GitHub Release. Trigger: release, version bump, publish. Do NOT load for: implementation, review, planning, setup."
description-en: "Generic release automation for projects using Keep a Changelog + GitHub. Single confirmation gate then end-to-end automation: bump detection, CHANGELOG promotion, tag, GitHub Release. Trigger: release, version bump, publish. Do NOT load for: implementation, review, planning, setup."
description-ja: "汎用リリース自動化スキル。Keep a Changelog と GitHub を使うあらゆるプロジェクトで動作。単一確認ゲートで bump 判定・CHANGELOG 昇格・タグ・GitHub Release まで全自動実行する。リリース、バージョンバンプ、タグ作成、公開で起動。実装・コードレビュー・プランニング・セットアップには使わない。"
kind: workflow
purpose: "Release projects through changelog, version, tag, and GitHub Release gates"
trigger: "release, version bump, publish"
shape: workflow
role: orchestrator
pair: harness-review
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Bash", "AskUserQuestion", "Skill"]
argument-hint: "[patch|minor|major|--dry-run]"
context: fork
effort: high
user-invocable: true
---

# Harness Release (Generic)

Generic release automation skill for **any project** using Keep a Changelog + GitHub.

**Design principle**: Single confirmation gate. The user reviews and approves the full plan exactly once. After approval, the skill runs file rewrites → commit → push → tag → GitHub Release without interruption.

> **Literal invocation note**: The entry point for this skill uses literal commands such as `harness-release`, `/release`, `/release patch`, `/release --dry-run` exactly as typed.

## Bare invocation contract

if $ARGUMENTS == "":
  → Interpret as "I want to commit my current work and release it", then run the Review Gate detection
  → Auto-advance to Step 0 (Review Gate) only if the target work can be identified unambiguously
  → If the target is unclear or there is no review state, use AskUserQuestion to present options before proceeding

On the first response to a bare invocation, always output the following literal marker:

`RELEASE_AUTOSTART: target=<work-summary>, base_ref=<ref>, mode=<patch|minor|major|auto>`

Prohibited actions: "task is unclear", "waiting for instructions", "no tasks found", "waiting for additional instructions".

<!-- The block above is the AUTO-START CONTRACT. Follows the skill-editing.md "within first 3 lines" rule. Implements the patterns.md P27 3-point solution (machine-readable condition + prohibited-action literals + AUTOSTART marker) -->

### Output Contract (P35: UX fix for "appears stuck")

The **last line** of skill output at conclusion must always contain the following literal:

`↑ Claude will summarize these results. Press Enter to continue or enter a new prompt for different instructions.`

This is an explicit instruction addressing the UX problem where output via `<local-command-stdout>` makes users feel the session has "stopped" (patterns.md P35).

When only `harness-release` / `/release` is entered, treat it as
**"I want to commit my current work and release it"**.
Do not stop with "no tasks found" or "waiting for instructions".

In a bare release, run the **Review Gate** and **Work Commit Gate** before the normal release preflight.

1. Check `git status --porcelain` and `git log @{upstream}..HEAD` / `main..HEAD` to identify the target "current work"
2. Check `.claude/state/review-result.json` and `.claude/state/review-approved.json` to see if the target work has an `APPROVE` review
3. If no APPROVE review exists, confirm with `AskUserQuestion`
4. If the user selects "Start with review", launch `harness-review` and do not proceed to release until `APPROVE` is returned
5. If `harness-review` returns `REQUEST_CHANGES`, hold the release and re-run `harness-review` after fixing with `harness-work`. Loop until `APPROVE`
6. After `harness-review` returns `APPROVE`, create a work commit for the working tree changes
7. Once the working tree is clean, proceed to the normal release preflight / confirmation gate / tag / GitHub Release

### Review Gate AskUserQuestion

When `harness-release` runs and review approval cannot be confirmed, do not guess and release. Show the following Ask:

```text
question: "harness-release will commit your current work and release it, but no APPROVE review was found for this work. How would you like to proceed?"
options:
  - label: "Start with review (Recommended)"
    description: "Runs harness-review and proceeds to commit/release only if APPROVE is returned."
  - label: "release dry-run"
    description: "No file changes — only shows the release plan and missing gates."
  - label: "Cancel"
    description: "Stop without review or release."
```

If the user selects "Start with review", run `harness-review` within the same session.
The target for `harness-review` is determined by `harness-review`'s own bare review contract.
If the review returns `APPROVE`, return to the `harness-release` Work Commit Gate.
If the review returns `REQUEST_CHANGES`, hold the release and re-run `harness-review` after fixing with `harness-work`.
This fix-then-re-review loop continues until `APPROVE`.

Return control to the user only in these cases:

1. The fix requires a decision that needs the spec document / Plans.md / API / permission / migration / billing input, requiring `AskUserQuestion`
2. Multiple fix approaches exist and the choice affects user value or compatibility
3. The user chose `release dry-run` or `Cancel` in the Ask

`REQUEST_CHANGES` alone must not be used as a final stopping reason.

### Work Commit Gate

In a bare release, if the working tree has uncommitted changes, create a review-approved work commit separately from the release version bump commit.

```bash
git status --short
git diff --stat
git add <reviewed files>
git commit -m "<type>: <summary>"
```

Generate a short commit message from the review summary / Plans.md task / branch name.
If a message cannot be determined, use `AskUserQuestion` to present 2–3 commit message candidates.
After creating the work commit, verify or update `commit_hash` in `.claude/state/review-result.json`, then proceed to release preflight.

After entering the normal release preflight, treat a dirty working tree as a failure as usual.
Do not proceed to version bump / tag / GitHub Release with a dirty tree.

## Quick Reference

```bash
/release              # Review gate → commit → release current work
/release patch        # Explicitly specify patch bump
/release minor        # Explicitly specify minor bump
/release major        # Explicitly specify major bump
/release --dry-run    # Show plan only, do not execute
```

## Prerequisites

Projects using this skill must satisfy the following:

1. `CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/) format
2. An `[Unreleased]` section exists
3. The project has one of the following version files:
   - `VERSION` (standalone file)
   - `package.json` (npm)
   - `pyproject.toml` (Python, `[project]` or `[tool.poetry]`)
   - `Cargo.toml` (Rust, `[package]`)
4. `gh` CLI is installed and authenticated
5. git remote `origin` points to GitHub
6. For Claude Code plugin projects, the `claude` CLI supports `plugin tag`

If these conditions are not met, Preflight will detect and abort.

`prUrlTemplate` for multi-host review URLs is recognized as a future candidate,
but this skill's release automation uses `gh` CLI and GitHub remote as the primary path.
Auto-retrieval of owner / branch / release assets / CI metadata varies too much per host, so Phase 56.2.3 keeps this docs-only.

## Single Gate Flow

```
[Bare release only: Work review/commit pre-stage]
  ↓
  0. Review Gate (AskUserQuestion → harness-review if not yet reviewed)
  0.5 Work Commit Gate (commit review-APPROVE work separately from release bump)
  ↓
[Pre-Gate: information gathering only, no file changes]
  ↓
  1. Preflight (working tree clean / CHANGELOG / gh etc.)
  2. Automatic version file detection
  3. Read current version
  4. Claude plugin tag preflight (plugin projects only)
  5. Parse [Unreleased] content → estimate bump level
  6. Calculate new version
  7. Create CHANGELOG diff draft (in memory)
  8. Create GitHub Release notes draft (in memory)

★━━━━━━ Single Confirmation Gate ━━━━━━★
  Present the full plan to the user exactly once:
    - Detected version file
    - Current version → new version
    - Bump detection reason (e.g., "[Unreleased] has ### Added → minor")
    - CHANGELOG change preview
    - GitHub Release notes draft
    - List of files to commit
    - Final actions (push + tag + release publish)

  User response:
    "yes"              → Proceed to Post-Gate
    "<revision>"       → Regenerate draft per instruction, re-confirm
    "cancel/no"        → Exit without doing anything
★━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━★
  ↓
[Post-Gate: no interruptions after approval]

  9.  Rewrite version file
  10. Rewrite CHANGELOG.md ([Unreleased] → [X.Y.Z] promotion + compare link)
  11. git add + commit
  12. Claude plugin tag validation + tag (plugin projects only)
  13. GitHub Release semver tag (only for projects that need it)
  14. git push origin <branch> --tags
  15. gh release create vX.Y.Z
  16. Completion report
```

## Pre-Gate Details

### 1. Preflight

```bash
# Required tools
command -v gh >/dev/null || { echo "gh CLI not found"; exit 1; }
command -v python3 >/dev/null || { echo "python3 required"; exit 1; }

# working tree
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree has uncommitted changes"; exit 1;
fi

# CHANGELOG
[ -f CHANGELOG.md ] || { echo "CHANGELOG.md not found"; exit 1; }
grep -q "^## \[Unreleased\]" CHANGELOG.md || { echo "[Unreleased] section not found"; exit 1; }

# plugin/mirror projects
scripts/release-preflight.sh
```

This working tree clean check is the gate for the normal release preflight.
In a bare release where you want to commit "current work", complete the Review Gate and Work Commit Gate before this check.
Do not abort and stop on this check alone for an unreviewed dirty tree.

`scripts/release-preflight.sh` also detects mirror drift in `opencode/`, `skills-codex/`, and `codex/.codex/skills/` before tag creation. If `node scripts/build-opencode.js` generates a diff, the release stops — commit that diff first, then proceed to the tag.

### 2. Automatic Version File Detection

Search in priority order. The first match is the canonical source:

```python
# Python snippet to run inline
import os, json, re
import tomllib  # Python 3.11+

def detect_version_file():
    if os.path.exists("VERSION"):
        with open("VERSION") as f:
            return ("VERSION", f.read().strip(), None)
    if os.path.exists("package.json"):
        with open("package.json") as f:
            data = json.load(f)
        return ("package.json", data["version"], None)
    if os.path.exists("pyproject.toml"):
        with open("pyproject.toml", "rb") as f:
            data = tomllib.load(f)
        if "project" in data:
            return ("pyproject.toml", data["project"]["version"], "[project]")
        if "tool" in data and "poetry" in data["tool"]:
            return ("pyproject.toml", data["tool"]["poetry"]["version"], "[tool.poetry]")
    if os.path.exists("Cargo.toml"):
        with open("Cargo.toml", "rb") as f:
            data = tomllib.load(f)
        return ("Cargo.toml", data["package"]["version"], "[package]")
    raise RuntimeError("No supported version file found")
```

Details: [version-files.md](${CLAUDE_SKILL_DIR}/references/version-files.md)

### 3. Claude Plugin Tag Preflight

Projects with `.claude-plugin/plugin.json` also create a Claude plugin release tag in addition to the normal GitHub Release tag.

In short, before manually assembling `git tag -a`, pass through Claude Code's own plugin validation, then create the `{plugin-name}--v{version}` tag.

In Pre-Gate, do not rewrite any files. Verify the following.
Read version sync with a structured parser — do not use `grep` / `sed` on JSON:

```bash
command -v claude >/dev/null || { echo "claude CLI not found"; exit 1; }
claude plugin validate .claude-plugin/plugin.json

HARNESS_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root .

claude plugin tag .claude-plugin --dry-run
```

`${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py` reads all existing release surfaces and determines the canonical in the order `VERSION > package.json > .claude-plugin/plugin.json > .codex-plugin/plugin.json`.
If any of the following are mismatched or missing, do not proceed to tag / release:

- `VERSION`
- `package.json` `.version`
- `.claude-plugin/plugin.json` `.version`
- `.codex-plugin/plugin.json` `.version`
- `.claude-plugin/marketplace.json` `.metadata.version`
- `.claude-plugin/marketplace.json` `.plugins[].version` (each plugin entry in the array)

On mismatch, display which surface differs from canonical, or which field is missing / invalid.
For machine processing or CI use `--json`:

```bash
python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root . --json
```

This check prevents three types of accidents:

- Cutting a tag while `VERSION` and `.claude-plugin/plugin.json` version are out of sync
- Entering the release workflow while `package.json` / marketplace entry version is stale
- Skipping plugin manifest / marketplace entry validation and hitting issues on the plugin install / update side

`--dry-run` shows the tag name that `claude plugin tag` would create and the equivalent `git tag -a` / push command. Include the commands shown here in the Confirmation Gate plan.

### 4. Automatic Bump Detection

Parse headings directly under `[Unreleased]` to determine bump level:

| Headings in [Unreleased] | Estimated bump |
|--------------------------|----------------|
| Contains `### Breaking Changes` or `### Removed` | **major** |
| Contains `### Added` (no Removed/Breaking) | **minor** |
| Only `### Fixed` / `### Changed` / `### Security` | **patch** |
| Empty section | **error: nothing to release** |

If the user explicitly specifies `/release patch|minor|major`, that takes priority.
Details: [bump-detection.md](${CLAUDE_SKILL_DIR}/references/bump-detection.md)

### 5. CHANGELOG Draft Creation (in memory)

Calculate the following without writing yet:

1. Extract the body of `## [Unreleased]`
2. Build the result with `## [<new>] - YYYY-MM-DD` inserted between `## [Unreleased]` and `## [<previous>]`
3. Footer compare links:
   - `[Unreleased]: .../compare/v<prev>...HEAD` → `v<new>...HEAD`
   - Add `[<new>]: .../compare/v<prev>...v<new>`
4. Dynamically extract the repo URL from the existing `[Unreleased]: ` line

### 6. Release Notes Draft Creation (in memory)

Generate GitHub Release markdown from the `## [<new>]` section content:

```markdown
## What's Changed

**<release theme (1 line)>**

### Before / After
<table>

### Added / Changed / Fixed / Removed
<copy relevant sections>

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Details: [release-notes.md](${CLAUDE_SKILL_DIR}/references/release-notes.md)

## Confirmation Gate

Once all drafts are ready, present to the user exactly once:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Release Plan: v<old> → v<new> (<bump>)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Version file: <detected file>
 Bump reason:  <why this level was chosen>

 CHANGELOG changes:
   <N> changes detected in [Unreleased]
   Finalized as [<new>] - YYYY-MM-DD
   Compare link added

 GitHub Release notes preview:
   <first 10 lines>
   ...

 Files to modify:
   - <version file>
   - CHANGELOG.md

 Final actions:
   - git commit -m "chore: release v<new>"
   - claude plugin tag .claude-plugin --push --remote origin  # plugin projects only
   - git tag -a v<new>                                        # if GitHub Release semver tag is needed
   - git push origin <branch> --tags
   - gh release create v<new>

Proceed? [yes / cancel / <revision>]
```

## Post-Gate Details

Execute without interruption after approval. On failure, follow this policy:

| Failure point | Recovery |
|---------------|----------|
| File rewrite failure | Abort there; local state remains dirty for human judgment |
| Commit failure | Hook rejection etc. Show cause to user and prompt to fix |
| Plugin tag validation failure | Fix `VERSION` / `.claude-plugin/plugin.json` / marketplace entry mismatch; do not proceed to tag creation |
| Push failure | Remote-side issue. Local commit/tag remain intact |
| `gh release create` failure | Tag is already pushed; existing release.yml safety net may fire, or run `gh release create` manually |

### Tag Creation for Claude Plugin Projects

For projects with `.claude-plugin/plugin.json`, verify version sync once more after commit, then create the plugin tag:

```bash
HARNESS_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root .

claude plugin tag .claude-plugin --dry-run
claude plugin tag .claude-plugin --push --remote origin
```

The tag created by `claude plugin tag` has the form `{plugin-name}--v{version}`. For projects where the existing GitHub Release workflow expects a `vX.Y.Z` tag, create `git tag -a v<new>` separately from the plugin tag. Delegate plugin distribution tags to `claude plugin tag` and treat the GitHub Release semver tag as a compatibility surface for release automation.

## `--dry-run` Mode

Run all Pre-Gate steps and display everything up to the Confirmation Gate, but **stop at the gate without proceeding to Post-Gate**.

For Claude plugin projects, even in dry-run, execute `python3 "${HARNESS_PLUGIN_ROOT}/scripts/check-release-version-sync.py" --root .` and `claude plugin tag .claude-plugin --dry-run` to display the plugin tag name that would be created and the push target. If any of `VERSION` / `package.json` / `.claude-plugin/plugin.json` / `.codex-plugin/plugin.json` / `.claude-plugin/marketplace.json` version surfaces are mismatched or missing, stop at dry-run time.

## Environment Variables

Used for per-project customization:

| Variable | Description |
|----------|-------------|
| `HARNESS_RELEASE_PROJECT_ROOT` | Repository root (default: `$(pwd)`) |
| `HARNESS_RELEASE_BRANCH` | Branch to push to (default: current branch) |
| `HARNESS_RELEASE_HEALTHCHECK_CMD` | Additional command to run during Preflight |
| `HARNESS_RELEASE_SKIP_GH` | Set to `1` to skip GitHub Release creation |

## CHANGELOG Writing Rules

The `[Unreleased]` section must contain at least one of the following subsections:

```markdown
## [Unreleased]

### Added       ← minor
### Changed     ← patch
### Deprecated  ← minor
### Removed     ← major
### Fixed       ← patch
### Security    ← patch
### Breaking Changes  ← major (non-standard in Keep a Changelog but widely used)
```

This skill parses these headings mechanically, so spelling variations (`### Fix` / `### Bug Fixes` etc.) are not recognized. Use the KaCL standard headings.

## Related Skills

- `harness-release-internal` - Additional harness-specific preflight/finalization run when releasing the `claude-code-harness` itself (not for distribution)
- `harness-plan` - Plans.md management
- `harness-review` - Code review before release

## Design Philosophy

- **Single gate**: The user makes a judgment call exactly once. Multiple mini-confirmations become rubber stamps and lose meaning
- **Draft everything upfront**: No "rethinking" once Post-Gate begins. All drafts must be ready before the gate
- **Transparent failures**: On mid-execution failure, do not attempt automatic rollback — show the current state to the user and let them decide
- **Project-agnostic**: No assumptions about specific environments such as VERSION file format, mirrors, or residue checks. Harness-specific processing is isolated in `harness-release-internal`
