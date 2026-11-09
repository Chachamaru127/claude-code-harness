# 技能目录

技能层级结构、全类别一览、开发用技能的参考文档。

## 技能评估流程

> 💡 重型任务（并行审查、CI 修复循环）中，技能会通过 Task 工具并行启动 `agents/` 中的子代理。

**开始工作前，必须执行以下流程：**

1. **评估**：确认可用技能，评估本次委托是否有对应的技能
2. **启动**：如果有对应技能，使用 Skill 工具启动后再开始工作
3. **执行**：按照技能的步骤推进工作

```
ユーザーの依頼
    ↓
スキルを評価（該当するものがあるか？）
    ↓
YES → Skill ツールで起動 → スキルの手順に従う
NO  → 通常の推論で対応
```

## 技能层级结构

技能以 `skills/<name>/SKILL.md` 为主体，必要时在 `references/` 下放置辅助文件，为扁平化结构。完整的分发技能一览和说明，请参见下方"全技能类别一览"（从 `skills/*/SKILL.md` 自动生成）。

**使用方法：**
1. 使用 Skill 工具启动与委托对应的技能
2. 技能根据用户意图加载适当的 `references/`
3. 按照步骤执行工作

## 全技能类别一览

下表从 `skills/*/SKILL.md` 的 frontmatter 自动生成。请勿手动编辑，运行 `harness gen docs` 更新（`harness gen docs --check` 用于 CI 固定）。

