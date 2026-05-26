# Claude Code / Codex upstream snapshot - 2026-04-23

This snapshot confirms the official upstream as of 2026-04-23 and breaks down items
to be directly integrated into Claude Code Harness versus those to be left as
automatic inheritance / future tasks.

Confirmed on:

- 2026-04-23 (Asia/Tokyo)

Primary sources:

- Claude Code docs changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code GitHub changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- OpenAI Codex releases: <https://github.com/openai/codex/releases>
- OpenAI Codex `rust-v0.123.0` release tag: <https://github.com/openai/codex/releases/tag/rust-v0.123.0>

Confirmed versions:

- Claude Code `2.1.117`
- Claude Code `2.1.118`
- Codex `0.123.0`

Classifications:

- `A: Implement`: Land in hooks / release / setup / skills / tests / docs on the Harness side. In 53.1.1, implementation task IDs are fixed, and the actual implementation is done in follow-up tasks.
- `C: Automatic inheritance`: Receive improvements from Claude Code / Codex core as-is. Overlaying Harness wrappers would create dual responsibilities.
- `P: Future task`: Do not implement now, but leave as a follow-up candidate in Plans. Do not implement speculatively.

## Version-by-version breakdown

| Version | Upstream item | How it improves | Category | Harness surface | Harness action |
|---------|---------------|-----------------|----------|-----------------|----------------|
| Claude Code 2.1.118 | Vim visual mode / visual-line mode | Easier to select and edit with keyboard only | C | TUI usage | No Harness wrapper needed. Auto-inherit as Claude Code core editor UX |
| Claude Code 2.1.118 | `/cost` and `/stats` merged into `/usage`; old commands become typing shortcuts that open the relevant tab | Single entry point for usage information, less confusion | C | docs / session guidance | In 53.1.6, shift any `/cost` / `/stats`-centered descriptions to `/usage`-centered. Inherit behavior from core |
| Claude Code 2.1.118 | `/theme` supports creating/switching named custom themes, with JSON manual editing and plugin `themes/` directory support | Opportunity for plugins to ship visual defaults | P | plugin setup / design policy | Record purpose in setup docs in 53.1.5. Do not decide whether to bundle themes in Harness plugin this time; no speculative implementation |
| Claude Code 2.1.118 | Hooks can invoke MCP tools directly via `type: "mcp_tool"` | Possibility of creating read-only diagnostic hooks without shell scripts | A | hooks / MCP diagnostics / tests | In 53.1.2, validated limited to read-only MCP health/resource diagnostics. Current shipped hooks manifest is no-op; write-type MCP tool invocation from hooks is fixed in tests as prohibited |
| Claude Code 2.1.118 | `DISABLE_UPDATES` blocks all update paths, including manual `claude update` | Can stop even manual updates in enterprise-managed environments | A | setup docs / plugin policy | In 53.1.5, explain the difference from `DISABLE_AUTOUPDATER`. Do not add a custom Harness updater block |
| Claude Code 2.1.118 | WSL can inherit Windows-side managed settings via `wslInheritsWindowsSettings` | Easier to align managed settings in Windows/WSL mixed environments | P | enterprise setup docs | Include in managed settings cleanup in 53.1.5. Do not apply to Harness defaults excessively |
| Claude Code 2.1.118 | Auto Mode `autoMode.allow` / `soft_deny` / `environment` can include `"$defaults"` to extend built-ins | Can add custom rules without removing default safety rules | A | permissions / sandbox docs / settings template | In 53.1.4, fix guidance and tests as "add to `"$defaults"`" rather than "replace" |
| Claude Code 2.1.118 | Auto mode opt-in prompt adds "Don't ask again" | Reduces repeated confirmation noise | C | Auto Mode UX | Auto-inherit as Claude Code core interaction UX. Do not overlay prompt suppression in Harness |
| Claude Code 2.1.118 | `claude plugin tag` creates release git tags with plugin version validation | Harder to cut tags with version mismatch in plugin releases | A | harness-release / release tests | In 53.1.3, add preflight / dry-run guidance and validation placement to release flow |
| Claude Code 2.1.118 | `--continue` / `--resume` find sessions that added the current directory via `/add-dir` | Fewer missed resumes for multi-directory sessions | C | session-control docs | Update old resume assumptions in 53.1.6 if any. Inherit implementation from core |
| Claude Code 2.1.118 | `/color` syncs session accent color to claude.ai/code when Remote Control is connected | Visual consistency with remote UI | C | Remote Control UX | No Harness surface. Auto-inherit |
| Claude Code 2.1.118 | `/model` picker honors `ANTHROPIC_DEFAULT_*_MODEL_NAME` / `_DESCRIPTION` overrides with custom gateways | Model display becomes more accurate in gateway environments | C | model guidance | Auto-inherit since Harness does not wrap the model picker. Touch in provider docs follow-up if needed |
| Claude Code 2.1.118 | Plugin auto-update skips caused by another plugin's version constraint appear in `/doctor` and `/plugin` Errors | Easier to find reasons for plugin dependency failures | A | setup / plugin policy docs | Explain together with dependency auto-resolve / missing dependency hints in 53.1.5 |
| Claude Code 2.1.118 | MCP OAuth / custom header authentication fixes | Fewer re-auth loops and 401-hang issues with MCP connections | C | MCP runtime | Auto-inherit core fix. Don't add MCP health watch yet; no OAuth workaround |
| Claude Code 2.1.118 | Credential save crash on Linux / Windows no longer corrupts `~/.claude/.credentials.json` | Lower risk of credential corruption | C | auth runtime | Auto-inherit core fix. Harness does not directly rewrite credentials |
| Claude Code 2.1.118 | `/login` clears `CLAUDE_CODE_OAUTH_TOKEN` session token so disk credentials can take effect | Login works better after starting with env token | C | auth runtime | Auto-inherit core fix |
| Claude Code 2.1.118 | New message scroll pill and `/plugin` badges readability fixes | TUI display more readable | C | TUI | Auto-inherit |
| Claude Code 2.1.118 | Plan acceptance dialog no longer offers auto mode when running with `--dangerously-skip-permissions` | Less confusion about permission mode display | C | permission UX | Auto-inherit. Narrow Harness permission guidance to `"$defaults"` in 53.1.4 |
| Claude Code 2.1.118 | Agent-type hooks no longer fail with "Messages are required for agent hooks" on non-Stop events | Easier to handle agent hook scope | C | agent hooks | Auto-inherit core fix. Treat separately from `mcp_tool` hook in 53.1.2 |
| Claude Code 2.1.118 | `prompt` hooks no longer re-fire on tool calls made by an agent-hook verifier subagent | Reduced hook re-entry noise from verifier subagent | C | hook runtime | Auto-inherit. Do not add re-entry prevention hooks on Harness side |
| Claude Code 2.1.118 | `/fork` stores a parent pointer instead of writing the full parent conversation per fork | Forks are lighter, less disk usage | C | session/fork | Auto-inherit. Harness session-state can assume pointer hydration |
| Claude Code 2.1.118 | Alt+K / Alt+X / Alt+^ / Alt+_ keyboard freeze fixes | Keyboard input less likely to freeze | C | TUI input | Auto-inherit |
| Claude Code 2.1.118 | Remote session connect no longer overwrites local `model` setting | Less risk of local settings being destroyed during remote session use | C | remote session | Auto-inherit |
| Claude Code 2.1.118 | Typeahead no longer errors when pasted file paths start with `/` | Absolute path pasting works naturally | C | prompt input | Auto-inherit |
| Claude Code 2.1.118 | `plugin install` on already-installed plugin re-resolves wrong-version dependencies | Easier to repair dependency issues | A | plugin setup docs | In 53.1.5, record as the policy to rely on core rather than overlaying a Harness resolver |
| Claude Code 2.1.118 | File watcher invalid path / fd exhaustion errors are handled | Less likely to crash on watcher errors in long-running sessions | C | long-running sessions | Auto-inherit |
| Claude Code 2.1.118 | Remote Control sessions are not archived on transient CCR initialization blips | Sessions less likely to disappear from temporary remote initialization failures | C | remote session | Auto-inherit |
| Claude Code 2.1.118 | Subagents resumed via `SendMessage` restore the explicit `cwd` they were spawned with | Working directory less likely to drift after subagent resume | C | subagent orchestration | Auto-inherit as a Claude Code core fix, separate from Codex native `send_input` |
| Claude Code 2.1.117 | Forked subagents can be enabled on external builds with `CLAUDE_CODE_FORK_SUBAGENT=1` | Can test forked subagents in external builds | P | agents / skills docs | Organize as a future candidate in 53.1.6. Do not force the env var into Harness defaults |
| Claude Code 2.1.117 | Agent frontmatter `mcpServers` load for main-thread agent sessions via `--agent` | Agent configurations with MCP prerequisites work more easily in main-thread agents | P | agents audit / MCP setup | Record as a follow-up candidate for agents audit in 53.1.6 |
| Claude Code 2.1.117 | `/model` selections persist across restarts and startup header shows project / managed-settings pins | Easier to understand where model settings come from | C | model guidance | Auto-inherit. Harness does not overwrite model pins |
| Claude Code 2.1.117 | `/resume` offers to summarize stale large sessions before re-reading | Resuming large, stale sessions becomes lighter | C | session-memory / resume docs | Record reason not to add wrapper in 53.1.6. Prioritize Claude Code core summary |
| Claude Code 2.1.117 | Faster MCP startup when local and claude.ai MCP servers are both configured | Shorter startup wait time | C | MCP startup | Auto-inherit. Limit MCP health watch to read diagnostic candidates in 53.1.2 |
| Claude Code 2.1.117 | Already-installed plugin install now installs missing dependencies | Easier self-repair of missing dependencies | A | plugin setup docs | In 53.1.5, record as policy not to overlay Harness resolver on auto-resolve |
| Claude Code 2.1.117 | Plugin dependency errors include install hints and `claude plugin marketplace add` auto-resolves missing dependencies | Dependency resolution from marketplace becomes clearer | A | plugin setup / marketplace policy | Organize for enterprise use / safe marketplace operations in 53.1.5 |
| Claude Code 2.1.117 | Managed settings `blockedMarketplaces` / `strictKnownMarketplaces` are enforced across plugin install/update/refresh/autoupdate | Managed marketplace policy harder to bypass | A | managed settings docs | Explain in 53.1.5 without applying excessively to normal user defaults |
| Claude Code 2.1.117 | Advisor Tool experimental label / link / startup notification, plus stuck-result fixes | Easier to understand position of experimental Advisor; fewer stalls | C | advisor strategy | Keep Harness Advisor Strategy as-is. Leave final quality judgment to Reviewer |
| Claude Code 2.1.117 | `cleanupPeriodDays` retention sweep covers tasks, shell snapshots, backups | Old auxiliary data less likely to accumulate | C | maintenance / session storage | Auto-inherit core cleanup. Do not duplicate deletion in Harness maintenance |
| Claude Code 2.1.117 | OpenTelemetry command / usage / effort attributes | Observability data becomes more detailed | C | telemetry | Auto-inherit since Harness does not directly handle OTel schema |
| Claude Code 2.1.117 | Native macOS/Linux builds replace Glob/Grep tools with embedded `bfs` and `ugrep` through Bash | Faster search, fewer tool round-trips | C | search guidance | Organize in 53.1.6 as items not to add wrappers for |
| Claude Code 2.1.117 | Windows caches `where.exe` executable lookups per process | Faster Windows subprocess startup | C | Windows runtime | Auto-inherit |
| Claude Code 2.1.117 | Default effort for Pro/Max subscribers on Opus 4.6 / Sonnet 4.6 is `high` | Initial quality tends to be higher for complex tasks | C | effort guidance | Update old medium-assumption descriptions in 53.1.6 if any. Harness does not forcibly override |
| Claude Code 2.1.117 | OAuth / WebFetch / proxy / keyboard / SDK reload / Bedrock / MCP elicitation / subagent model / idle memory / VS Code plugin panel / Opus context fixes | Fewer issues with auth, fetch, proxy, input, MCP, subagent, memory, context display | C | runtime stability | Auto-inherit core fixes. Do not add Harness workarounds |
| Codex 0.123.0 | Built-in `amazon-bedrock` model provider with configurable AWS profile support | Easier to handle Bedrock provider as a standard path on the Codex side | A | Codex setup docs / provider policy | Update provider guidance in 53.2.1; do not mix with Claude-side Bedrock guidance |
| Codex 0.123.0 | `/mcp verbose` shows diagnostics, resources, and resource templates while plain `/mcp` stays fast | Can see detailed MCP diagnostics only when needed | A | troubleshoot / setup skill | Record usage distinction between normal `/mcp` and verbose diagnostics in 53.2.2 |
| Codex 0.123.0 | Plugin MCP loading accepts both `mcpServers` and top-level server maps in `.mcp.json` | Can read existing plugin MCP configurations in a wider range of formats | A | Codex setup / plugin MCP docs | Explain both formats in 53.2.2; do not mix with Claude Code side terminology |
| Codex 0.123.0 | Realtime handoffs let background agents receive transcript deltas and explicitly stay silent | Background agents during long tasks can respond only when needed | A | harness-loop / breezing guidance | Organize silence policy in 53.2.3. Do not conflict with advisor/reviewer drift detection |
| Codex 0.123.0 | Host-specific `remote_sandbox_config` requirements for remote environments | Can separate sandbox requirements per remote environment | A | sandbox / execution policy | Tabulate in 53.2.4 and confirm overlap with existing `--approval-policy` / `--sandbox` guidance |
| Codex 0.123.0 | Bundled model metadata refreshed, including current `gpt-5.4` default | Easier to track current default model information | A | Codex setup docs | Record in 53.2.1 as the policy to not over-pin on Harness side |
| Codex 0.123.0 | `/copy` after rollback copies the latest visible assistant response | Copy content after rollback works intuitively | C | TUI UX | Record in 53.2.5 as auto-inherited bug fix. No workaround added |
| Codex 0.123.0 | Follow-up text submitted during manual shell commands is queued | Less `Working` stall when entering next input during manual shell | C | long-running UX | Record in 53.2.5 as auto-inherited improvement for long-running work UX |
| Codex 0.123.0 | Unicode / dead-key input fixed in VS Code WSL terminals | Less breakage of Japanese/symbol input in WSL terminal | C | terminal input | Record in 53.2.5 as auto-inherited |
| Codex 0.123.0 | Stale proxy env vars are not restored from shell snapshots | Less risk of communication breakage from old proxy settings | C | session shell snapshots | Record in 53.2.5 as auto-inherited |
| Codex 0.123.0 | `codex exec` inherits root-level shared flags such as sandbox and model options | May reduce need to double-pass the same flags on the wrapper side | A | codex exec wrapper / sandbox docs | Confirm whether duplicate flag reduction is possible in 53.2.4 |
| Codex 0.123.0 | Review prompts no longer leak into TUI transcripts | Review internal prompts less visible | C | review privacy | Auto-inherit Codex core fix |
| Codex 0.123.0 | Code Review skill instructions tightened | Codex-driven review instructions become more strict | C | review skill | Harness reviewer is a different surface. Clean up overlap in Phase 53.3.1 if needed |
| Codex 0.123.0 | App-server protocol docs updated for threadless MCP resource reads and namespaced dynamic tools | More explanation for MCP resource read / dynamic tools | P | future MCP / app-server docs | Out of 53.2.2 scope; handle when needed. Do not implement speculatively beyond release body |
| Codex 0.123.0 | Dependency alerts fixed, Rust dev debug-info reduced, Python app-server SDK types refreshed | Artifacts and development experience become more stable | C | dependency / build runtime | No direct Harness changes |

