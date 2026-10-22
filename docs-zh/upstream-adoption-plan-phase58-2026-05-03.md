# Phase 58 Upstream Adoption Plan - 2026-05-03

本文档为决定 Claude Code `2.1.120`-`2.1.126` 和 Codex `0.125.0` / `0.128.0` 的更新如何
在 Claude Code Harness 中活用的采用计划。

## 一句话概括

Phase 58 是不直接添加 Claude / Codex 的新功能，而是翻译成符合 Harness 安全边界、审查记录、Codex 并行运用的形式后再导入。

## 打个比方

新工具到货了。
区分立刻投入使用、加保护盖、放在架子上三种情况。

## 公式信息

- Claude Code changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code GitHub changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- Codex `rust-v0.125.0`: <https://github.com/openai/codex/releases/tag/rust-v0.125.0>
- Codex `rust-v0.128.0`: <https://github.com/openai/codex/releases/tag/rust-v0.128.0>

## 采用菜单

### 🛡️ A. Claude protected-write hardening

活用的更新：

- Claude Code `2.1.121`: 对 `.claude/skills/`、`.claude/agents/`、`.claude/commands/` 的 write prompt bypass 范围发生变化。
- Claude Code `2.1.126`: `.claude/`、`.git/`、`.vscode/`、shell config files 等的 protected path bypass 范围扩大。
- Claude Code `2.1.126`: `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` precedence 修正。

既存実装：

- `go/internal/guardrail/helpers.go` 将 `.git/`、`.env`、secret keys、`.husky/` 等作为 protected path 处理。
- `go/internal/guardrail/rules.go` deny 保护 path 写入的 `Write/Edit/MultiEdit`，也 deny Bash 重定向的 `.env/.git/key` 写入。
- `templates/claude/settings.security.json.template` 拥有 `.claude/settings*` 和 `.claude-plugin/settings*` 的 deny。

不足：

- 没有 `.claude/skills`、`.claude/agents`、`.claude/commands`、`.vscode`、shell rc/profile files 的分类。
- 没有将 `.claude/rules`、`.claude/memory`、setup metadata 分类为 warn 的。
- 没有检测通过 Bash `tee` / 重定向向 `.claude/*`、`.vscode/*`、shell config files 写入的用例。
- 没有在 `harness.toml` / settings / template / CI 中验证 managed sandbox 边界。

不竞争的使用方式：

- 不整体 deny `.claude/`。
- 区分 deny / ask / warn。
- 不在 `PermissionRequest` 而在 `PreToolUse` guardrail 侧阻止。
- 即使在 `WorkMode` 也不缓和 protected path 规则。

採用判断：

- ✅ 导入推荐。
- 最先放入。
- 成为事故防止的基础。

実装計画：

1. 在 `go/internal/guardrail/helpers.go` 中追加 protected path taxonomy。
2. deny: `.git/`、secrets、shell rc/profile files、destructive hook entrypoints。
3. ask: `.claude/skills/`、`.claude/agents/`、`.claude/commands/`、`.vscode/`。
4. warn: `.claude/rules/`、`.claude/memory/`、setup metadata。
5. 在 `go/internal/guardrail/rules.go` 中共通化 `Write/Edit/MultiEdit` 和 Bash write 的分类。
6. 在 `scripts/ci/check-consistency.sh` 中验证 managed sandbox 边界。
7. 在 `tests/test-claude-upstream-integration.sh` 中追加 Phase 58.2.1 实现检测。

検証：

- `go test ./go/internal/guardrail/...`
- `bash tests/test-claude-upstream-integration.sh`
- `bash scripts/ci/check-consistency.sh`
- `./tests/validate-plugin.sh`

### ✂️ B. PostToolUse `updatedToolOutput` output governance

活用的更新：

- Claude Code `2.1.121`: `PostToolUse` hooks can replace output for all tools via `hookSpecificOutput.updatedToolOutput`。

既存実装：

