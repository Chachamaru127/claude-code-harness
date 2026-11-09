# 将 Claude Code 2.1.80-2.1.84 引入 Harness 的故事

## X文章标题候选

Claude Code 的更新，Harness 是如何"放大"的

## 引言

Claude Code 的 2.1.80〜2.1.84 在 hooks、skill frontmatter、agent frontmatter、安全设置、rules 适用范围内有重要更新。

这次在 Harness 中做的，不是简单地列举"对应了新功能"。
而是将 Claude Code 本身变好的部分，连接到实际开发流程，变成更强效的形式。

换句话说，Claude Code 单体变好 10 的地方，通过加入 Harness 变成了 15 或 20 的增强。

这篇文章中，Claude Code 侧增加了什么，Harness 侧如何引入，结果了什么变好了，用非专家也能理解的方式总结。

## 1. 本次的主题不是"追从"而是"放大"

AI 开发工具的更新，容易以"新功能增加了"结束。

但实际上对新功能本身，
- 如何连接到日常实现
- 如何在团队运用中减少事故
- 如何不每次调整 prompt 就能稳定

更重要。

Harness 就是为此而存在的层。不是原封不动地接收 Claude Code 的新功能，而是连接到计划、实现、review、安全装置、规则运用，带到对日常开发体验有效的程度。

## 2. Claude Code 侧的更新和 Harness 侧的引入

### 2-1. 将新的 hooks 变为开发中的注意唤起

首先是 hooks。hooks 是"某事件发生的瞬间自动运行什么"的机制。

Claude Code 的 2.1.83 和 2.1.84 中，可以处理以下事件：

- `TaskCreated`
- `CwdChanged`
- `FileChanged`

仅看这些，是"事件增加了"的说法。

Harness 在此连接了新的 reactive hook。

- task 被创建了就记录
- `Plans.md` 变了就在下次实现前促重新读取
- 规则或设置变了就通知前提已变
- 移到 worktree 或其他工作场所就促重新确认上下文

也就是说，将"可以取得事件"的状态，变成了"不易遗漏前提变化"的状态。

由此减少：
- 按旧计划继续实现
- 移到其他 worktree 却以旧前提继续
- 没注意到规则更新就继续作业

### 2-2. 将安全设置变为自动对使用者有效的形式

接下来是安全相关。

Claude Code 2.1.83 中加入了特别有价值的设置：

- `sandbox.failIfUnavailable`
- `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`

用浅显的话说：
- sandbox 不能用的话就不在危险状态下继续
- 尽量不向 Bash 和 hook、联动进程传递认证信息

Harness 中不仅"可以设置"，还作为插件默认值编入。并在分发缓存同步中也反映了，带到了安装后在实际运营中真正有效的程度。

这个差异很大。

有新功能的话，不自己设置就不会生效。但编入 Harness 的话，"不知不觉中忘记使用安全功能"减少了。

### 2-3. 在重作业中从一开始就加深思考

Claude Code 2.1.80 中，skill frontmatter 可以带 `effort` 了。

frontmatter 是写在 Markdown 文件开头的设置栏。`effort` 是"思考多深"的指定。

Harness 将此分配到了主要 skill：

- `harness-work`：高
- `harness-review`：高
- `harness-release`：高
- `harness-plan`：中
- `harness-sync`：中
- `harness-setup`：中

这次更新的好处是，不用每次说"这次请深入思考"，就能根据作业性质提高初始思考密度。

特别是 review 和 release 这样遗漏成本高的场景有效。

### 2-4. 稳定化 subagent 的初始动作

Claude Code 2.1.83 中，agent 可以带 `initialPrompt` 了。

这是能在 subagent 启动的瞬间，预先给予"应该优先考虑什么"的机制。

Harness 中：
- Worker
- Reviewer
- Scaffolder

加入了初始动作指示。

例如：
- Worker 首先整理 task、DoD、目标文件、验证方针
- Reviewer 首先确认 verdict 的基准，不混淆 minor 和 major
- Scaffolder 首先整理现有构成和本次设置目的

由此减少了 subagent 一开始就走偏方向的风险。

### 2-5. 将 rules 的适用范围内变成不易损坏的写法

Claude Code 2.1.84 中，rules 和 skills 的 `paths:` 可以使用 YAML 数组了。

之前多个目标模式用 1 行字符串持有，
- 难读
- 难追加
- 容易因逗号或空白损坏

Harness 更新了 template 和 `localize-rules.sh`，将 `paths:` 移到了 YAML 数组。

外观朴素，但这个变更有效果：
- 适用范围更容易读
- 将来更容易追加
- 自动生成时的事故减少

## 3. 结果，什么变好了

将以上用非专家的方式总结，本次变好的是以下 5 点：

- 前提变化时更容易注意到
- 安全设置不仅能设置，在实际运营中也更容易生效
- 重作业中从一开始就更容易深入思考
- subagent 不容易偏离角色
- 规则运用更容易读，不容易损坏

都不是外观变化大的东西。但每天使用会有差异的部分。

正因为如此，本次更新不是"Claude Code 新功能增加了"，而是"用 Harness 将那个改善变成了实际开发强度"最接近。

## 4. 本次特意没有扩大的东西

本次范围内，没有以相同重量全部引入。

理由简单，即使 Claude Code 侧变好了，通过 Harness 介入能进一步放大的项目和放大不了的项目是存在的。

本次优先的是：
- reactive hooks
- 安全设置
- skill / agent 的初始动作质量
- rules 的可维护性

这些"直接关系到 Harness 特长领域"的项目。

## 总结

Claude Code 2.1.80〜2.1.84 的更新本身有价值。

但通过加入 Harness，有的东西变成了"对开发流程有效的形态"。

本次更新正是瞄准了那里。

不是原封不动地接收 Claude Code 变好的部分，而是连接到实现、review、安全、运用的层，变得更强地可用。

这就是本次 Harness 侧的更新。

## 文章封面图像 prompt

以白色背景为基础的高分辨率科技系信息图。中央大标题"Harness Amplifies Claude Code Updates"。左"Claude Code 2.1.80-2.1.84"、右"Harness"。从中央到右 5 根强箭头。5 张卡片分别"Reactive Hooks""Safer Sandbox""Skill Effort""Agent Initial Prompt""YAML Paths"。整体干净、未来感、编辑设计、SaaS 产品发布氛围。配色白、深蓝、蓝绿、少量橙色。文字易读，信息整理明晰，作为 X 文章封面图像也美观，缩小显示也不崩溃。1:1，余白宽，噪点少，图标最少，不过度夸张的高雅设计。

## 封面图像内文本候选

Claude Code Updates
Amplified by Harness

- Reactive Hooks
- Safer Sandbox
- Better Agent Starts
- Deeper Skill Execution
- More Reliable Rules

## alt 文本

表示 Claude Code 更新被 Harness 放大的信息图。5 个项目 Reactive Hooks、Safer Sandbox、Skill Effort、Agent Initial Prompt、YAML Paths 被整理。

## 用于文章共享的简短告知文

将 Claude Code 2.1.80〜2.1.84 引入了 Harness。
本次的主题不是"追从"而是"放大"。

从新的 hooks、安全设置到 skill / agent 的初始动作、rules 适用范围内，连接到了对实际运营有效的形态。
整理成了文章。
