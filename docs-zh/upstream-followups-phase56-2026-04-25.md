# Phase 56 Follow-up Decisions - 2026-04-25

本文档为 Phase 56 的 follow-up task `56.2.1` 到 `56.2.4` 固定
"立即实现"和"仅记录保留"的区分的记录。

## ひとことで

Harness 是**只最小追従已分发的 surface，不增加责任重叠的 wrapper。**

## たとえると

新增道路标志时，
可以直接追加到现在的指示板上就追加，
不制作与交通管制本身重复的变更，这种整理。

## Official References

- Claude Code status line docs: <https://code.claude.com/docs/en/statusline>
- Claude Code hooks docs: <https://code.claude.com/docs/en/hooks>
- OpenAI Codex `rust-v0.124.0` release: <https://github.com/openai/codex/releases/tag/rust-v0.124.0>
- OpenAI Codex config reference: <https://developers.openai.com/codex/config-reference>
- OpenAI blog, Codex App Server: <https://openai.com/index/unlocking-the-codex-harness/>

## 56.2.1 Claude Code `PostToolUse.duration_ms` and status line fields

### Current Harness surface

| Surface | Current state | Decision impact |
|---------|---------------|-----------------|
| `scripts/session-monitor.sh` | `SessionStart` 收集 project / git / Plans 状态，只是不接收 `PostToolUse` 输入 | 混合 `duration_ms` 会导致责任偏移 |
| `scripts/statusline-harness.sh` | 已经读取 Claude Code status line stdin JSON | `effort.level` / `thinking.enabled` 可以低风险追従 |
| `statusline-telemetry.jsonl` | 保存 status line 来源的 cost / duration / role | `effort` / `thinking` 可以同样粒度保留 |

### Decision

| Upstream field | Harness decision | Why |
|----------------|------------------|-----|
| `PostToolUse.duration_ms` | **PostToolUse.duration_ms 本次为 no-op** | Harness 已分发的 Session Monitor 用于 `SessionStart`，尚无 per-tool latency sink。混合 `cost.total_duration_ms` 会使"会话时间"和"各个 tool 时间"难以分辨 |
| `effort.level` | **采用到 statusline** | `scripts/statusline-harness.sh` 已在读取 status line JSON，可以不增加 runtime hook 反映 |
| `thinking.enabled` | **采用到 statusline** | 与 `effort.level` 同样，可以在现有 statusline surface 安全地可视化 |

### Display spec

- 在 status line 第 1 行显示 `effort:<level>`
- thinking 有效时显示 `think:on`，无效时显示 `think:off`
- 没有字段时不输出任何内容
- 在 telemetry JSONL 中追加 `effort_level` 和 `thinking_enabled`

## 56.2.2 Codex `0.124.0` stable hooks parity review

### Parity table

| 観点 | Claude Code | Codex `0.124.0` | Harness decision |
|------|-------------|-----------------|------------------|
| Main config surface | `hooks/hooks.json` / `.claude-plugin/hooks.json` | inline `config.toml` 和 managed `requirements.toml` 在 release note 中明确 | **不在已分发的 `codex/.codex/config.toml` 中追加** |
| Admin policy surface | project / plugin settings + hook files | `requirements.toml` 可以用 security-sensitive policy 固定 | org policy 留在 docs，不放入配布 default |
| MCP tools observation | Claude Code hook matcher 按 tool name 处理 | release note 中明确了 MCP tools observation | 读取系诊断有价值，但不与 Claude 侧 hook 双重化 |
| `apply_patch` observation | Claude 侧以 `Write` / `Edit` 系 guardrail 为主 | release note 中明确了 `apply_patch` observation | 在 Codex package 专用 test 完备前为 no-op |
| long-running Bash observation | Claude 侧并用 `PermissionRequest` / `PostToolUseFailure` / `Monitor` | release note 中明确了 long-running Bash observation | 不向 Codex runtime 叠加双重 log policy |
| Block timing | 执行前 deny / 执行后 feedback 强 | surface 不同，也涉及 admin requirements | parity 以"相同 policy 如何分担"对齐 |

### Decision