## 53.1.2 MCP tool hook decision

Target hook use case:

- Limit to future read-only MCP health / resource list diagnostics.
- For example: checking MCP server connectivity status, listing exposed resources, checking for resource template existence — without adding shell scripts, directly from a hook.
- Out of scope: audit logs that rewrite external state, checkpoint recording, issue creation, database updates, file writes.

Decision this time:

- `hooks/hooks.json` / `.claude-plugin/hooks.json` are kept as no-op with no changes this time.
- Reason: As of 2026-04-23, the official changelog announces `type: "mcp_tool"`, but the Hooks reference's hook handler field table is still centered on `command` / `http` / `prompt` / `agent`, and the required field names and input expansion conventions for `mcp_tool` cannot be read as a stable spec.
- Another reason: Hooks in distributed plugins are read in all enabled environments, so a permanently-present read-only MCP diagnostic tool cannot yet be assumed. Putting an environment-dependent MCP tool directly in the manifest may increase hook errors in unconfigured environments.

Safety conditions:

- Do not call write-type MCP tools from hooks.
- Even when adding `type: "mcp_tool"` to the manifest in the future, limit tool names to those clearly identifiable as read-only diagnostics: `health` / `list` / `read` / `get` / `status` / `diagnostic` / `resource`, etc.
- Do not call from hooks tool names containing `write` / `create` / `update` / `delete` / `remove` / `record` / `mutate` / `set` / `insert` / `upsert` / `patch`.
- This policy is fixed in `tests/test-claude-upstream-integration.sh`. Currently, it detects no-op; if an `mcp_tool` hook is added in the future, a jq check requires it to have a read-only name.

