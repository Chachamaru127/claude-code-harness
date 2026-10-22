# CC 升级追从策略

Claude Code 新版本对应时更新 Feature Table 的质量标准。

## 基本原则

Feature Table 追加必须伴随**对应的实现变更**或**类别 C（CC 自动继承）的明确分类**。

不能以"只在 Feature Table 追加了行"的状态合并 PR。

## 3 类别分类

| 类别 | 定义 | PR 合并 |
|---------|------|----------|
| **(A) 有实现** | hooks / scripts / agents / skills / core 有对应实现变更 | 可 |
| **(B) 只写了** | 仅变更 Feature Table。无实现 | **不可** — 必须提示实现方案 |
| **(C) CC 自动继承** | CC 本体的修改不需要 Harness 侧变更（性能改善、bug 修复等） | 可（Feature Table 明确记载"CC 自动继承"） |

## 规则

### 1. Feature Table 追加必须有实现或分类伴随

向 Feature Table 追加新行时，满足以下任一条件：

- **(A)** 同一 PR 内包含对应实现文件变更
- **(C)** 在 Feature Table 中明确记载为"CC 自动继承"

都不满足时，该项目判定为类别 B（只写了）。

### 2. 检测到类别 B 时阻止 PR 并要求实现方案

类别 B 项目存在 1 件时：

- **阻止** PR 合并
- 对各类别 B 项目要求提示包含以下的**实现方案**：
  - Harness 独特附加价值的说明
  - 变更目标文件和具体变更内容
  - 用户体验的改善（至今/今后）

实现方案被承认后，创建包含实现的追加 commit 或后续 PR。

### 3. 推荐追加"附加值"列

推荐在 Feature Table 追加 A / B / C 分类可视化的"附加值"列。

```markdown
| Feature | Skill | Purpose | 付加価値 |
|---------|-------|---------|---------|
| PostCompact フック | hooks | コンテキスト再注入 | A: 実装あり |
| Streaming leak fix | all | メモリリーク修正 | C: CC 自動継承 |
```

此列的效果：
- review 时立即发现类别 B 的残留
- Feature Table 各项目的"为什么在这里"自动文档化
- 将来 CC 升级集成时可以参考过去的判断

## 适用范围

本策略适用于以下文件变更时：

- `CLAUDE.md` 的 Feature Table 部分
- `docs/CLAUDE-feature-table.md`

不适用于通常的实现 PR、文档修正、release 作业。
