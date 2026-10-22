# Skill Overrides Policy (Phase 62.2.5)

> **状态**: Active (2026-05-07)
> **对象**: Claude Code `2.1.129` 中 `skillOverrides` 设置支持
> `off` / `user-invocable-only` / `name-only` 的 3 mode。
> 明示 Harness 的 skill 治理与它的关系，为 enterprise / individual 定合适的 default。

## 一句话概括

`skillOverrides` 3 mode 是**是否让模型覆盖 skill** 的 policy。
Harness 默认**什么都不设置** (= CC default 动作)，但 enterprise governance 中
推荐 `name-only`。

## 打个比方

决定"厨师（模型）能在多大程度上改编食谱（skill）"的 policy。
- `off`：禁止改编（仅执行既定 skill）
- `user-invocable-only`：仅允许用户用 `/<skill>` 明确启动的 skill，禁止模型自动启动
- `name-only`：仅允许通过 skill name 字段一致启动（抑制 description-based 自动 trigger）
- 未设置：CC default 动作。一定程度允许改编

## 3 种 mode 的含义

| mode | 意味 | 用途 |
|------|------|------|
| `off` | 完全无效化模型介由的 skill activation | 高等 enterprise 环境，想完全固定 skill 动作时 |
| `user-invocable-only` | 仅允许用户用 `/<skill>` 明确启动的 skill，禁止模型自动启动 | 中间 governance 想避免"模型暗默调用 skill"动作时 |
| `name-only` | 仅允许 skill 的 name 字段一致导致的启动（抑制 description-based 自动 trigger） | 想防止因 description 模糊一致导致的意外 skill 发动时 |
| 未设置 (default) | CC default 动作。包含 description-based 自动 trigger 全部有效 | 个人开发、Harness 默认 |

## Harness 默认方針

| 环境 | 推荐 mode | 理由 |
|------|-----------|------|
| 个人 / 单独开发 | 未设置 (CC default) | description 基础的自动 trigger 便利 |
| Team (small) | 未设置 + skill manifest 审计 | 用 `scripts/generate-skill-manifest.sh` 可视化 skill 一览 |
| Enterprise governance | **`name-only`** | 抑制 description 模糊一致，仅允许明确 skill 启动 |
| 教育 / training session | `user-invocable-only` | 禁止模型自动启动，让学习者主动选择 skill |

`harness-init` 生成的 template 中**不放入 default** (= 尊重 CC default)。
enterprise 用户在 `.claude/settings.json` 或 `.claude/settings.local.json` 中明示。

## 与 skill manifest 的关系

Phase 59.1.2 中 `scripts/generate-skill-manifest.sh` 输出 `kind` / `purpose` / `trigger` /
`shape` / `role` / `base` / `pair` / `owner` 等 metadata 为机器可读格式。

在 `skillOverrides: name-only` 环境中，CC 仅按 skill 的 **name** 匹配。
description-based 自动 trigger 无效。
因此 skill 名应该**语义上明示** (`harness-work` / `harness-review` 等动词 + 名词)。

| skill 命名 | name-only mode 的行为 |
|-----------|----------------------|
| `harness-work` | 明确启动 OK (`/harness-work`) |
| `breezing` (alias) | 明确启动 OK (`/breezing`) |
| `harness-loop` | 明确启动 OK (`/harness-loop`) |
| 抽象的 / 一般语 (例: `helper`) | 名称冲突风险，应避免 |

## 設定例

### Enterprise governance (`.claude/settings.json`)

```json
{
  "skillOverrides": "name-only"
}
```

### 个别无效化（仅特定环境）

```json
{
  "skillOverrides": "off"
}
```

由此能在自动化批量执行中完全停止 skill 的暗默启动。

### 默认（不推荐明确指定）

没有明确指定 `default` 的 mode，因此保持未设置以保留 CC default。

## tests / `harness-init` 中的处理

- `tests/test-settings-baseline.sh` (Phase 62.1.4 中探讨创建) 将 `skillOverrides` 的存在
  **允许但不强制**（不妨碍个人开发中的 `default`）
- `harness-init` 不将 `skillOverrides` 放入生成 settings
- 移植 / customize 时需要 enterprise governance 的话参照本 doc

## Acceptance 条件 (Phase 62.2.5 DoD)

- [x] 用表写出 3 种 mode 的含义
- [x] 推荐默认按环境（个人 / team / enterprise / education）固定
- [x] Enterprise governance 用途明示
- [x] 与 Phase 59.1.2 skill manifest 的关系明記
- [x] `harness-init` 中是否放入 default 的判断记录 (= 不放入)

## 関連 doc

- Phase 59.1.2 (`scripts/generate-skill-manifest.sh`) — skill metadata 机械化
- Phase 58.2.3 (`docs/upstream-followups-phase58-2026-05-03.md`) — 作为 setup / docs 候选的处理
- Claude Code 2.1.129 CHANGELOG: `skillOverrides` setting now works with `off`, `user-invocable-only`, `name-only` options