## 53.1.3 plugin tag release flow decision

Scope:

- Claude Code `2.1.118` `claude plugin tag`
- `harness-release` release flow

Decision this time:

- Add Claude plugin project tag preflight to `skills/harness-release/SKILL.md`.
- For projects with `.claude-plugin/plugin.json`, do not proceed to tagging unless `VERSION` and `.claude-plugin/plugin.json` version match.
- In Pre-Gate and `--dry-run`, run `claude plugin tag .claude-plugin --dry-run` to visualize the created plugin tag name and the tag/push-equivalent commands.
- In Post-Gate, re-confirm version sync after the release commit, then create the `{plugin-name}--v{version}` tag with `claude plugin tag .claude-plugin --push --remote origin`.
- For projects where existing GitHub Release automation assumes a `vX.Y.Z` tag, create a semver tag separately from the plugin tag. Delegate plugin distribution tags to `claude plugin tag`; do not rely solely on manual `git tag`.

Safety conditions:

- Do not create a tag if `claude plugin validate .claude-plugin/plugin.json` fails.
- Do not create a tag if `VERSION` and `.claude-plugin/plugin.json` do not match.
- `--dry-run` does not create a tag; it is used to display the execution command in the release plan.
- This guidance is grep-fixed in `tests/test-claude-upstream-integration.sh`.

