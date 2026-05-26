# Commit Safety Rules

Safe operation rules for commit actions in Harness.
Prevents agents from accidentally reverting or overwriting commits.

## /undo — Undoing Changes Within a Session (CC 2.1.108+)

`/undo` was added in CC 2.1.108 as an alias for `/rewind`.

### Behavior Definition

`/undo` undoes the immediately preceding action (tool call or file change) within the Claude Code session. **It is different from git commit revert/reset.**

| Operation | Target | Effect on git |
|------|------|------------|
| `/undo` | The immediately preceding tool call within the CC session | Reverts the change from disk, but does not affect anything already `git commit`-ed |
| `git revert` | A git commit | Creates a new revert commit |
| `git reset --hard` | A git commit | Irreversible. Protected by Harness deny rules |

### Usage Constraints for Harness Agents

**Worker / Reviewer must not execute `/undo` autonomously.**

It is only permitted when all of the following conditions are met, upon explicit instruction from the Lead (user):

1. The user has explicitly said "undo the last change"
2. The target of the undo is a file change made before `git commit` (for committed changes, use `git revert`)
3. The affected files are limited to changes within a single session

### Prohibited Patterns

- Using `/undo` to erase a commit in response to `REQUEST_CHANGES` (use `git revert` instead)
- A Reviewer autonomously running `/undo` after determining "this change is unnecessary"
- Using `/undo` instead of `--amend` during a correction loop (use `git commit --amend` instead)

### Valid Use Cases for /undo (for reference)

- A human undoing an accidental file overwrite by an agent immediately after it happened
- Undoing an unintended file write during a dry run within a session

### Related Rules

- `git reset --hard` is protected by the `deny` rule in `.claude-plugin/settings.json` and guardrail R11
- `git push --force` is protected by guardrail R06 and deny rules
- Irreversible git operations must require manual execution by the user (see Permission Boundaries)

Details: [CLAUDE.md — Permission Boundaries](../../CLAUDE.md)
