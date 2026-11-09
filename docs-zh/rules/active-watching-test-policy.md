# Active Watching Test Policy

Session Monitor 等**外部进程/文件/daemon 能动监视功能**新增时遵守的测试公约。
将 D40 (tri-state health) 和 P29 (dual hooks sync) 运维规则化，在 v4.3.3 这样的
"向未安装用户误警告 regression"在初期阶段就堵住的 SSOT。

## 为什么需要这个规则

v4.3.1 在 Session Monitor 添加 `harness-mem` 能动监视后，
v4.3.3 hotfix 需要修复"`~/.claude-mem/` 不存在 = 未 opt-in harness-mem 的用户"中
每会话显示 `⚠️ harness-mem unhealthy: not-initialized` 的 regression。

根本原因是只做了 inclusion-based testing，没有写**依赖目标不存在状态**的测试。
active watching 依赖 opt-in 外部资源的情况多，"未安装/未启动/破损"的
**3 种状态全部从一开始覆盖**是唯一的再发防止对策。

## 适用范围

新增以下任一相关代码时，遵循本公约：

- 在 `go/internal/session/monitor.go` 添加新的 health check
- 从 `scripts/hook-handlers/` 等探测外部 daemon / HTTP endpoint
- 读取 `~/.claude-*/` 或 `$HOME/` 下的 optional 目录
- 监视 MCP server 的启动状态
- 每会话检查 Codex daemon / external CLI 的可用性
- 在 `UserPromptSubmit` 或 `SessionStart` hook 中将外部资源可用性加载到 additionalContext

相反，以下不适用：

- 必需依赖（Go 标准库、`bin/harness` 本身）的 sanity check
- 仅在 CI 环境运行的测试（CI 中依赖必然存在的前提可以）

## 3 种状态的定义

active watching 目标依赖可能取的状态和各自要求的行为：

| 状态 | 识别符 (reason) | `healthy` | Exit | Monitor 警告 | 典型例 |
|------|----------------|-----------|------|------------|--------|
| 未安装 / opt-in 未使用 | `not-configured` | **true** | 0 | **不出** | `~/.claude-mem/` 不存在 |
| 未启动 / 不达 | `daemon-unreachable`, `timeout`, `unreachable` | false | 1 | 出 | TCP connect 失败 |
| 设置破损 / 文件缺失 | `corrupted`, `invalid-config` | false | 1 | 出 | settings.json 不存在 |
| 正常 | `""` | true | 0 | 不出 | 全构成要素 OK |

重要原则：

- **"未使用"不等于"损坏"**。opt-in 功能只是未使用的状态时不出警告
- 判定逻辑**集中在 health check 子命令侧**，Monitor / 其他调用方保持行为一致（D40）
- `healthy=true + reason="not-configured"` 是 Monitor 实现必须处理的 warning 抑制契约

## 测试命名公约

3 种状态各自至少写 1 个测试。命名固定如下：

| 状态 | 测试函数名模式 | 验证内容 |
|------|-------------------|---------|
| `not-configured` | `TestXxx_NotConfigured` | `exit=0`, `healthy=true`, `reason="not-configured"`, Monitor 不出 warning |
| `unreachable` | `TestXxx_DaemonUnreachable` 或 `TestXxx_Unreachable` | `exit=1`, `healthy=false`, 具体 reason 字符串, Monitor 出 warning |
| `corrupted` | `TestXxx_Corrupted` | `exit=1`, `healthy=false`, `reason="corrupted"`, Monitor 出 warning |
| 正常 | `TestXxx_Healthy` | `exit=0`, `healthy=true`, `reason=""`, Monitor 静默通过 |

Monitor 侧集成测试也用相同命名公约（如：`TestMonitorHandler_XxxNotConfigured`）。

## 检查清单

PR 包含 active watching 功能时确认：

- [ ] health check 侧写了 4 个测试（正常 + 3 异常）
- [ ] Monitor 侧写了 assert `not-configured` 时不出 warning 的集成测试
- [ ] `reason` 字符串以 enum 方式列出（不用 free-text。在文档中以表明示）
- [ ] Monitor 侧引用了 `healthy=true + reason="not-configured"` 契约
- [ ] 与现有依赖（`harness-mem` 等）的命名公约不冲突
- [ ] 在文档（`go/SPEC.md` 等）中记载了 3 种状态

## 事例附录：v4.3.3 harness-mem hotfix

本公约诞生的直接触发事例。作为参考模仿测试结构。

- **背景 commit**：[`23589344`](https://github.com/Chachamaru127/claude-code-harness/commit/23589344) (PR #98 / v4.3.3 hotfix)
- **health check 实现**：`go/cmd/harness/mem.go` 的 `runMemHealthCheck()` — 早期 return 2 段（`UserHomeDir` 失败 / `~/.claude-mem/` 不存在）返回 `not-configured`
- **health check 测试**：`go/cmd/harness/mem_test.go`
  - `TestRunMemHealth_Healthy`
  - `TestRunMemHealth_DaemonUnreachable`
  - `TestRunMemHealth_NotConfigured` ← 3 状态覆盖率的核心
  - `TestRunMemHealth_Corrupted`
- **Monitor 集成测试**：`go/internal/session/monitor_test.go`
  - `TestMonitorHandler_HarnessMemHealthy`
  - `TestMonitorHandler_HarnessMemUnhealthy`（fixture reason = `daemon-unreachable`）
  - `TestMonitorHandler_HarnessMemNotConfigured` ← 明确 assert 警告不出

此事例确认的是，3 种状态中**缺少任何 1 个都会出 regression**。
如果一开始就写了 `not-configured` 测试，v4.3.1 时就能发现问题。

## 相关规则

- [D40](../../.claude/memory/decisions.md) — tri-state health 的设计判断（本文的理论依据）
- [P29](../../.claude/memory/patterns.md) — dual hooks.json sync + CI gate（布线侧的再发防止）
- [migration-policy.md](./migration-policy.md) — exclusion-based verification 的姐妹公约（删除残骸 vs 依赖不存在）
- [test-quality.md](../../.claude/rules/test-quality.md) — 测试品质一般（禁止形骸化测试）
- [implementation-quality.md](../../.claude/rules/implementation-quality.md) — 实现品质一般
