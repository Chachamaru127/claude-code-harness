# Skills Audit 2026-04-20

配合 Claude Code / Codex upstream 追从的再实施，总检查了
`skills/`、`codex/.codex/skills/`、`.agents/skills/` 的 `SKILL.md`。

## Summary

- 对象：3 系统的 `SKILL.md`
- 检测：102 件
- `skills/` -> `codex/.codex/skills/` 主要同步概览维持
- `.agents/skills/` 是不同系统，Claude/Codex 的机械替换 drift 多
- 本次修正完毕：
  - `claude-codex-upstream-update` 在 PR 对象的 `skills/`、`codex/.codex/skills/` 中同步，local-only `.agents/skills/` 也在作业环境中更新
  - `cc-update-review` 重新定义为 Claude/Codex upstream update review，在 PR 对象 2 系统和 local-only mirror 中同步
  - 删除了不存在 Anthropic 侧 Codex repo URL、旧 Codex plugin directory、旧 Codex feature-table path、旧 TypeScript guardrail path 的引用
  - Phase 51.2.1-51.2.3 / Worker 3：Codex native skill orchestration drift、session-memory / memory policy path drift、Codex loop state policy、harness-release-internal mirror policy 修正
  - Phase 51.2.4 / Worker 4：media / announcement skill 的发动契约、对话输入 tool 差分、harness-review mirror link drift 修正

## Findings Tracker

| Priority | Area | Finding | Next action | Status |
|----------|------|---------|-------------|--------|
| P0 | `codex/.codex/skills/harness-work` | 说是 Codex native 但混有 `Agent(...)`, `SendMessage`, `claude-code-harness:worker` 风的 Claude Code 伪代码 | 统一为 Codex tool model (`spawn_agent`, `send_input`, `wait_agent`, `close_agent`) | Done 2026-05-05 |
| P0 | `codex/.codex/skills/breezing` | 有 `user-invocable: true` 但无 `allowed-tools`，正文是 subagent tools 前提 | metadata 和 allowed tool 契约对齐 | Done 2026-05-05 |
| P1 | `.agents/skills/memory` | `Codex / Codex / OpenCode`、`.Codex/memory/decisions.md` 等替换 drift | 与 `.claude/memory` 正本分离 Codex 侧表现 | Done 2026-05-05 |
| P1 | `.agents/skills/session-memory` | `.Codex/memory`、`.Codex/state`、`~/.Codex` 作为正本对待 | 更新为 session-state / memory 的实际存在路径 | Done 2026-05-05 |
| P1 | `codex/.codex/skills/session-memory` | 将 `${CLAUDE_SESSION_ID}` 作为 Codex 侧固定前提 | 与 Codex session id 获取公约与 session-init 对齐 | Done 2026-05-05 |
| P1 | `skills/session-memory` | `docs/MEMORY_POLICY.md` 参照不存在 | 创建参照先，或替换为现有 memory docs | Done 2026-05-05 |
| P1 | `harness-review` mirrors | `../../docs/ultrareview-policy.md` 在 mirror 侧成为不存在的相对路径 | 改为 repo root 基准或 skill-local reference | Done 2026-05-05 |
| P1 | `x-announce`, `x-article` | `allowed-tools` 中有 `Agent` / `AskUserQuestion`，Codex 侧对应暧昧 | 添加 Task / Codex input UI 的对应表 | Done 2026-05-05 |
| P1 | `generate-slide`, `generate-video` | `disable-model-invocation` / `user-invocable` 与正文 trigger 矛盾 | 按实际发动面整理 metadata | Done 2026-05-05 |
| P1 | `harness-loop` Codex mirror | state 保存先固定为 `.claude/state/codex-loop/` | 明文化 `.claude` 共通 state 与 Codex native state 的职责 | Done 2026-05-05 |
| P2 | `harness-release-internal` | mirror policy 未将 `.agents/skills/` 作为同步对象对待 | 或将 `.agents` 作为生成物排除，或包含在同步对象中 | Done 2026-05-05 |
| P2 | `.agents/skills/harness-setup` | 旧 Codex state/plugin directory 名和 `Codex-harness-worker` 等粗略替换 drift | 通过 `.agents` 生成规则的检讨统一修正 | Open |

## Tracking

本 audit 结果作为未完了任务留在 `Plans.md` Phase 51.2。
本 scope 中修正了 upstream update 的质量 gate 直结的 2 Skills，其余下次 skill mirror cleanup cycle 切出。