## 53.1.4 Auto Mode "$defaults" permission and sandbox policy

Scope:

- Claude Code `2.1.118` Auto Mode `autoMode.allow` / `autoMode.soft_deny` / `autoMode.environment`
- Harness `.claude-plugin/settings.json`
- Project-level template: `templates/claude/settings.security.json.template`

Decision this time:

- Auto Mode built-in defaults stay in place through "$defaults".
- Harness does not replace Claude Code's built-in Auto Mode defaults.
- Only when adding `autoMode.allow` / `autoMode.soft_deny` / `autoMode.environment` at project/enterprise level, include `"$defaults"` in each array and append project-specific / organization-specific entries after it.
- Do not add an `autoMode` object to the distributed plugin's `.claude-plugin/settings.json` in this task. The reason is that the contents and update responsibilities for built-in defaults should belong to Claude Code core; distributing an empty replacement config from Harness easily creates misalignment with upstream defaults.
- In the project-level template, place only a note about caution when adding `autoMode`. Do not speculatively fix actual additional entries as they differ per project.

Addition format:

```json
{
  "autoMode": {
    "allow": ["$defaults", "<project-specific allow entry>"],
    "soft_deny": ["$defaults", "<project-specific soft deny entry>"],
    "environment": ["$defaults", "<project-specific environment entry>"]
  }
}
```

Safety conditions:

- Do not remove `"$defaults"`.
- Do not expand `"$defaults"` and rewrite it as "the default list Harness considers."
- Maintain existing `permissions.deny` / `permissions.ask` / `sandbox.failIfUnavailable` / `sandbox.network.deniedDomains` / `sandbox.filesystem`.
- Adding Auto Mode entries is not a reason to relax deny / ask / sandbox.

R05 guardrail and sandbox.network.deniedDomains are not duplicated by Auto Mode:

- R05 is a dangerous operation detection on the Go guardrail side, detecting `sudo` wrappers, `find -delete` / `find -exec rm ...`, macOS dangerous removal paths, etc. from command strings. Auto Mode is a classification layer for automatic approval, with different responsibilities from Harness-specific second-layer guards like R05.
- `sandbox.network.deniedDomains` stops access to metadata endpoints at the sandbox network boundary. Auto Mode's `environment` guidance is a classification of "what environment conditions make automation easier" and is not a substitute for a network deny list.
- `permissions.deny` / `permissions.ask` remain as explicit deny/confirmation rules. By layering Claude Code's deny precedence with Harness guardrails, defenses against destructive operations and sensitive read access are not weakened even when Auto Mode defaults are updated.

Verification:

- `tests/test-claude-upstream-integration.sh` fixes this section, the template note, and the maintenance of existing deny / ask / deniedDomains in `.claude-plugin/settings.json`.
- If `autoMode` is added to `.claude-plugin/settings.json` in the future, the same test's jq check requires that `"$defaults"` is included in each entry of `allow` / `soft_deny` / `environment`.