- `go/pkg/hookproto/types.go` 的 `PostToolHookSpecific` 只有 `hookEventName` 和 `additionalContext`。
- `harness hook post-tool` 只在有警告时返回 `additionalContext`。
- shell hooks 也以 `additionalContext` 为中心，不替换 tool output。

不足：

- 没有 `updatedToolOutput` 类型。
- 没有保持 `tool_response`、`tool_use_id`、`duration_ms` 的输入。
- 没有 before / after / audit record 的模型。
- 没有不消除 review / test / lint 证据的机器测试。

不竞争的使用方式：

- 既定不修改 tool output。
- 仅 opt-in。
- 允许用途限定为 secret redaction、长大输出 compaction、machine-readable normalization。
- 禁止用途为删除 review / test / lint / error evidence。
- stdout 仅为 JSON 契约，不混合对人说明。

採用判断：

- 🟡 先设计后导入。
- 实现在 A 之后。
- 虽然便利但容易破坏证据。

実装計画：

1. 追加 `docs/output-governance.md`。
2. 在 `go/pkg/hookproto` 中追加 `ToolResponse`、`ToolUseID`、`DurationMS`、`UpdatedToolOutput`。
3. 设计 `HARNESS_OUTPUT_GOVERNANCE=redact|compact|normalize` 这样的 opt-in。
4. 集中到单一的同步 PostToolUse mutation handler。
5. 在 `.claude/state/output-governance.jsonl` 中记录 original hash / updated hash / policy / reason。
6. 在测试中固定 test failure / review finding / lint error 为禁止替换。

検証：

- no-default-mutation test
- Bash secret redaction shape test
- review/test failure output non-mutation test
- audit record test
- stdout JSON-only test
- `bash tests/test-claude-upstream-integration.sh`

### 🧭 C. Claude setup / MCP / telemetry / provider guidance

活用的更新：

- `claude ultrareview [target] --json`
- `${CLAUDE_EFFORT}`
- `claude plugin validate` schema acceptance
- MCP `alwaysLoad`
- `claude plugin prune`
- `ANTHROPIC_BEDROCK_SERVICE_TIER`
- `claude project purge`
- `claude_code.skill_activated.invocation_trigger`
- Windows PowerShell primary shell
- forked skills/subagents deferred tools

既存実装：

- `/ultrareview` 有不在 Harness flow 内调用的方针。
- `claude plugin validate` 在 `tests/validate-plugin.sh` 中执行。
- 有 Codex MCP / provider guidance。
- Windows docs 以 Git Bash / MSYS / Cygwin / WSL2 为中心。

不足：

- `claude ultrareview --json` 和 Harness `review-result.v1` 的边界未更新。
- 没有 `${CLAUDE_EFFORT}` 用于 skill tuning 的方针。
- 没有 Claude Code MCP `alwaysLoad` 和 deferred discovery 的区分使用。
- 没有 `plugin prune` 的安全导径。
- Claude Code Bedrock service tier guidance 未与 Codex provider docs 分离。
- `project purge` 和 Harness state cleanup 的区别未整理。
- docs 中没有 PowerShell primary shell route。

不竞争的使用方式：

- 不混淆 Claude Code MCP 和 Codex MCP docs。
- `ANTHROPIC_BEDROCK_SERVICE_TIER` 仅限 Claude Code provider guidance。
- `plugin prune` 不引导不存在的 dry-run，先放事前确认步骤。
- `ultrareview --json` 不作为 `/harness-review` 的替代，而是作为 CI second-opinion 候选。

採用判断：

- ✅ 作为 docs / setup 更新导入推荐。
- 不增加 runtime wrapper。

実装計画：

