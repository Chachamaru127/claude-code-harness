# Claude Code / Codex upstream snapshot - 2026-05-03

本 snapshot 为 Phase 56 以后未处理的 upstream 确认记录，
分解为应立即纳入 Claude Code Harness 的项目、应计划化的项目、自动继承的项目。

确认日：

- 2026-05-03 (Asia/Tokyo)

本地确认：

- `claude --version`: `2.1.126 (Claude Code)`
- `codex --version`: `codex-cli 0.128.0`

现有 Harness 的追従完毕点：

- Claude Code `2.1.119`
- Codex `0.124.0` stable
- Codex `0.125.0-alpha.2` watch
- 详情: `docs/upstream-update-snapshot-2026-04-25.md`

一次信息：

- Claude Code docs changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code GitHub changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- OpenAI Codex releases: <https://github.com/openai/codex/releases>
- OpenAI Codex `rust-v0.125.0` release tag: <https://github.com/openai/codex/releases/tag/rust-v0.125.0>
- OpenAI Codex `rust-v0.128.0` release tag: <https://github.com/openai/codex/releases/tag/rust-v0.128.0>
- OpenAI Codex `rust-v0.128.0...rust-v0.129.0-alpha.2` compare: <https://github.com/openai/codex/compare/rust-v0.128.0...rust-v0.129.0-alpha.2>

分类：

- `A: 検証強化`: 在本次 snapshot / Feature Table / CHANGELOG / tests 中固定 upstream 追従判断。
- `C: 自動継承`: 继承 Claude Code / Codex 本体的修正。不叠加 Harness wrapper。
- `P: Plans 化`: 对 Harness 有使用价值，但本 snapshot PR 中不进行 runtime 实现，切为 Phase 58 task。

## Version-by-version breakdown