- **Codex hooks 只做 parity review，已分发的 config 为 no-op**
- 在 `codex/.codex/config.toml` 中只留"为什么不追加"的 comment
- managed `requirements.toml` 是组织 policy，不在配布 template 中推测书写
- 不立即将 Claude Code 侧已持有的相同责任 guardrail 在 Codex 侧双重实现

### Note on docs drift

`rust-v0.124.0` release 中明确了 hooks 的 stable 化和 inline / managed config。
另一方面 current config reference 中仍残留 `hooks.json` 读取对应的 feature flag 记述。
Harness 以此 docs drift 为理由，**现在只留 parity table 和 no-op 理由，不推测实现 config。**

## 56.2.3 `prUrlTemplate` / `--from-pr` multi-host review support

### Current boundary

| Surface | Current assumption | Decision |
|---------|--------------------|----------|
| `harness-review` | diff / file review 基于 git 不依赖 host，但 PR metadata 的自动获取尚未抽象化 | review core 保持，PR host 抽象化为后续 |
| `harness-release` | 以 `gh` CLI 和 GitHub remote 为前提构建 release automation | 维持 GitHub-first automation |
| footer PR links | 如果有 `prUrlTemplate` 则 human-facing link 可以 multi-host | **docs-only** 整理，automation surface 尚不扩大 |

### Decision

- `prUrlTemplate` / `--from-pr` multi-host support 留为 **docs-only**
- GitHub Enterprise / GitLab / Bitbucket 中显示 review URL 本身作为将来候选保留
- 但 owner / branch / CI / release asset 获取 **GitHub CLI remains primary**
- 将非 Git host 混入 automation，在切分各 host 的 API / auth / CI surface 的 task 另起后再进行

## 56.2.4 Codex `0.124.0` multi-environment app-server and branch/workdir policy

### Current Harness policy

| Current mechanism | What it protects | Multi-environment implication |
|-------------------|------------------|-------------------------------|
| Worker `isolation: worktree` | 减少同一 repo 内的并行写入竟争 | 维持 primary repo 的 branch/workdir 边界 |
| Codex sandbox / remote policy docs | 整理 remote host 各自的 sandbox 差异 | 即使增加 environment，sandbox policy 的放置场所也在 requirements 侧 |
| cherry-pick based merge | 明确 main 取り込み边界 | 不混合多 environment 的产出物 |

### Safe default

| Scenario | Safe default |
|----------|--------------|
| 1 session 中想看多 environment | 可以调查，但**写入限制为每 turn 1 个 primary environment** |
| 混合 remote environment | 非 primary environment 首先 read-only 确认，写入时明确切换 |
| 有多个 branch / workdir | merge / cherry-pick / Plans 更新只在 primary repo/worktree 中进行 |
| 切换 environment | 在下次写入前明文化 target repo / branch / workdir |

### Decision

- Codex App Server 的 multi-environment 作为 **workflow guidance 采用**
- Harness 自身的 branch/workdir 实现，在以单一 repo / primary worktree 为 safe default 的基础上，**在 Codex 写入前追加 primary-environment guard**
- 在 `codex/README.md` 中追记 **one primary environment per write turn** 作为 safe default
- 即使包含 remote workspace，也从 read-only 开始

### Runtime guard

- `scripts/codex-primary-environment-guard.sh` 将初次写入目标记录为 primary environment
- 后续写入面向不同 worktree / 不同 repo 时，默认停止
- 想临时允许时为 `HARNESS_CODEX_ALLOW_NON_PRIMARY_WRITE=1`
- 想切换 primary 本身时为 `HARNESS_CODEX_RESET_PRIMARY_ENVIRONMENT=1`
- 想无效化 guard 的特殊环境为 `HARNESS_CODEX_DISABLE_PRIMARY_ENV_GUARD=1`

## Why This Way

Harness 想要守护的是"不漏掉 upstream 的新功能"和
"不因看起来便利就双重增加 wrapper"的两立。

因此 Phase 56.2 中，
已在分发中的 statusline 小幅追従，
hook / multi-host / multi-environment 以 docs 和 safe default 先固定边界。
