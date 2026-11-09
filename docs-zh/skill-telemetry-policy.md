# Skill Telemetry Policy (Phase 62.2.3)

> **状态**: Active (2026-05-07)
> **对象**: Claude Code `2.1.126+` 中触发的 `claude_code.skill_activated` OTel event
> 的 `invocation_trigger` 字段记录到 local ledger 时的运用规则。

## ひとことで

Skill 发动的 trigger 种类（人 / 模型 / skill 连锁）记录到 **local ledger**，
作为识别哪些 skill 浪费地发动的材料。
记录时必须遵守 **privacy / retention / opt-out**。

## たとえると

与"将读过的书名只写入账本"相似。
不写内容（本书 = skill 输入 / 输出），只记录何时・哪种・读了哪本书（skill_activated event）。

## telemetry sink 设计的前提

Phase 58.2.3 中判断"telemetry sink 设计先行"。本文定义其 sink 规格。

| 项目 | 规格 |
|------|------|
| sink 种类 | **local-only JSON Lines ledger**（无外部发送） |
| ledger 路径 | `.claude/state/skill-trigger-stats.jsonl` |
| append 方式 | **append-only**（仅追加。不 compaction 也不 deletion） |
| 获取路径 | Claude Code 的 OTel event 由 `scripts/skill-trigger-telemetry.sh` 接收 |
| 输出形式 | 1 行 1 JSON object |

## 记录字段

各 record 仅包含以下字段。**不记录可识别个人的信息**。

```json
{
  "timestamp": "2026-05-07T00:00:00Z",
  "skill_name": "harness-work",
  "invocation_trigger": "human|model|skill-chain",
  "session_id": "session-abc123",
  "duration_ms": 0
}
```

| 字段 | 必需 | 说明 |
|-------|------|------|
| `timestamp` | yes | RFC3339 UTC |
| `skill_name` | yes | 发动的 skill 名 (`harness-work` 等) |
| `invocation_trigger` | yes | `human` / `model` / `skill-chain` 之一 |
| `session_id` | yes | CC session ID（12 字符以上时 truncate 到前 12 字符） |
| `duration_ms` | no | skill 执行时间。仅在 CC 提供时记录 |

**不记录的字段**：
- skill 的输入 prompt
- skill 的输出正文
- 用户名 / 邮箱地址
- API token / 认证信息
- 个别文件路径（不记录比 skill 名更细的粒度）

## privacy 原则

1. **local-only**：ledger 放在 `.claude/state/`，不发送到外部
2. **identifier minimization**：session_id truncate 到 12 字符以下的 prefix
3. **content opacity**：不记录 skill 的输入输出正文
4. **opt-out 可能**：环境变量 `HARNESS_SKILL_TELEMETRY_DISABLE=1` 无效化

## retention

| Trigger | 保持期间 | 删除时机 |
|---------|---------|--------------|
| 默认 | **30 天** | `scripts/maintenance/prune-skill-telemetry.sh`（手动或 cron） |
| 用户删除要求 | 即时 | `rm .claude/state/skill-trigger-stats.jsonl` |
| repo clone / 共享时 | 不共享 | `.gitignore` 追加（state path 一并排除，现有 .gitignore 已覆盖） |

30 天后的 record **推荐手动删除**，但不自动删除（想定 audit 用途的长期保持）。
实现删除时，为保持 append-only 性质，使用 rotation 方式（移动到 `stats.jsonl.{date}`）。

## opt-out

### 完全无效化

在 `.claude/settings.json` 或环境变量无效化：

```bash
export HARNESS_SKILL_TELEMETRY_DISABLE=1
```

或者：

```json
{
  "env": {
    "HARNESS_SKILL_TELEMETRY_DISABLE": "1"
  }
}
```

### 部分无效化（skill 单位）

在 `.claude/settings.local.json` 写 exclude list：

```json
{
  "harness": {
    "skill_telemetry_exclude": ["harness-work", "harness-loop"]
  }
}
```

## 関連 doc

- Phase 58.2.3 (`docs/upstream-followups-phase58-2026-05-03.md`) — telemetry sink 设计判断
- Phase 61 (`docs/sandbagging-aware-weak-supervision.md`) — `.claude/state/elicitation/events.jsonl` ledger 相同的 append-only 设计遵循
- Claude Code OTel reference (Anthropic docs)

## Acceptance 条件 (Phase 62.2.3 DoD)

- [x] `docs/skill-telemetry-policy.md` 存在（本文）
- [x] privacy / retention / opt-out 记载
- [x] 与 Phase 58.2.3 的判断不矛盾（sink 设计固定为 local-only）
- [x] sink 路径：`.claude/state/skill-trigger-stats.jsonl`
- [x] schema：timestamp / skill_name / invocation_trigger / session_id / duration_ms

## 参考

- Claude Code 2.1.126 CHANGELOG: `claude_code.skill_activated` OTel event includes `invocation_trigger`
- Phase 61 的 sandbagging-aware weak-supervision ledger 设计 (privacy-first, append-only)
