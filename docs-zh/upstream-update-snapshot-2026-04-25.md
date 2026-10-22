# Claude Code / Codex upstream snapshot - 2026-04-25

本 snapshot 为 2026-04-25 时点的官方 upstream 确认记录，分解为应直接纳入 Claude Code Harness 的项目、以及仅自动继承 / 留作将来任务的项目。

确认日：

- 2026-04-25 (Asia/Tokyo)

一次信息：

- Claude Code docs changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code GitHub changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- OpenAI Codex releases: <https://github.com/openai/codex/releases>
- OpenAI Codex `rust-v0.124.0` release tag: <https://github.com/openai/codex/releases/tag/rust-v0.124.0>

确认对象：

- Claude Code `2.1.119`
- Codex `0.124.0` stable
- Codex `0.125.0-alpha.2` pre-release

分类：

- `A: 検証強化`: 不改变 Harness 的实现，在 snapshot / Feature Table / CHANGELOG / tests 中固定 upstream 追従判断。
- `C: 自動継承`: Claude Code / Codex 本体的改进直接继承。若叠加 Harness wrapper 会造成双重责任。
- `P: 将来タスク`: 本次不实现，但作为后续候选项留在 Plans。alpha 和规格未稳定的项目不做推测实现。

## Version-by-version breakdown

| Version | Upstream item | 这样会更好 | Category | Harness surface | Harness action |
|---------|---------------|------------|----------|-----------------|----------------|
| Claude Code 2.1.119 | `/config` settings persist to `~/.claude/settings.json` and join project/local/policy precedence | 本地的 theme / editor / verbose 设置重启后保留，managed settings 的优先顺序更容易理解 | P | setup / managed settings docs | 与 Phase 53 的 plugin-managed-settings policy 重复，纳入下次 setup docs 的 precedence 表整合 |
| Claude Code 2.1.119 | `prUrlTemplate` customizes footer PR badge URLs | 使用 GitHub Enterprise / GitLab / Bitbucket review URL 的团队更容易从 footer 跳转到正确的 review 页面 | P | review / release docs | 检查 GitHub 固定的 PR guidance，作为企业 git host 对应的后续候选 |
| Claude Code 2.1.119 | `--print` honors agent `tools:` and `disallowedTools:` frontmatter | CI / script 执行中也能更容易地使 interactive 相同的 tool 限制生效 | A | upstream snapshot / tests | 在 Phase 56 中记录 `--print` 的 frontmatter parity，作为将来 CI review runner 的 gate 候选 |
| Claude Code 2.1.119 | `--agent <name>` honors `permissionMode` for built-in agents | main-thread agent 执行中 built-in agent 的 permission 方针也更容易反映 | P | agents / permission docs | 与 Phase 53 的 `--agent` + `mcpServers` follow-up 一起留在 agents audit |
| Claude Code 2.1.119 | `PostToolUse` and `PostToolUseFailure` inputs include `duration_ms` | hook 侧可以测量 tool 执行时间，用于慢速处理的诊断 | P | hooks / session monitor | 纳入 Session Monitor 或 hook telemetry 的价值很高，但在改变现有 hook JSON shape 前作为独立 task 处理 |
| Claude Code 2.1.119 | OTEL `tool_result` / `tool_decision` include `tool_use_id`, and `tool_result` includes `tool_input_size_bytes` | 更容易将 trace 和 tool input size 关联 | P | telemetry docs | 处理 Harness telemetry 时的后续候选。现状不追加 schema wrapper |
| Claude Code 2.1.119 | Status line stdin JSON includes `effort.level` and `thinking.enabled` | 可以从 status line 显示思考强度或 thinking 状态 | P | statusline / session monitor | 纳入 Harness status line 的价值很高，但作为 UI 显示方针的独立 task |
| Claude Code 2.1.119 | Subagent and SDK MCP server reconfiguration connects servers in parallel; MCP OAuth / headers / client secret / env placeholder fixes | MCP 的重新配置和认证更稳定 | C | MCP runtime | 继承本体改进。不追加 Harness reconfiguration wrapper 或 OAuth workaround |
| Claude Code 2.1.119 | `blockedMarketplaces` correctly enforces `hostPattern` and `pathPattern` entries | managed marketplace policy 的漏洞减少 | C | managed settings | Phase 53 policy 的本体修正作为自动继承 |
| Claude Code 2.1.119 | Glob/Grep tools no longer disappear on native macOS/Linux when Bash is denied; auto mode no longer overrides plan mode | Bash deny / plan mode 下的行为更稳定 | C | permissions / search / Auto Mode | 继承本体修正。Harness 不放宽 Bash deny，也不增加 Auto Mode guidance |
| Codex 0.124.0 | TUI quick reasoning controls and model-upgrade reasoning reset | 可以从 TUI 快速调整 reasoning level，容易避免 model 变更时的旧 reasoning | C | Codex TUI | 作为本体 UX 自动继承。不改变 Harness skill frontmatter |
| Codex 0.124.0 | App-server sessions manage multiple environments and choose environment / working directory per turn | 更容易用同一 session 处理多个 workspace / remote environment | P | Codex workflow / branch policy | 作为 Phase 56 follow-up 切出 multi-environment branch/workdir policy |
| Codex 0.124.0 | First-class Amazon Bedrock support for OpenAI-compatible providers with AWS SigV4 auth | Codex 侧 Bedrock 利用更容易作为正式 provider 处理 | C | Codex provider docs | Phase 53 provider policy 以自动继承维持，必要时 docs refresh |
| Codex 0.124.0 | Remote plugin marketplaces can be listed and read directly | remote plugin source 的确认更容易 | P | plugin mirror policy | 作为 Harness plugin mirror / marketplace source policy 的后续候选 |
| Codex 0.124.0 | Hooks are stable, configurable inline in `config.toml` and managed `requirements.toml`, and can observe MCP tools, `apply_patch`, and long-running Bash | Codex 侧也可以建立 stable hook policy | P | Codex hooks / guardrails / tests | 与 Claude Code hooks 的 parity 作为独立 task 切出。不以推测修改 config.toml |
| Codex 0.124.0 | Eligible ChatGPT plans default to Fast service tier unless explicitly opted out | 适用 plan 的响应更快 | C | runtime UX | 作为本体 / plan 侧的行为自动继承。Harness 不固定 service tier |
| Codex 0.124.0 | Permission-mode drift, `wait_agent` queued mailbox timeout, relative stdio MCP command resolution, managed config startup edge cases | permissions / subagent wait / MCP startup / managed config 更稳定 | C | Codex runtime | 继承本体修正。不改变 Harness worker prompt 或 setup defaults |
| Codex 0.125.0-alpha.2 | Pre-release tag exists, release body is thin | 可以更早检测下一个 stable 将纳入的变更候选 | P | upstream watch | 不从 alpha 做推测实现。stable release 或有足够 release notes 时再确认 |