## 53.1.5 plugin / managed settings policy

Scope:

- Claude Code `2.1.118` plugin `themes/` directory
- `DISABLE_UPDATES` and existing `DISABLE_AUTOUPDATER`
- Claude Code `2.1.117` `blockedMarketplaces` / `strictKnownMarketplaces`
- plugin dependency auto-resolve / missing dependency hints
- Windows / WSL managed settings inheritance (`wslInheritsWindowsSettings`)

Decision this time:

- Create `docs/plugin-managed-settings-policy.md` as the canonical source for setup / plugin policy docs.
- Add a pointer from `skills/harness-setup/SKILL.md` to the same docs so marketplace policy and dependency policy are clear during setup.
- Distinguish `DISABLE_AUTOUPDATER` (stops auto-update) from `DISABLE_UPDATES` (stronger enterprise-managed stop that also halts manual `claude update`).
- Treat `blockedMarketplaces` / `strictKnownMarketplaces` as policy for managed environments only; do not apply excessively to normal user defaults.
- For normal team onboarding, prioritize `extraKnownMarketplaces`; only enterprises requiring strict allowlists use `strictKnownMarketplaces` in managed settings.
- Rely on Claude Code core for plugin dependency auto-resolve and missing dependency hints. Do not add a Harness-specific dependency resolver, direct cache editing, or marketplace policy bypass.
- Leave plugin `themes/` directory as `P` for now. As Harness is an operational safety plugin, bundling themes requires separate review of brand / accessibility / terminal compatibility; no speculative implementation.
- Record `wslInheritsWindowsSettings` as a managed settings candidate for Windows/WSL mixed enterprise environments; do not include in Harness defaults.

Safety conditions:

- Do not add `DISABLE_UPDATES`, `blockedMarketplaces`, `strictKnownMarketplaces` as defaults to `.claude-plugin/settings.json`.
- Trust managed settings' top-level precedence and Claude Code core's install / update / refresh / auto-update enforcement.
- Harness remains in explanation / release guidance / validation grep and does not re-implement the trust boundary itself.
- This guidance is fixed in `tests/test-claude-upstream-integration.sh` with: policy docs existence, `DISABLE_UPDATES` / marketplace policy / dependency resolver / themes decision descriptions, and Feature Table completion marks.

## 53.1.6 Claude Code UX automatic inheritance policy

Scope:

- Claude Code `2.1.118` `/cost` / `/stats` to `/usage` integration
- Claude Code `2.1.118` `/continue` / `/resume` improvement to find sessions with `/add-dir`-added current directory
- Claude Code `2.1.117` main-thread `--agent` + agent frontmatter `mcpServers` loading
- Claude Code `2.1.117` `CLAUDE_CODE_FORK_SUBAGENT=1` external build flag
- Claude Code `2.1.117` stale large session summary, native `bfs` / `ugrep` search, high effort default

Decision this time:

- Treat `/usage` as the primary entry point for usage / cost / statistics.
- Treat `/cost` / `/stats` as legacy typing shortcuts. When explaining cost confirmation or statistics entry points in old docs, guide to `/usage` first and supplement with `/cost` / `/stats` as shortcuts to open the needed tab.
- Auto-inherit from Claude Code core the improvements to `/resume` finding `/add-dir` sessions and stale large session summary. Harness does not add duplicate resume indexes, custom stale-session summarizers, or transcript re-reading wrappers.
- Leave `--agent` + `mcpServers` as a follow-up candidate for agents audit. How agent frontmatter with MCP prerequisites is read in main-thread agents requires an inventory of existing agent definitions and MCP setup guidance, so record as `P` in this task.
- Do not force `CLAUDE_CODE_FORK_SUBAGENT=1` into Harness defaults. Treat as an upstream flag for verifying forked subagents in external builds; do not include in distributed plugin settings / skill defaults / environment templates.
- Do not add wrappers for native `bfs` / `ugrep` search. Search speedup is in the domain provided by Claude Code native macOS / Linux builds through Bash; adding a separate Harness search shim increases path resolution, glob differences, and fallback differences.
- Auto-inherit high effort default as Claude Code core model/account policy. Harness's `harness-work` effort scoring remains a local policy that adds `ultrathink` or `high` for complex tasks, without overwriting built-in defaults for Pro / Max subscriber accounts with fixed values.

Reasons not to add Harness wrappers:

- These are areas where Claude Code core makes runtime decisions, such as UI command routing, session discovery, agent frontmatter loading, native search, and model/account defaults.
- Re-implementing the same judgment as Harness wrappers would retain old behavior even after upstream fixes, or conflict with user managed settings / account policy / platform-specific builds.
- Harness's responsibility is to update old descriptions to be `/usage`-centered, record `C` as automatic inheritance, and leave `--agent` + `mcpServers` needing agent audit and external build flags as `P` for future candidates.

Verification:

- `tests/test-claude-upstream-integration.sh` fixes: this section, `/usage` primary entry point, legacy shortcut handling, `--agent` + `mcpServers` follow-up, external build flag not-as-default policy, native search / high effort default automatic inheritance, and Feature Table `C/P` notation.

## 53.2.1 Codex provider and model metadata setup policy

Scope:

- Codex `0.123.0` built-in `amazon-bedrock` model provider
- `model_providers.amazon-bedrock.aws.profile`
- Codex `0.123.0` bundled model metadata refresh and current `gpt-5.4` default
- Residual old fixed model slug setup guidance
- Separation from Claude Code-side Bedrock guidance

