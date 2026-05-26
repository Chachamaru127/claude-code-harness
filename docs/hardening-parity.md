# Hardening Parity

Last updated: 2026-03-25

This document is a shared policy for clarifying how far Harness provides the same safety guarantees for both **Claude Code** and **Codex CLI**.

The two key points are:

- What is shared is the **policy** — i.e., what is considered dangerous
- Implementations are separated to match platform differences

Claude Code can be stopped immediately before and after execution via hooks.
Codex CLI does not have the same hooks, so it approximates the same effect through pre-execution instruction injection, post-execution quality gates, and pre-merge verification.

## Policy Matrix

| Policy | Example | Severity | Claude Code | Codex CLI |
|--------|---------|----------|-------------|-----------|
| No verification bypass | `git commit --no-verify`, `git commit --no-gpg-sign` | Deny | PreToolUse deny | Prohibited in instructions + quality gate fail |
| Protected branch destructive reset | `git reset --hard origin/main`, `git reset --hard main` | Deny | PreToolUse deny | Prohibited in instructions + quality gate fail |
| Direct push to protected branch | `git push origin main` | Confirm | PreToolUse ask (configurable as deny / allow) | Confirmation in instructions, merge gate route recommended |
| Force push | `git push --force`, `git push -f` | Deny | PreToolUse deny | Prohibited in instructions, merge gate route required |
| Protected files editing | `package.json`, `Dockerfile`, `.github/workflows/*`, `schema.prisma`, etc. | Warn | PreToolUse approve + warning | Quality gate fail (stricter than Claude) |
| Pre-push secrets scan | Hardcoded secret, DB URL, private IP, token-like string | Deny | Deny or fail before the equivalent push Bash | Quality gate fail |

## Protected Files Profile

The default protected files are limited to those that "have broad impact if broken, but are not touched on every normal implementation."

- `package.json`
- `Dockerfile`
- `docker-compose.yml`
- `.github/workflows/*.yml`
- `.github/workflows/*.yaml`
- `schema.prisma`
- `wrangler.toml`
- `index.html`

Design intent:

- **Warn as the default, not deny**
  Since legitimate changes are possible, intent confirmation is prioritized first
- **Clearly confidential / dangerous files like `.env` or private keys are denied under a separate rule**
  These are the responsibility of the existing protected path rules, not protected files
- **Codex CLI merge gate is currently treated as fail**
  Because Codex cannot interactively confirm before execution, protected files are stopped more firmly via post-execution inspection

## Runtime Mapping

### Claude Code

Claude Code prioritizes runtime enforcement.

- **PreToolUse**
  Deny / ask / warn on dangerous commands before execution
- **PostToolUse**
  Warn on tampering and security patterns after writes
- **PermissionRequest**
  Auto-approve only safe read-only / test commands

### Codex CLI

Because Codex CLI has no runtime hooks, approximate enforcement is achieved via the following 3 layers.

1. **Pre-execution contract injection**
   Prohibited actions are stated explicitly in the instructions passed to `codex exec`, and the same contract is saved in the state artifact
2. **Post-exec quality gate**
   Worker artifacts are inspected based on diff / file / content
3. **Merge gate**
   Artifacts that do not pass the quality gate cannot be merged into main

## Known Asymmetry

This is important. The two are not completely identical.

| Item | Claude Code | Codex CLI |
|------|-------------|-----------|
| Pre-execution interruption | Possible | Not directly possible |
| Post-execution warning | Possible | Approximated via quality gate |
| Per-command deny | Strong | Instructions-dependent + post-check |
| Blocking before merge to main | Possible | Possible |
| Protected files | Warn-focused | Fail-focused |
| Direct push / force push | Detectable at runtime | Runtime detection not possible; mitigated by merge gate operations |

In short:

- **Claude Code is good at stopping things in the moment**
- **Codex CLI protects by not letting output through**

## Operator Guidance

- Prioritize the Claude Code path for work where safety is the top priority
- Use Codex CLI for implementation and review assistance, and always pass through the quality gate before merging to main
- For work touching protected files or release-adjacent areas, operate with the assumption that Codex will fail rather than warn

## Validation Surface

At minimum, the following 4 points should be verifiable via `validate-plugin` tooling:

- A shared policy document exists
- The Claude Code guardrail covers the target rules
- The Codex wrapper injects the hardening contract
- The Codex quality gate has parity-specific checks