<!-- BEGIN GENERATED SKILL CATALOG (harness gen docs) -->
<!-- Auto-generated from skills/*/SKILL.md frontmatter. Do not edit by hand; run `harness gen docs`. -->

## 技能目录一览

| 技能 | 说明 |
|--------|------|
| agent-browser | 通过 repo agent-browser CLI 进行浏览器自动化。导航、表单、截图、抓取和 Web 应用检查的明确辅助工具。优先使用 Browser Use 或 Playwright（如果可用）。不要加载用于：分享 URL、嵌入链接或编辑截图文件。 |
| breezing | 团队执行模式——带有团队编排的 harness-work 向后兼容别名。Composer/composer 2.5 映射到 cursor 后端。 |
| cc-update-review | Claude/Codex 更新集成的质量防护栏。检测仅文档的 Feature Table 添加并要求实现或明确规划。仅供内部使用。 |
| ci | CI 红了？找我们。流水线消防队部署。用户提到 CI 失败、构建错误、测试失败或流水线问题时使用。不要加载用于：本地构建、标准实现工作、审查或设置。 |
| cursor-ask | 对 cursor-agent (Composer) 的只读委托，用于问题调查、设计讨论和对抗性合理性检查。无 worktree、无 cherry-pick、无 Lead diff 审查——cursor-agent 锁定在 ask 模式，无法写入。用户说：ask cursor、cursor sanity check、get a second opinion、adversarial review、design discussion、investigate with cursor、cursor:ask 时使用。不要加载用于：实现、重构、文件编辑、commit/push 工作或任何需要写访问权限的操作（改用 cursor:do 或 breezing --cursor）。 |
| cursor-do | 通过 cursor-companion.sh 在隔离 worktree 中委托单个写任务给 Cursor Composer，然后 Lead 审查 diff 并 cherry-pick。用户调用 cursor:do、说 delegate to cursor、have composer write it、refactor with cursor、hand a file edit to Composer 时使用。不要加载用于：规划、仅代码审查、只读调查或多任务团队运行（改用 breezing --cursor 或 cursor:ask）。 |
| cursor-review | 将 Cursor Composer 审查作为咨询性第二意见运行，同时将主要审查裁决保留在 host brain。用户调用 cursor:review、要求 Cursor 审查或希望 composer 对 diff 进行合理性检查时使用。Cursor 绝不拥有 APPROVE/REQUEST_CHANGES。 |
| cursor-setup | 为 Claude Code Harness 配置和验证 Cursor 后端。用户调用 cursor:setup、希望将 Cursor 作为本地默认实现后端或询问 Cursor 插件/代理就绪状态时使用。分发默认设置保持为 opt-in；只有当明确请求时才更改本地 env/user 设置。 |
| failure-codifier | 从 breezing 编排日志和 Judgment Ledger 中提取重复失败模式，发出带置信度分数的 failure-rule.v1 提案。patterns.md 或 decisions.md 的 SSOT 升级仅为提案——需要人工审批。用户提到 failure codifier、failure patterns、self-learning loop、codify failures 或 failure-rule proposals 时使用。不要加载用于：直接 SSOT 编辑、自动升级或与失败分析无关的实现。 |
| harness-accept | 在 ship/wait/reject 决策之前为非工程师 vibecoder 生成验收演示 HTML。读取由 harness-plan-brief 存储为 personal-preference.v1 的验收标准（通过 user_request_hash 连接），然后渲染单文件 HTML，显示每项标准为已验证或未验证，并附上 ship/wait/reject 推荐。用户要求验收审查、想决定是否交付任务或说：acceptance demo、accept demo、`受け入れ判断`、`受入レビュー`、ship/wait/reject 判定、`検収レビュー` 时使用。不要加载用于：实现、代码审查或发布工作。 |
| harness-loop | 使用 /loop（Claude Code 动态模式）和 ScheduleWakeup 重新进入的长时间任务循环，在每次唤醒时带新鲜上下文。内部通过 Agent 调用 harness-work。触发：long-running、loop、wake-up、autonomous。不要加载用于：一次性任务执行、审查、发布或规划。 |
| harness-plan | HAR：基于研究的、经团队验证的任务规划，Plans.md 管理，进度同步。触发：create a plan、add tasks、update Plans.md、mark complete、check progress。不要加载用于：实现、审查或发布。 |
| harness-plan-brief | 在实现开始前为非工程师 vibecoder 生成计划简报 HTML。搜索 harness-mem（仅项目）查找相关过去的决策、模式和 Plans 存档条目，然后渲染单文件 HTML 工件，总结理解、选项、风险、验收标准和置信度。用户请求规划预览、批准前的非工程师友好摘要或说：plan brief、planning preview、`計画概要`、`計画レビュー` 时使用。不要加载用于：实际实现、代码审查或发布工作。 |
| harness-progress | 为非工程师 vibecoder 生成进度追踪器 HTML 以便一览会话进度（cc:WIP / cc:TODO / cc:完了 计数、百分比、已用/预估分钟数、迄今成本/估算、偏离警报）。使用 Plans.md 作为真相来源，渲染带自动再生支持的单文件 HTML。用户询问进度概览、会话状态快照、dashboard 或说：progress tracker、`進捗確認`、`進捗ボード`、dashboard 时使用。不要加载用于：实际实现、代码审查或发布工作。 |
| harness-release | 使用 Keep a Changelog + GitHub 的通用发布自动化。单一确认门，然后端到端自动化：bump 检测、CHANGELOG 升级、PR/main 合并、tag、GitHub Release。触发：release、version bump、publish。不要加载用于：实现、审查、规划或设置。 |
| harness-review | HAR：多角度代码、计划、范围审查。安全/质量检查。触发：review、code review、plan review、scope analysis。不要加载用于：实现、新功能、bugfix、设置或发布。 |
| harness-setup | HAR：项目初始化、工具设置、代理配置、memory 设置、skill mirror 同步。触发：setup、init、new project、CI/Codex setup、harness-mem、mirror。不要加载用于：实现、审查、发布或规划。 |
| harness-sync | HAR：Plans.md 与实现同步。漂移检测、标记更新、回顾。触发：sync-status、where am I、check progress。--snapshot 用于快照。不要加载用于：规划、实现、审查或发布。 |
| harness-work | HAR：从单个任务到完整并行团队运行执行 Plans.md 任务。触发：implement、execute、do everything、breezing、team run、parallel、composer、composer 2.5。不要加载用于：规划、审查、发布或设置。 |
| japanese-writing-drafter | 检测操作员在会话中期纠正代理的日语措辞（重写句子、指出文体问题、说"这种表述不好，像这样改"）并将待处理的写作规则提案起草到 ~/.claude/writing-lint/proposals.jsonl 供后续人工审查。此技能是 proposals.jsonl 的唯一写入者——它从不编辑 rules.jsonl 也从不将状态设置为 pending 以外的内容。升级到 rules.jsonl 仅通过人工运行的 scripts/writing-rule-approve.sh 进行。用户提到 writing-rule proposal、`表現を直して`、`文体を直して`、`その言い方はNG`、writing lint 提案、`指摘をルール化して` 时使用。不要加载用于：批准或拒绝提案（使用 scripts/writing-rule-approve.sh）、列出待处理提案（使用 scripts/writing-rule-list.sh）或扫描文本是否符合现有词典（writinglint 引擎 / PostToolUse 钩子执行此操作）。 |
| maintenance | 文件清理和归档。整理臃肿的 Plans.md、session-log.md、旧日志和状态文件。触发：/maintenance、cleanup、archive、organize、split session-log。不要加载用于：实现、审查、发布或新功能开发。 |
| memory | 管理 SSOT、memory 和跨工具 memory 搜索。decisions.md 和 patterns.md 的守护者。用户提到 memory、SSOT、decisions.md、patterns.md、merging、migration、SSOT promotion、sync memory、save learnings、memory search、harness-mem、past decisions 或 record this 时使用。不要加载用于：实现工作、审查、临时笔记或会话内日志记录。 |
| session-send | 当用户要求通知其他会话、请求会话交接、说 tell other agent 或需要跨会话消息时，应使用此技能。 |

<!-- END GENERATED SKILL CATALOG (harness gen docs) -->

## 开发用技能（不公开）

以下技能为开发/实验用，不包含在仓库中（.gitignore 排除）：

```
skills/
├── test-*/      # テスト用スキル
└── x-promo/     # X投稿作成スキル（開発用）
```

这些技能仅在单独的開発环境中使用，不包含在插件分发中。

## 相关文档

- [CLAUDE.md](../CLAUDE.md) - 项目开发指南（概述）
- [docs/CLAUDE-feature-table.md](./CLAUDE-feature-table.md) - Claude Code 新功能运用表
- [docs/CLAUDE-commands.md](./CLAUDE-commands.md) - 主要命令一览
- [.claude/rules/skill-editing.md](../.claude/rules/skill-editing.md) - 技能文件编辑规则