## Phase 56 follow-up candidates

| Follow-up | Why it matters | Suggested Plans owner |
|-----------|----------------|-----------------------|
| 検討是否将 Claude Code `PostToolUse.duration_ms` 纳入 Session Monitor / hook telemetry | 可以向 user-facing 说明慢 hook / tool 执行 | hooks / session monitor |
| 検討是否将 Claude Code status line `effort.level` / `thinking.enabled` 纳入 Harness status line | 可以将长时间工作中的"当前以什么强度思考"可视化 | statusline / session monitor |
| 整理 `prUrlTemplate` / `--from-pr` multi-host review support | 使 GitHub Enterprise / GitLab / Bitbucket 用户的 review 导径更自然 | harness-review / release |
| Codex `0.124.0` stable hooks 和 Claude Code hooks 的 parity review | 有可能将 Codex 侧的 stable hooks 活用于 guardrail / long-running Bash / MCP tool observation | Codex package / guardrails |
| Codex multi-environment app-server 和 branch/workdir policy | 可以减少多个 repo / worktree / remote environment 的混淆 | Codex workflow |

## Phase 56.2 closeout

Phase 56 的 follow-up decision 记录在 `docs/upstream-followups-phase56-2026-04-25.md`。

要点：

- `PostToolUse.duration_ms` 本次为 no-op，将 per-tool telemetry sink 留作独立 task
- `effort.level` / `thinking.enabled` 纳入 `scripts/statusline-harness.sh`，也保存在 statusline telemetry
- Codex stable hooks 只做 parity review，`codex/.codex/config.toml` 中只留 no-op 理由的 comment
- `prUrlTemplate` / `--from-pr` multi-host review 为 docs-only，维持 GitHub-first
- Codex multi-environment app-server 作为 workflow guidance，对 write 限制为每 turn 1 个 primary environment，采用 safe default 和 write guard

## B: 書いただけ 0 件的理由

- Feature Table 的 Phase 56 追加行全部连接到本 snapshot 和 Plans 的 Phase 56 task。
- 本次不改变分发 hook / settings / guardrail，将官方差异分为 `A: 検証強化`, `C: 自動継承`, `P: 将来タスク`。
- `A` 是"Phase 56 snapshot 和 upstream integration test 的验证强化"，不捏造实现。
- `P` 作为 Plans 中的后续 task 保留，从不稳定的 `0.125.0-alpha.2` 不做推测实现。

## No-op adaptation decision

本次为 no-op adaptation。

理由：

- Claude Code `2.1.119` 的大部分是本体 runtime / TUI / MCP OAuth / managed settings 的修正，Harness 若叠加 wrapper 容易产生双重责任。
- Codex `0.124.0` 的 stable hooks 价值高，但与 Claude Code hooks 的 config surface 不同。不立即向 `codex/.codex/config.toml` 追加 hook，作为 Codex hooks parity review 切出更安全。
- Pre-release 的 Codex `0.125.0-alpha.2` release body 很薄，不从 compare 推测规格实现。