Decision this time:

- Create `docs/codex-provider-setup-policy.md` as the canonical source for Codex provider / model metadata setup guidance.
- Only users/projects using Bedrock add `model_provider = "amazon-bedrock"` and `[model_providers.amazon-bedrock.aws] profile = "codex-bedrock"` to their own Codex config.
- In Harness's distributed `codex/.codex/config.toml`, place only an explanatory comment for `amazon-bedrock`. Do not set an actual `model_provider` default.
- Harness does not write AWS credentials, temporary tokens, secret keys, or Bedrock endpoint overrides.
- Treat `gpt-5.4` as current bundled model metadata for Codex `0.123.0`. Harness setup does not fix `model = "gpt-5.4"` as a default.
- Remove the old `gpt-5.2-codex` recommendation sample from `scripts/check-codex.sh` and change to a description that relies on the current default metadata of Codex CLI.
- Keep Claude Code-side Bedrock guidance in the domain of `CLAUDE_CODE_USE_BEDROCK`, `ANTHROPIC_DEFAULT_*`, `modelOverrides`. Do not mix with Codex's `model_provider = "amazon-bedrock"`.

Bedrock config example:

```toml
model_provider = "amazon-bedrock"

[model_providers.amazon-bedrock.aws]
profile = "codex-bedrock"
```

Checking for old fixed model slugs:

```bash
rg -n "gpt-5\.2-codex|gpt-5-codex|gpt-5\.1|codex-mini|gpt-5\.3-codex|gpt-5\.4" \
  docs skills codex skills-codex scripts tests templates .claude-plugin opencode .agents -u
```

Handling results:

- The `gpt-5.2-codex` sample in `scripts/check-codex.sh` is outdated as setup guidance and will be removed.
- `gpt-5.4` in `scripts/codex-loop.sh`, `scripts/config-utils.sh`, and advisor contract tests are model policies / fixtures for Advisor Strategy, not Codex setup defaults, so they are maintained this time.
- Bedrock / model names in past version descriptions in `docs/CLAUDE-feature-table.md` are maintained as historical descriptions.
- Do not add old model slugs as recommended values in new setup docs / skills / Codex README.

Verification:

- `tests/test-claude-upstream-integration.sh` grep-fixes: provider policy docs, `harness-setup` pointer, Codex README / config note, old `gpt-5.2-codex` sample removal, Feature Table 53.2.1 completion mark.

## 53.2.2 Codex MCP diagnostics and plugin loading policy

Scope:

- Codex `0.123.0` `/mcp verbose`
- Codex `0.123.0` plugin `.mcp.json` loading
- `mcpServers` format in plugin `.mcp.json`
- Top-level server map format in plugin `.mcp.json`

Decision this time:

- Create `docs/codex-mcp-diagnostics.md` as the canonical source for Codex MCP diagnostics / plugin MCP loading guidance.
- In normal Codex TUI usage, use `/mcp` as lightweight server status confirmation.
- Use `/mcp verbose` only when: MCP server is not visible, startup errors are unclear, or need to check presence of resources / resource templates.
- Guide `/mcp verbose` as the troubleshooting entry point for viewing diagnostics, resources, and resource templates.
- Update plugin `.mcp.json` to assume acceptance of both `mcpServers` format and top-level server map format.
- For new plugins, prioritize `mcpServers` format for easier sharing with other tools.
- For existing plugins in top-level server map format, use Codex's loading improvement and do not require unnecessary migration.

`.mcp.json` examples:

```json
{
  "mcpServers": {
    "docs": {
      "command": "node",
      "args": ["server.js"]
    }
  }
}
```

```json
{
  "docs": {
    "command": "node",
    "args": ["server.js"]
  }
}
```

Reason not to mix with Claude Code-side MCP guidance:

- Codex TUI's `/mcp` / `/mcp verbose` is Codex runtime's diagnostic entry point.
- Codex plugin `.mcp.json` loading is a loading improvement for the Codex plugin side.
- Claude Code-side `claude mcp ...`, `.claude/mcp.json`, hook `type: "mcp_tool"` are different surfaces.
- The `type: "mcp_tool"` hook safety decision in 53.1.2 is about Claude Code hooks, with separate responsibilities from the Codex `/mcp verbose` guidance in 53.2.2.

Verification:

- `tests/test-claude-upstream-integration.sh` grep-fixes: `docs/codex-mcp-diagnostics.md`, `harness-setup` pointer, Codex README guidance, `/mcp verbose`, diagnostics / resources / resource templates, `mcpServers` format, top-level server map format, not-mixing-with-Claude-Code-side-MCP policy, Feature Table 53.2.2 completion mark.
- `tests/test-codex-package.sh` detects `/mcp verbose` and `.mcp.json` loading guidance in Codex README.

## 53.2.3 Codex realtime handoff silence policy

Scope:

- Codex `0.123.0` realtime handoff
- Transcript deltas received by background agents
- `harness-loop` background runner
- `breezing` Worker / Advisor / Reviewer
- Advisor / reviewer drift detection

Decision this time:

- Adopt Codex `0.123.0`'s realtime handoff improvement as `A: documented / guided`.
- That background agents can receive transcript deltas is not a reason to increase interim notifications; treat it as a premise for updating judgment only when needed.
- Add `Realtime Handoff / Silence Policy` to `skills-codex/harness-loop/SKILL.md` and Codex mirror `codex/.codex/skills/harness-loop/SKILL.md`.
- Add Worker / Advisor / Reviewer silence policy to `skills-codex/breezing/SKILL.md` and Codex mirror `codex/.codex/skills/breezing/SKILL.md`.
- Reflect the same thinking as notification cleanup during long-running execution in shared `skills/breezing/SKILL.md` and `skills/harness-loop/SKILL.md`.
- Add instruction to the 1-cycle prompt generated by `scripts/codex-loop.sh` not to produce unnecessary interim reports just from transcript deltas.

