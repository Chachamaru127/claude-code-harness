# 技能路由规则（参考）

技能之间的路由规则参考文档。

> **SSOT 的位置**: 各技能的 `description` 字段是路由的 SSOT。
> 本文件是提供详细说明与示例的参考文档，实际路由取决于各技能的 description。
>
> **重要**: 各技能的 description 与正文中的「Do NOT Load For」表格必须完全一致。

## Codex 相关路由

### harness-review（包含 Codex 评审功能）

**目的**: 在 Codex CLI（`codex exec`）中提供第二意见评审（v3 起从 `codex-review` 合并而来）

**触发关键词**（引自 description）:
- "review", "code review", "plan review"
- "scope analysis", "security", "performance"
- "quality checks", "PRs", "diffs"
- "/harness-review"

**排除关键词**（引自 description）:
- "implementation", "new features", "bug fixes"
- "setup", "release"

### harness-work --codex（包含 Codex 实现功能）

**目的**: 将 Codex 用作实现引擎（v3 起合并）

**触发关键词**:
- "implement", "execute", "/work"
- "breezing", "team run"
- "--codex", "--parallel"

**排除关键词**（引自 description）:
- "planning", "code review", "release"
- "setup", "initialization"

**对应**: 通过 `/harness-work --codex` 执行

## 路由判定流程（参考）

> 本节说明的是 Claude Code 的内部行为，并非额外的关键词定义。
> 实际路由只依据各技能 description 中记载的关键词进行判定。

```
ユーザー入力
    │
    ├── description のトリガーキーワードにマッチ → 該当スキルをロード
    ├── description の除外キーワードにマッチ → 該当スキルを除外
    └── どちらでもない → 通常のスキルマッチング
```

## 优先级规则（参考）

当关键词同时命中多个技能时的优先级:

1. **排除最优先**: 命中排除关键词的技能绝不加载
2. **具体关键词优先**: 完全匹配 > 部分匹配

> **注**: 不使用「上下文判定」，因为它会引入歧义。判定由 description 的关键词确定性地完成。

## 更新规则

1. **description = SSOT**: 各技能的 `description` 字段是路由的正式定义
2. **与正文一致**: 各技能的「Do NOT Load For」表格必须与 description 完全一致
3. **本文件的职责**: 详细说明与判定流程的参考（不是 SSOT）
4. **保持完整列表**: 不使用泛化表述（"〜全般"），而是列举具体关键词
