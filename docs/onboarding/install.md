# Install, Update, Uninstall

Choose the tool you are using now (今使っている tool) before running commands.
This page keeps the Claude-first install path and the existing Codex CLI setup
path intact while showing candidate and unsupported hosts without upgrading
their support tier.

`not_observed != absent`: when runtime proof is missing, record `not observed`
instead of turning uncertainty into a support or rejection claim.

## Common Success Contract

Every host section has:

- first prompt,
- first command,
- verification command,
- success look.

For candidate or unsupported hosts, these fields describe a research or boundary
check. They are not install instructions.

### Claude Code (`supported`)

Install:

```bash
claude
```

Then inside Claude Code:

```text
/plugin marketplace add Chachamaru127/claude-code-harness
/plugin install claude-code-harness@claude-code-harness-marketplace
/harness-setup
```

Update:

```text
/plugin update claude-code-harness
/harness-setup
```

Uninstall:

```text
/plugin uninstall claude-code-harness
```

First prompt:

```text
Plan a small change with acceptance criteria.
```

First command:

```text
/harness-plan
```

Verification command:

```text
/harness-sync
```

Success look: the session can see the Harness workflow skills, `Plans.md`
status is readable, and the next suggested action is plan, work, review, or
release instead of raw ad hoc implementation.

### Codex CLI (`internal-compatible`)

Install:

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git
cd claude-code-harness
./scripts/setup-codex.sh --user
```

Direct plugin install is verified for Codex CLI `0.132.0` through an isolated
marketplace smoke that packages `.codex-plugin/plugin.json` and
`codex/.codex/skills/` into a temporary marketplace. The repo keeps
`scripts/setup-codex.sh --user` as the user-facing fallback until the direct
plugin path has the same backup and legacy-cleanup guarantees.

```bash
cd claude-code-harness
bash tests/test-codex-plugin-adapter.sh
```

Use the fallback script if marketplace install is unavailable or if you need
the existing backup and legacy-skill cleanup behavior.

Update:

```bash
cd /path/to/claude-code-harness
git pull --ff-only
./scripts/setup-codex.sh --user
```

Uninstall:

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$CODEX_HOME/backups/manual-codex-uninstall"
for name in harness-plan harness-work harness-review harness-release harness-setup harness-sync breezing harness-loop; do
  [ -e "$CODEX_HOME/skills/$name" ] || continue
  mv "$CODEX_HOME/skills/$name" "$CODEX_HOME/backups/manual-codex-uninstall/"
done
```

This uninstall path removes only copied Harness skill entries. It does not
delete Codex settings, project files, or harness-mem state.

First prompt:

```text
Use $harness-plan to create a plan for this change.
```

First command:

```text
$harness-plan
```

Verification command:

```bash
test -d "${CODEX_HOME:-$HOME/.codex}/skills/harness-plan"
test -f "${CODEX_HOME:-$HOME/.codex}/config.toml"
```

Success look: Codex lists or invokes Harness skills from `CODEX_HOME`. Direct
plugin install proves Codex CLI marketplace compatibility only; Codex app proof
is tracked separately and `scripts/setup-codex.sh --user` remains the fallback.

### Codex app (`candidate`)

Unsupported reason: Codex app behavior is not proven by Codex CLI setup,
Codex CLI help output, or `scripts/setup-codex.sh --user`. Phase 73.1.3 has no
end-user app install, update, or uninstall route.

First prompt:

```text
Use the Harness onboarding doc to identify the next safe planning step.
```

First command:

```text
No install command in Phase 73.1.3; candidate smoke only.
```

Verification command:

```bash
rg -n "Codex app.*candidate|app-specific smoke" docs/tool-capability-matrix.md docs/bootstrap-routing-contract.md docs/onboarding
```

Success look: the result is recorded as `candidate`, `manual`, or
`not observed`; it is not counted as Codex CLI parity.

### OpenCode (`internal-compatible`)