1. 追加 `docs/claude-code-setup-mcp-telemetry-provider.md`。
2. 在 `docs/ultrareview-policy.md` 和 `skills/harness-review/SKILL.md` 中追记 `claude ultrareview --json` 的边界。
3. 在 `docs/effort-level-policy.md` 中追记 `${CLAUDE_EFFORT}` 的限定用途。
4. 在 `skills/harness-setup/SKILL.md` 中追加 MCP `alwaysLoad` 和 deferred discovery 的区分使用。
5. 在 `docs/plugin-managed-settings-policy.md` 中追加 `plugin validate` / `plugin prune` 的安全导径。
6. 将 Claude Code Bedrock service tier guidance 从 Codex provider policy 分离追加。
7. 在 compatibility docs 中追加 PowerShell primary shell route。

検証：

- `bash tests/test-claude-upstream-integration.sh`
- `./tests/validate-plugin.sh`
- docs grep gate: `alwaysLoad`、`CLAUDE_EFFORT`、`plugin prune`、`ANTHROPIC_BEDROCK_SERVICE_TIER`、`project purge`、`invocation_trigger`、`PowerShell`、`deferred tools`

### 🔐 D. Codex permission profiles / `--full-auto` migration

活用的更新：

- Codex `0.125.0`: permission profiles round-trip across TUI, user turns, MCP sandbox state, shell escalation, app-server APIs。
- Codex `0.125.0`: `codex exec --json` reasoning-token usage。
- Codex `0.125.0`: rollout tracing records tool, code-mode, session, and multi-agent relationships。
- Codex `0.128.0`: built-in permission profiles, sandbox CLI profile selection, cwd controls, active-profile metadata。
- Codex `0.128.0`: `--full-auto` deprecated in favor of explicit permission profiles and trust flows。

既存実装：

- Phase 58 snapshot / follow-up / Plans 中有记录。
- `codex/.codex/config.toml` 拥有 no-inline-hooks 方针和 agent sandbox。
- `docs/codex-sandbox-execution-policy.md` 处理 0.123 系的 sandbox policy。

不足：

- 没有 permission profile / trust flow 的正本 docs。
- `scripts/codex/codex-exec-wrapper.sh` 中残留 `--full-auto`。
- `scripts/codex-loop.sh` 的 local worker 中残留 `--dangerously-bypass-approvals-and-sandbox`。
- `codex exec --json` reasoning token usage 没有保存先。
- 没有 rollout trace 和 existing AgentTrace 的重复整理。
- `scripts/check-codex.sh` 仍是 `npm update -g @openai/codex` guidance。

不竞争的使用方式：

- 不在新规 docs 的 default 中增加 `--full-auto`。
- 实现前用 `codex exec --help` 确认现行 flag。
- `requirements.toml` 作为 org-managed policy 的放置场所，不在配布 default 中推测放入。
- 明文化 `approval_policy: never` / `sandbox: workspace-write` 的现有 worker setup 和 permission profiles 的关系。

採用判断：

- ✅ 导入推荐。
- 但 flag 替换先用 help / smoke test 确认后。
- 在 A 之后第二重要。

実装計画：

1. 追加 `docs/codex-permission-profiles-policy.md`。
2. 更新 `codex/README.md` 和 `codex/.codex/skills/harness-setup/SKILL.md` 到 profile 方针。
3. 将 `--full-auto` 移为 legacy fallback。
4. 将 wrapper / loop 的 flag 迁移到显式 profile 或显式 sandbox/trust flow。
5. 追加 `codex exec --json` reasoning usage 保存到 job result 的设计。
6. 制作 rollout trace 不与 `.claude/state/agent-trace.jsonl` 重复计算的 mapper 方针。

検証：

- `bash tests/test-codex-package.sh`
- `bash tests/test-codex-loop-cli.sh`
- 用 fake `codex` 测试 `--json` reasoning usage 保存
- wrapper flag test
- `bash tests/test-claude-upstream-integration.sh`

### 🧩 E. Codex plugin workflows / `/goal` / MultiAgentV2

活用的更新：

- Codex `0.125.0`: app-server Unix socket, sticky environments, remote thread config/store。
- Codex `0.125.0`: remote plugin install and marketplace upgrade。
- Codex `0.128.0`: persisted `/goal` workflows。
- Codex `0.128.0`: plugin workflows, plugin-bundled hooks, hook enablement state, external-agent config import。
- Codex `0.128.0`: MultiAgentV2 thread caps, wait-time controls, root/subagent hints, depth handling。