Silence policy:

- Report only on: cycle / task completion, blocked, validation failure, review `REQUEST_CHANGES`, advisor `STOP`, plateau, contract readiness failure, or when user explicitly requests status.
- Do not silence advisor / reviewer drift such as unanswered `advisor-request.v1`, undelivered `review-result.v1`, review loop plateau.
- When only transcript deltas are received and task status / review verdict / advisor decision has not changed, explicitly stay silent.
- Keep fine-grained tool stdout increments on the log / status side.
- Default is: "one final report per cycle" in `harness-loop`, "one progress feed per task completion" in `breezing`.

Why it doesn't conflict with advisor / reviewer drift:

- Silence policy is a policy to reduce unnecessary notifications and does not weaken quality judgment or stop conditions.
- Advisor remains as the `PLAN` / `CORRECTION` / `STOP` consultant; Reviewer remains as the `APPROVE` / `REQUEST_CHANGES` quality judge; they stay separated.
- Drift is detected as an anomaly separate from conversational silence, treated as missing contract / review artifact in `.claude/state/session.events.jsonl`.

Verification:

- `tests/test-claude-upstream-integration.sh` grep-fixes: snapshot, Codex harness-loop / breezing, shared harness-loop / breezing, and silence policy and drift exceptions in `scripts/codex-loop.sh`.
- `tests/test-codex-package.sh` detects realtime handoff / silence policy in Codex README and Codex skill mirror.
- `./scripts/sync-skill-mirrors.sh --check` confirms no drift between `skills-codex` and Codex mirror.

## 53.2.4 Codex sandbox / execution policy

Scope:

- Codex `0.123.0` host-specific `remote_sandbox_config`
- `allowed_sandbox_modes` in `requirements.toml`
- `codex exec` root-level shared flags inheritance
- `scripts/codex-companion.sh`
- `scripts/codex/codex-exec-wrapper.sh`

Decision this time:

- Create `docs/codex-sandbox-execution-policy.md` as the canonical source for Codex sandbox / execution policy.
- Guide `remote_sandbox_config` as a host-specific policy in `requirements.toml` constrained by admins, not in user / project `config.toml`.
- Place a comparison table for remote devbox / ephemeral CI runner / shared host / unknown host, and organize `allowed_sandbox_modes` per host class.
- Host matching is best-effort classification using FQDN-first, kernel hostname fallback. As this is not strong device authentication, do not use broad wildcards for persistent hosts.
- Each requirements source applies the first matched `remote_sandbox_config` before merge and maintains source precedence. Do not assume that lower-priority source host rules weaken higher-priority source `allowed_sandbox_modes`.
- Since `codex exec` inherits root-level shared flags from Codex `0.123.0` onward, do not redundantly pass the same sandbox / model / approval policy from the Harness wrapper side.
- Do not change runtime wrapper behavior in 53.2.4.

Wrapper flag reduction assessment:

| Wrapper | Assessment result | Decision |
|---------|-----------------|----------|
| `scripts/codex-companion.sh` structured task mode | Converts `task --write` to `--sandbox workspace-write`, preserving caller intent when explicit `--sandbox` / `-s` / `--full-auto` / bypass flags are present | Maintain. This is not redundant transfer of root shared flags, but exec-local conversion of Harness workflow intent |
| `scripts/codex/codex-exec-wrapper.sh` | Runs the hardening prompt with a single `codex exec - --full-auto` policy; does not stack separate `--approval-policy` / `--sandbox` pairs | Maintain. Changing `--full-auto` changes approval / sandbox behavior, requiring a separate task and focused regression test |
| docs / setup guidance | No need to add old `--approval-policy` / `--sandbox` double-specification | In docs, explicitly state "one call, one source of truth" |

Items to leave as automatic inheritance:

- The behavior of `codex exec` inheriting root-level shared flags itself is auto-inherited as a Codex core fix.
- Harness does not re-implement that fix.
- What Harness does: guidance not to add duplicate flags, documentation of existing wrapper intent, organization of storage location for remote sandbox policy.

Verification:

- `tests/test-claude-upstream-integration.sh` grep-fixes: policy docs, snapshot section, Feature Table completion mark, CHANGELOG, `harness-setup` pointer, wrapper comments.
- `tests/test-codex-package.sh` detects sandbox / exec policy and `remote_sandbox_config` guidance in Codex README.
- `bash -n scripts/codex-companion.sh scripts/codex/codex-exec-wrapper.sh` confirms shell syntax after wrapper comment addition.

## 53.2.5 Codex automatic bug fix inheritance policy

Scope:

- Codex `0.123.0` `/copy` after rollback
- manual shell follow-up queue
- Unicode / dead-key input
- stale proxy env
- VS Code WSL keyboard
- review prompt leak

Decision this time:

- Treat Codex `0.123.0`'s `/copy` after rollback, manual shell follow-up queue, Unicode / dead-key input, stale proxy env, VS Code WSL keyboard as `C: Automatic inheritance`.
- `/copy` after rollback is a fix to correctly copy the currently-displayed assistant message in the TUI; Harness does not directly manage clipboard / rollback state.
- Manual shell follow-up queue is a Codex TUI queuing fix for when the next input is sent during manual shell; it is not an area where `harness-loop` or `codex-loop` should overlay its own queue.
- Unicode / dead-key input and VS Code WSL keyboard are terminal input layer fixes; it is safer for Harness skill / wrapper not to convert key events.
- Stale proxy env is a fix not to restore old proxy environments from shell snapshots; in Harness session docs, only record the policy "trust core behavior and do not add a proxy scrubber."
- Review prompt leak is a transcript hygiene fix in the Codex review runtime; receive the core fix separately from the Harness reviewer surface.

Reasons not to implement directly:

- The reason not to implement directly is to auto-inherit the core fixes.
- These are runtime bug fixes for clipboard, TUI queue, terminal input, shell snapshot restore, and review transcript — with different responsibilities from Harness's Plan / Work / Review orchestration policy.
- Harness does not add workarounds, copy wrappers, manual shell queue shims, or proxy snapshot scrubbers.
- Adding forced wrappers would leave old behavior or platform-specific exceptions on the Harness side even after Codex core fixes.

Scope of Harness docs updates:

- In `skills/harness-loop/SKILL.md`, record that manual shell follow-up queue and `/copy` rollback are auto-inherited as long-running work UX, and that the loop runner does not have additional input queue.
- In `skills/session/SKILL.md`, briefly record stale proxy env, Unicode / dead-key, VS Code WSL keyboard as auto-inherited session shell / terminal input.
- Feature Table and CHANGELOG are entry points; the rationale and decision details are consolidated in this snapshot section.

Verification:

- `tests/test-claude-upstream-integration.sh` grep-fixes: this section, `C: Automatic inheritance` classification, reasons not to implement directly, no-workaround policy, and the reflection in Feature Table / CHANGELOG / long-running / session docs.

## 53.3.1 Phase 53 closeout / Phase 51.2 dependency note

Phase 53's A/C/P adoption closes here.

Completion check:

- Feature Table classified each item from Claude Code `2.1.117-2.1.118` and Codex `0.123.0` as `A` / `C` / `P` in the Phase 53 supplementary table.
- CHANGELOG `[Unreleased]` records Phase 53 user-facing changes from snapshot through MCP hook safety, plugin tag, Auto Mode, managed settings, Codex provider / MCP / realtime / sandbox / bug-fix inheritance.
- `tests/test-claude-upstream-integration.sh` grep-fixed Phase 53 snapshot and major guidance.
- `tests/validate-plugin.sh` PASS at Phase 53 closeout. Existing warnings are only script executable bit and missing `IMPLEMENTATION_GUIDE.md` recommendation.

Overlap cleanup with Phase 51.2:

- Phase 53 is a cycle to absorb specific diffs from upstream `0.123.0`, not a full cleanup of Codex-native skill audit.
- 53.2.3's realtime handoff silence and 53.2.4's sandbox / exec policy only covered the minimum necessary guidance and mirror sync for `harness-loop` / `breezing` / `harness-setup`.
- Phase 51.2.1-51.2.4's remaining Codex-native tool model, memory/session path drift, review / loop / release mirror path policy, and media skill metadata continue to be owned by Phase 51.2.
- When broadly fixing mirror / path drift in the future, handle it on the Phase 51.2 side without mixing with Phase 53's upstream snapshot tracking.

## Harness judgement

In 53.1.1, only create the snapshot without pre-implementing follow-up tasks.

Confirmed as implementation candidates:

- `type: "mcp_tool"` hook: completed in 53.1.2 as no-op + safety test. Manifest addition comes after required field spec and permanently-available read-only diagnostic tools are in place
- `claude plugin tag`: 53.1.3
- Auto Mode `"$defaults"`: 53.1.4
- plugin themes / managed settings / update controls / dependency auto-resolve docs: 53.1.5
- Claude Code UX automatic inheritance / future candidate cleanup: 53.1.6
- Codex Bedrock provider / model metadata: 53.2.1
- Codex `/mcp verbose` / `.mcp.json` loading: 53.2.2
- Codex realtime handoff silence policy: 53.2.3
- Codex `remote_sandbox_config` / `codex exec` shared flags: 53.2.4
- Codex automatic bug fix notes: 53.2.5

Reasons to leave as automatic inheritance:

- UI / TUI / keyboard / OAuth / file watcher / Remote Control / runtime stability fixes are areas where Claude Code or Codex core handles, and adding Harness wrappers easily creates behavioral differences and dual responsibilities.
- `/resume`, `/fork`, subagent cwd restore, Codex follow-up queue, etc. are effective for long-running work, but receiving core behavior first is safe. Only update necessary docs/guidance in Harness in follow-up tasks.
- Codex `0.123.0`'s app-server protocol / namespaced dynamic tools are recorded only within the release body range; no speculative implementation from comparison.

## Why `B: Documentation-only` is 0

This snapshot does not use `B: Documentation-only` as a classification.

- All `A` items were connected to specific Plans tasks in Phase 53. Nothing ends at just adding to the Feature Table.
- For all `C` items, the reason for inheriting core fixes automatically and the reason not to add wrappers on the Harness side were stated explicitly.
- All `P` items explicitly state "not implementing this time" and avoid speculative implementation.

Therefore, `CHANGELOG.md` and `docs/CLAUDE-feature-table.md` are entry points to the snapshot, and the primary sources and decision rationale are placed in this document.
