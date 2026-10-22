# Changelog

[日本語](CHANGELOG_ja.md) | [Current usage](README.md)

CLI means an application operated by typed commands. A hook runs automatically at a workflow event. A worktree is a separate checkout for a task. Preflight means checks before starting or publishing; a schema defines the shape of a data record. MCP connects an assistant to external capabilities. Model effort values such as high/xhigh/max are provider-specific settings, not completion scores.

Each release describes what changed at that time. Its defaults and commands may have changed again; use the current README for installation.
**Unreleased** contains changes not yet published in a versioned release.

The [complete original history](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md) is preserved byte for byte.
For historical technical details and links relative to the old source tree, use the [original changelog at commit 6c198b4c76f9](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md).
Engineering-only phase/task bookkeeping stays in that archive. Existing comparison references are retained exactly; missing historical comparisons have not been invented.

## [Unreleased]

### Added

- `docs-zh/` directory with Chinese translations of all 108 Japanese-containing `docs/**/*.md` files, plus Chinese versions of `README_ja.md` → `README_zh.md`, `CHANGELOG_ja.md` → `CHANGELOG_zh.md`, and `LICENSE.ja.md` → `LICENSE.zh.md`. Structural parity CI: `scripts/ci/check-doc-zh-parity.sh`.
- Chinese versions of the six root-level project documents: `CLAUDE_zh.md`, `CONTRIBUTING_zh.md`, `IMPLEMENTATION_GUIDE_zh.md`, `SECURITY_zh.md`, `Plans_zh.md`, and `spec_zh.md`. The structural parity gate now covers them alongside `docs-zh/` (114 checked files). Translation helpers: `scripts/ci/sync-zh-code-blocks.py` restores fenced code blocks byte-for-byte from the source document, and `scripts/ci/reflow-zh-prose.py` re-wraps Chinese prose to the source's visual width so line counts stay comparable.
- `scripts/ci/fix-doc-zh-links.py` also repoints `docs/` links inside the new root-level Chinese files to `docs-zh/`, and same-level root links to their `_zh` counterparts. The language-specific links in `README_zh.md` and `CHANGELOG_zh.md` keep their existing targets.
- `skills/routing-rules_zh.md`: Chinese version of the skill routing reference. The English trigger and exclusion keywords are quoted verbatim from each skill's `description` field and therefore stay untranslated — they are the literal matching strings, not prose. The fenced routing-flow diagram stays byte-identical to the source, matching the code-block contract used across the other translations. The structural parity gate now covers this pair as well (115 checked files) via a new `SKILL_PAIRS` list in `scripts/ci/check-doc-zh-parity.sh`.

## [5.16.0] - 2026-10-15

### Changed

- Rename the distribution plugin ID to `harness` in the shared marketplace and all host manifests; repository and marketplace names and project config paths stay unchanged. Claude Code follows the marketplace rename map on supported builds; refresh the marketplace, install the new ID in the original scope, and check that only one copy is active. Plugin-owned databases are not automatically transferred. See [the switching guide](https://github.com/Chachamaru127/claude-code-harness/blob/main/docs/onboarding/plugin-rename.md).

- Rewrite the English and Japanese READMEs and every changelog release in plain language, retaining upgrade conditions and linking the complete original history. A short animated hero shows the work path; a static version is provided for reduced motion.
- Source builders now need Go 1.26.0 for the module and workspace. All four bundled platform binaries use that toolchain; users of those binaries do not need to install Go.
- Update `golang.org/x/sys` 0.47.0 to 0.49.0 and `modernc.org/sqlite` 1.56.0 to 1.60.1, with libc 1.77.1 and memory 1.12.1.
- Benchmark maintainers receive patch updates for the audited `@vercel/agent-eval` 1.4.x line; Dependabot no longer proposes incompatible major/minor bumps against its pinned checks.

### Fixed

- Users of the separate claude-mem product no longer receive a false legacy-home warning just because `~/.claude-mem/` exists. Harness now requires harness-mem markers.
- The external-network guard no longer mistakes dotted filenames such as `late.txt` or `config.json` for hosts. Registered top-level-domain hosts such as `evil.sh` remain blocked.
- Quality, post-write review, and pre-compaction agent hooks use the resolvable `claude-haiku-5-5` model ID, avoiding the unrecognized-model error from the bare alias.
- Hook state now stays under the project root even when execution starts elsewhere. Hook-input cwd takes precedence over `CLAUDE_PROJECT_DIR`, preserving separate worktree locks and plan monitoring.
- Integration tests isolate host Git settings and disable background Git maintenance. If a cleanup race recurs, a brief wait and writer-process report expose the cause. This affects test reliability, not project Git configuration.
- Patch benchmark dependency overrides to `undici ^7.30.0`, `brace-expansion ^5.0.12`, and `@grpc/grpc-js ^1.14.6`, resolving advisories that blocked pull-request checks.

## [5.15.0] - 2026-09-06

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5150---2026-09-06) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L62)

### Added

- Japanese readers get a mobile-friendly product guide describing requests and expected results, with model settings in expandable details.

### Changed

- The English, Japanese, and Codex guides explain task execution, role defaults, manual model selection, progress, and restart. Task-count progress is distinguished from passing acceptance checks.
- Claude deep planning and advisors default to Fable 5.1/high; Codex frontier roles use GPT-6 astra. Lightweight workers, existing Codex role effort, and the isolated Sonnet security reviewer retain separate settings.
- Workflow instructions now require scoped outcomes, recoverable inputs, independent delegation, and observed completion evidence while retaining checks, review limits, and permission boundaries.

### Fixed

- Linux and macOS preserve numeric handoff timestamps during initialization and resume, so structured handoffs can be restored.
- Advisor regression tests no longer mutate the operator's settings; explicit project model selections remain checked.
- Native companion dispatch normalizes supported working-directory spellings so reviews inspect the requested project.
- Large plan context and worker status travel through input streams, preserving evidence without exceeding operating-system command argument limits.
- Codex setup binds the managed reviewer profile so a default inline role cannot shadow it. Custom bindings stay intact; native inherited permissions and external read-only review execution remain distinct.
- External dispatch preserves explicit Codex model and effort, including `ultra`. Advisor defaults come from the target project rather than the installed plugin.
- Execution and the primary-environment guard use the same working directory and write intent. Unsupported overrides and extra writable roots are rejected before dispatch.
- Claude and Codex packages include the helpers needed by advisors and loops. Loop dispatch and restart retain the plan, completion criteria, failures, and prior advice.
- Go workers retain task descriptions and review refinements. Optional review contracts require an explicit verdict rather than accepting an `APPROVE` substring in contradictory text.
- Browser review instructions include completion criteria, inferred scope, exclusions, and reviewer notes without changing result formats or routes.

## [5.14.1] - 2026-08-31

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5141---2026-08-31) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L113)

### Fixed

- Secret-read exceptions now match a leading `~/` against the process home on both declarations and command paths. This changes spelling only: bare `~`/`~/`, `$HOME`, and `~user` are not expanded or newly allowed.
- Write-only `cat > file`, `cat >> file`, and `cat > file <<EOF` no longer trigger secret-read denial for a later environment-file assignment. Reading a file with `cat FILE`, input redirection, or a file argument before/after output redirection remains denied; `&>` and `&>>` do not hide input files.

## [5.14.0] - 2026-08-31

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5140---2026-08-31) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L131)

### Added

- Optional `destructive_delete: defer` denies uncertain deletions and queues them in `.claude/state/deferred-ops.jsonl` while letting unattended work continue. Duplicate retries remain denied without duplicate entries. `warn` remains the default; its allowed-with-warning cases are unchanged.
- Select the policy with `harness.toml [safety.permissions] destructiveDelete`, project YAML `safety.destructive_delete`, or `HARNESS_DESTRUCTIVE_DELETE_POLICY`. Statically proven agent-owned targets are allowed; root-external paths, `..`, unresolved variables, globs, and bare `.` are queued under defer. Relative/project paths with preceding commands retain warn behavior.
- Operators use `bin/harness deferred list` and `bin/harness deferred approve <id>`. Approval permits the next identical command exactly once, then is consumed; another attempt is denied and queued again. There is no bulk or automatic approval. The progress page shows pending entries and approval commands.
- Agents may list but cannot run deferred approval or edit its approval/audit files through guarded writes. Approval records the operator; queue updates are locked together with approval and consumption. Arbitrary interpreter writes remain a documented residual limitation.

## [5.13.2] - 2026-08-29

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5132---2026-08-29) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L168)

### Fixed

- Plugin-cache synchronization no longer creates incomplete directories for versions not yet installed. It repairs `agents/` in existing caches and leaves version manifests unchanged.
- Marketplace copies sync only when their Git HEAD represents the same version. Tracked research files are no longer deleted from those copies, allowing plugin updates to discover the actual newest version. Private-path cleanup applies only to caches.

### Changed

- The synchronization report corrects the cause of missing plugin components and records the repair priority; it does not change manifests or Go-generated code.

## [5.13.1] - 2026-08-26

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5131---2026-08-26) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L187)

### Changed

- The development plan prioritizes avoiding early approval stalls in unattended runs and schedules memory-pipeline repair, Japanese writing-rule seeding/retirement, and checks for overlap with native CLI features. These are planned work, not new runtime capabilities.

## [5.13.0] - 2026-08-25

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5130---2026-08-25) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L193)

### Added

- Sessions on one PC can discover and message each other across Claude Code, Codex, Cursor, Grok, and Hermes. Presence lasts until SessionEnd; turn refreshes preserve declared labels/tasks. Broadcast now spans linked worktrees. Unknown harness-mem roster entries are preserved.
- Session registration exports delivery identity through `CLAUDE_ENV_FILE`. The `session-send` skill explains `bin/harness inbox send --team/--from/--to/--subject` for completion notices, edit-area declarations, and handoffs; speculative discussions are outside that guidance.
- Message verification is OFF by default: `[livemsg] verification = "off" | "on"`. Resolution order is environment, project YAML, project TOML, plugin TOML, default. OFF skips verification entirely. ON checks file/commit existence and Git status; HOLD delivers nothing and returns a reason.
- A read-only reviewer interface exists but is not connected to live message delivery. Without a reviewer, record `not_observed` and use the mechanical check result rather than implying a human-language claim was reviewed. Hermes receives turn delivery only, with no generated enforcement hook.

### Fixed

- HOLD results now actually stop delivery. Version numbers and email addresses no longer look like missing files; slash-free tokens must use a known file extension.
- Deferred Hermes enforcement no longer prevents delivery generation; hosts missing their required home installation are explicitly skipped. Session lists preserve and show team/agent identity, avoiding silently undelivered messages addressed with session IDs. Wiring checks now inspect actual generated output.

## [5.12.0] - 2026-08-24

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5120---2026-08-24) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L225)

### Added

- Codex Breezing workers use `gpt-5.6-luna`/`max` through the managed worker profile or central route. Unsupported companion `max` is translated to raw Codex reasoning configuration. Reviewers, advisors, and deep roles stay `gpt-5.6-sol`/`xhigh`.
- Codex reviews explicitly pass model, review model, and effort through a local app-server proxy. `review --commit` is rejected before dispatch; only successful delegations are recorded. Interrupts reach both companion and proxy, with remaining child processes killed/reaped after at most one second.

### Changed

- After updating Codex, rerun setup and restart Codex. Setup backs up and atomically migrates only the two Harness-owned legacy notify forms after preflight; custom or ambiguous configurations fail without mutation. Missing `features.multi_agent` and `features.default_mode_request_user_input` are added.
- Claude/Codex packages include worker/reviewer profiles and review helpers; Codex also includes fingerprint-check binaries. Rejected primary-environment checks prevent provider startup. Main-session choices and explicitly selected backends are outside the worker default pin.
- Release instructions use the tag-triggered workflow and post-publication verification. Windows named-pipe behavior has fixture/static evidence only; live Windows app-server execution was not observed.

## [5.11.0] - 2026-08-22

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5110---2026-08-22) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L242)

### Changed

- Destructive-delete policy now defaults from `ask` to `warn`. Statically unresolved but project-relative targets may proceed with an audit warning; external paths, `..`, unresolved variables, globs, and bare `.` still ask. Set `HARNESS_DESTRUCTIVE_DELETE_POLICY=ask` or project policy to restore the old default.
- Invalid explicit policy values normalize to ask. Repositories with valuable untracked data under the project root, and guardrail development, should opt out with TOML `destructiveDelete = "ask"` or YAML `safety.destructive_delete: ask`. The runtime floor is unchanged.

## [5.10.0] - 2026-08-22

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5100---2026-08-22) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L248)

### Added

- Choose `destructive_delete = ask | warn` via project YAML `safety.destructive_delete`, TOML `[safety.permissions] destructiveDelete`, or `HARNESS_DESTRUCTIVE_DELETE_POLICY`. Default is still ask in this release. Warn allows uncertain project-relative or own-session scratch deletions with `R05_WARN` and an audit record; external paths, `..`, unresolved variables, globs, and bare `.`/`/` still ask. Later deny/ask rules always override the warning. A documented symlink residual remains.

### Changed

- Releases use only `vX.Y.Z` tags. Earlier plugin-prefixed tags remain as history; installation did not depend on them. English/Japanese READMEs remove duplicate command/stage tables and links while retaining support tiers.

## [5.9.0] - 2026-08-17

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#590---2026-08-17) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L259)

### Added

- Reviews now select runtime checks for security risk and browser checks for UX risk. Approval cannot silently lower the selected profile. Missing browser capability becomes a pending validation; acceptance reads saved execution/review artifacts and does not recommend shipping criteria still pending.
- Optional scope checks use `[scope_leash] enforce_level = off|warn|enforce`, default warn. Writes outside the declared scope are checked before execution; omitted scope produces a stop-time advisory. Worker reports are saved under `.claude/state/review/`.
- Browser evidence can include Playwright recordings embedded in acceptance HTML. Missing recordings are represented as text with a reason. Planning/review include one renewed investigation and one alternative outside the initial approach.
- Japanese writing checks are OFF by default (`writing_lint.enabled`). A personal JSONL dictionary checks edited Markdown/text, repeated sentence endings, and mixed styles. Post-write findings are advisory; a remaining major issue blocks Stop once, then warns on re-entry. Humans alone promote drafted rule proposals with `scripts/writing-rule-approve.sh`.
- Plan, progress, and acceptance pages adapt to mobile screens. Progress shows pending writing-rule approvals; installed diagram-design may be used for diagrams. Completion criteria separate mechanical checks, language-model judgment, and purpose; an optional blind reader check applies only to persuasive/document work. Reviewers use fresh context, fixed criteria, absolute assessment, and the actual artifact.
- The configuration schema formally includes writing_lint and quality_pack. Worker guidance avoids stopping the operator for routine temporary cleanup while retaining approval boundaries; verification-chain checks now run during plugin validation.

### Fixed

- Session-log cleanup warns only when the 600-line limit is exceeded and at least one entry can be archived. Entries newer than 30 days remain; unparseable dates count as archivable. Maintenance keeps the last 2,000 lines of orchestration, loaded-instruction, session-event, and changed-file records; agent-trace retains 1,000 if present.
- Subdirectory tool calls find the nearest `.harness` or `.git` root, stopping before home; without a marker they retain cwd. Project policy, preapproval, test-first settings, and work mode now use that root. `.claude` is not a root marker.
- Protected-path writes through `ln`, `cp`, `mv`, and `install` are now checked alongside redirection and `tee`. Only a known final destination argument is checked; one-argument forms with an implicit destination remain outside this detection. Grok release checks now accept its intentionally bundled manifest, hooks, and binary.

### Changed

- Update SQLite 1.55.0 to 1.56.0 (libc 1.74.4, go-isatty 0.0.24) and jsonschema/v6 6.0.2 to 6.0.3, rebuilding four platform binaries. Grok packages gain hooks and `harness gen` produces `.grok/hooks/harness-pretool.json --host grok`; live project-hook loading was observed, package reinstall/loading remained unverified.
- `--parallel N` requests concurrency; Claude Code controls actual scheduling (then-default 20, excess queued) and nested spawn depth (then-default 3). Harness does not override those native defaults.

## [5.8.0] - 2026-08-14

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#580---2026-08-14) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L401)

### Added

- Grok can execute headless delegated tasks with read-only default, worktree-change detection, and secret masking. A missing Grok binary reports not-configured (exit 3). Repair loops save iteration, verdict, and findings in `.claude/state/repair-loop/`; `MAX_REVIEWS` is checked from that state.
- Optional `--blind-judge` adds a reader who does not see the rubric for public UI copy, documents, and cognitive-load HTML. Code, tests, settings, and schemas are excluded; disagreement is advisory and does not overwrite the primary verdict.