Install:

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git
cd your-project
/path/to/claude-code-harness/scripts/setup-opencode.sh
```

Update:

```bash
cd /path/to/claude-code-harness
git pull --ff-only
cd your-project
/path/to/claude-code-harness/scripts/setup-opencode.sh
```

Uninstall:

```bash
mkdir -p .opencode/backups/manual-uninstall
[ -d .opencode/skills ] && mv .opencode/skills .opencode/backups/manual-uninstall/skills
[ -d .opencode/commands ] && mv .opencode/commands .opencode/backups/manual-uninstall/commands
[ -f opencode.json ] && mv opencode.json .opencode/backups/manual-uninstall/opencode.json
```

Move `AGENTS.md` only when you know it was created solely by Harness. Do not
delete project instructions blindly.

First prompt:

```text
Use the harness-plan skill to create a plan.
```

First command:

```text
harness-plan
```

Verification command:

```bash
test -f .opencode/skills/harness-plan/SKILL.md
test -f opencode.json
```

Success look: OpenCode can see Harness skill files and project guidance. Runtime
bootstrap parity is still unproven, so the tier stays `internal-compatible`.

### Cursor (`internal-compatible`)

Install:

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git
cd claude-code-harness
./scripts/setup-cursor.sh
```

Then reload Cursor (Developer: Reload Window) so the local plugin and skills
register. Do not register the repo via symlink under `~/.cursor/plugins/local`;
Cursor rejects symlink targets outside that directory.

Update:

```bash
cd /path/to/claude-code-harness
git pull --ff-only
./scripts/setup-cursor.sh
```

Uninstall:

```bash
mkdir -p ~/.cursor/backups/manual-cursor-uninstall
[ -d ~/.cursor/plugins/local/claude-code-harness ] \
  && mv ~/.cursor/plugins/local/claude-code-harness ~/.cursor/backups/manual-cursor-uninstall/
```

This uninstall path removes only the copied Harness local plugin. It does not
delete Cursor settings, project files, or harness-mem state.

First prompt:

```text
Plan a small change with acceptance criteria.
```

First command:

```text
/harness-plan
```

Verification command:

```bash
bash scripts/setup-cursor.sh --check
test -f ~/.cursor/plugins/local/claude-code-harness/skills/breezing/SKILL.md
```

Success look: Cursor lists Harness skills (for example `/breezing`,
`/harness-plan`) after reload. Workflow smoke and hook parity are not proven,
so the tier stays `internal-compatible` and PM handoff docs remain separate
from adapter install claims.

### GitHub Copilot CLI (`candidate`)

Unsupported reason: GitHub Copilot CLI may become a manual instruction profile
or adapter candidate, but Phase 73.1.3 has no verified Harness bootstrap,
skill-routing, install, update, or uninstall route for it.

First prompt:

```text
Check whether a Harness manual profile is possible, then report missing bootstrap proof.
```

First command:

```text
No Harness command in Phase 73.1.3; candidate investigation only.
```

Verification command:

```bash
rg -n "GitHub Copilot CLI.*candidate|Copilot.*bootstrap" docs/tool-capability-matrix.md docs/bootstrap-routing-contract.md docs/onboarding
```

Success look: evidence stays `candidate`, `manual`, or `not observed`; no support claim is made from Superpowers or official CLI docs alone.

### Antigravity CLI (`future/unsupported`)

Unsupported reason: no official or locally verified Harness adapter route is in
the current artifact set. Phase 73.1.3 therefore provides no install, update, or
uninstall path for end users.

First prompt:

```text
No end-user prompt in Phase 73.1.3; record only whether an official route is observed.
```

First command:

```text
No command in Phase 73.1.3.
```

Verification command:

```bash
rg -n "Antigravity CLI.*future/unsupported|official or verified adapter route" docs/tool-capability-matrix.md docs/bootstrap-routing-contract.md docs/onboarding
```

Success look: Antigravity remains `future/unsupported` or `not observed`; the
public onboarding path does not present it as installable.
