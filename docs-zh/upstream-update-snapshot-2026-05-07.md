# Claude Code upstream snapshot - 2026-05-07

本 snapshot 确认了 Phase 56 / Phase 58 追従完毕的 `2.1.119`-`2.1.126` 以外的
**`2.1.112`-`2.1.118` 以及 `2.1.127`-`2.1.132`** (合计 13 版本)，
作为 Harness 的 Tier 1 5 件 + Tier 2 5 件实现的记录。

确认日：

- 2026-05-07 (Asia/Tokyo)

本地确认：

- `claude --version`: `2.1.132 (Claude Code)` 想定
- (CHANGELOG 从 GitHub 官方来源确认)

现有 Harness 的追従完毕点：

- Claude Code `2.1.119` (Phase 56)
- Claude Code `2.1.120`-`2.1.126` (Phase 58，部分实现在 Phase 62.2.x 完成)

一次信息：

- Claude Code GitHub CHANGELOG: <https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md>
- Claude Code docs CHANGELOG: <https://code.claude.com/docs/en/changelog>

分类：

- `A: 検証強化`: 在本次 Phase 62 中通过 snapshot / Feature Table / CHANGELOG / tests / 实现固定。
- `C: 自動継承`: 继承 Claude Code 本体的修正。不叠加 Harness wrapper。
- `B: 書いただけ`: **0 件** (本 snapshot 中不做 `B`)。全部署为 `A` 或 `C`。

## Version-by-version breakdown