既存実装：

- Phase 58 snapshot / follow-up / Plans 中有记录。
- `codex/.codex/config.toml` 拥有 no-inline-hooks 方针、`[features].multi_agent = true`、`[agents].max_threads = 8`。
- Breezing 以 Codex native `spawn_agent` / `send_input` / `wait_agent` / `close_agent` 为前提。
- one-primary-environment policy 在 README / guard script / test 中。

不足：

- `/goal` 可以写什么未定义。
- 没有 plugin-bundled hooks / hook enablement state 的 opt-in 步骤。
- 没有 external agent import 的 ownership 边界。
- 没有 MultiAgentV2 controls 和 `agents.max_threads = 8` 的对应表。
- state path 的说明中 `${CODEX_HOME}/state/harness/` 和 `.claude/state/...` 有偏差。

不竞争的使用方式：

- `Plans.md` 为 SSOT。
- `/goal` 限于 session continuation memo。
- 不在 `/goal` 中写 task ID / DoD / status marker。
- plugin-bundled hooks 为既定无效的 opt-in。
- external agent import 不直接使用，先制作 allowlist / conversion table。
- remote / sticky environment 为 read-only first。
- 写入限制为每 write turn 1 个 primary environment。

採用判断：

- 🟡 面向设计 review。
- 在 58.3.1 的 permission profile 方针后着手。

実装計画：

1. 追加 `docs/codex-plugin-workflow-policy.md`。
2. 将 `/goal`、plugin hooks、hook enablement state、external agent import、MultiAgentV2、sticky environment 分为采用 / opt-in / 禁止 / 保留。
3. 更新 `codex/README.md` 和 `codex/AGENTS.md`。
4. 将 `codex/.codex/config.toml` 的 no-inline-hooks 方针用 Codex 0.128 风格改写。
5. 在测试中固定 MultiAgentV2 和 `agents.max_threads = 8` 的关系。
6. 将 state path 的说明分为 `.claude/state/...` 和 `${CODEX_HOME}` 的责任。

検証：

- `bash tests/test-codex-package.sh`
- `bash tests/test-claude-upstream-integration.sh`
- no-inline-hooks / plugin opt-in grep gate
- `/goal` 和 `Plans.md` SSOT boundary grep gate
- one-primary-environment regression test

## 導入順

1. 🛡️ A. Claude protected-write hardening
2. 🔐 D. Codex permission profiles / `--full-auto` migration
3. ✂️ B. PostToolUse output governance design
4. 🧭 C. Claude setup / MCP / telemetry / provider guidance
5. 🧩 E. Codex plugin workflows / `/goal` / MultiAgentV2

## 面向审阅者的判定标准

### 可以引入

- 不与现有 Harness 正本冲突。
- 可以用 test 防止复发。
- 不将 upstream 功能过度 wrapper 化。
- 不启用危险自动化的既定值。
- 不消除证据日志和审查结果。

### 应该保留

- 制作与 `Plans.md` 不同的正本。
- 像整体 deny `.claude/` 那样破坏通常运用。
- 将 `--full-auto` 或 dangerous bypass 作为新 default 扩大。
- 用 output mutation 隐藏 test / review / error evidence。
- 无 opt-in 地将 Codex plugin hooks 和 external agent import 有效化。

## 下一步执行命令

新 session 的启动命令：

```bash
claude
```

启动后第一个输入：

```text
/harness-work 58.2.1
```

面向的场景：

最先固安全边界。58.2.1 通过后，即使加入 58.2.2 以后的便利功能也不容易出事故。

并行的替代：

```text
/breezing 58.2.1 58.3.1 --parallel 2
```

面向的场景：

Claude 侧的 protected path hardening 和 Codex 侧的 permission profile migration 重叠文件少，reviewer 容易作为 2 条 PR 分开确认。
