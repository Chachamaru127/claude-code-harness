# Plugin and Managed Settings Policy

Last updated: 2026-05-03

This document fixes the operational decisions around plugin / managed settings / managed sandbox
features added in Claude Code `2.1.117-2.1.126` as Harness setup guidance.

## In one sentence

Harness helps explain safe operation of the plugin marketplace, but does not replace Claude Code
core's resolver or managed settings enforcement.

## Analogy

Think of Harness as a sign board that tells staff which entrance to use when entering a building.
The actual turnstile checking badges is Claude Code core.
If the sign board built its own turnstile, the rules would be duplicated and it would be unclear
which one is correct.

## Official references

- Claude Code changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code settings: <https://code.claude.com/docs/en/settings>
- Claude Code plugin dependency versions: <https://code.claude.com/docs/en/plugin-dependencies>
- Claude Code plugin install guide: <https://code.claude.com/docs/en/discover-plugins>

## Items and decisions

| Item | Purpose | Harness decision |
|------|------|--------------|
| Plugin `themes/` directory | Bundle appearance themes with plugin | P for now. Harness is an operational plugin and does not include themes at this time |
| `DISABLE_AUTOUPDATER` | Stop automatic updates | Use for personal / team update timing control. Does not stop manual updates |
| `DISABLE_UPDATES` | Stop all update paths | Use only in managed environments. Stops even manual `claude update` |
| `blockedMarketplaces` | Block specific marketplace sources | Managed settings only. Do not include in defaults for normal users |
| `strictKnownMarketplaces` | Allow only approved marketplace sources | Managed settings only. Do not include in defaults for normal users |
| `extraKnownMarketplaces` | Introduce and register marketplaces for teams | Prefer this for normal team onboarding |
| Plugin dependency auto-resolve / missing dependency hints | Automatic resolution of dependent plugins and error guidance | Do not add a Harness-specific dependency resolver. Defer to Claude Code core |
| `wslInheritsWindowsSettings` | Inherit Windows managed settings in WSL | For Windows/WSL mixed enterprise environments. Do not include in Harness defaults |
| `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` | Align allowed sandbox boundaries with admin settings | Managed settings only. Do not include in Harness standard template / plugin default / harness.toml, and do not override Claude Code core precedence |

## Update controls

`DISABLE_AUTOUPDATER` is an environment variable for stopping automatic updates.
Use it when you want to stop automatic updates for Claude Code core and plugins.

`DISABLE_UPDATES` is a stronger environment variable for managed environments.
It stops not just automatic updates but also manual `claude update`.
This is intended for environments where organizations distribute only verified versions.

| Purpose | What to use | Note |
|------|----------|--------|
| Prevent personal auto-updates | `DISABLE_AUTOUPDATER=1` | Manual update still possible |
| IT admin fully closes update paths | `DISABLE_UPDATES=1` | Manual `claude update` also stops; provide separate distribution/update procedures |
| Stop CC core updates while keeping plugin auto-update | `DISABLE_AUTOUPDATER=1` + `FORCE_AUTOUPDATE_PLUGINS=1` | Confirm plugin-side dependency constraints and marketplace policy first |

Harness policy:

- Do not include `DISABLE_UPDATES` as a default in `.claude-plugin/settings.json` or project templates.
- Set it via managed settings or terminal management environment variables for enterprise distribution.
- Even when updates are stopped, maintain `harness-release` version sync / plugin tag / validate flow.

## Marketplace policy

`blockedMarketplaces` and `strictKnownMarketplaces` are managed settings for administrators
to control marketplace sources. They are not intended for defaults in normal user or
open-source project configurations.

| Setting | What it does | When to use |
|------|------------|----------------|
| `blockedMarketplaces` | Blocks specified marketplace sources | When you want to explicitly stop dangerous/deprecated marketplaces |
| `strictKnownMarketplaces` | Only allows sources in the allowlist | When you want an enterprise to use only vetted marketplaces |
| `extraKnownMarketplaces` | Introduces and registers marketplaces | When you want to distribute recommended marketplaces to a team |

`strictKnownMarketplaces` is a policy gate.
It only decides what to allow — it does not automatically register marketplaces.
If you also want everyone to register, combine `strictKnownMarketplaces` with
`extraKnownMarketplaces` in managed settings.

Example:

```json
{
  "strictKnownMarketplaces": [
    { "source": "github", "repo": "acme-corp/approved-plugins" }
  ],
  "extraKnownMarketplaces": {
    "acme-tools": {
      "source": {
        "source": "github",
        "repo": "acme-corp/approved-plugins"
      }
    }
  }
}
```

Harness policy:

- Do not include `blockedMarketplaces` / `strictKnownMarketplaces` in defaults for normal users.
- For team onboarding, Harness setup guides `extraKnownMarketplaces`.
- For enterprise managed environments, defer to the managed settings top-level precedence.
- Do not implement a Harness-specific marketplace allowlist/blocklist evaluator.

## Dependency resolution

Claude Code reads a plugin's `dependencies` and auto-resolves dependent plugins at install time.
If a dependency later goes missing, it can be resolved from configured marketplaces via
`/reload-plugins`, background plugin auto-update, re-running `claude plugin install`, or
`claude plugin marketplace add`.

