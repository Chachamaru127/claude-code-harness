# Claude Code / Codex upstream snapshot - 2026-04-21

本 snapshot 为 2026-04-21 时点的官方 upstream 确认记录，按直接采纳 / 自动继承 / Plans 化分类。

一次信息:

- Claude Code changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- Claude Code docs changelog: <https://code.claude.com/docs/en/changelog>
- OpenAI Codex releases: <https://github.com/openai/codex/releases>

## Version-by-version breakdown

| Version | Upstream item | Category | Harness surface | Action |
|---------|---------------|----------|-----------------|--------|
| Claude Code 2.1.116 | Large-session `/resume` is faster and handles dead-fork entries more efficiently | C | session resume/fork UX | Harness 的 session-control 变更不需要。大容量 transcript 的 resume guidance 与之不矛盾 |
| Claude Code 2.1.116 | MCP startup defers `resources/templates/list` until first `@` mention | C | MCP / `@` mention guidance | Harness 侧的 MCP setup 不变。将来做 MCP health watch 时以 deferred startup 为前提 |
| Claude Code 2.1.116 | `/reload-plugins` and background auto-update install missing marketplace dependencies | P | plugin setup / marketplace docs | Plugin dependency policy 的说明和 setup smoke 留待后序 review。现在不在 Harness 上叠加 dependency resolver |
| Claude Code 2.1.116 | Sandbox auto-allow no longer bypasses dangerous-path safety for `rm` / `rmdir` | C | guardrail / Bash safety | 与 Phase 51 的 R05 guardrail 同方向。Harness 侧维持现有 test，自动继承 CC 本体修复 |
| Claude Code 2.1.116 | Agent frontmatter `hooks:` fire for main-thread agents via `--agent` | P | agents / skills docs | 保留给后序 audit：Harness agents 在 `--agent` main-thread execution 中是否有 hook 前提 |
| Claude Code 2.1.116 | Bash tool shows GitHub API rate-limit hints for `gh` commands | P | ci / release / review skills | `gh` retry/backoff guidance 作为 CI / release skills 的候选。这次不实现，Plans 化 |
| Codex 0.122.0 | `/side` conversations and queued slash / `!` shell prompts while work is running | P | long-running work guidance | 可用于 Harness loop / breezing 的"作业中的横向提问"UX。与 Codex-native skill audit 一同处理 |
| Codex 0.122.0 | Plan Mode can start implementation in a fresh context with context usage shown | P | `/plan-with-agent` / `/work --codex` handoff | 与 Plan -> Work 的 context carry policy 比较。暂不改变 Harness 的 phase model |
| Codex 0.122.0 | Plugin workflows add tabbed browsing, toggles, marketplace removal, remote/cross-repo/local sources | P | plugin mirror / setup policy | 留待后序整理 Harness plugin mirror policy 和 marketplace source policy |
| Codex 0.122.0 | Filesystem permissions add deny-read glob, managed deny-read, platform sandbox enforcement, isolated `codex exec` | P | sandbox / guardrail | 与 Claude 侧 `sandbox.network.deniedDomains` 是不同轴。作为 Codex mirror 的 sandbox policy 留待后序比较 |
| Codex 0.122.0 | Tool discovery and image generation default-on, higher-detail image handling | P | Codex mirror skill metadata | 留在 allowed-tools / image skill / tool discovery guidance 的 drift audit |
| Codex 0.122.0 | App-server stale prompt dismissal and resume/fork token usage replay | C/P | session resume / heartbeat | Codex 本体 UX 自动继承。确认 Harness heartbeat / resume summary 与之是否重复 |
| Codex 0.123.0-alpha.2 | Pre-release with thin release body | P | future compare | 不从 release body 推测实现。等 stable 化或 release notes 变厚时再确认 |

## UX judgement

这次几乎没有需要直接实现到 Harness 的 upstream 功能。Phase 51 已实现 `AskUserQuestion.updatedInput` 和 Claude 2.1.113 hardening，因此 2.1.116 / Codex 0.122.0 是"检查是否与现有实现矛盾"或"留给后序 setup / Codex-native skill audit"的版本，这样比较安全。

不直接实现的原因:

- Claude 2.1.116 的大部分是 Claude Code 本体的 TUI / resume / plugin updater 改进，Harness 叠加 wrapper 会制造行为差异或双重责任。
- Codex 0.122.0 的 plugin workflow / filesystem permission / Plan Mode 等较大设计变更，与现有 Phase 51.2 的 Codex-native skill audit 同时处理更易管理依赖关系。
- Codex 0.123.0-alpha.2 是 pre-release 且 release body 很薄，不从 compare 推测实现。

## Follow-up candidates

- 将 Codex plugin marketplace source policy 和 Harness mirror policy 的整合方案与 Phase 51.2.3 一同整理。
- 判断是否向 CI / release / review skills 添加 `gh` rate-limit hint 的 retry/backoff 方针。
- 确认是否将 `--agent` main-thread hooks 的行为反映到 Harness agents 的 frontmatter policy。
- 制作 Codex deny-read glob / isolated `codex exec` 与 Harness sandbox / guardrail policy 的差异表。
