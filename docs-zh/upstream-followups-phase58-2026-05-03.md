# Phase 58 Follow-up Decisions - 2026-05-03

本文档为将 Phase 58 的未处理 upstream 分为"立即实现前应设计"和"自动继承即可"的判断备忘录。

## ひとことで

Harness 是**不将 Claude Code / Codex 本体的新功能立即 wrapper 化，先固定安全边界和用户导径。**

## たとえると

新工具到货时，不立即发给所有人，
给危险的刀具加保护盖，决定使用的架子和名字后再送上现场，这种整理。

## Official References

- Claude Code changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code GitHub changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- OpenAI Codex `rust-v0.125.0` release: <https://github.com/openai/codex/releases/tag/rust-v0.125.0>
- OpenAI Codex `rust-v0.128.0` release: <https://github.com/openai/codex/releases/tag/rust-v0.128.0>
- OpenAI Codex `0.129.0-alpha.2` compare: <https://github.com/openai/codex/compare/rust-v0.128.0...rust-v0.129.0-alpha.2>

## 58.2.1 Claude protected-write and `dangerously-skip` hardening

### Current Harness surface

| Surface | Current state | Gap from upstream |
|---------|---------------|-------------------|
| `go/internal/guardrail/helpers.go` | 将 `.git/`、`.env`、keys、`.husky/` 等作为 protected path 处理 | Claude Code 2.1.121 / 2.1.126 的 skip mode 使 `.claude/`、`.vscode/`、shell config files 等也成为 prompt bypass 对象 |
| `go/internal/guardrail/rules.go` | block / ask / warn `Write/Edit/MultiEdit` 和 Bash write | 立即 deny `.claude/` 整体可能会破坏 rules / memory / setup 更新 |
| `.claude-plugin/settings.json` / `harness.toml` | 同步 sandbox denied domains 等 | 需要在 `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` precedence bug fix 后重新确认 managed sandbox 边界 |

### Decision

- **不立即 deny `.claude/` 整体**
- 先制作 protected path taxonomy
  - deny: `.git/`、secrets、shell rc / profile files、destructive hook entrypoints
  - ask: `.claude/skills/`、`.claude/agents/`、`.claude/commands/`、`.vscode/`
  - warn: `.claude/rules/`、`.claude/memory/`、project-local setup metadata
- 即使在使用 `--dangerously-skip-permissions` 的 session 中，Harness hook 可工作的范围内也不缓和 guardrail
- managed sandbox 按 `harness.toml` -> generated settings -> template -> tests 的顺序确认

### Acceptance target

- protected path table 在 docs 或 rule comment 中
- Go guardrail tests 中有 `.claude/skills`、`.claude/agents`、`.claude/commands`、`.vscode`、shell config files 的 deny / ask / warn 期望值
- `tests/test-claude-upstream-integration.sh` 检测 Phase 58 hardening coverage
- 不过度 deny 通常 setup / memory / rules 更新

## 58.2.2 `PostToolUse.updatedToolOutput` output governance

### Current Harness surface

Phase 56 中将 `PostToolUse.duration_ms` 为 no-op。
理由是尚无 per-tool telemetry sink，混合 session duration 和 tool duration 会难以分辨。

Claude Code 2.1.121 中，`PostToolUse` 可以通过 `hookSpecificOutput.updatedToolOutput` 返回所有 tool 的输出。

### Decision

- **既定不修改 tool output**
- 使用时为 opt-in
- 最初候选限定为 redaction / compaction / machine-readable normalization
- 不丢失 original output 和更新后 output 的 traceability
- 不用于消除 review 和 test 的证据

### Acceptance target

- `updatedToolOutput` 的允许用途 / 禁止用处在 docs 中
- 实现时测试 before / after / audit record
- 在 stdout 为 JSON 契约的 tool 中，不将面向人的说明混合到 stdout

## 58.2.3 Claude setup / MCP / telemetry refresh

### Decision

以下作为 setup / docs / validation 的候选，不作为 runtime wrapper。

| Item | Decision |
|------|----------|
| `claude ultrareview [target] --json` | 不与 `/harness-review` 竞争，作为 CI second-opinion 留在 comparison task |
| `${CLAUDE_EFFORT}` | 有在 skill prompt tuning 中使用的价值，但不机械追加到所有 skill |
| `claude plugin validate` schema acceptance | 在 release / marketplace validation docs 中确认 |
| MCP `alwaysLoad` | 在 setup docs 中留下 always-load 和 deferred discovery 的区分使用 |
| `claude plugin prune` | 作为 stale dependency cleanup 的 docs 化候选。但 uninstall/prune 是破坏性的，优先 dry-run 相当的说明 |
| `ANTHROPIC_BEDROCK_SERVICE_TIER` | 作为 Claude Code Bedrock guidance 对待，不与 Codex provider policy 混淆 |
| `claude project purge` | 不与 Harness state cleanup 混淆，作为 `--dry-run` first 的 maintenance guidance |
| `claude_code.skill_activated.invocation_trigger` | 有纳入 skill analytics 的价值，但 telemetry sink 设计为先 |

## 58.3.1 Codex permission profiles and `--full-auto` migration

### Current Harness surface

`codex/.codex/config.toml` 在 Phase 56 中记录了 no-inline-hooks 方针。
Codex `0.125.0` / `0.128.0` 大幅推进了 permission profiles 和 sandbox profile controls。

### Decision

- 不在新规 docs 的 default 中增加 `--full-auto`
- 以显式 permission profiles / trust flows 为主导
- `requirements.toml` 作为 org-managed policy 的放置场所，不在配布 default 中推测放入
- 将 `codex exec --json` reasoning token usage 作为 loop / report telemetry 候选
- 确认 rollout tracing 和 existing AgentTrace 的重复

### Acceptance target

- 用 `rg` 盘点 stale `--full-auto` guidance
- Codex permission profile examples 不与 config surface 矛盾
- 立即向 `codex/.codex/config.toml` 追加 hook 时追加 Codex package test
- 继续 no-op 时在 config comment / docs / tests 中留理由

## 58.3.2 Codex plugin hooks, `/goal`, MultiAgentV2, app-server updates

### Decision

| Item | Decision |
|------|----------|
| `/goal` workflows | 不与 `Plans.md` SSOT 双重化。调查作为 runtime continuation 候选 |
| plugin-bundled hooks / hook enablement state | 重新评估 Phase 56 的 no-inline-hooks 方针，但在配布 default 中优先无效状态和 opt-in |
| external agent import | 决定 Claude / Codex / external agent 的 ownership 边界后再使用 |
| MultiAgentV2 thread caps / wait controls | 验证 `agents.max_threads = 8` 和 v2-specific controls 的关系 |
| sticky environments / remote thread config | 维持 one primary environment per write turn，remote 为 read-only first |
| app-server release artifacts / Python SDK | Harness 不同 SDK 的话留为 docs-only |

## Why This Way

Phase 58 的 upstream 不是简单的 docs refresh。
Claude 侧 permission / hook output mutation、Codex 侧 permission profiles / plugin hooks / goal workflow 变化很大。

因此，本 snapshot 中不急于增加 runtime，
先固定"守护什么"、"继承自动到什么程度"、"在哪个 task 中实现"。