| Version | Upstream item | 这样会更好 | Category | Harness surface | Harness action |
|---------|---------------|------------|----------|-----------------|----------------|
| Claude Code `2.1.112` | Auto mode for Opus 4.7 stability fix | Opus 4.7 在 auto mode 中短期 unavailable 不会发生 | C | runtime | 自动继承 |
| Claude Code `2.1.113` | Subagent stalling mid-stream fail after 10 minutes | Worker 冻结时的检测在 CC 侧确定为 600s timeout | A | `agents/worker.md`, `docs/team-composition.md` | Phase 62.1.1 中作为 2 层防御明文化 (CC 600s + elicitation-handler.sh) |
| Claude Code `2.1.113` | `sandbox.network.deniedDomains` setting | 可以在 session 级别 outbound network deny | A | `.claude-plugin/settings.json`, `templates/claude/settings.security.json.template` | Phase 62.1.4 中将 template baseline 扩展为 9 件 (追加 paste-site 系 6 件) |
| Claude Code `2.1.113` | deny rules match `env`/`sudo`/`watch` wrappers | CC 侧 deny wrapper bypass | A | `go/internal/guardrail/rules_test.go` | Phase 62.1.5 中将 R06/R11/R12 × 3 wrapper 的 9 案例固定为 fix posture |
| Claude Code `2.1.113` | `/private/{etc,var,tmp,home}` dangerous removal targets, `find -exec`/`-delete` not auto-approved | macOS 和基于 find 的移除安全性提升 | C | guardrail | 现有的 R05 helpers 已由 classifyBashProtectedWrite / hasDangerousFindDelete 覆盖 |
| Claude Code `2.1.114` | Permission dialog crash fix with agent teammate | breezing 更稳定 | C | runtime | 自动继承 |
| Claude Code `2.1.116` | `/resume` 67% faster on 40MB+ sessions | session resume 高速化 | C | session | 自动继承 |
| Claude Code `2.1.116` | `/reload-plugins` auto-installs missing dependencies | plugin lifecycle 更稳定 | C | plugin | 自动继承 |
| Claude Code `2.1.116` | Bash tool hints when `gh` hits rate limit | API rate limit 可见 | C | Bash runtime | 自动继承 |
| Claude Code `2.1.116` | Sandbox auto-allow bypasses dangerous-path check (security) | dangerous-path check 的双重触发消失 | C | sandbox | 自动继承 |
| Claude Code `2.1.117` | `CLAUDE_CODE_FORK_SUBAGENT=1` works in SDK and `claude -p` | 非对话中 fork subagent | P (Phase 58 已追従) | CI review docs | Phase 58 中已处理 |
| Claude Code `2.1.117` | Agent frontmatter `mcpServers` loaded for main-thread sessions | main-thread agent 中 MCP 也能工作 | C | agent runtime | 自动继承 (Harness 侧无需追加实现) |
| Claude Code `2.1.117` | `cleanupPeriodDays` covers `tasks/`, `shell-snapshots/`, `backups/` | session cleanup 覆盖范围更广 | C | maintenance | 自动继承 |
| Claude Code `2.1.117` | Default effort for Pro/Max on Opus/Sonnet 4.6 is `high` | Pro/Max 用户的既定行为 | C | runtime | 自动继承 |
| Claude Code `2.1.118` | `/cost` and `/stats` merged into `/usage` | 利用信息的入口统一 | C | session | 自动继承 |
| Claude Code `2.1.118` | Hooks can invoke MCP tools via `type: "mcp_tool"` | 可以从 hook 直接调用 MCP | A | `docs/hooks-mcp-tool-evaluation.md` | Phase 62.1.3 中 **采用判断: 保留**。固定再评估 trigger 3 项 |
| Claude Code `2.1.118` | Auto mode `"$defaults"` to extend built-in | 扩展既有 default | C | auto-mode runtime | Phase 53 中已处理 (auto mode policy doc) |
| Claude Code `2.1.118` | `claude plugin tag` for release tags | release flow 中集成 plugin tag | C | release | Phase 53 中已处理 (`harness-release` skill 已支持 tag) |
| Claude Code `2.1.118` | `DISABLE_UPDATES` env var | manual update 控制 | C | runtime | Phase 53 中已处理 (`docs/plugin-managed-settings-policy.md`) |
| Claude Code `2.1.127`-`2.1.128` | (no 2.1.127 release; 2.1.128 batch fixes) | runtime UX 改进 | C | UX | 自动继承 |
| Claude Code `2.1.128` | `--plugin-dir` accepts `.zip` plugin archives | plugin archive 读取灵活性提升 | C | plugin | 自动继承 |
| Claude Code `2.1.128` | `EnterWorktree` creates branch from local HEAD (not `origin/<default>`) | 防止意外的分支起点 | C | worktree | 自动继承 (与 Harness 的 WorktreeCreate hook 整合) |
| Claude Code `2.1.128` | MCP `workspace` reserved server name | MCP 名字冲突防止 | C | MCP | 自动继承 |
| Claude Code `2.1.128` | Sub-agent progress summaries fixes | 进度通知的重复·缺失减少 | C | agent | 自动继承 |
| Claude Code `2.1.129` | `--plugin-url <url>` for `.zip` plugin archives | remote plugin 获取 | C | plugin | 自动继承 |
| Claude Code `2.1.129` | `CLAUDE_CODE_FORCE_SYNC_OUTPUT=1`, `CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE` | 输出同步、auto-update 控制 | C | env | 自动继承 |
| Claude Code `2.1.129` | `skillOverrides` works with `off` / `user-invocable-only` / `name-only` | skill governance 的选择扩大 | A | `docs/skill-overrides-policy.md`, `tests/test-settings-baseline.sh` | Phase 62.2.5 中将 3 mode 的区分使用和推荐 default docs 化 |
| Claude Code `2.1.129` | OTel `claude_code.pull_request.count` for MCP-created PRs | PR creation telemetry 扩展 | C | telemetry | 自动继承 |
| Claude Code `2.1.129` | `Bash(mkdir *)` and similar allow rules now honored, `deniedMcpServers` mixed-case | permission rules 的一致性 | C | permissions | 自动继承 |
| Claude Code `2.1.131` | VS Code extension fix on Windows; Mantle endpoint auth fix | 企业稳定性 | C | enterprise runtime | 自动继承 |
| Claude Code `2.1.132` | `CLAUDE_CODE_SESSION_ID` env to Bash tool subprocess | 从 Bash 子进程直接获取 session ID | A | `docs/session-id-env-policy.md`, `tests/test-hook-handler-session-id.sh` | Phase 62.2.4 中将 4 路径的区分使用 policy docs 化，hook handlers 维持 stdin JSON 路径的 policy 由 test 固定 |
| Claude Code `2.1.132` | `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1` opt-out fullscreen | 可以关闭 terminal fullscreen | C | TUI | 自动继承 |
| Claude Code `2.1.132` | Various TUI / paste / vim / MCP / cache fixes | 细节稳定化 | C | runtime | 自动继承 |