### Changed

- Correct Grok routing against the actual account catalog: lite/standard use `grok-4.5`; deep/advisor/review use `grok-4.6`/xhigh; release/long-context use `grok-4.6`/high. Both support 500k context, but 4.5 does not accept xhigh. Earlier catalog evidence described a different same-named CLI.
- Deletion confirmation depends on targets: project paths and this session's temporary paths containing its session ID may proceed. Temp roots, other sessions, escaping symlinks, globs, ambiguous assignments/substitutions/values, xargs-added targets, and recursive memory deletion still ask. Absolute-target pipelines and a single literal variable assignment can be resolved; single-quoted or escaped `$` disables variable resolution.
- Upstream notes document native concurrency/depth, strict network allowlists, and credential masking. On macOS credential masking falls back to deny, so replacing denyRead remained a proposal.
- The verified Grok catalog accepts low/medium/high/xhigh for 4.6, low/medium/high for 4.5. Native Claude concurrency/depth notes identify `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` (default 20) and `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (default 3) as host controls rather than Harness settings.

### Fixed

- Cursor discovery checks `agent` before the legacy executable, accepting the generic name only when its resolved path has an exact Cursor identity component; unknown binaries are not executed to identify them. Grok documentation now distinguishes native hook capability from missing Harness packaging; generation is still deferred in this release.

## [5.7.0] - 2026-08-12

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#570---2026-08-12) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L427)

This release also records that Claude Code did not read permission rules in `.claude-plugin/settings.json`. A shipped rule is not evidence that the session applied it; verify active rules in `/permissions`.

### Fixed

- `harness work-mode` uses the actual session ID: explicit `--session-id`, then exported `HARNESS_SESSION_ID`, then the last hook ID no older than two hours. The old monitor ID is rejected. SessionEnd clears work mode and a 24-hour TTL limits leftovers. Live ID probes passed; propagation of the environment file into a new Claude session still required post-release observation.
- Codex-mode direct-write restrictions and reviewer no-write rules now read Breezing state files and native agent identity. Reviewer result files may be written only inside physically and lexically contained `.claude/state/`; traversal and symlink escapes are blocked. Self-registration requires agent_id so it cannot mark the lead as reviewer.
- Writes to `~/.claude/projects/<slug>/memory/**` and `~/.claude/plans/**` no longer ask. Settings, skills, agents, commands, hooks, plugins, and similarly prefixed backup directories remain outside that exception; worktree-escape checks are unchanged.
- Fix false shell-test failures caused by early grep exit under pipefail, and correct plan commit references after squash merging. Reachability checks skip shallow clones as unobserved rather than claiming verification.
- The earlier global workaround `HARNESS_WORK_MODE=1` also skipped outside-project write confirmation when no work run was active. This release records that limit and supplies session-scoped work-mode control; protected-path denial and outside-worktree destructive checks remain separate.

### Added

- `harness work-mode on|off|status` adds a session-specific state control and refuses unresolved identity. Existing session metadata is preserved. Regression checks now prove that policy context fields and configurable knobs have actual producers instead of testing hand-built context only.
- Grok model routing was changed against a catalog later found to belong to another same-named CLI; see 5.8.0 before using those historical selections. This release retained Codex xhigh because max acceptance was unverified.
- The later-corrected historical Grok table selected grok-3-mini (low/high), grok-4.20-non-reasoning, grok-4.3 for deep/advisor/review/release, and grok-4.20-0309-reasoning for long context; the responses-only multi-agent model was excluded from tool roles. That table used the wrong product catalog, corrected in 5.8.0.

### Changed

- Safety-layer guidance distinguishes agent-only permissions/hooks from OS-enforced process-tree sandboxing. Apply stronger controls narrowly and test one project before user-wide adoption; excludedCommands matches launch names, not inherited subprocess privileges.
- Session-log warning limit rises from 500 to 600 lines; the 30-day retention rule and `SESSION_LOG_MAX_LINES` override stay unchanged. Update x/sys 0.46.0 to 0.47.0 and SQLite 1.54.0 to 1.55.0 with rebuilt binaries; CI actions and benchmark agent-eval move to their documented new versions, including 1.4.0.
- CI tools update CodeQL 4.37.1 to 4.37.3, Scorecard 2.4.3 to 2.4.4, and setup-python 6.3.0 to 7.0.0; removed pip-install input is unused here. Twenty benchmark experiments type-check against agent-eval 1.4.0 without renamed configuration keys.

### Security

- Benchmark dependencies move to audited agent-eval `~1.4.0`, undici `^7.29.0`, nanoid `^3.3.17`, and brace-expansion `^5.0.9`. Three high advisories are resolved; five low advisories remain below the moderate audit threshold. The used CLI and ExperimentConfig interfaces remain type-compatible.

## [5.6.0] - 2026-08-01

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#560---2026-08-01) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L618)

### Security

- Secret-read exceptions validate resolved relative and absolute paths against the worktree, including symlink escape. Agents cannot edit `.claude-code-harness.config.json` or `.yaml`; operators must change releaseAuto manually. Public example configuration remains writable.
- Protected-branch checks now recognize leading `+` force-push refspecs. `git push origin +main` and `+refs/heads/main` ask; hard reset of protected refs is denied. Unprotected `+feature/x` retains its prior behavior.

### Added

- Every prompt receives the configured response language from project YAML `i18n.language`, then `CLAUDE_CODE_HARNESS_LANG`, then English.

### Fixed

- Language documentation now points to the runtime YAML setting. Floor tests clear inherited operator exceptions so environment settings cannot invalidate or skip their checks.
- macOS progress regeneration uses unique temporary filenames after interruption. Nine other temporary-file sites and 173 pipefail/grep checks are repaired, with recurrence checks; assertions are retained. Static recurrence checks do not cover commands assembled indirectly through variables/functions.
- Operators can invoke `/harness-plan-brief`, `/harness-progress`, and `/harness-accept` as documented. Cursor distribution keeps its own skill-visibility normalization.

## [5.5.0] - 2026-07-29

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#550---2026-07-29) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L732)

### Fixed

- Runtime checks now catch GNU long-form recursive deletion and find-delete outside the task worktree even in autonomous work mode. Shell-executed heredoc bodies remain scanned for secret reads; prose heredocs/comments no longer trigger false destructive-delete matches.
- Secret preapproval applies only to the matching active task/phase, rather than leaking into unrelated future runs.

### Added

- Guardrail warnings, asks, and denials are audited in `.claude/state/audit/guardrail-fires.jsonl`; plain allows are omitted. Raw commands/paths are never saved, only SHA-256 and length; secret-read and billing categories omit even those values.
- Writes to OS temporary/cache directories no longer ask when resolved symlinks remain contained. Recursive deletion inside the worktree can also skip confirmation only when all targets are proven contained; dynamic targets, preceding commands, pipelines/background work, and parent references still ask. Untracked/uncommitted files can still be lost.
- Protected-branch push preapproval uses mandatory expiry, matching task scope and command, and a use limit (default 10); each use increments the counter. Unresolved scope retains confirmation. It affects guardrail R12 only, not the five runtime-floor categories.

## [5.4.0] - 2026-07-26

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#540---2026-07-26) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L810)

### Added

- Address a session with `bin/harness inbox send --team <t> --from <id> --to <agent> "message"`; `inbox sent` reports read state. Delivery occurs at turn boundaries, strips control/ANSI characters, labels content as data, and caps each message at 768 bytes and total at 4,096 bytes. Only the target console can grant risk approval. No unread messages means no output.
- `session declare --task <id>` and `session list` show labels, work, and elapsed time. Lists now combine shared presence and local roster, including non-Git sessions. Generated Codex/Cursor delivery resolves identity from environment then hook session_id; unresolved identity warns and does not stop work.
- `/breezing` now plans when needed, implements, runs fresh-context review plus Codex second opinion up to three rounds until APPROVE, and reports. Unspecified planning scope covers all currently actionable work, classified as required/recommended/optional/rejected with reasons.
- Validation accepts `claude-opus-5`. Always-loaded rules shrink from 103.2KB to 29.2KB while keeping approval and deny contracts; situation-specific instructions move to references.

### Changed

- Native Claude subagents become the intended implementation default, with explicit `--backend codex|cursor` choices. Claude brain/advisor default to Opus 5/xhigh (Fable selectable), review to Fable 5/xhigh, worker to Sonnet 5; Cursor brain roles use Fable 5/xhigh. Codex standard/deep/review/advisor use GPT-5.6-sol/xhigh, release/long-context high, lite stays GPT-5.4-mini.
- Before compaction, only changed `Plans.md` is automatically checkpoint-committed. Other files are excluded. Failed commits or `precompactAutoCommit: false` retain blocking behavior.

### Fixed

- File leases use shared presence plus local roster so live sessions in another worktree retain ownership after the 60-minute TTL. Missing shared presence falls back silently. Stop blocks unfinished tasks once, then permits stopping with a warning on re-entry, ending infinite research-session loops.

### Removed

- Remove Opus 4.8 from the model catalog. `HARNESS_BRAIN_MODEL=opus` and `opus5` both select Opus 5.

## [5.3.1] - 2026-07-20

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#531---2026-07-20) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L912)

### Fixed

- Progress and session-start counts parse actual task Status cells, case-insensitively, across current and legacy markers. Legends, examples, and prose no longer create fake WIP counts or drift warnings.

## [5.3.0] - 2026-07-19

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#530---2026-07-19) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L926)

### Changed

- Codex CLI, Cursor, and Grok become supported on verified host workflows, without claiming equal capabilities. Cursor has no filesystem jail; Grok uses a Claude-envelope pre-tool floor; Codex CLI Bash enforcement does not imply Codex app parity. Codex app, OpenCode, Hermes, Copilot CLI, and Antigravity are not promoted.

### Added

- Project JSON `runtimefloor.releaseAuto: true` optionally permits version-tag pushes and non-destructive GitHub release actions. Default remains OFF; missing/malformed config blocks. Release deletion, npm publishing, Vercel, Kubernetes, and Terraform remain blocked. Preflight requires workflow smoke for every distributed host and stops on any failure.

### Fixed

- Benchmark fixture Vitest updates to `^4.1.0` to address CVE-2026-47429 across 20 fixtures. An upstream-unfixed low advisory in provider-utils remains; fixture checks enforce the minimum version.

## [5.2.0] - 2026-07-17

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#520---2026-07-17) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L949)

### Added

- `harness release --check` proposes a bump read-only after seven days from the last semantic-version tag, after two days with Security notes, or immediately with a Breaking heading. It always exits 0 and changes no version files. Session start shows only actual candidates; unavailable checks remain unobserved.
- Independent test-wiring audit proposes additions only and permits one appeal. Post-write checks warn, without denying, about test removal, added `|| true`, `set +e`, or fewer assertions. Hermes/LSP and public capability-claim checks now run in CI.

### Changed

- Cross-repository handoffs use harness-mem task records. Version guidance points to `scripts/sync-version.sh`, which owns seven version strings across six files. Release proposals ignore plugin-prefixed tags and accept Breaking Changes headings.

### Fixed

- Cross-platform builds pin the Go toolchain to go.mod and disable embedded VCS metadata so bundled binaries match reproducibility checks. Seven tracked research files can be re-added without silently falling under gitignore.

## [5.1.0] - 2026-07-16

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#510---2026-07-16) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1013)

### Added

- Setup detects Maven/Gradle Java and Kotlin projects, chooses Java when both markers exist, and generates matching test commands and naming guidance.
- A host registry and structural workflow checks distinguish support tiers. Grok gains setup (`--check` supported), isolated packaging, and routing as internal-compatible; only Claude is publicly supported at this release. Hermes is a manual-symlink candidate, with no setup/package/model routing or enforcement parity.
- AST search (code-structure search) is requested after repeated same-symbol searches or before similar multi-module fixes. TypeScript/TSX completion uses language-server diagnostics when Harness MCP is connected; other files or no connection are non-blocking. References/definition/hover remain unwired instructions.
- Initial Grok packaging/routing named grok-4.5 and grok-composer-2.5-fast. Subsequent releases corrected the catalog evidence; do not use these historical IDs as a current setup recipe.

### Fixed

- Completion output defaults to English unless Japanese is selected. Windows Stop checks deterministically block WIP. Hook generation skips explicitly deferred hosts instead of failing after partial output. Release tags must match VERSION before publishing.
- Public `.env.example`, `.env.template`, `.env.sample`, and `.env.dist` can be written/staged exactly. Extra suffixes, real secrets, secret-directory nesting, and secret symlink targets remain blocked, including Git commands with changed working directories. Bulk support claims cannot hide behind a partial disclaimer.
- Codex packages include required registry helpers and override Claude-only agent/async hooks with an inline empty hook map. Generated Codex/Cursor hooks use vendor-supported keys while shared command-based checks and delivery stay active. An unconfigured Cursor executable reports exit 3. Host-tier documentation and tests match the shipped internal-compatible tiers.

## [5.0.0] - 2026-07-08

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#500---2026-07-08) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1129)

### Breaking Changes

- The redesigned skill/hook/distribution structure replaces the 4.x line. After upgrading from 4.16.x, run `/reload-plugins`.

### Added

- Planning presents anticipated secret reads, external sends, and destructive operations for task-scoped advance approval. Undeclared actions still stop; later releases connect additional preapprovals to runtime checks. Secret paths can be declared with `HARNESS_RUNTIME_FLOOR_SECRET_ALLOW` or JSON `runtimefloor.secretAllow`; blanket opening, invalid config, and project-external absolute paths are rejected.
- `harness doctor` warns about Harness worktrees older than seven days or no longer registered in Git. Spawn scripts fetch once and create task worktrees from one base SHA; reaping touches only Harness worktrees/task branches, skips dirty worktrees by default, requires force to remove them, and refuses running inside the target.
- Five runtime checks cover billing, external egress, secret reading, production deployment, and destruction outside the worktree. OS temporary/cache cleanup is allowed narrowly. Worker wrappers fingerprint selected settings and credential locations before/after execution and stop on outside writes; routine runtime caches are excluded. A working fingerprint checker is required before optional automatic approval can activate.
- Parallel integration rebases, cherry-picks without committing, runs the policy gate, and commits only on success; failure restores the working tree. Shared append files have assigned owners, task worktrees do not bump versions, and generated artifacts rebuild once on trunk.
- Failure Codifier extracts read-only rule proposals (three occurrences: medium confidence; five: high) and requires human promotion. Judgment history is append-only, project-scoped, and can recall up to three past decisions by string matching. Neither changes policy automatically.
- Night Watch is OFF by default (`NIGHT_WATCH_ENABLED=false`) and needs opt-in installation. It reports unresolved loops, tasks stale at 72 hours, and decisions open at 168 hours; task age uses file modification time. Mirror status/verify distinguishes in-sync, drift, and unconfigured; automatic synchronization is OFF.
- A retired-name registry detects migration leftovers. Free-text Breezing requests can be split into three to seven tasks for confirmation; a No response executes none. Claude brain roles optionally select Fable 5 with `HARNESS_BRAIN_MODEL=fable`, otherwise retain Opus 4.8; unknown values fail.
- Live Cursor pre-tool denial was verified and Shell tool names are normalized to Bash; its support tier remains candidate. AppleScript guidance permits activation/open only, excluding System Events input injection. Official-feature inventory separates observed facts from unverified version claims.
- The self-learning rollout plan is recorded separately from shipped capabilities; automatic promotion/approval remains OFF. Companion execution and integration outcomes gain audit records so attempted, failed, and completed work can be distinguished.
- Use `bin/harness wt fingerprint capture/diff` to inspect monitored changes. Monitoring covers Claude settings/plugin registries and credential locations (`~/.aws/`, `~/.ssh/`, `~/.gnupg/`, `~/.config/gcloud/`, `~/.netrc`); routine Claude project/cache writes are excluded. This is before/after detection, not an OS filesystem jail. `HARNESS_AUTO_APPROVE=on` is forced OFF if the fingerprint command cannot succeed.

### Changed

- Self-review means sharing the producing context, not merely using the same model family. Fresh Cursor review can advise before primary brain review; it does not replace the primary verdict.

### Fixed

- Release skills hand publishing to the tag-triggered workflow and verify a non-draft GitHub Release with at least four assets. Security reviews declare authorized audit scope, use isolated fresh-context Sonnet 4.6, and return only verdict/count/location/fix summaries to reduce model safeguard interruptions; this reduces triggering rather than guaranteeing availability.

## [4.16.4] - 2026-06-28

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4164---2026-06-28) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1241)

### Changed

- Commands that send data to hosts outside the allowlist (`curl`, `wget`, `nc`, `scp`, `rsync`) ask you before every run. In research sessions you watch yourself, you can turn off only this check by setting `HARNESS_RUNTIME_FLOOR_EGRESS=off` before Claude Code starts: `export` it in the launching shell, or add `{ "env": { "HARNESS_RUNTIME_FLOOR_EGRESS": "off" } }` to `~/.claude/settings.json`. Only the exact value `off` works; unset or any other value keeps the check. A sandboxed or prompt-injected worker cannot change it, because it is read from the environment of the hook process started by the person launching the session. Billing, secret reading, production publishing, and destruction outside the worktree stay checked and cannot be turned off.

## [4.16.3] - 2026-06-24

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4163---2026-06-24) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1267)

### Fixed

- Reloaded plugins now include directly referenced hook scripts in packages/caches and reject stale roots missing them. On Codex, `breezing --cursor` now includes its helper scripts and can start; omitted Codex effort receives a default.

## [4.16.2] - 2026-06-24

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4162---2026-06-24) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1291)

### Fixed

- The public release now includes the pre-execution safety check that earlier existed only in local test builds. Five kinds of action always come to you for confirmation, shown as `RUNTIME_FLOOR:<category>`: billing, sending data outside, reading secrets, publishing to production, and deleting outside the worktree. In this release no setting or environment variable turns them off (4.16.4 later allows turning off only the outside-sending check). Cleanup inside OS temporary and cache areas (`/tmp`, `/var/tmp`, `/private/tmp`, `$TMPDIR`, user cache) is allowed. Deleting in `~/Desktop`, `~/Documents`, `/etc`, or `/opt` still asks.
- `/harness-release` now stops after pushing the tag. A GitHub Actions workflow triggered by that tag (`.github/workflows/release.yml`) publishes the GitHub Release, because Claude Code 2.1.183+ blocks the publish command itself. The skill then checks every 5 seconds, up to 60 times (about 5 minutes), for a non-draft release with at least 4 attached files. On timeout it warns instead of failing, because the tag is already pushed. Inference (high confidence, from the script at this tag): a project without such a workflow gets no published release, and a project that attaches fewer than 4 files ends with the warning even when publishing succeeded.
- Explicitly adding secret files to Git is now denied for `git add`, `git stage`, and `git commit <path>`: `.env`, `.env.local`, `.env.production`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa`, `id_ed25519`, `secrets/`, `.ssh/`, `.aws/`, `.npmrc`, `.pypirc`, `credentials`. Removing a secret from remote Git history usually requires rewriting that history and a force update, which Harness denies under its force-push policy. This does not erase copies others already obtained; deleting the file in a new commit leaves the old history intact. Text inside a commit message (for example `-m "fix .env loading"`) is not treated as a path. Bulk `git add .` and `git add -A` are still allowed and rely on `.gitignore` and existing write protection. `git -C <dir>`, `$(...)`, backticks, quoting, and escaped quotes are inspected so they cannot hide a secret path.
- A bilingual glossary (`docs/onboarding/glossary.md`, linked from the README quickstart) explains terms that appear in generated output, such as spec (product specification), contract (agreed requirements), `cc:完了` (finished and verified), and confidence % (reported certainty). Confidence bands at this release: 75% or more, proceed; 40 to 74%, caution; below 40%, consult. They are decision aids, not a success-probability guarantee.

## [4.16.1] - 2026-06-19

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4161---2026-06-19) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1355)

### Fixed

- An APPROVE from `/harness-review`, or from the review step inside `/harness-release`, is now saved to `.claude/state/review-result.json`, so the next `git commit` is no longer blocked with "Run /harness-review before committing". A hook that runs when the reviewer finishes saves it as a backup; the reviewer stays read-only. Commits that change only `VERSION`, `.claude-plugin/plugin.json`, `harness.toml`, or `CHANGELOG.md`, and merge commits, no longer use up that approval, so release version-bump commits pass. Decisions are logged in `.claude/state/commit-cleanup-audit.jsonl`. When Git is unavailable the old behavior (delete the approval) stays.
- Shorter skill descriptions reduce truncation risk but the total still exceeds the 6,000-character target. `docs/i18n.md` explains output language: `i18n.language` in `.claude-code-harness.config.yaml`, then `CLAUDE_CODE_HARNESS_LANG`, then English as default, in that order; you can also ask per message. Machine-readable JSON and commit prefixes stay English. Security reviews state findings without exploit code. The reviewer can still stop mid-review because of the model's own safety filter; `docs/known-limitations.md` advises switching to Opus 4.8 or sending security-focused changes to human review.

## [4.16.0] - 2026-06-18

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4160---2026-06-18) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1393)

### Added

- Optional `HARNESS_SESSION_RELAY=monitor|both` enables addressed cross-session messages; default OFF. Claude Monitor polls every five seconds, Cursor/Codex use companion handoffs. Messages are data, not approval; immediate delivery is Claude-to-Claude only and not combined with harness-loop. Upstream waitingFor guidance helps identify WIP stalled over ten minutes. Messages are stored inside Harness (`.claude/sessions/relay-signals.jsonl`) without extra tools, and harness-mem masking applies to them.

### Fixed

- Fresh setup creates harness.toml without overwriting an existing file or an unrelated plugin manifest. Sync skips absent hooks only when no destination hook exists; orphaned destinations still fail. Windows memory commands launch JavaScript through its runtime. Footers follow the chosen language. The `AGENTS.md` that `setup-codex.sh --project` copies into your project now says Codex supports hooks while Harness had not yet connected them, with interim protection in `.codex/rules/`. Inference (medium confidence): copies made before this release keep the old "hooks unsupported" text until you copy the file again. Cursor evidence again matches internal-compatible.

## [4.15.0] - 2026-06-05

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4150---2026-06-05) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1447)

### Added

- The promise "agents cannot edit their own settings" now has a single source in `harness.toml` and is copied into the shipped `.claude-plugin/settings.json` as four deny rules: `Edit` and `Write` on `.claude/settings*` and `.claude-plugin/settings*`. An automated CI check fails if any of the four is missing. Later finding (5.7.0): that release records that Claude Code does not read `permissions` from a plugin's `.claude-plugin/settings.json`. This historical runtime has not been re-tested. The [current plugin settings contract](https://code.claude.com/docs/en/plugins-reference#settings) applies only `agent` (default agent) and `subagentStatusLine` (worker status display), so file presence alone does not prove these rules were active. Put the deny rules in your own user or project settings to enforce them.
- The self-audit checklist used by `/harness-review` and diagnostic sessions now reads the `hooks` block of `.claude/settings.local.json` and flags `command` hooks the owner did not intend. That file is usually git-ignored and skips code review. This is a check performed when the audit runs, not continuous monitoring.

### Changed

- Writes to `.claude-plugin/settings.json` and `.claude/settings.local.json` now produce a protected-path warning, the same level as `.claude-plugin/plugin.json`. It covers routes that slip past the deny rules, such as shell redirection.

### Fixed

- Orchestration totals include delegation records created mid-session rather than only at session boundaries.

## [4.14.0] - 2026-06-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4140---2026-06-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1491)

### Added

- Codex and Cursor delegations are now recorded, one line each, in `.claude/state/orchestration-ledger.jsonl`: backend, subcommand, write or not, exit code, duration, session ID. Prompt text and secrets are not recorded. Status and setup polling are not counted. Totals per project are kept in `orchestration-totals.json`. The `harness-orchestration` skill builds a shareable HTML scorecard on request; each backend shows used, configured but unused, or not configured (not configured is not an error). A one-time terminal summary appears when all tasks finish. These numbers measure activity, not quality or successful completion.

## [4.13.3] - 2026-06-01

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4133---2026-06-01) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1517)

### Fixed

- Cursor first-use paths repair helper discovery, prerequisites, worktree integration, and failure visibility. Same-PC file leases, session registration, edit-collision feedback, and Go/Markdown/shell broadcasts resume. They are coordination hints, not hard locks; separate clones/PCs do not share them and broadcasts remain append-only. Inbox content is sanitized and treated as data.
- If Cursor leaves changes uncommitted, the lead commits them in the worktree as one commit (using `--no-verify` to skip hooks there) before integration; the normal guards and pre-commit hooks run on the main-side commit. Export `TASK_SUMMARY` to set that commit message; otherwise it is `cursor: cursor-do delegated change`. Helper scripts are searched in `CLAUDE_PLUGIN_ROOT`, `HARNESS_PLUGIN_ROOT`, `CLAUDE_PROJECT_DIR`, the current folder, then the installed plugin folders; if none has them, the command stops with exit 2. Worktree paths are absolute from the Git root. Leases are shared across worktrees of one repository and expire only after 60 minutes and when the owning session is no longer registered; registrations older than 24 hours are pruned. Outside a Git repository, or when the lease store cannot be reached, editing proceeds with no lease and no warning. Inbox forwards only path, sender, and age, capped at 4,096 bytes, discarding broadcast text.

### Changed

- Breezing and Cursor delegation show a startup banner plus two to four steps (at most five lines) and concise intermediate results, replacing the one-line-only silence.

## [4.13.2] - 2026-05-30

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4132---2026-05-30) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1616)

### Added

- `/cursor:ask` sends a read-only question, research, or design review to Cursor (composer-2.5-fast); Claude summarizes the answer in 3 to 5 lines. `/cursor:do` gives one write task to Cursor in its own worktree (`.claude/worktrees/cursor-do-<id>`); the lead reviews the diff, cherry-picks it (copies the approved commit), and marks the Plans.md task `cc:done [hash]`. Both need: a `.cursorignore` that hides `.env`, `*.pem`, `*.key`, `.ssh`, `.aws`, `.git`; `*.cursor.sh` in `sandbox.network.allowedDomains`; and `~/.cursor` in `sandbox.filesystem.allowWrite` in `~/.claude/settings.json`. Cursor itself cannot keep file writes inside a folder. Write safety comes from the separate worktree, the lead's diff review, and the cherry-pick that passes Harness guardrails.

### Changed

- `/harness-review --cursor` adds Cursor as an advisory second opinion. The main reviewer's verdict decides: its REQUEST_CHANGES rejects; its APPROVE stands even if Cursor disagrees, and the disagreement is recorded. `--dual --cursor` runs Claude, Codex, and Cursor reviews. `/breezing --cursor --reviewer-only` sends only the review step to Cursor, for use when Anthropic rate limits or Codex review authentication fail.
- Prompt tuning for Opus 4.8: deeper reasoning is requested through effort level (complexity score 3 or more gives `high`; with code risk, `xhigh`) instead of inserting the word "ultrathink"; reviews record every finding with severity and confidence before deciding; spawn conditions for parallel workers are explicit. The advisor agent moves to Opus 4.8. Worker and reviewer agents stay on Sonnet 4.6. Startup narration was shortened, then relaxed in 4.13.3.
- Each host gets its own package with internal skill paths and without other hosts' metadata. Install Cursor with `scripts/setup-cursor.sh`, which copies a real folder (symlinks into `~/.cursor/plugins/local` are rejected by Cursor); `scripts/setup-cursor.sh --check` builds and validates the package without installing it. Harness workflow skills are shown in Cursor as skills rather than hidden. Cursor becomes internal-compatible, not publicly supported. `scripts/diagnose-harness-skill-duplication.sh` lists duplicate Harness skill copies without deleting them; `docs/local-harness-environment-cleanup.md` describes cleanup.

### Removed

- Remove an unconnected scaffolding agent; setup and planning continue to perform its intended work inline.

### Fixed

- Git skip-hook/signing flags are caught even beside shell separators. Version sync no longer rolls plugin.json back from stale harness.toml.

## [4.13.1] - 2026-05-29

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4131---2026-05-29) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1679)

### Changed

- Non-Claude implementation calls the Codex/Cursor companion directly rather than spawning an extra Claude worker. Before cherry-picking, leads run public-claim, consistency, and plugin contract checks as well as reviewing the diff.

## [4.13.0] - 2026-05-29

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4130---2026-05-29) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1686)

### Added

- Choose who writes code with `scripts/set-impl-backend.sh [--user] <claude|codex|cursor>`. `/breezing` and `/harness-work` then send implementation to that backend. Order of precedence: command flag, `HARNESS_IMPL_BACKEND`, project `env.local`, user file `~/.config/claude-harness/impl-backend.env`, then Claude. Review and advice always stay on Claude, never on the chosen backend, so a backend never reviews its own work (the skill text says Opus; the reviewer agent file at this release set Sonnet 4.6). Cursor is a local opt-in candidate: its output is untrusted and enters only through a separate worktree, the lead's diff review, and cherry-pick. Read-only delegation uses ask mode, and Cursor's run-everything mode (`--force`) is never used. `--debug` or `HARNESS_CURSOR_DEBUG=1` prints the command and errors to stderr with `--api-key`, `--auth-token`, and `Authorization:` values masked.

### Changed

- Cursor ACP streaming integration is not adopted for whole-task delegation; reassess only if streaming, external IDE embedding, or per-action permissions become requirements. Shell hygiene changes do not alter behavior.

## [4.12.11] - 2026-05-28

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#41211---2026-05-28) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1704)

### Changed

- Add Cursor candidate packaging/routing evidence and static smoke. Public support still requires observed workflow checks; this release does not claim enforcement parity.

## [4.12.10] - 2026-05-28

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#41210---2026-05-28) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1724)

### Fixed

- A release is complete only when its work is merged to the default branch and tags/publication point to a commit reachable from that branch.

## [4.12.9] - 2026-05-28

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4129---2026-05-28) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1730)

### Changed

- Refresh Claude 2.1.143–152 and Codex 0.131–134 guidance for disallowed tools, skill reload, message display, and Codex profiles. Native Auto-mode consent changes do not change Harness opt-in or hard-deny defaults.

## [4.12.8] - 2026-05-27

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4128---2026-05-27) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1736)

### Changed

- Nontrivial plans now require independent team/subagent consultation before finalization, with explicit lightweight exceptions and evidence in the plan; bilingual guides describe the requirement.
- Planning checks spec/task alignment, prior memory, product value, security, and practical feasibility without reading secret values.

## [4.12.7] - 2026-05-27

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4127---2026-05-27) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1748)

### Fixed

- Harness's own release preflight checks its repository branch protection so its review gate cannot drift silently.

## [4.12.6] - 2026-05-27

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4126---2026-05-27) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1755)

### Changed

- CodeQL scans every main push and pull request.

### Fixed

- TOML parser fuzz checks run regularly, and distribution checks require every shipped platform hook binary.

### Security

- Quick install and Codex update guidance remove automatic fallbacks that installed or updated optional tools globally with an unpinned `npm install -g`. Install optional development tools with Homebrew or with a version-pinned package-manager command instead. Scorecard exceptions document intentionally shipped binaries and restricted security-reporting and branch-protection decisions.

## [4.12.5] - 2026-05-27

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4125---2026-05-27) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1781)

### Fixed

- Patch the Breezing agent-eval dependency tree to close remaining Dependabot advisories.
- Benchmark overrides patch undici, minimatch, and uuid, and dry-run tasks now point at tracked evaluation fixtures.

### Security

- Scoped npm updates and an audit gate monitor that benchmark without adding noisy update entries for disposable fixtures.

## [4.12.4] - 2026-05-27

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4124---2026-05-27) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1796)

### Added

- SECURITY.md provides private vulnerability reporting and guidance for public issues.

### Fixed

- Restore English by default, with Japanese selected by request, `i18n.language: ja`, or `CLAUDE_CODE_HARNESS_LANG=ja`.

### Security

- Evidence labels reject absolute, parent-relative, nested, and non-slug paths. Test paths are passed as process arguments instead of shell code; YAML paths enter Python as arguments rather than source interpolation.

## [4.12.3] - 2026-05-25

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4123---2026-05-25) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1812)

### Changed

- New task rows use `pm:requested`, `cc:todo`, `cc:wip`, `cc:done`, `pm:approved`. Existing Japanese/uppercase markers remain readable; no bulk migration happens without explicit action.

### Fixed

- Release version sync includes the Codex manifest. Guardrail reasons remain English with Japanese opt-in; protected environment-file exceptions and orphan-loop recovery retain their tested behavior.

## [4.12.2] - 2026-05-24

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4122---2026-05-24) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1830)

### Fixed

- README checks again match the documented Cursor route, five workflow verbs, Go-based protection, and Japanese opt-in.

## [4.12.1] - 2026-05-24

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4121---2026-05-24) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1836)

### Changed

- Bilingual READMEs lead with setup, operating flow, support boundaries, and migration; approved visuals replace internal release names. Planning now creates both spec.md product behavior and Plans.md tasks, recording either a spec delta or a reason to skip; spec takes precedence.

## [4.12.0] - 2026-05-23

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4120---2026-05-23) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1845)

### Added

- Tool-first onboarding separates Claude, Codex CLI, and OpenCode bootstrap routes and their support limits. Existing users get a read-only migration report before changes. Repo-health, distribution, and release checks verify the promised shipped surface; decision HTML records merge/release evidence. Start at `docs/onboarding/index.md`.
- At this release Claude is supported, Codex CLI/OpenCode internal-compatible, Codex app/Cursor/Copilot CLI candidates, and Antigravity unsupported. `harness doctor --migration-report` inventories stale caches, missing slash entries, duplicates, symlinks, backups, and memory without deleting them. OpenCode real-runtime parity is unobserved. `release-preflight.sh --check-adapters` combines clean-tree, adapter, mirror, archive, capability, bootstrap, and CI checks.

## [4.11.4] - 2026-05-21

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4114---2026-05-21) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1889)

### Added

- A manual sandbox-network recipe (restrict which hosts isolated processes can contact) is in `docs/sandbox-allowlist-recipe.md`. It explains `HTTP/2 403 / x-deny-reason: host_not_allowed`, 29 allowed domains, 9 denied domains, and 6 excluded commands. `templates/sandbox-settings.json.template` now matches it; its previous 8 domains could cause `git clone`, `pip`, `go mod`, or `cargo` to fail.
- Copy the whole template only if `~/.claude/settings.json` has no `sandbox` key; check with `jq 'has("sandbox")' ~/.claude/settings.json`. Otherwise merge it, preserving `filesystem` (file-access policy) and `failIfUnavailable` (stop if isolation is unavailable). Back up settings, combine arrays, preserve file permissions, validate exact hosts, and fully restart Claude. New settings have exactly 29 allowed and 9 denied domains; merged settings may exceed those counts. Firecrawl still needs `FIRECRAWL_API_KEY`. Agents do not edit this operator setting themselves.
- The 9 denied domains (cloud metadata endpoints and paste sites) block SSRF (requests to internal cloud services) and data-exfiltration paths. `deniedDomains` takes precedence even when a domain is in `allowedDomains`.


## [4.11.3] - 2026-05-19

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4113---2026-05-19) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1993)

### Changed

- `/harness-release` and `/harness-review` now end with one fixed line telling you that Claude will summarize the result and that you can press Enter to continue or type a new instruction. This addresses slash-command output that looked like a stop. At this release the line is always Japanese (`↑この結果は Claude が要約します。Enter キーで次へ進むか、新規 prompt で別の指示を出してください。`); 4.16.0 makes it follow your language setting. Other skills are unchanged.

## [4.11.2] - 2026-05-19

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4112---2026-05-19) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2035)

### Fixed

- Calling release without arguments starts the default release target and announces it instead of waiting for another instruction; safety checks and approval requirements remain.

## [4.11.1] - 2026-05-18

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4111---2026-05-18) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2073)

### Fixed

- `/harness-review` and `/ci` reappear in the skill list and no longer stop silently after launch. A setting meant only for skills with dangerous side effects had blocked them. Bare `/harness-review` prints a `REVIEW_AUTOSTART:` line and starts. Project guidance explains when that setting is appropriate and how to diagnose a silent skill.

## [4.11.0] - 2026-05-18

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4110---2026-05-18) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2111)

### Added

- Project TOML `[[safety.guardrail.protectedPathAskList]]` permits exact environment-file shell writes to ask, with a nonempty reason and audit context. It is not allow: direct Write/Edit, secrets/keys, Git internals, hooks, shell profiles, external paths, and mixed hard-deny writes stay denied. Detection covers redirection/tee, not in-place sed. Optional local skill mirrors are validated.
- CI smoke builds and checks Linux/macOS/Windows; workflow actions are commit-pinned with weekly updates and seven-day cooldown. CodeQL, Scorecard, and workflow syntax checks add release evidence without claiming a public cross-host spin-off.
- Optional terminal notifications for background sessions: `HARNESS_TERMINAL_NOTIFY=1` or `bell` (bell), `title` (window title), `osc9` (macOS or iTerm popup), `notify` (Linux desktop notification); unset or `0` is silent. It works without `HARNESS_WEBHOOK_URL`. Native `/goal` stays a short continuation note; acceptance criteria stay in Plans.md. The Harness security template `templates/claude/settings.security.json.template` adds two baselines you must copy into your own settings to use: `worktree.baseRef: "fresh"` (new worktrees start from `origin/<default branch>` so unpushed commits are not carried in; choose `head` in project settings to carry them), and `autoMode.hard_deny` with 7 entries that stay blocked even in Auto mode: `Bash(sudo:*)`, `Bash(rm -rf:*)`, `Bash(rm -fr:*)`, `Bash(git push -f:*)`, `Bash(git push --force:*)`, `Bash(git reset --hard:*)`, `mcp__codex__*`. Policy also forbids `claude agents --dangerously-skip-permissions` on protected branches, with credentials, or for production deployment.

### Changed

- Review is read-only by default, with lightweight `--quick` and `--codex-closeout` modes; commits, pushes, and releases stay in execution or release flows. Workflows use least privilege and avoid retaining checkout tokens; obsolete PR runs cancel while release/benchmark runs finish.

### Fixed

- Release archives exclude local context, private development skills, other-client mirrors, fixtures, and sandbox examples. OpenCode names/frontmatter are normalized to supported forms.

## [4.10.0] - 2026-05-12

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4100---2026-05-12) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2292)

### Added

- Named plans: list them in `plans/manifest.json` with a `default` entry plus any others, pick one with `--plan NAME`; the last choice is kept in `.claude/state/active-plan.json`. Repositories with a single `Plans.md` (or `plans.md`, `PLANS.md`) need no change. Manifest paths must be relative to the project root; absolute paths, `..`, and symlinks leaving the repository are rejected. Long runs, CI, and issue bridging should pass `--plan NAME` instead of relying on the saved choice. Test-first enforcement remains a local opt-in trial, not a global default. Product specifications remain separate from the task ledger.

### Fixed

- `harness codex-loop start` now fails with `startup_failed` (non-zero exit, last runner log lines saved) when the runner dies immediately, reports `runner_lost_job_running` for orphaned jobs, and cancels them on stop or unexpected exit. Worktree hooks reject JSON-shaped cwd values. Broadcasts mark displayed entries read with dates and skip stale cwd; release preflight catches mirror drift before tags. Codex 0.130.0 guidance is version-backed.

## [4.9.0] - 2026-05-10

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#490---2026-05-10) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2333)

### Added

- Three single-page HTML views for non-engineers. `/harness-plan-brief` shows, before work starts, Claude's understanding, options, risks, acceptance criteria, and a 0 to 100 confidence with reasons; your decision is recorded with a SHA-256 hash (a fingerprint calculated from the request). `/harness-accept` shows ship, wait, or reject: ship when 80% or more of the criteria are verified, wait at 50% or more, reject below 50% or when no criteria are verified. `/harness-progress` shows progress %, current work, last 5 done, next 5 to do, and five warning types (scope creep, time overrun, repeated failure, cost warning, high-risk file). The progress page also regenerates automatically, at most once per 60 seconds, after Write, Edit, MultiEdit, or Bash; this hook is on by default in the plugin. Brief and acceptance pages share the request hash so they can be linked. Each page ends with a "basis for this artifact" section.
- Searching other projects' memory is opt-in per run with `--cross-project-group <name>`. Groups are defined in `.claude/rules/cross-project-groups.yaml`, and your own redaction dictionary in `.claude/rules/client-redaction.yaml`. Masking runs in layers: memory-server removal of `<private>` content and project scope, then your dictionary, then Japanese named-entity masking, then a final scan before HTML is written. The final scan stops HTML generation (exit 1) when it finds 5 or more consecutive katakana characters. Each search is logged to `.claude/state/audit/cross-project-search.jsonl` with a hash of the query, not the query text. These are fixed patterns, not a general privacy guarantee. Names in other scripts or spelled in ways the dictionary does not cover can pass.

## [4.8.1] - 2026-05-09

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#481---2026-05-09) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2436)

### Fixed

- Plan checks understand tracked archives without requiring completed work in the active plan. Network deniedDomains now comes from harness.toml; sync warns about generated-settings drift instead of treating output as the source.

### Security

- Fix session-start sync silently removing six paste-site network blocks after `be2a1781`. Blocks for `pastebin.com`, `transfer.sh`, `0x0.st`, `paste.ee`, `termbin.com`, and `ix.io` now live in `harness.toml` and survive synchronization.

This network list was generated from `harness.toml` into the plugin settings; its runtime effect at that time has not been re-tested. The [current official contract](https://code.claude.com/docs/en/plugins-reference#settings) applies only `agent` and `subagentStatusLine` from plugin settings, so copy network blocks into your own user or project settings.

## [4.8.0] - 2026-05-08

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#480---2026-05-08) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2492)

### Changed

- Follow-up for Claude Code 2.1.112 to 2.1.132. MCP-tool hooks (hooks that call an external tool directly, `type: "mcp_tool"`) are not adopted for now; Harness keeps its shell-wrapper hooks and will reassess when the memory MCP is generally available, wrapper delay is measured, or Claude Code publishes hook auth guidance. Effort level seen by hooks cannot relax any guardrail. Hooks keep reading the session ID from their JSON input; Bash commands may use Claude Code's `CLAUDE_CODE_SESSION_ID`. Force-push, hard-reset, and protected-branch push checks are confirmed to catch `env`, `sudo`, and `watch` wrappers.

### Added

- A stalled worker may be restarted at most once, after its task stays in progress for more than 10 minutes or a stall log appears. For sessions over 30 minutes, start Claude Code with `ENABLE_PROMPT_CACHING_1H=1` (a Claude Code option) to use the one-hour prompt cache.
- Optional output redaction, off unless `HARNESS_OUTPUT_GOVERNANCE_ENABLE=1`. It only replaces keys matching `sk-` followed by 20 or more letters or digits, or `sk-ant-` followed by 20 or more letters, digits, or hyphens. It does not touch output from Read, Grep, Glob, TodoWrite, or Bash, so keys printed by commands or found in files are not redacted. Its audit file `.claude/state/output-audit.jsonl` keeps the original text as well as the redacted text, so that file itself contains the key and must be protected or deleted.
- Skill-trigger telemetry is stored only locally in `.claude/state/skill-trigger-stats.jsonl`, keeps the first 12 characters of the session ID, and stops with `HARNESS_SKILL_TELEMETRY_DISABLE=1`.
- The network-deny template `templates/claude/settings.security.json.template` grows from 3 to 9 hosts by adding paste and upload sites: `pastebin.com`, `transfer.sh`, `0x0.st`, `paste.ee`, `termbin.com`, `ix.io`. This is a template; nothing changes until you copy the entries into `sandbox.network.deniedDomains` yourself. The original asked users to add them to `.claude-plugin/settings.json`. The later 5.7.0 record says Claude Code does not read that file's `permissions`. This historical runtime has not been re-tested. The [current plugin settings contract](https://code.claude.com/docs/en/plugins-reference#settings) applies only `agent` (default agent) and `subagentStatusLine` (worker status display), not `sandbox`; put the network-deny entries in your user or project settings to apply them. `skillOverrides` stays unset by default; `name-only` is suggested for companies and `user-invocable-only` for education.

## [4.7.0] - 2026-05-06

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#470---2026-05-06) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2577)

### Added

- Manage harness-mem with `harness mem status|setup|update|doctor|off|purge`, including ownership and safe-purge rules. Weak-supervision reports record missing evidence, hollow passes, skipped tests, and unreproduced bugs with privacy tags in a local append-only ledger.

### Changed

- By default, plugin `Setup:init` tries once to set up harness-mem for Claude Code and Codex, without blocking. SessionStart never installs it. Set `CLAUDE_CODE_HARNESS_MEM_AUTO_SETUP=0` to turn the attempt off. Advisors may read compact cues from past weak-evidence events. Those events are written locally first and forwarded to harness-mem when possible, without reading memory internals. PLAN (plan), CORRECTION (correction), and STOP (stop) stay the advisor's only answers.

## [4.6.1] - 2026-05-05

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#461---2026-05-05) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2589)

### Fixed

- OpenCode generation includes Breezing and matches its skill mirror.

## [4.6.0] - 2026-05-05

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#460---2026-05-05) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2595)

### Added

- Release checks parse version files/manifests before tagging. Contributors get a Go-first implementation guide and machine-readable skill design metadata checked across Claude/Codex/OpenCode.

### Changed

- Codex guides use its native agent APIs. Media/announcement workflows require explicit manual invocation. Heavy work details move to references while entry and stop conditions stay visible; updated skill mirrors stay aligned.

### Fixed

- Loops find helpers in the plugin rather than the user's project. Broken review links, marketplace version drift, untracked-file residual scans, unsupported agent fields, misplaced team docs, executable/library checks, and template duplicate-output false positives are corrected. Agent safety depends on plugin hooks, Go checks, and worker preflight, not ignored frontmatter.

## [4.5.4] - 2026-05-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#454---2026-05-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2623)

### Fixed

- Clean-checkout language/manifest tests use only tracked public files and no longer require private local skills.

## [4.5.3] - 2026-05-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#453---2026-05-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2629)

### Fixed

- Cache sync copies tracked declared directories only and removes stale private content/OS metadata. Release safety-net builds outside tracked bin and preserves existing release assets. Local upstream/media notes no longer ship publicly.

## [4.5.2] - 2026-05-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#452---2026-05-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2637)

### Changed

- Core workflow skills remain discoverable; broad internal helpers stop auto-loading but remain explicitly accessible. Full mirror checks include non-core skills.

### Fixed

- Remove duplicate prompt-policy injection and worker preload of review context. Cache repair retains declared skills and output styles so enabled plugins load.

## [4.5.1] - 2026-05-03

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#451---2026-05-03) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2650)

### Changed

- Sensitive paths now distinguish deny, ask, and warn for behavior-changing config, secrets, hooks, and setup metadata. Codex guidance covers 0.125/0.128 permission profiles, network policy, telemetry limits, updating, and legacy-only full-auto.

## [4.5.0] - 2026-05-03

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#450---2026-05-03) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2657)

### Changed

- Direct push to `main` or `master` now asks for confirmation instead of being blocked. Set `safety.protected_branch_push` in `.claude-code-harness.config.yaml`, or `protectedBranchPush` in `harness.toml`, to `ask` (confirm), `deny` (block), or `allow` (permit).

### Fixed

- Windows Git Bash/MSYS/Cygwin resolves its .exe through the shim and builds worktree paths correctly, rejecting JSON-shaped cwd. Windows locking uses mkdir/no-lock fallbacks where Unix flock is unavailable. Breezing on Windows no longer falls back to Solo mode because the hook binary or worktree path could not be found.

### Added

- Document Claude 2.1.120–126 and Codex 0.125/0.128 changes with Windows worktree regression checks.

## [4.4.0] - 2026-04-26

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#440---2026-04-26) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2685)

### Added

- Codex Breezing defaults and loop batch execution accompany upstream guidance for Claude 2.1.116–119 and Codex 0.123–124. User answers can bridge through updatedInput.answers; unsupported or prerelease capabilities remain proposals rather than guessed implementations.

### Fixed

- Loop startup accepts heading IDs like `6G-6`, `Plans.md:546`, and ranges. It launches by absolute script path, retains real worker failure codes/logs, and terminates child jobs on stop. Setup preserves current symlinks, backs up stale ones without moving their source files, and avoids backup-name collisions.
- Hooks validate plugin roots when the environment is missing, cache sync repairs marketplace paths, and non-UI contracts omit inactive fields instead of null values that fail release checks.

### Security

- Add cloud metadata endpoints (addresses that can return service credentials) to `sandbox.network.deniedDomains`, the network block list. R05 dangerous-deletion checks now include `find -delete`, `find -exec rm`, and macOS paths `/private/etc`, `/private/var`, `/private/tmp`, `/private/home`, and `~/Library`.

This network list was generated from `harness.toml` into the plugin settings; its runtime effect at that time has not been re-tested. The [current official contract](https://code.claude.com/docs/en/plugins-reference#settings) applies only `agent` and `subagentStatusLine` from plugin settings, so copy network blocks into your own user or project settings.

## [4.3.3] - 2026-04-20

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#433---2026-04-20) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2815)

### Fixed

- Users without harness-mem (no `~/.claude-mem/` folder) no longer see `harness-mem unhealthy` at every session start; unconfigured exits 0. Installed-but-unreachable or corrupt memory still exits 1 and warns.

## [4.3.2] - 2026-04-20

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#432---2026-04-20) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2871)

### Fixed

- Session drift scans use a bounded tail buffer; null-safe memory-hook tests and narrower migration exceptions improve internal checks. No user workflow changes.

## [4.3.1] - 2026-04-19

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#431---2026-04-19) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2922)

### Added

- The session monitor now warns, one line each, about three things. Memory health: checks `~/.claude-mem/` and connects to the memory daemon at `HARNESS_MEM_HOST:HARNESS_MEM_PORT` (default `127.0.0.1:37888`). Unanswered advisor or reviewer requests older than 600 seconds by default, set by `orchestration.advisor_ttl_seconds`. Plans drift when 5 or more tasks are in progress or Plans.md has not changed for 24 hours, set by `monitor.plans_drift.wip_threshold` and `monitor.plans_drift.stale_hours`. All three keys go in `.claude-code-harness.config.yaml`. The health check runs the `harness` program from the plugin or PATH, never from the project's own `bin/`, so a planted binary in a repository cannot replace it.

### Fixed

- New and resumed sessions now receive the previous session's summary from harness-mem on the first prompt; the scripts existed but were never connected. This needs harness-mem to be running and `curl` and `jq` to be installed. When memory is not set up or not reachable, the step is skipped silently and other hooks continue.

## [4.3.0] - 2026-04-19

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#430---2026-04-19) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3000)

### Fixed

- Bare `/harness-review` starts automatically and prints a `REVIEW_AUTOSTART:` line. Workers cannot change Plans.md status markers (a hook denies Write or Edit that rewrites `cc:` markers), clone other repositories inside a worktree, or call the advisor directly; leads relay advice. Workers must submit 5 self-checks with evidence; the lead sends incomplete reports back at most 2 times before escalating. Configure the rules in `[worker.self_review]` of `harness.toml`. Universal findings from one worker are passed to the next worker in the same `/breezing` run and discarded when it ends. Review rounds rise from 3 to 10, overridable per project. Leads may take over review when Codex review stalls.

## [4.2.0] - 2026-04-18

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#420---2026-04-18) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3046)

### Added

- Compaction (summarizing conversation history) is blocked while a long-running worker is active or `Plans.md` has uncommitted changes. Reviewer/advisor sessions are not blocked. This works from repository subdirectories and honors `plansDirectory` (a custom plan location).
- `harness-session-monitor` starts automatically when the plugin is enabled. It records branch and last commit correctly inside worktrees (isolated working checkouts).
- Prompt caching (reuse previously processed input) is opt-in via `ENABLE_PROMPT_CACHING_1H=1 claude`: retention rises from 5 minutes to 1 hour. Use 1 hour for sessions over 30 minutes, otherwise 5 minutes. `scripts/enable-1h-cache.sh` writes `export ENABLE_PROMPT_CACHING_1H=1` to `env.local`; `source env.local` passes it to Claude subprocesses.
- Reviewer/advisor use `xhigh` (reasoning effort between `high` and `max`; `/effort xhigh` selects it). On models other than Opus 4.7, it falls back to `high`. The `harness-review` skill stays at `high` unless its caller overrides it.
- High-resolution visual review targets up to 2576px on the short edge (3.75 MP, million pixels). Resize larger images first. Task Budgets (API spending/token limits, public beta) are not adopted in this release. Re-entry tools output JSON (structured data) only.

### Changed

- Agents use directory discovery and monitors use `monitors/monitors.json` rather than invalid plugin manifest fields.
- Plugin agents silently ignore frontmatter (the definition's configuration header) `permissionMode` and `hooks:`. Those agent-level settings may not have applied. This release documents the limitation in `docs/agent-frontmatter-policy.md`; it does not fix that behavior. The unsupported settings were removed in 4.6.0.
- Opus 4.7 follows instructions literally. Harness rewrote prompts for 4 agents and 7 skills with explicit limits; custom prompts may need the same adjustment.
- `/undo` is not used autonomously. `/ultrareview` (Claude Code's built-in review) complements Harness review and does not replace its acceptance decision.

### Removed

- `harness.toml`'s `[telemetry]` settings, `otel_endpoint` and `webhook_url`, were never used by runtime code and are removed. Set the notification destination with the environment variable `HARNESS_WEBHOOK_URL`.

### Fixed

- Sync no longer restores invalid fields. `claude plugin validate` no longer reports `monitors: Invalid input` or `agents: Invalid input`. Ranges such as `harness codex-loop start 41.1-41.4` work again. The POSIX `bin/harness` shell entry point, overwritten by an arm64 binary, is restored.
- Helper discovery from a sibling install, stale failure state on resume, and duplicate re-entry into the same run are repaired. Advisor timeouts preserve partial text. If high-risk preflight or retry-threshold consultation fails, task execution continues without advice. Missing CI results before the first push are a warning.

### Security

- Claude Code 2.1.110 itself re-evaluates `permissions.deny` (refusal rules) after `PermissionRequest` (the permission-request hook) returns rewritten `updatedInput`. It retains `PreToolUse`'s `additionalContext` (extra model context) after a tool fails and closes Bash bypasses using backslash escapes, compound commands, or environment-variable prefixes. Harness re-verifies its R01–R13 guardrails against these upstream changes with 34 regression checks.


## [4.1.1] - 2026-04-16

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#411---2026-04-16) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3170)

### Added

- Advisor settings (on or off, mode, consultation limit, retry threshold, model) are read from `.claude-code-harness.config.yaml` or the template; advisor state in `.claude/state/advisor/` is created automatically.

### Fixed

- Symlinked command entrypoints locate their real binaries so PATH-installed loop commands work.

## [4.1.0] - 2026-04-16

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#410---2026-04-16) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3180)

### Added

- `/maintenance` is back, answering the cleanup warnings that pointed to it. `plans` moves finished tasks to an archive, `session-log` splits session-log.md by month, `logs` deletes old files in `.claude/logs/`, `state` trims `agent-trace.jsonl`, and `all` runs these four in order. Add `--dry-run` to list targets without changing anything; thresholds and exclusions can be given in words. `harness codex-loop start all --max-cycles 3`, `status`, and `stop` run Codex task, review, and checkpoint cycles in the background, saving state in `.claude/state/codex-loop/`.

### Changed

- Codex-specific skill sources remain separate from shared skills; release tooling handles major/minor bumps.

### Fixed

- Package/mirror checks verify Codex review and workflow surfaces against their actual sources.

### Removed

- The `allow1` skill is removed from distribution and checks.

## [4.0.4] - 2026-04-14

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#404---2026-04-14) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3295)

### Fixed

- Marketplace installs now include the hook engine for macOS Apple Silicon, macOS Intel, and Linux amd64 (about 32 MB in total). Before 4.0.4, installs from `/plugin marketplace add` had no engine, so on Linux amd64 (including WSL2) and Apple Silicon no guardrail ran at all. If you used 4.0.0 to 4.0.3 from the marketplace, update. Windows was not included in this release. Inference (high confidence): on a platform without a binary, hooks keep doing nothing. A missing or unsupported binary now writes a diagnostic to stderr and exits 0 with empty stdout, for hook and non-hook commands alike, so the session continues but no protection is active. `harness sync` keeps `./skills/`.

### Added

- Lean release archives exclude development content; plugin validation checks skill paths, and version bumps add comparison links.

### Changed

- Generic release supports VERSION/package.json/pyproject.toml/Cargo.toml and one reviewable confirmation before execution. Harness-specific preflight/finalization moves to its internal wrapper.

## [4.0.3] - 2026-04-13

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#403---2026-04-13) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3409)

### Fixed

- Installed plugins loaded zero skills because the manifest pointed at the wrong folder. Development checkouts hid the problem. Run `claude plugin update claude-code-harness` to get the fix. A later sync could undo it until 4.0.4, so update to 4.0.4 or newer.

## [4.0.2] - 2026-04-12

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#402---2026-04-12) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3432)

### Added

- `harness doctor --residue`, PR validation, and release preflight detect known migration leftovers; historical exceptions retain old evidence without allowing active obsolete references.

### Removed

- Remove remaining 3.x active references and document migration ownership.

## [4.0.1] - 2026-04-11

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#401---2026-04-11) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3473)

### Security

- Harness's own permission checks now repeat fixes Claude Code made in 2.1.89 to 2.1.98, as a second layer. Commands with backslash-escaped spaces or flags are never treated as safe. Only `LANG`, `LANGUAGE`, `TZ`, `NO_COLOR`, `FORCE_COLOR`, and `LC_*` may prefix a command that is otherwise safe; any other variable makes it unsafe. Repeated spaces and tabs are normalized before checks. Protected-path checks follow symlinks; a broken or looping link is denied, a path that does not exist yet is allowed so new files can be created. `.husky/` git hooks are protected. A "defer" decision now reaches Claude Code.

### Changed

- Review reports lead with verdict, reasons, actions, and severity, with technical data separated; at this release review output was required to be Japanese (the English default was restored in 4.12.4). Bare review chooses the last tag, then `main`, then the last 10 commits as base, and caps at 10 commits. Skill names return to `harness-*` (for example `harness-review`) after a brief `HAR:*` naming. Long-process monitor guidance is added.

### Fixed

- Sync stops overwriting valid manifest settings, startup matchers reject near-miss event names, and validation/memory wiring uses the Go runtime names.

## [4.0.0] - 2026-04-09

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#400---2026-04-09) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3643)

### Breaking Changes

- Hooks now call a bundled Go program (`bin/harness hook ...`) instead of shell and Node scripts. Run `harness sync` to regenerate hook files; the old `run-hook.sh` wrapper is gone. Node is no longer required for hooks. Direct push to protected branches changes from a warning to a block (later relaxed to a confirmation in 4.5.0). Custom hooks that called the old shell scripts must be pointed at the new commands.

### Added

- The 37 hook handlers and the protection rules now run in Go, settings files are generated from `harness.toml` with `bin/harness sync`, and state is kept in SQLite (`state/harness.db`). New commands: `bin/harness doctor --migration` (migration status), `bin/harness validate` (skill and agent definition check), and `harness status` (agent state). Binaries were built for macOS Apple Silicon, macOS Intel, and Linux amd64 and attached to the GitHub Release. Inference (high confidence, from 4.0.4): marketplace installs did not receive these binaries until 4.0.4, so their guardrails were not running.

## [3.17.1] - 2026-04-06

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3171---2026-04-06) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3774)

### Fixed

- With harness-mem installed in its standard location `~/.harness-mem/runtime/harness-mem`, the memory bridge could not find it and exited silently, so resume context was not restored at session start. It now checks that location first, after an explicit `HARNESS_MEM_ROOT` override.

### Changed

- Document Claude Code 2.1.91–92 features (not Harness implementations): `disableSkillShellExecution`, plugin `bin/` directories, MCP `maxResultSizeChars` up to 500K, and subagent-spawning fixes.

## [3.17.0] - 2026-04-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3170---2026-04-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3807)

### Added

- `harness-review --dual` runs Claude and Codex reviewers in parallel and merges their verdicts; if either requests changes, the result requests changes. The `dual_review` output field shows each model's verdict and why they disagreed. If Codex is unavailable, the review runs with Claude alone. Plain `harness-review` and `harness-review code` are unchanged.
- `harness-review --security` focuses on the OWASP Top 10, authentication/authorization, and data exposure, with stricter-than-usual verdict criteria.
- On Claude Code 2.1.89+, when auto mode's classifier refuses a command, Harness logs it to `permission-denied.jsonl` and notifies the lead if a Breezing worker was refused. A guide documents Claude Code's `defer` decision; no Harness defer rules ship yet.
- After compaction, saved WIP task state is restored. Task-completion notifications go to Slack, Discord, or any URL only when `HARNESS_WEBHOOK_URL` is set; otherwise nothing is sent. OTel spans are sent by HTTP POST only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set; otherwise local JSONL remains. Codex workers receive effort calculated from files, dependencies, keywords, and completion criteria instead of always medium.

### Changed

- Harness blocks commands by returning JSON with exit code 2. Claude Code before 2.1.90 did not reliably honor that block; use Claude Code 2.1.90 or later for dependable guardrail denials. Other Claude Code 2.1.87–90 fixes are inherited without extra wrappers.
- Correct seven overstated feature claims: HTTP hooks were templates only, OTel was custom JSONL, the analytics dashboard and Slack integration were planned, LSP and desktop scheduled tasks are Claude Code native, and Auto Mode was only in its first rollout phase, not the default.
- Release guidance covers `--dry-run`, `--complete`, and `--announce`, mirrors, semantic-version selection, a regression checklist, and states that Harness is not distributed via npm.

## [3.16.0] - 2026-04-01

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3160---2026-04-01) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3924)

### Added

- Optional team mode: `scripts/plans-issue-bridge.sh` builds draft tracking-issue and sub-issue content for an issue tracker from Plans.md without creating issues; Plans.md stays the source of truth.
- `/harness-release --dry-run` runs a vendor-neutral pre-release check (`scripts/release-preflight.sh`) covering working tree, changelog, environment parity, health checks, CI, and leftovers in shipped files.
- `harness-plan create` can add optional design (UI) or contract (API) briefs; `scripts/generate-skill-manifest.sh` writes a machine-readable skill list (`skill-manifest.v1`).

### Changed

- Planning and release guides, and the Claude/Codex/OpenCode mirrors, include these entry points.

## [3.15.0] - 2026-03-28

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3150---2026-03-28) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3949)

The runtime effect in this historical release has not been re-tested. The [current plugin settings contract](https://code.claude.com/docs/en/plugins-reference#settings) applies only `agent` and `subagentStatusLine`; plugin-file presence alone does not prove protection was active.

### Added

- With Claude Code's TaskCreated, FileChanged, and CwdChanged hooks, Harness reminds you to re-read state after a task is created, Plans.md or rules change, or you switch worktree.
- Heavy workflows and worker/reviewer/scaffolder agents start from completion criteria and a verification plan (`effort` and `initialPrompt` settings).

### Changed

- Using Claude Code 2.1.85's conditional `if`, the permission hook runs only for low-risk Bash such as `git status`, `git diff`, `pytest`, and `npm run lint`; existing guardrails handle dangerous commands.
- Harness added `sandbox.failIfUnavailable: true` and `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` to its plugin settings file. Claude Code does not apply sandbox or permission settings from that file, so to fail closed when the sandbox is unavailable and to scrub credentials from subprocesses, set them in your own Claude Code settings.
- Rule path lists use structured YAML; public mirrors exclude internal-only skills.

## [3.14.0] - 2026-03-25

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3140---2026-03-25) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4006)

### Changed

- Claude Code and Codex apply the same guardrails: skipping hooks or signing (`--no-verify`, `--no-gpg-sign`), `git reset --hard` on protected branches, direct pushes to `main`/`master`, and edits to protected files are detected and warned about; this release does not say any of them is blocked. Codex runs receive these rules and are checked for bypass flags, protected-file edits, and leaked secrets before merge. Codex's AGENTS.md now includes the Harness rule details.

### Fixed

- Marketplace installs lacked the memory hook scripts, so SessionStart, UserPromptSubmit, PostToolUse, and Stop hooks errored. Memory hooks now go through one bridge script. Cache sync also resolves the plugin root correctly.

## [3.13.0] - 2026-03-25

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3130---2026-03-25) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4036)

### Added

- Codex-native versions of `harness-work` and `breezing` use Codex's own agent APIs (spawn/send/wait/close); other workflows are shared with Claude. Installed in `~/.codex/skills/`, they work from any project. Differences from Claude Code: worktrees are created explicitly with `git worktree add`, review uses Codex alone with no reviewer-agent fallback, and team mode starts only with an explicit `--breezing`, never automatically.
- `harness-review` adds a fifth perspective, AI residuals: it scans the diff for leftovers such as mock data, dummy users, `localhost` URLs, `TODO`/`FIXME`, skipped tests, and hard-coded API keys, rated minor or major.
- With harness-mem installed, SessionStart, UserPromptSubmit, and Stop hooks save session memory and show a Continuity Briefing from the previous session at the next start.

## [3.12.0] - 2026-03-21

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3120---2026-03-21) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4092)

### Added

- If Plans.md is missing, work creates it (`harness-plan create --ci`). Requests in the conversation such as "add" or "fix" that are not in Plans.md are appended automatically.
- Every mode reviews after implementation: Codex first, the internal reviewer as fallback. On REQUEST_CHANGES it fixes and re-reviews up to 3 times. Only critical/major findings block approval; minor, recommendation, and out-of-scope findings do not.
- After commit, a completion report shows what was done, before/after, changed files, and remaining Plans.md work; Breezing reports once after all tasks.

### Changed

- Breezing workers commit inside their worktree; the lead reviews, sends fixes (up to 3 rounds), and cherry-picks only approved commits. Only the lead edits Plans.md.
- codex-cli 0.115.0 removed the `-a never` flag, so earlier Harness versions fail on every Codex call with that CLI; upgrade. Codex calls now use `--full-auto`, and review calls use a read-only sandbox. These flags match the CLI at that time and are not current permission guidance.

## [3.11.0] - 2026-03-20

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3110---2026-03-20) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4161)

The runtime effect in this historical release has not been re-tested. The [current plugin settings contract](https://code.claude.com/docs/en/plugins-reference#settings) applies only `agent` and `subagentStatusLine`; plugin-file presence alone does not prove protection was active.

### Added

- On Claude Code 2.1.78+, the StopFailure hook logs sessions that fail to stop because of API errors such as rate limit 429 or authentication 401. Logs go to `${CLAUDE_PLUGIN_DATA}` when set, otherwise `.claude/state/stop-failures.jsonl`; on 429 the lead is notified. Run `scripts/show-failures.sh` for a summary by error code and time. Automatic recovery (backoff and restart) and dynamic effort are designs only, not implemented.
- A sandbox `allowRead` example (`.env.example`, `docs/**`) was added to the plugin settings file; To use this example under the current official contract, copy it into your own user or project settings; its historical runtime effect has not been re-tested.

### Changed

- Since Claude Code 2.1.77, a settings `deny` rule wins even when a hook returns `allow`; hook guidance reflects this. Claude Code renamed `/fork` to `/branch`.
- A deny rule for legacy Codex MCP tools (`mcp__codex__*`) was added to the plugin settings file. Claude Code does not read permission rules from that file; add the rule to your own settings to block them.
- Setup documents `CLAUDE_PLUGIN_DATA` and `ANTHROPIC_CUSTOM_MODEL_OPTION`. Worker and reviewer agents use effort `medium`.

## [3.10.6] - 2026-03-19

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3106---2026-03-19) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4238)

### Fixed

- Plugin installs (`claude plugin install`) lacked the compiled engine, so every PreToolUse, PostToolUse, and PermissionRequest hook failed with MODULE_NOT_FOUND and the R01–R09 guardrails did not run at all. The compiled engine now ships with the plugin. If you installed the plugin on 3.0.0–3.10.5, your guardrails were not active; upgrade.
- A metrics HTTP hook to `localhost:9090` was enabled by default, not just offered as a template. Without a metrics server, every Write, Edit, Bash, and Task call produced a connection-refused error and up to a 5-second delay. It is removed from the defaults; to use it, copy `docs/examples/hooks-metrics-http.json` into your own hooks configuration.
- Remove a broken `codex-review` link. The license is MIT in both plugin and marketplace metadata (marketplace previously said Proprietary).

### Changed

- Agent tool restrictions use the official name `Agent` instead of the older `Task` alias.

### Added

- MCP question dialogs (`elicitation_dialog`) raised in background Breezing workers are logged like permission prompts.
- The Harness Ops output style ships with the plugin. Select it with `/config` → Output style → `Harness Ops`.

## [3.10.5] - 2026-03-15

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3105---2026-03-15) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4294)

### Fixed

- `scripts/i18n/set-locale.sh ja` now also switches skill descriptions in the redesigned skill directory, which previously stayed in English.

### Changed

- Local Superset state and announcement-development skills are excluded from tracking.

## [3.10.4] - 2026-03-15

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3104---2026-03-15) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4314)

### Added

- Agent turn limits: worker 100, reviewer 50, scaffolder 75. At the limit the lead collects partial results, which caps runaway loops and token cost.
- Notification events (`permission_prompt`, `idle_prompt`, `auth_success`) are logged to `.claude/state/notification-events.jsonl` for later diagnosis, including background Breezing permission prompts.
- Feature docs list Claude Code 2.1.74's `/context` command, which shows context usage and helps diagnose frequent compaction.

## [3.10.3] - 2026-03-14

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3103---2026-03-14) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4342)

### Changed

- Codex commands are `$harness-plan`, `$harness-sync`, `$harness-work`, `$breezing`, and `$harness-review`; older names such as `$work`, `$plan-with-agent`, and `$verify` are gone. `scripts/setup-codex.sh` and `scripts/codex-setup-local.sh` move Harness skills that no longer ship out of `~/.codex/skills` into a backup.
- Hook guidance covers the SessionEnd timeout setting `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`.
- For contributors: ordinary changes leave version files untouched and record entries under Unreleased; pre-commit and CI check consistency without automatic patch bumps.

### Added

- In cloud sessions (`--remote`), Harness records `HARNESS_IS_REMOTE` in `CLAUDE_ENV_FILE` so other hooks can tell cloud from local.
- Background Breezing workers skip MCP question forms they cannot answer; ordinary sessions still ask you, and results are logged. After compaction, WIP/TODO task state is restored.
- Claude Code 2.1.76 features documented for use (not Harness implementations): `worktree.sparsePaths` for large repositories and stale-worktree cleanup, `-n`/`--name` session names, `/effort` (low/medium/high), partial results kept when a background agent is killed, and auto-compaction stopping after 3 consecutive failures.

### Breaking Changes

- With Claude 2.1.76, each `--plugin-dir` accepts one path. For several plugins repeat the flag: `--plugin-dir path1 --plugin-dir path2`. A single Harness plugin needs no change.

## [3.10.2] - 2026-03-12

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3102---2026-03-12) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4430)

### Fixed

- When completed tasks reach the total, TaskCompleted finalizes harness-mem once with work_completed rather than waiting for Stop. A success marker prevents duplicate finalization; unresolved session identity or unreachable API skips silently. Claude 2.1.74 documentation and release metadata are aligned.

## [3.10.1] - 2026-03-12

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3101---2026-03-12) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4463)

### Added

- SubagentStart/SubagentStop hooks match `worker`, `reviewer`, `scaffolder`, and `video-scene-generator` separately, so each role's start and stop is tracked.
- Document Claude Code features (not Harness implementations): Chrome integration (`--chrome`, beta), language servers (`.lsp.json`), agent-team task dependencies, `--teammate-mode`, `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, `cleanupPeriodDays`, `/btw`, plugin CLI commands, Remote Control, and the agent `skills` field.

### Changed

- The shipped default for Breezing workers remains `bypassPermissions`, which skips every permission prompt. `--auto-mode` is opt-in and only for compatible parent sessions; templates and agent definitions keep `bypassPermissions`. Documentation alone does not switch the default.

## [3.10.0] - 2026-03-11

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3100---2026-03-11) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4509)

### Added

- Enable the two-line Harness status display with `/statusline use scripts/statusline-harness.sh`. Line 1 shows model, branch, staged/modified file counts (files selected for commit versus edited files), and agent/worktree (an isolated working checkout). Line 2 shows context usage (the model's input capacity used; yellow at 70%, red at 90%), session cost, elapsed time, and output style.
- Guides cover Claude Code features, not Harness defaults: `/sandbox` isolates processes at the operating-system level using macOS Seatbelt or Linux bubblewrap. Introduce it in stages as a complement to `bypassPermissions` (skip permission prompts).
- Model guidance covers `opusplan` (Opus for planning, Sonnet for execution), `CLAUDE_CODE_SUBAGENT_MODEL` (override the subagent model), and `availableModels` (restrict which models users can select).
- Rewind with `Esc+Esc` or `/rewind`. Managed Code Review (Teams/Enterprise research preview) uses instructions in `REVIEW.md` and complements local `harness-review`.
- Long-context guidance covers `sonnet[1m]` (Sonnet's one-million-token input window), per-model prompt caching (reuse previously processed input), and `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` (disable automatic adjustment of reasoning effort).


## [3.9.0] - 2026-03-11

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#390---2026-03-11) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4573)

### Added

- Enable `/output-style harness-ops` to structure progress, check results, review, escalation, and at most three decision choices, with the recommendation first.
- Agent Teams (the team execution used by `breezing`) require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`. `teammateMode` (how teammates appear) is `auto`, `in-process`, or `tmux`. Guidance recommends 5–6 tasks per teammate and 3–5 teammates (Harness: 1–3 workers plus 1 reviewer), and requiring workers to submit a plan for approval. `TeammateIdle` (teammate idle) and `TaskCompleted` (task completed) hooks can return exit code 2 to send feedback and require further work.

### Changed

- Draft v3.7.3 and v3.8.0 changes ship in this release; neither was released separately.
- Claude Code 2.1.72 integration documents `ExitWorktree` (explicitly leave a working checkout), restored per-call Agent `model` selection, `/clear` keeping background agents, `/plan` accepting a description, and more Bash auto-approvals. Reasoning effort becomes `low`, `medium`, or `high`; `max` was removed in Claude Code 2.1.72.
- Agent definitions declared `permissionMode: bypassPermissions` (skip permission prompts). This was a historical configuration error: 4.2.0 found plugin agents silently ignore it, and 4.6.0 removed it.
- Claude Code 2.1.71+ documentation covers `/agents` (interactive agent management), `--agents` (define agents at launch), subagent `background` (run in the background) and `local` memory (project-local storage), `CronCreate`/`CronList`/`CronDelete` (create/list/delete scheduled tasks), `CLAUDE_CODE_DISABLE_CRON` (disable scheduling), and Desktop Scheduled Tasks.
- Auto Mode default changes remain planned, not active in this release; its research preview was scheduled to begin on 2026-03-12.


## [3.7.2] - 2026-03-10

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#372---2026-03-10) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4725)

### Fixed

- Hook stdout stays JSON-only by discarding telemetry chatter; empty task counts no longer leak standalone zero lines.

### Changed

- Direct-execution tests check quiet session summaries and usage hooks.

## [3.7.1] - 2026-03-09

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#371---2026-03-09) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4736)

### Changed

- Worker and reviewer agent type names are unified as `claude-code-harness:worker` and `claude-code-harness:reviewer`. Before this, the names differed between files, so the worker's pre-write guard and the reviewer's completion log did not reliably run; they now apply.
- Breezing workers run in the background and cannot show permission prompts, so they use `bypassPermissions`, which skips all permission checks; unintended file rewrites or dangerous commands can pass. On Claude Code 2.1.71+, opt in to Auto Mode with `/breezing --auto-mode` or `/harness-work --breezing --auto-mode`: it auto-approves only predefined safe operations and blocks commands such as `rm -rf` and `git push --force`. Planned stages: opt-in now, default after validation, then removal of `bypassPermissions` once stable.
- Each worker runs in its own git worktree, so parallel workers editing the same file no longer collide; the lead merges after completion.

## [3.7.0] - 2026-03-08

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#370---2026-03-08) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4773)

### Added

- When a task fails 3 times, Harness classifies the cause and saves a proposed fix task instead of only stopping. Approve with `approve fix <task_id>` to add it to Plans.md as a `.fix` task, or decline with `reject fix <task_id>`.
- `/harness-sync --snapshot` saves current progress; the next SessionStart or `/resume` shows the latest summary and the change since the previous snapshot.
- Completed tasks automatically get the 7-character commit hash in their status (`cc:完了 [a1b2c3d]`); rows without a hash remain valid.
- Breezing prints a one-line progress update each time a worker finishes a task.
- Plans.md phases may include an optional `Purpose:` line; it is written only when you state the purpose.

## [3.6.0] - 2026-03-08

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#360---2026-03-08) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4859)

### Breaking Changes

- Plans now require five columns including completion criteria and dependencies; the three-column format is dropped. Migrate task rows before using sync.

### Added

- `harness-plan create` infers testable completion criteria and dependencies, and ranks tasks by impact and risk; high-impact, high-risk tasks get a `[needs-spike]` marker and a technical-validation task. Plans are checked for empty or untestable criteria and circular dependencies.
- Plan review adds a fifth axis, user value.
- Sync runs a retrospective by default when at least one task is complete; skip with `--no-retro`.
- Breezing checks scope, dependencies, and risk before starting, and assigns tasks with no dependencies first, then dependent tasks as their prerequisites finish. Solo work first confirms purpose and impact.

## [3.5.0] - 2026-03-07

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#350---2026-03-07) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4899)

### Added

- Three consecutive tool failures within 60 seconds trigger escalation. Guides combine `TeammateIdle` (a hook called when a teammate becomes idle) with active `/loop 5m /sync-status` checks, preserve background-agent results through compaction (summarizing conversation history), and recommend version-pinned plugin installs (`owner/repo@vX.X.X`).

### Changed

- Claude Code 2.1.70–2.1.71 update notes: `--resume` no longer re-injects skills; compaction keeps images. Hangs with `--print`, plugin-hook bugs, and parallel plugin-install bugs are fixed in Claude Code itself.

### Fixed

- Windows checkouts without real symlinks (links to another path) expose workflow skills before `SessionStart` (the session-start hook).

### Security

- Failure counters refuse writes through symlinked state directories or files.


## [3.4.2] - 2026-03-06

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#342---2026-03-06) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4936)

### Changed

- Bilingual READMEs explain installed behavior and grounded comparisons; Codex setup follows path-based skill loading.

### Added

- Rerunnable work-all success/failure evidence packs and bilingual flow/safety visuals support verification.

### Fixed

- Evidence runners retain actual Claude/test exit codes instead of inverted statuses; claim/distribution drift checks run before release.

## [3.4.1] - 2026-03-06

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#341---2026-03-06) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4962)

### Changed

- Bilingual feature tables use the `harness-work` and `harness-review` names consistently.

### Fixed

- Feature tables replace legacy names (`task-worker`, `code-reviewer`, `work`, `all skills`) with `harness-work`, `harness-review`, and `all harness-* skills`. This corrects misleading instructions for starting with `/breezing` and `/harness-work`.


## [3.4.0] - 2026-03-06

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#340---2026-03-06) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4980)

### Added

- The InstructionsLoaded event is handled. Teammate idle and task-completion hooks can stop a teammate by returning `{"continue": false, "stopReason": "..."}`.
- Guides cover Claude Code 2.1.69's `${CLAUDE_SKILL_DIR}` references, agent IDs and types, `/reload-plugins`, `includeGitInstructions: false`, and projects in a git subdirectory.

### Changed

- Breezing role checks look up `agent_id` first, then `session_id`. Skill references resolve from the skill's own directory. Project templates ship only documented permission-mode defaults.

### Fixed

- A `false` stop response is no longer dropped, so the stop reason is applied.

## [3.3.1] - 2026-03-05

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#331---2026-03-05) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5010)

### Changed

- Bilingual visuals adopt the orange palette, replace the logo, and remove duplicate diagrams/tables.

### Added

- Four-perspective review graphics and Japanese versions of core flow/safety graphics are added.

## [3.3.0] - 2026-03-05

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#330---2026-03-05) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5036)

### Added

- Complexity scoring (file count, critical directories, task keywords, past failures) injects `ultrathink` at a score of 3 or more, so complex tasks get deeper reasoning and simple tasks stay fast.
- Three LLM-backed agent hooks run on every relevant action, adding model calls, cost, and latency: before each Write/Edit, a quality guard checks for secrets, TODO stubs, and security issues; after each file write, a lightweight haiku review runs; at Stop, a guard warns about unfinished `cc:WIP` tasks. A PreCompact hook catches WIP tasks before compaction.
- Worktree creation records worker identity in `.claude/state/worktree-info.json`; removal cleans Codex temporary files and logs. Session setup writes `HARNESS_VERSION`, `HARNESS_EFFORT_DEFAULT=medium`, and `HARNESS_BREEZING_SESSION_ID` to `CLAUDE_ENV_FILE`.
- A metrics HTTP hook to `localhost:9090` was described as a template, but it was actually enabled by default until 3.10.6 and caused connection errors and delays without a metrics server.

### Changed

- Describe command/prompt/http/agent hooks and effort-aware worker/reviewer handoffs against Claude Code 2.1.68 guidance; later upstream constraints supersede broad historical hook claims.

### Fixed

- Prompt hooks are documented as available on all events, not only Stop/SubagentStop; remove a dead documentation link.

## [3.2.0] - 2026-03-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#320---2026-03-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5075)

### Added

- `/harness-work --no-tdd` skips the TDD phase (write a failing test before implementing the change).
- On session start, before skills are discovered, broken Windows symlinks (links to skill directories) are detected and replaced with directory copies by `scripts/fix-symlinks.sh`.

### Changed

- TDD (test-first development) is now on by default. The old `[feature:tdd]` opt-in marker is no longer needed. Every in-progress task gets TDD reminders unless marked `[skip:tdd]`; workers and solo execution proceed from failing tests to passing tests.


## [3.1.0] - 2026-03-03

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#310---2026-03-03) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5101)

### Added

- `/harness-work` picks the mode by task count: 1 task solo, 2–3 parallel, 4 or more Breezing. Codex (`--codex`) is used only when you ask for it. `/breezing` runs `/harness-work --breezing`.
- Codex `config.toml` adds a `[notify]` after-agent memory bridge and a read-only sandbox for the reviewer; guides cover Codex-specific limits.

### Changed

- Codex integration is CLI-only (MCP server references removed). Flags follow that CLI version, and long prompts are passed on standard input to avoid argument-length limits.

### Fixed

- Prompt files get unique names so parallel runs do not collide; errors go to log files instead of being discarded. Skill metadata and routing errors are corrected.

### Removed

- 15 redirect skills and old suffix aliases are removed: `breezing` (old), `codex-review`, `handoff`, `harness-init`, `harness-update`, `impl`, `maintenance`, `parallel-workflows`, `planning`, `plans-management`, `release-har`, `setup`, `sync-status`, `troubleshoot`, `verify`, `work`, the `*-harness` aliases, and `x-release-harness`. By function (from the v3 architecture notes, not this release's text): planning, plans-management, sync-status → `harness-plan` (sync later moved to `harness-sync`); work, impl, parallel-workflows, old breezing → `harness-work`; codex-review, verify, troubleshoot → `harness-review`; release-har, x-release-harness, handoff → `harness-release`; setup, harness-init, harness-update, maintenance → `harness-setup`.

## [3.0.0] - 2026-03-02

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#300---2026-03-02) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5142)

### Breaking Changes

- The redesigned workflow consolidates 42 skills into five verbs and 11 agents into three. Hooks use a Node-based typed engine and SQLite instead of scattered state files; mirrors become symlinks. Legacy skills/agents remain during this release's transition.

### Added

- One session lifecycle handles start, transitions, finish, fork, and resume, with migration of old state into SQLite and a structural validator.

### Fixed

- Correct the SQLite module typing, and run the tampering check once per write instead of twice.

### Removed

- rsync mirror sync, standalone Bash guardrail scripts, and scattered state files are replaced by the new engine.

## [2.26.1] - 2026-03-02

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2261---2026-03-02) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5193)

### Added

- Bilingual READMEs gain six section-specific diagrams per language for task flow, parallel work, safety, skills, and teams.

### Fixed

- The approval table now includes automatic refinement before committing, matching the actual work flow.

## [2.26.0] - 2026-03-02

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2260---2026-03-02) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5203)

### Added

- `/work` runs Claude Code's built-in `/simplify` after review approves and before committing. `--deep-simplify` also uses the `code-simplifier` plugin; `--no-simplify` skips the step. `/simplify` and `/batch` are Claude Code 2.1.63+ features; Harness only invokes or proposes them.
- `/breezing` detects repeated edits across many files (migrate, replace-all, add-to-all) and proposes handing them to Claude Code's built-in `/batch`.
- Hook guidance documents Claude Code's `type: "http"` hooks, which POST hook data to a URL you configure, with Slack, metrics, and dashboard samples. Harness configures no endpoint; adding one sends data to that service.

### Changed

- Version references move from Claude Code 2.1.49+ to 2.1.63+. Guidance adds shared auto memory across worktrees and `/clear` resetting the skill cache. `/work` state records refinement as default, deep, or skipped.

## [2.25.0] - 2026-02-24

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2250---2026-02-24) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5231)

### Added

- `CLAUDE_CODE_SIMPLE` (Claude Code's reduced-feature mode, version 2.1.50+) silently disabled 37 skills, 11 agents, and memory. `SessionStart` and `Setup` now detect it and warn in the terminal's error output (`stderr`) and session context (`additionalContext`, information passed to the model). The impact is classified as skills disabled, agents disabled, or hooks only. A compatibility guide explains limitations and workarounds; detection does not restore disabled features.

### Changed

- The compatibility matrix changes SIMPLE mode from caution to handled and lists its impact. Handled means detection and guidance, not restored features.


## [2.24.0] - 2026-02-24

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2240---2026-02-24) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5260)

### Added

- Compatibility notes cover Claude Code 2.1.50–2.1.51 features: memory-leak fixes, completed-task cleanup, WorktreeCreate/WorktreeRemove hooks, declarative worktree isolation, SIMPLE mode, and remote control. At this release Harness documents the worktree hooks only as future work.
- Troubleshooting adds `claude agents list` (Claude Code 2.1.50+) to check agents when a spawn fails.
- Stop background agents with `Ctrl+F` (Claude Code 2.1.49+); `Esc` is not recommended.

### Changed

- Recommended Claude Code version rises from 2.1.49+ to 2.1.51+.

## [2.23.6] - 2026-02-24

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2236---2026-02-24) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5288)

### Added

- The `release-har` skill's branch policy allows ordinary direct push to `main` for solo projects; force push stays prohibited. The project template `templates/AGENTS.md.template` drops its ban on direct `main` push for solo projects in the same way, so newly generated project rules allow it.

### Changed

- The Codex worker quality gate also treats Python skip patterns, catch-all assertions, and relaxed test configuration as test tampering.

## [2.23.5] - 2026-02-23

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2235---2026-02-23) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5309)

### Added

- Test-tampering detection covers 12+ patterns, including weakened assertions (`toBe` → `toBeTruthy`), inflated timeouts, catch-all assertions, and Python skip decorators.
- `HARNESS_AUTO_TEST=run` makes the auto-test hook actually run related tests and return pass/fail. Without it, tests are only recommended.
- Separately, after `git push` a hook detects CI failures and adds a CI-fix recommendation to your next prompt.
- `sync-rules-to-agents.sh` copies `.claude/rules/*.md` into the Rules section of `codex/AGENTS.md` so Codex reads project rules. `codex-exec-wrapper.sh` runs that sync before `codex exec`, saves `[HARNESS-LEARNING]` notes to `codex-learnings.md`, and filters secrets.
- In `/breezing`, when `.claude/state/review-result.json` records APPROVE for the current HEAD commit, the final phase skips the manual APPROVE confirmation.
- Codex execution policy (`harness.rules`): `npm test`, `yarn test`, and `pnpm test` run without asking. `git push --force`, `git reset --hard`, `rm -rf`, `git clean -f`, `DROP TABLE`, and `DELETE FROM` ask for confirmation.

### Changed

- `/breezing` implementer count is at least 1 and at most the smallest of the independent task count, `--parallel N`, the planner limit, and 5.
- The `release-har` skill shows a `--dry-run` preview first, infers the semantic-version bump, writes four-section release notes with compare links, and adds an announcement only with `--announce`.

## [2.23.3] - 2026-02-22

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2233---2026-02-22) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5348)

### Added

- The Codex package includes the `generate-slide` skill; bilingual READMEs document the `/generate-slide` command.

### Changed

- Non-Breezing Codex work and second-opinion reviews use `codex exec`, with CLI setup/troubleshooting rather than MCP wording.

### Fixed

- Setup checks actual Codex CLI readiness; mirrors and regression checks match the CLI-only contract.

## [2.23.2] - 2026-02-22

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2232---2026-02-22) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5380)

### Fixed

- Codex work/team guides use native multi-agent APIs and `${CODEX_HOME:-~/.codex}/state/harness/`. `--claude` delegates review too; `--claude --codex-review` fails before execution. OpenCode drops then-development-only Breezing files.

## [2.23.1] - 2026-02-22

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2231---2026-02-22) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5402)

### Changed

- Codex setup adds new files, backs up/replaces managed existing files, and preserves destination-only user files; project/user setup use the same merge. Guides move into expandable quick-start details.

### Added

- Setup injects five missing planning/worker/reviewer roles idempotently without duplicating existing roles.

## [2.23.0] - 2026-02-21

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2230---2026-02-21) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5428)

### Added

- Codex planning discussion uses native agents and lead-relayed analyst/critic dialogue. Five role definitions support planning, implementation, and review.

### Changed

- Three Breezing references keep Codex-specific content and are excluded from the shared copy. Codex team runs require `[features] multi_agent = true` in `config.toml`; Harness's environment check looks for it.

## [2.22.0] - 2026-02-21

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2220---2026-02-21) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5454)

### Added

- This release shipped default security rules in `.claude-plugin/settings.json` and stated that Claude Code 2.1.49+ applies them on install, so `/harness-init` was no longer needed for them. Release 5.7.0 later recorded that Claude Code does not read permission rules from this plugin file. Do not assume these rules were active unless `/permissions` lists them in your session.
- The `ConfigChange` hook records configuration-file changes to the team timeline only while Breezing is active, and never blocks. The Stop hook reads the final assistant message (Claude Code 2.1.47+) and stores only its length and SHA-256 hash, never the text, using atomic writes.

### Security

- Rules in that file at this release had no blanket allow. Deny: `.env` and secret files, SSH keys (`id_rsa`, `id_ed25519`, `.ssh/`), `.aws/`, `.npmrc`, `sudo`, `rm -rf` and `rm -fr`, and the database CLIs `psql`, `mysql`, `mongo`, `mongod`. Ask: `git push --force`, `git reset --hard`, `git clean -f`, ordinary `git rebase` and `git merge`, `npm`/`bun`/`pnpm install`, `npx`, and `npm exec`. These were this release's defaults, not current policy.

### Changed

- Breezing guides adopt Claude Code 2.1.49+ worktree isolation (`isolation: "worktree"`), so parallel implementers edit separate checkouts of the files, and the 2.1.47+ agent model-field behavior. Conflicting changes can still require resolution when merged. Only the `video-scene-generator` agent gains background execution (`background: true`). Codex and OpenCode team references are synchronized. Version references move from Claude Code 2.1.38 to 2.1.49.

## [2.21.0] - 2026-02-20

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2210---2026-02-20) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5506)

### Added

- `/breezing` reviews the plan before coding: a Planner (`plan-analyst`) and a Critic (`plan-critic`) discuss it first. This is on by default; `--no-discuss` skips it. Tasks are checked for scope, ambiguity, overlapping file ownership, dependency consistency, and test-first markers before they are created.
- Mark a task with `[feature:tdd]` in Plans.md to generate its tests first.
- 8 or more tasks are split into batches; the next batch is recommended when 60% of the current one completes. Implementers can message each other directly, and the task-completion hook recommends partial reviews and next batches.

### Fixed

- Signals tolerate simultaneous threshold crossings, deduplicate within sessions, and preserve planning handoffs across compaction. Resume maps stale task IDs; each active task is counted once. Safe fixed-string/JSON handling includes Python fallback without jq.

## [2.20.13] - 2026-02-19

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#22013---2026-02-19) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5545)

### Changed

- Codex guides use native spawn/wait/send/resume/close and its own state directory; setup ensures multi_agent and role defaults. `--claude` means implementation plus review, and conflicts with `--codex-review`.

### Fixed

- Claude review routing now matches that explicit delegation in both work and Breezing.

## [2.20.11] - 2026-02-19

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#22011---2026-02-19) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5570)

### Changed

- The Harness UI dashboard (`/harness-ui`, added in 2.12.0) leaves the distribution. Its assets, skills, templates, and hooks are no longer shipped, and session start no longer registers it.

### Fixed

- Issue #50: the 8 memory wrapper scripts with hardcoded absolute paths (`scripts/harness-mem*`, `scripts/hook-handlers/memory-*.sh`) are no longer shipped, and hooks and config no longer call them.

## [2.20.10] - 2026-02-18

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#22010---2026-02-18) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5585)

### Changed

- Codex setup defaults to user scope `${CODEX_HOME:-~/.codex}`; `--project` opts into project scope. Codex work uses Codex by default with explicit `--claude` delegation, and recovery state follows that routing.

## [2.20.9] - 2026-02-15

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2209---2026-02-15) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5607)

### Changed

- Codex-side second-review documentation consistently describes Claude CLI `claude -p` delegation.

## [2.20.8] - 2026-02-14

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2208---2026-02-14) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5623)

### Changed

- Recommended Claude Code version rises from 2.1.38+ to 2.1.41+. If you run Breezing through Bedrock, Vertex, or Foundry, 2.1.41+ is required because it fixes team model IDs there. 2.1.41+ also shows hook error output.
- Guides add `/rename` automatic session naming and `claude auth login`, `claude auth status`, and `claude auth logout` (Claude Code 2.1.41+). Compatibility notes extend through 2.1.42.

## [2.20.7] - 2026-02-14

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2207---2026-02-14) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5635)

### Fixed

- Replace the prompt-based Stop evaluator with a deterministic command that returns valid JSON, removing recurring model-output parse failures.

## [2.20.6] - 2026-02-14

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2206---2026-02-14) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5645)

### Fixed

- Broadcast hooks use the valid PostToolUse event name and suppress subprocess chatter from hook stdout.

## [2.20.5] - 2026-02-12

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2205---2026-02-12) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5656)

### Fixed

- `/breezing --codex` now spawns Codex implementers; before, the flag was ignored and the standard worker ran. The skill instructions forbid the lead from editing source in Codex mode. Standard mode keeps the standard worker. N implementers start together, where N = min(independent tasks, `--parallel N`, 3). Recovery after compaction restores the selected mode.

## [2.20.4] - 2026-02-11

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2204---2026-02-11) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5669)

### Fixed

- Harness messages and the `codex-review` skill refer only to `codex exec` (Codex CLI). Development-only skills are excluded from the Codex and OpenCode copies.

### Security

- A PreToolUse hook denies any `mcp__codex__*` tool call with an explanatory message, and the `codex-cli-only` rule forbids it, so the retired Codex MCP server cannot be used by accident. Use the Codex CLI (`codex exec`) instead.

## [2.20.3] - 2026-02-10

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2203---2026-02-10) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5686)

### Fixed

- Hook JSON uses proper encoding and data arguments instead of source interpolation. State directories use mode 700; idle events deduplicate within five seconds and JSONL rotates from 500 to 400 lines. Safe string matching/type conversion prevents parse and injection errors.

## [2.20.2] - 2026-02-10

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2202---2026-02-10) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5702)

### Added

- TeammateIdle and TaskCompleted hooks log team events to `.claude/state/breezing-timeline.jsonl`. Memory guidance separates Claude Code auto memory, Harness decisions and patterns, and agent memory; none replaces the others.

### Changed

- Version references move from Claude Code 2.1.30+ to 2.1.38+. Guidance covers team hooks, agent memory, fast mode, auto memory, skill-budget scaling (2% of the context window, 2.1.32+), and `Task(agent_type)` subagent restriction. The 500-line skill limit becomes a recommendation.

## [2.20.1] - 2026-02-10

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2201---2026-02-10) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5721)

### Fixed

- Repair post-write shell parsing and Python fallback stdin conflicts across ten hooks. Portable printf/string matching and bilingual warnings keep advisory hooks from stopping work on incidental errors.

## [2.20.0] - 2026-02-08

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2200---2026-02-08) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5734)

### Changed

- 28 skills become 19. `/memory` absorbs `/sync-ssot-from-memory` and `/cursor-mem`. `/setup` absorbs `/setup-tools`, `/harness-mem`, `/codex-setup`, `/2agent`, and `/localize-rules`. `/ci`, `/agent-browser`, and `/x-release-harness` no longer appear as slash commands (`user-invocable: false`); Claude can still load them automatically.
- Breezing runs in three phases: preparation keeps your permission mode, the middle phase limits the lead to task coordination, and the final phase lets the lead verify and commit.
- Teammates always run with `mode: "bypassPermissions"`, so they get no permission prompts. Protection relies on PreToolUse hooks, disallowed tools, spawn instructions, `.claude/rules/`, and lead monitoring. This fixes background teammates being auto-denied Bash ("prompts unavailable").
- GitHub release notes are written in English.

### Added

- The first `/codex-review` run checks Codex readiness once. On macOS without `timeout` or `gtimeout`, guides tell you to run `brew install coreutils`.

### Fixed

- Guard hooks parse JSON once, check symlinks, and no longer use `eval`. Codex commands use a portable timeout.

### Removed

- Merged skills move to `skills/_archived/`. Build output (including `mcp-server/dist/`), development notes, and lock files leave the repository.

## [2.19.0] - 2026-02-08

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2190---2026-02-08) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5787)

### Changed

- Five implementation commands become two: `/work` (Claude implements) and `/breezing` (team runs to completion). Both accept `--codex`, which at this release delegated implementation through Codex MCP, and both ask the same interactive scope question. `/work` picks a strategy by task count: 1 task directly, 2–3 in parallel, 4 or more iteratively. The state file becomes `work-active.json`; the old `ultrawork-active.json` is still read.

### Removed

- `/ultrawork` → use `/work all`. `/breezing-codex` → use `/breezing --codex`. `/codex-worker` → use `/work --codex`. The old skills move to `skills/_archived/`.

## [2.18.11] - 2026-02-06

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21811---2026-02-06) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5820)

### Added

- Breezing (team mode) v2 separates a coordinating lead, implementers, and an independent read-only reviewer. Hooks enforce reviewer read-only access and implementer file ownership per session. `--codex-review` adds Codex review. Completion reports include per-teammate metrics.
- Codex mode (`--codex`, recorded as `codex_mode: true` in `ultrawork-active.json`): Claude acts as manager, and every Edit/Write is blocked except Plans.md status-marker updates.

### Changed

- Codex review reads `decisions.md` and `patterns.md`, allows 2,500 instead of 1,500 output characters, and approves when critical and high findings are zero; low or medium findings alone no longer block.

## [2.18.10] - 2026-02-06

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21810---2026-02-06) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5857)

### Added

- Seven agents gain project/user persistent memory. Read-only reviewers/analyzers retain no Bash/Write/Edit; memory excludes secrets, personal data, and source snippets.

## [2.18.7] - 2026-02-05

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2187---2026-02-05) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5868)

### Changed

- Ordinary Git push no longer asks; force/force-with-lease still require confirmation.

## [2.18.6] - 2026-02-05

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2186---2026-02-05) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5876)

### Fixed

- Codex `harness.rules` (rules for command permissions) parse reliably. Safe checks such as `git clean -n` (preview untracked-file deletion) and `sudo -n true` (check sudo without an interactive prompt) no longer trigger needless permission questions. The Claude security template, `templates/claude/settings.security.json.template`, uses valid `:*` permission syntax (match command arguments) and prompts only on destructive variants.


## [2.18.5] - 2026-02-05

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2185---2026-02-05) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5889)

### Added

- The `gogcli-ops` skill guides Google Workspace CLI work on Drive, Sheets, Docs, and Slides, including sign-in, account selection, and converting URLs to IDs. It is read-only by default; writes ask for confirmation. This skill was later retired.

## [2.18.4] - 2026-02-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2184---2026-02-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5900)

### Added

- Set up the Codex CLI inside a session with `/codex-setup` or `/setup-tools codex`; `scripts/codex-setup-local.sh` handles project-local setup. `/harness-init` and `/harness-update` can optionally sync Codex CLI files. In 2.20.0, `/codex-setup` and `/setup-tools` were merged into `/setup`.

## [2.18.2] - 2026-02-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2182---2026-02-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5910)

### Added

- Codex CLI distribution includes skills, temporary rule-based guards, setup, and `$skill` instructions (invoke a skill by name), with package checks. Run `scripts/setup-codex.sh`; see `codex/README.md` for the setup steps.

### Changed

- README includes Codex CLI setup instructions.


## [2.18.1] - 2026-02-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2181---2026-02-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5925)

### Added

- Video generation adds Japanese speech providers: `aivis` (Aivis Cloud API, an external service; options such as `speaker_id` and `intonation_scale`) and `voicevox` (VOICEVOX character voices such as Zundamon). Sample speaker configurations are included.

### Changed

- The MCP server becomes optional: the plugin's `.mcp.json` is removed and `mcp-server` is not distributed, so installing the plugin no longer registers it. Set it up separately if you need it.

## [2.18.0] - 2026-02-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2180---2026-02-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5941)

### Added

- Claude Code 2.1.30 compatibility. Harness changes: troubleshooting routes complex session issues to `/debug`; the agent trace schema v0.3.0 records task token count, tool uses, and duration; notebookLM and review read PDFs by page range (`pages`); review, CI, and release use richer `git log` flags.
- Guidance for upstream Claude Code features: MCP OAuth with `--client-id` and `--client-secret` for servers without dynamic client registration, subagent MCP access (fixed in 2.1.30), about 68% lower memory with `--resume`, and the `reducedMotion` accessibility setting.

## [2.17.10] - 2026-02-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21710---2026-02-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5957)

### Added

- PreCompact and SessionEnd hooks save session state before compaction and clean up at session end. Agent trace schema v0.2.0 records which plugin made an edit. A sandbox settings template is provided as `templates/sandbox-settings.json.template`.

### Changed

- `deploy`, `generate-video`, `memory`, and `verify` run in a forked, isolated context.
- `/release` is renamed so it no longer clashes with Claude Code's built-in command. The v2.17.10 tag ships it as `/release-harness`; by 2.18.0 it is `/release-har`.

## [2.17.9] - 2026-02-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2179---2026-02-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5972)

### Changed

- New project config templates set `review.mode: codex`, so reviews in newly set-up projects go to Codex (OpenAI) by default; change `review.mode` to use another reviewer.
- `/ultrawork --codex` creates worktrees only when useful. A single task, fully sequential dependencies, or overlapping files run directly instead.

## [2.17.8] - 2026-02-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2178---2026-02-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5983)

### Fixed

- `/release` launches from the Skill tool again. Removing `disable-model-invocation: true` also means Claude can start the release skill on its own, not only when you type it.

## [2.17.6] - 2026-02-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2176---2026-02-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5992)

### Added

- Video scenarios use a JSON schema, semantic checks, and a template registry with path-traversal protection. Bilingual READMEs gain a short starting path.

### Changed

- Japanese descriptions are added to 28 skills and README organization is simplified.

### Fixed

- Scenario error filtering and slide_in transition names match the schema.

## [2.17.3] - 2026-02-03

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2173---2026-02-03) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6028)

### Added

- After `/harness-review`, `/ultrawork` repairs automatically until it approves, up to 3 retries, tracked in `ultrawork-retry.json`. REJECT or STOP halts immediately for manual action; after 3 retries it stops.
- All existing verification scripts run in priority order and stop at the first failure. Review reports include "How to Achieve A" guidance.

### Changed

- At this historical release, review switched to Codex automatically whenever Codex MCP was available, and otherwise fell back to parallel subagents. Set the timeout with `timeout_ms` (milliseconds).
- Changed-file counts use the merge base plus staged and unstaged changes; review aspects are chosen from file paths.

## [2.17.2] - 2026-02-03

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2172---2026-02-03) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6066)

### Added

- Codex worker completion finds and marks the matching task done; it asks if no task matches instead of silently dropping the update.

### Changed

- Worker scripts share common helpers and safer data handling.

## [2.17.1] - 2026-02-03

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2171---2026-02-03) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6089)

### Added

- Agent trace (an edit log) records edits made with `Edit`/`Write` in `.claude/state/agent-trace.jsonl`. The records feed session summaries, progress checks, and memory across sessions.

### Changed

- The session-end summary shows the project name, current task, and recent edits. Git status uses a five-second cache (reuse a saved result for five seconds).

### Fixed

- Trace writes enforce file permissions and check symlinks (links to another path). Log rotation is locked so concurrent updates do not lose records.


## [2.17.0] - 2026-02-03

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2170---2026-02-03) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6113)

### Added

- Codex Worker delegates implementation to OpenAI Codex: the `codex-worker` skill for one task, and `/ultrawork --codex` for parallel workers in git worktrees. Quality gates check evidence, lint and type-check, tests, and test tampering. File locks use TTL and heartbeat, and Plans.md is updated when a task completes.

### Changed

- Worker/reviewer routing uses explicit inclusion/exclusion rules to reduce accidental loading.

### Fixed

- Validate shell/Git/JSON inputs and portable whitespace patterns; arithmetic no longer exits unexpectedly under strict shell mode.

## [2.16.21] - 2026-02-03

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21621---2026-02-03) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6140)

### Changed

- The `/ultrawork` Codex options `--codex`, `--parallel`, and `--worktree-base` are marked as a design draft and do not work in this release. Related scripts and references are untracked drafts, not shipped features. 2.17.0 implemented `/ultrawork --codex`.

## [2.16.20] - 2026-02-03

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21620---2026-02-03) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6152)

### Changed

- Routing rules become one source, with deterministic Codex worker/reviewer selection.

## [2.16.19] - 2026-02-03

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21619---2026-02-03) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6161)

### Fixed

- Stop feedback emits concise keywords instead of duplicating the full reason.

## [2.16.17] - 2026-02-03

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21617---2026-02-03) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6169)

### Added

- Seventeen skills show argument hints in autocomplete, such as `/harness-review [code|plan|scope]` and `/troubleshoot [build|test|runtime]`. Hints only change what autocomplete shows. Sessions can notify each other.

### Changed

- Tests and guides follow the skills-only architecture.

## [2.16.14] - 2026-02-02

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21614---2026-02-02) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6191)

### Changed

- Implementation requests register in Plans.md automatically so progress includes ad-hoc work.

## [2.16.11] - 2026-02-02

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21611---2026-02-02) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6204)

### Changed

- Commands become skills; `/work`, `/harness-review`, and other names are unchanged. Internal skills such as `impl` and `verify` are hidden from the menu. Renamed: `dev-browser` → `agent-browser`, `docs` → `notebookLM`, `video` → `generate-video`. READMEs add troubleshooting and uninstall steps.

## [2.16.5] - 2026-01-31

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2165---2026-01-31) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6223)

### Added

- `/generate-video` adds AI-generated images (Nano Banana Pro, an external image service), royalty-free background music, Japanese subtitles, and effects such as GlitchText and Particles.

## [2.16.0] - 2026-01-31

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2160---2026-01-31) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6237)

### Changed

- Experimental: `/ultrawork` asks less often. `rm -rf` runs without a prompt only on paths approved in the plan; other paths still ask. Ordinary `git push` runs without a prompt during the run; force push still asks.

## [2.15.0] - 2026-01-26

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2150---2026-01-26) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6250)

### Added

- `/setup-opencode` configures OpenCode compatibility automatically, and the same skills work in both. This describes the historical compatibility mode, not current support parity.

## [2.14.0] - 2026-01-16

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2140---2026-01-16) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6263)

### Added

- `/work --full` can run tasks in parallel. `--parallel N` sets how many run at once; `--parallel 3` runs up to 3. Each worker reviews its own result.

## [2.13.0] - 2026-01-14

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2130---2026-01-14) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6276)

### Added

- Codex MCP review uses four parallel perspectives: security, quality, performance, and accessibility.

## [2.12.0] - 2026-01-10

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2120---2026-01-10) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6289)

### Added

- `/harness-ui` opens a browser dashboard for progress; it was removed from the distribution in 2.20.11. Browser automation handles page actions and screenshots; it shipped as `dev-browser` and was renamed `agent-browser` in 2.16.11.

## [2.11.0] - 2026-01-08

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2110---2026-01-08) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6298)

### Added

- Sessions can send and receive messages to each other. The `crud` command generates endpoints with Zod input validation.

## [2.10.0] - 2026-01-04

[Original technical record](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2100---2026-01-04) | [Source at original commit](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6307)

### Added

- Language-server definition/reference lookup and syntax-structure search support accurate code investigation.

## Earlier Versions

For 2.9.x and earlier, see [GitHub Releases](https://github.com/Chachamaru127/claude-code-harness/releases).

[Unreleased]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.16.0...HEAD
[5.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.15.0...v5.16.0
[5.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.14.1...v5.15.0
[5.14.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.14.0...v5.14.1
[5.14.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.13.2...v5.14.0
[5.13.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.13.1...v5.13.2
[5.13.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.13.0...v5.13.1
[5.13.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.12.0...v5.13.0
[5.12.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.11.0...v5.12.0
[5.11.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.10.0...v5.11.0
[5.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.9.0...v5.10.0
[5.9.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.8.0...v5.9.0
[5.8.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.7.0...v5.8.0
[5.7.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.6.0...v5.7.0
[5.6.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.5.0...v5.6.0
[5.5.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.4.0...v5.5.0
[5.4.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.3.1...v5.4.0
[5.3.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.3.0...v5.3.1
[5.3.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.2.0...v5.3.0
[5.2.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.1.0...v5.2.0
[5.1.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.0.0...v5.1.0
[5.0.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.4...v5.0.0
[4.16.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.3...v4.16.4
[4.16.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.2...v4.16.3
[4.16.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.1...v4.16.2
[4.16.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.0...v4.16.1
[4.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.15.0...v4.16.0
[4.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.14.0...v4.15.0
[4.14.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.3...v4.14.0
[4.13.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.2...v4.13.3
[4.13.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.1...v4.13.2
[4.13.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.0...v4.13.1
[4.13.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.11...v4.13.0
[4.12.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.10...v4.12.11
[4.12.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.9...v4.12.10
[4.12.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.8...v4.12.9
[4.12.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.7...v4.12.8
[4.12.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.6...v4.12.7
[4.12.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.5...v4.12.6
[4.12.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.4...v4.12.5
[4.12.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.3...v4.12.4
[4.12.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.2...v4.12.3
[4.12.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.1...v4.12.2
[4.12.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.0...v4.12.1
[4.12.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.4...v4.12.0
[4.11.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.3...v4.11.4
[4.11.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.2...v4.11.3
[4.11.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.1...v4.11.2
[4.11.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.0...v4.11.1
[4.11.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.10.0...v4.11.0
[4.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.9.0...v4.10.0
[4.9.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.8.1...v4.9.0
[4.8.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.8.0...v4.8.1
[4.8.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.7.0...v4.8.0
[4.7.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.6.1...v4.7.0
[4.6.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.6.0...v4.6.1
[4.6.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.4...v4.6.0
[4.5.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.3...v4.5.4
[4.5.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.2...v4.5.3
[4.5.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.1...v4.5.2
[4.5.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.0...v4.5.1
[4.5.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.4.0...v4.5.0
[4.4.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.3...v4.4.0
[4.3.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.2...v4.3.3
[4.3.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.1...v4.3.2
[4.3.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.0...v4.3.1
[4.3.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.2.0...v4.3.0
[4.2.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.1.1...v4.2.0
[4.1.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.1.0...v4.1.1
[4.1.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.4...v4.1.0
[4.0.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.3...v4.0.4
[4.0.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.2...v4.0.3
[4.0.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.1...v4.0.2
[4.0.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.0...v4.0.1
[4.0.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.17.1...v4.0.0
[3.17.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.17.0...v3.17.1
[3.17.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.16.0...v3.17.0
[3.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.15.0...v3.16.0
[3.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.14.0...v3.15.0
[3.10.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.10.2...v3.10.3
[3.10.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.10.1...v3.10.2
[3.10.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.10.0...v3.10.1
[3.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.9.0...v3.10.0
[3.9.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.2...v3.9.0
[3.7.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.1...v3.7.2
[3.7.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.0...v3.7.1
[3.7.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.6.0...v3.7.0
[3.4.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.0...v3.4.1
[3.4.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.1...v3.4.2
[3.5.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.2...v3.5.0
[3.4.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.3.1...v3.4.0
[3.3.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.3.0...v3.3.1
[3.3.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.2.0...v3.3.0
[2.26.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.26.0...v2.26.1
[2.26.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.25.0...v2.26.0
[2.25.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.24.0...v2.25.0
[2.24.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.6...v2.24.0
[2.23.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.5...v2.23.6
[2.23.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.3...v2.23.5
[2.23.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.2...v2.23.3
[2.23.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.1...v2.23.2
[2.23.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.0...v2.23.1
[2.23.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.22.0...v2.23.0
[2.22.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.21.0...v2.22.0
[2.21.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.13...v2.21.0
[2.20.13]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.11...v2.20.13
[2.20.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.10...v2.20.11
[2.20.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.9...v2.20.10
[2.20.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.8...v2.20.9
[2.20.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.7...v2.20.8
[2.20.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.6...v2.20.7
[2.20.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.5...v2.20.6
[2.20.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.4...v2.20.5
[2.20.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.3...v2.20.4
[2.20.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.2...v2.20.3
[2.20.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.1...v2.20.2
[2.20.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.0...v2.20.1
[2.20.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.19.0...v2.20.0
[2.19.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.11...v2.19.0
[2.18.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.10...v2.18.11
[2.18.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.7...v2.18.10
[2.18.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.6...v2.18.7
[2.18.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.5...v2.18.6
[2.18.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.4...v2.18.5
[2.18.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.2...v2.18.4
[2.18.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.1...v2.18.2
[2.18.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.0...v2.18.1
[2.18.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.10...v2.18.0
[2.17.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.9...v2.17.10
[2.17.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.8...v2.17.9
[2.17.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.6...v2.17.8
[2.17.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.3...v2.17.6
[2.17.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.2...v2.17.3
[2.17.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.1...v2.17.2
[2.17.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.0...v2.17.1
[2.17.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.21...v2.17.0
[2.16.21]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.20...v2.16.21
[2.16.20]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.19...v2.16.20
[2.16.19]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.17...v2.16.19
[2.16.17]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.14...v2.16.17
[2.16.14]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.11...v2.16.14
[2.16.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.5...v2.16.11
[2.16.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.0...v2.16.5
[2.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.15.0...v2.16.0
[2.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.14.0...v2.15.0
[2.14.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.13.0...v2.14.0
[2.13.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.12.0...v2.13.0
[2.12.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.11.0...v2.12.0
[2.11.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.0...v2.11.0
[2.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.24...v2.10.0