| Version | Upstream item | 这样会更好 | Category | Harness surface | Harness action |
|---------|---------------|------------|----------|-----------------|----------------|
| Claude Code `2.1.120` | Windows 中没有 Git Bash 时使用 PowerShell tool | Windows 初始环境中 Claude Code 的 shell 执行更容易成立 | P | Windows compatibility / setup docs | 与 Phase 57 的 Windows worktree fix 配合，在 Phase 58.2.3 中确认 PowerShell primary shell 前提的 docs/test |
| Claude Code `2.1.120` | `claude ultrareview [target]` 和 `--json` | 从 CI 或 script 调用 Claude Code review 更容易 | P | `harness-review` / CI docs | 不与 `/harness-review` 竞争，在 Phase 58.2.3 中保留 non-interactive review input 和 JSON stdout contract 的比较 |
| Claude Code `2.1.120` | Skills can reference `${CLAUDE_EFFORT}` | skill 正文可以感知当前的 effort | P | skills / prompt guidance | 在 Phase 58.2.3 中确认 Harness skills 中放入 effort 条件分支的价值 |
| Claude Code `2.1.120` | `AI_AGENT` env for subprocesses | 在 `gh` 等外部 CLI 中更容易做 agent traffic attribution | C | CLI runtime | Harness 侧不增加 env wrapper，继承本体 |
| Claude Code `2.1.120` | `claude plugin validate` accepts additional schema fields | marketplace / plugin validation 的允许范围扩大 | P | plugin validation / release docs | 在 Phase 58.2.3 中重新审视 `.claude-plugin/marketplace.json` 和 `plugin.json` 的 validation guidance |
| Claude Code `2.1.120` | telemetry disable, false dangerous-rm prompt, Bash `find` fd exhaustion fixes | 现有操作更稳定，误检测和 host-wide crash 减少 | C | permissions / Bash runtime | Harness 不追加 wrapper，继承本体修正 |
| Claude Code `2.1.121` | `PostToolUse` hooks can replace output for all tools via `hookSpecificOutput.updatedToolOutput` | hook 可处理的 tool 输出 redaction / compaction / normalization 范围扩大 | P | hooks / telemetry / output governance | 既定不修改 tool output，在 Phase 58.2.2 中切出 opt-in 的 redaction / compaction 和 audit trail 设计 |
| Claude Code `2.1.121` | `--dangerously-skip-permissions` no longer prompts for writes to `.claude/skills/`, `.claude/agents/`, `.claude/commands/` | dangerous skip mode 的 UX 变快，但对 Harness 的 skill / agent / command integrity 有影响 | P | guardrail / protected paths / tests | 在 Phase 58.2.1 中将 protected path 的分类硬化为即使在 `dangerously-skip` 前提下也应守护的内容 |
| Claude Code `2.1.121` | MCP `alwaysLoad`, startup retry, `mcp_authenticate.redirectUri`, `claude plugin prune` | MCP / plugin 的启动和 cleanup 更稳定 | P | setup / MCP docs / plugin lifecycle | 将常驻加载的 MCP 和 deferred 的边界、plugin prune 的安全导径留到 Phase 58.2.3 |
| Claude Code `2.1.121` | `CLAUDE_CODE_FORK_SUBAGENT=1` works in SDK and `claude -p` | 非对话 session 中也更容易使用 fork subagent | P | CI review / agent docs | 在 Phase 58.2.3 中确认与 Harness 的 CI / headless review runner 的相性 |
| Claude Code `2.1.122` | `ANTHROPIC_BEDROCK_SERVICE_TIER` | Bedrock 利用时可选择 `default` / `flex` / `priority` | P | provider setup docs | 不与 Codex provider policy 混淆，作为 Claude Code Bedrock setup guidance 留到 Phase 58.2.3 |
| Claude Code `2.1.122` | `/resume` PR URL search for GitHub Enterprise / GitLab / Bitbucket | 更容易从 PR URL 找到关联 session | P | review / session docs | 连接到 Phase 56 的 multi-host docs-only 方针，维持 automation 的 GitHub-first |
| Claude Code `2.1.122` | OpenTelemetry numeric attrs and `claude_code.at_mention` | telemetry schema 更易于机器处理 | P | telemetry docs | 与 skill activation telemetry 配合，在 Phase 58.2.3 中确认 schema drift |
| Claude Code `2.1.122` | malformed hooks entry no longer invalidates entire settings file | 设置的一部分损坏不容易导致整体无效 | C | hooks / settings runtime | Harness 的 settings generator 继续输出有效 JSON。继承本体修正 |
| Claude Code `2.1.123` | OAuth 401 retry loop fix when `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` | 登录失败循环减少 | C | auth runtime | Harness 无需变更 |
| Claude Code `2.1.126` | `claude project purge [path]` | 可以批量删除 transcripts / tasks / file history / config entry | P | cleanup / maintenance docs | 以 `--dry-run` 为前提，切出与 Harness state cleanup 不混合的安全步骤到 Phase 58.2.3 |
| Claude Code `2.1.126` | `--dangerously-skip-permissions` bypasses writes to `.claude/`, `.git/`, `.vscode/`, shell config files, and other protected paths | dangerous skip mode 变得更强，但需要明文化 Harness 的安全边界 | P | guardrail / protected paths / permission docs | 在 Phase 58.2.1 中设计·实现 `.claude/`、`.git/`、`.vscode/`、shell config files 的 deny / ask / warn 边界 |
| Claude Code `2.1.126` | Security fix for `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` precedence | managed sandbox policy 的漏洞减少 | P | settings security consistency | 在 Phase 58.2.1 中通过 Harness settings / template / consistency check 重新确认 managed sandbox 边界 |
| Claude Code `2.1.126` | `claude_code.skill_activated` includes `invocation_trigger` and user slash command activation | 从 telemetry 更容易区分 skill 的启动路径 | P | telemetry / skill analytics | 在 Phase 58.2.3 中検討是否纳入 Harness skill usage analysis |
| Claude Code `2.1.126` | gateway `/v1/models` model picker, OAuth code paste, PowerShell 7 detection, deferred tools for forked skills/subagents | gateway / Windows / fork context 的 runtime 更稳定 | C/P | setup / Windows / agents | 基本自动继承。只将 Windows / forked skill guidance 所需内容在 Phase 58.2.3 中 docs 化 |
| Codex `0.125.0` stable | App-server Unix socket, sticky environments, remote thread config/store, pagination-friendly resume/fork | app-server / remote environment 的 session 管理变强 | P | Codex workflow / app-server docs | 维持 Phase 56 的 one primary environment policy，在 Phase 58.3.2 中整理 sticky environment |
| Codex `0.125.0` stable | Remote plugin install and marketplace upgrade | Codex 侧的 plugin lifecycle 变得实用 | P | Codex plugin setup / marketplace docs | 在 Phase 58.3.2 中切出与 Harness plugin mirror policy 不冲突的导径 |
| Codex `0.125.0` stable | Permission profiles round-trip across TUI, user turns, MCP sandbox state, shell escalation, app-server APIs | 更容易在多个 surface 维持 permission state 的一致性 | P | `codex/.codex/config.toml` / requirements / sandbox docs | 在 Phase 58.3.1 中整理 current config 和 profile-based policy 的差异 |
| Codex `0.125.0` stable | `codex exec --json` reports reasoning-token usage | 程序化 consumer 可以看到 reasoning token | P | codex loop telemetry / reports | 在 Phase 58.3.1 中検討是否纳入 `harness-loop` / breezing 的 usage report |
| Codex `0.125.0` stable | Rollout tracing records tool, code-mode, session, and multi-agent relationships | multi-agent 执行的 trace 更易于阅读 | P | agent trace / diagnostics | 在 Phase 58.3.1 中确认是否与 existing AgentTrace 整合 |
| Codex `0.128.0` stable | Persisted `/goal` workflows | 可以创建·暂停·恢复·清除 goal | P | Plans / goal workflow | 在不与 `Plans.md` SSOT 重复化的前提下作为 Phase 58.3.2 的候选保留 |
| Codex `0.128.0` stable | `codex update`, configurable keymaps, plan-mode nudges, `/statusline` and `/title` during active turns | Codex TUI 的长时间工作 UX 提升 | P | Codex setup / loop docs | 在 Phase 58.3.1 中将 setup docs 和 long-running status guidance 更新候选 |
| Codex `0.128.0` stable | Built-in permission profiles, sandbox CLI profile selection, cwd controls, active-profile metadata | 可以转向显式 permission profile | P | Codex config / sandbox / `--full-auto` deprecation | 在 Phase 58.3.1 中切出从 `--full-auto` 向显式 profile 的迁移 |
| Codex `0.128.0` stable | Plugin workflows: marketplace install, remote bundle caching/uninstall, plugin-bundled hooks, hook enablement state, external-agent config import | plugin 和 hook 的分发·启用 state 变得丰富 | P | Codex plugin / hooks / setup docs | 重新评估 Phase 56 的 no-inline-hooks 方针，在 Phase 58.3.2 中比较 plugin-bundled hooks |
| Codex `0.128.0` stable | MultiAgentV2 thread caps, wait-time controls, root/subagent hints, depth handling | multi-agent 実行的控制变得更细 | P | breezing / codex agents config | 在 Phase 58.3.2 中验证 `agents.max_threads` 和 MultiAgentV2 config 的关系 |
| Codex `0.128.0` stable | Managed network hardening, Bedrock `apply_patch`, MCP/plugin cleanup | network / provider / MCP 周边的故障减少 | P/C | guardrails / provider docs | 不在 Harness 中双重化，只将必要的 config docs 和 tests 切到 Phase 58.3.1 |
| Codex `0.128.0` stable | `--full-auto` deprecated in favor of explicit permission profiles and trust flows | permission 的意图更明确 | P | Codex docs / setup scripts | 在 Phase 58.3.1 中盘点旧的 `--full-auto` guidance |
| Codex `0.129.0-alpha.2` pre-release | alpha body is thin; compare shows hooks browser, workspace plugin sharing, MCP output truncation, apply_patch streaming, sandbox/app-server changes | 可以更早把握下一个 stable 的方向 | P | upstream watch | 不从 alpha 做推测实现。stable release 或有详细 release notes 时再确认 |