## Phase 62 implementation summary

Tier 1 (Phase 62.1.1-62.1.5) — 直接强化 Harness 的弱点：

| Task | 实现 |
|------|------|
| 62.1.1 | Worker stall 2 层防御 (CC 600s + elicitation-handler) |
| 62.1.2 | 在 long-running skill 中活用 ENABLE_PROMPT_CACHING_1H opt-in (5 件 → 既有记载 + breezing/SKILL.md / long-running-harness.md 扩展) |
| 62.1.3 | hooks `type: "mcp_tool"` 采用判断 doc (= 保留) |
| 62.1.4 | `sandbox.network.deniedDomains` baseline 扩展 (template canonical 9 件，settings.json 为 user 手动) |
| 62.1.5 | R06/R11/R12 wrapper bypass test (env/sudo/watch × 3 = 9 案例) |

Tier 2 (Phase 62.2.1-62.2.5) — Phase 58 设计完毕的实现：

| Task | 实现 |
|------|------|
| 62.2.1 | `PostToolUse.updatedToolOutput` opt-in handler (allowlist 方式 + audit ledger) |
| 62.2.2 | agent permissionMode reaffirmation test (Phase 59.2.3 方针在 test 中固定) |
| 62.2.3 | `skill_activated.invocation_trigger` telemetry (local-only ledger + privacy-first) |
| 62.2.4 | `CLAUDE_CODE_SESSION_ID` env policy doc + test (4 路径的区分使用) |
| 62.2.5 | `skillOverrides` 3 mode governance doc |

Tier 3 (= `C: 自動継承`):

UI 改进·性能改进·OAuth fix·terminal/clipboard fix 等 Harness 侧无需变更。

## なぜ B: 書いただけ を 0 件にしたか

`.claude/rules/cc-update-policy.md` 中 `B: 書いただけ` 项目会被 merge 阻塞。
Phase 62 中将所有 upstream item 分类为以下之一：

- 实现或 test 追加 (`A`) — Tier 1 + Tier 2 的 10 task 对应
- CC 自动继承 (`C`) — UX / 性能 / fix 系
- 现有 Phase 中已处理 (Phase 53 / 56 / 58 等)

既不能实现也不能测试的 upstream item 作为 `C` (自动继承) 以 1 行理由固定。
由此防止"只在 Feature Table 中添加了行"的状态。

## User 手動操作 follow-up

`.claude-plugin/settings.json` 的 `sandbox.network.deniedDomains` 受 Harness self-protection
guardrail (`Edit/Write(.claude-plugin/settings*) deny`) 保护不会被 edit。
为了与 template (`templates/claude/settings.security.json.template`) 同步，
user 手动追加以下 6 件：

```json
"deniedDomains": [
  "169.254.169.254",
  "metadata.google.internal",
  "metadata.azure.com",
  "pastebin.com",     // 追加
  "transfer.sh",       // 追加
  "0x0.st",            // 追加
  "paste.ee",          // 追加
  "termbin.com",       // 追加
  "ix.io"              // 追加
]
```

`tests/test-settings-baseline.sh` 将不一致记录为 WARN (不是 FAIL，允许)，
输出催促 user 手动同步的消息。

## 関連 doc

- Phase 56 snapshot: `docs/upstream-update-snapshot-2026-04-25.md`
- Phase 58 snapshot: `docs/upstream-update-snapshot-2026-05-03.md`
- Phase 62 follow-up doc: 无 (本 snapshot 中实现完毕)
- Phase 62 task entries: `Plans.md` Phase 62.1.1-62.3.1