When dependency resolution fails, the correct entry points are Claude Code's plugin UI,
`/doctor`, and the `errors` field in `claude plugin list --json`.
Do not add a Harness-specific dependency resolver.

What Harness does:

- In setup docs, guide users to follow Claude Code hints for missing dependencies.
- In release docs, use `claude plugin tag` and version constraints to create easily resolvable tags.
- If a marketplace is not registered, guide users to first use `/plugin marketplace add` or
  `claude plugin marketplace add`.

What Harness does not do:

- Do not automatically search for and install plugins from other marketplaces.
- Do not directly write to the cache using custom interpretation of `dependencies`.
- Do not build a resolver that bypasses `blockedMarketplaces` / `strictKnownMarketplaces`.

## Plugin prune

`claude plugin prune` is a cleanup command that removes automatically installed dependency
plugins that are no longer needed. It targets plugins installed by Claude Code to satisfy
another plugin's `dependencies`, not plugins installed directly by the user.

Harness policy:

- Use as cleanup guidance after plugin uninstall.
- First guide users to `claude plugin prune --dry-run`.
- Use `-y` only for non-interactive CI runs.
- Do not run unconditionally inside release / setup.
- If there is state in `${CLAUDE_PLUGIN_DATA}` that should be preserved, consider
  `--keep-data` on the uninstall side.

Recommended usage:

```bash
claude plugin prune --dry-run
claude plugin prune -y
```

## Project purge

`claude project purge [path]` is a strong cleanup command that deletes the transcripts,
tasks, file history, and config entries that Claude Code holds for a project.

Harness policy:

- Only guide this when there is a clear reason to delete local Claude state, such as
  archiving, handoff, or path/owner changes.
- First use `--dry-run` or `--interactive`.
- Do not use when there are in-progress tasks, review evidence, or handoff artifacts that are needed.
- Do not treat as an alternative cleanup for Harness's `Plans.md` or git history.

Recommended usage:

```bash
claude project purge . --dry-run
claude project purge . --interactive
```

## Plugin-bundled hooks

Plugins can include bundled hooks, but Harness avoids designs where "installing a plugin
triggers strong side effects immediately."

Harness policy:

- Base bundled hooks on opt-in.
- Disable by default: writes, push, deploy, external transmission, and tool output modification.
- When using `PostToolUse.hookSpecificOutput.updatedToolOutput`, follow `docs/output-governance.md`.
- Hook stdout must maintain the JSON contract; human-readable logs go to stderr.

Reason:

Plugins are close to the trust boundary.
If a project's behavior changes dramatically just by the user enabling a plugin, root cause
analysis and safety verification become difficult.

## Themes decision

With Claude Code `2.1.118`, named custom themes can be created/switched with `/theme`,
and plugins can now bundle a `themes/` directory.

Current decision:

- Harness does not bundle themes at this time.
- Keeping it as `P: future task` in Phase 53.
- Reason: Harness's primary value is operational safety for Plan / Work / Review, and
  distributed themes require separate review for branding, accessibility, and terminal compatibility.

Requirements before including a theme in the future:

1. Readable in light / dark terminals.
2. `/plugin` badges and warning text are not obscured.
3. Consistent with Harness docs / screenshots / release copy.
4. Features work fully even without the theme.

## Windows / WSL managed settings

`wslInheritsWindowsSettings` is for enterprise environments that want to inherit Windows
managed settings into WSL. Companies using Claude Code on both Windows and WSL can reduce
the overhead of managing settings in two places.

Harness policy:

- Do not include in Harness defaults.
- Only consider this for organizations that manage Windows / WSL terminals.
- Since unintentionally strong policies in WSL can affect the development experience,
  confirm active settings sources with `/status` before deploying.

## Managed sandbox precedence

Claude Code `2.1.126` introduced precedence hardening for `allowManagedDomainsOnly` and
`allowManagedReadPathsOnly`.

This is a safety-side change that prevents project-local templates or plugin defaults
from relaxing the sandbox boundary that administrators have set for "allow only this range."

Harness policy:

- Treat `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` as managed-settings-only.
- Do not include as defaults in Harness's standard distribution items:
  `harness.toml`, `.claude-plugin/settings.json`,
  `templates/claude/settings.security.json.template`,
  `templates/sandbox-settings.json.template`.
- For enterprise managed environments, use terminal management or Claude Code managed settings
  as the source of truth.
- Do not build a Harness-specific managed sandbox resolver.
- `scripts/ci/check-consistency.sh` performs regression checks to ensure these managed-only
  keys are not mixed into standard templates.

## Why this way

Plugin marketplace and managed settings are the trust boundary itself.
The trust boundary is the line defining "what is considered safe from here on."
This boundary should be managed by Claude Code core via managed settings precedence
and pre-installation checks.

Harness adds Plan / Work / Review operational quality and guardrails on top of that.
Therefore, instead of building its own configuration inspector, the policy is to document
correct usage of official mechanisms and stop documentation drift with necessary tests.