## Phase 58 follow-up candidates

详细 follow-up decisions: `docs/upstream-followups-phase58-2026-05-03.md`

| Follow-up | Why it matters | Suggested Plans owner |
|-----------|----------------|-----------------------|
| Claude protected-write 和 `dangerously-skip` hardening | 2.1.121 / 2.1.126 中 skip mode 的 protected write bypass 范围扩大了，需要重新定义 Harness 的 deny / ask / warn 边界 | 58.2.1 |
| `PostToolUse.updatedToolOutput` output governance | 全 tool output 可以通过 hook 替换了，在便利性之前先固定 opt-in / audit / no-default-mutation | 58.2.2 |
| Claude setup / MCP / telemetry refresh | `alwaysLoad`、`plugin prune`、Bedrock service tier、project purge、skill activation telemetry 对 setup guidance 有效 | 58.2.3 |
| Codex permission profiles 和 `--full-auto` migration | 0.125.0 / 0.128.0 中 profile-backed permission 成为中心，需要盘点 Harness Codex docs 的旧 flag guidance | 58.3.1 |
| Codex plugin hooks、`/goal`、MultiAgentV2、app-server updates | 0.128.0 的 plugin/hook/workflow surface 变化很大，需要不与 Plans SSOT 重复化的设计 | 58.3.2 |

## B: 書いただけ 0 件的理由

- Feature Table 只添加 Phase 58 的汇总行，连接到本 snapshot 和 `Plans.md` 的 `58.1.1`-`58.3.2`。
- 本次的 runtime 实现对象，不以推测做临时实现，而是作为带 DoD 的 task 分解为 `P: Plans 化`。
- `A` 作为 Phase 58 snapshot / upstream integration test 的验证强化对待。
- `C` 明记继承 Claude Code / Codex 本体 bug fix 的理由。
- Codex `0.129.0-alpha.2` 是 alpha，不从 compare 推测规格实现。

## No-op adaptation decision for this snapshot

本 snapshot 本身为 no-op adaptation。

理由：

- Claude Code `2.1.121` / `2.1.126` 的 permission 变更很重要，但立即 deny `.claude/` 整体可能会破坏 rules / memory / setup 更新。先在 Phase 58.2.1 中切出 protected path taxonomy。
- `PostToolUse.updatedToolOutput` 很强大，但既定修改 tool output 会降低 debugability。先在 Phase 58.2.2 中设计 opt-in 和 audit trail。
- Codex `0.128.0` 的 permission profiles / plugin hooks 价值高，但刚在 Phase 56 中放置了 no-inline-hooks 方针，在 Phase 58.3.x 中划分 profile-backed policy 和 plugin-bundled hooks 的责任。
- `0.129.0-alpha.2` 是 pre-release，release body 很薄，watch 停留到 stable。
