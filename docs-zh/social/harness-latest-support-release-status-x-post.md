# 如实梳理 Harness 现状的文章

## X 文章标题候选

1. Claude 已支持最新版，Codex 追到哪里了。如实梳理 Harness 的现状
2. AI 编码运维，不夸张才更有力。Harness 的 release 状态与最新版本支持
3. Claude 已支持到最新。Codex 追到了哪里，由 Harness 如实说明
4. 不说「完美」。梳理 Harness 的 release 状态与最新版本支持

## 采用标题

Claude 已支持最新版，Codex 追到哪里了。如实梳理 Harness 的现状

## 导语

在 AI 编码工具的宣传中，很容易想强调「已支持最新」「完全支持」「没有回归」。

但我认为，真正能赢得信任的，是把**确认到了哪里、从哪里开始还不能断言**分开来说。

这次在 Harness 中，

- release 能让人放心到什么程度
- 是否能看到回归
- Claude 是否已支持到最新
- Codex 反映到了什么程度

我重新确认了这些。

结果是，Claude 侧可以相当有把握地说「已支持最新」。另一方面，Codex 侧虽然已经看过最新 stable 并完成了重要的梳理，但还没到可以断言「完全支持」的阶段。

本文会从用户视角把这个差异讲清楚。

## 1. 先说结论

现在的结论可以归纳为以下 4 行。

- release 是相当好的状态
- 没有看到已知的回归
- Claude 可以说已支持到最新
- Codex 虽然已看过最新 stable 并做了反映，但还不说完全追随

这种说法可能显得保守。

但我认为，这类工具比起稍微夸大，**如实说出确认到了哪里，才能被更长久地信任**。

## 2. release「相当好」，但不说「完美」

首先是 release 的状态。

Harness 现在已经推进到 `v3.15.0`，工作树也是干净的状态。而且最近的 `validate-plugin` 是 success。

只看这里，会想说「已经完美了」。

但实际上，在那之前也有过 failure。

这时重要的是，

- 最新的确认结果是好的
- 但最近的历史里混有失败

这两点都要说。

也就是说，release 的观感准确来说是，

- 不是危险状态
- 也不是不能发布的状态
- 但也不能说「一直完全无缺地全绿」

Harness 在这里不会为了好看而抹平。

## 3. 有没有回归

回归是指「以前能运行的，因为这次的变更而坏掉」。

就目前的证据来看，**没有看到已知的回归**。

通过的是例如以下确认。

- 整个 plugin 的验证
- upstream 集成点的验证
- reactive hook runtime 的验证
- sync-plugin-cache 的验证
- AI residuals，即确认 AI 生成感的残骸或危险的遗留物

这些都通过了。

不过，这里也不过度断言。

即使自动测试通过，如果没有把

- 实际的最新 CLI
- 实际的长作业流程
- Claude 与 Codex 两条路径

全部 end-to-end 走一遍，那么不说「绝对没有回归」会更安全。

所以作为表述，

> 基于自动验证，没有看到回归

是最准确的。

## 4. 对从 Claude 使用 Harness 的人来说，可以说已支持最新

这里可以相当积极地表述。

在确认 Claude Code 最新 changelog 的基础上，Harness 已吸收了 `2.1.80` 到 `2.1.86` 的重要更新。

特别起作用的是以下部分。

### 4-1. 日常操作稍微变轻了

使用 `2.1.85` 的 hooks conditional `if`，将 permission hook 收窄到「偏安全的 Bash」。

由此，

- `git status`
- `git diff`
- `pytest`
- `npm run lint`

这类操作中，无谓的 hook 评价减少了。

并不显眼，但因为每天都要用，所以有效。

### 4-2. 更不容易看丢前提的变化了

吸收了 `TaskCreated`、`FileChanged`、`CwdChanged` 的 hook，记录 Plans、规则、设置、worktree 切换的变化，并能促使重新确认。

这样就能减少，

- 沿用旧 Plans 直接实现
- 明明换到了别的 worktree 却按之前的前提推进
- 没注意到规则变更就继续作业

这类偏差。

### 4-3. 也加强了安全性

已将 `sandbox.failIfUnavailable` 和 `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` 纳入设置。

通俗地说，就是

- sandbox 不可用就不要在危险状态下继续
- 不要向后台进程传递过多认证信息

这样的改善。

也就是说，对从 Claude 使用 Harness 的人来说，可以说**不仅追上了最新功能，还转换成了在日常开发中有效的形态**。

## 5. 对从 Codex 使用 Harness 的人来说，「进展很大，但还不说完全追随」才准确

这里需要稍微细致地说明。

查看 Codex 的最新 releases，包含 pre-release 的话有更新的版本，但 stable 的最新是 `0.117.0`。

在 Harness 中，看过这个 `0.117.0` 后，

- 哪些是价值高的更新
- 哪些应该立刻吸收
- 哪些应该在下一阶段做

进行了梳理。

这次在 Codex 侧起作用的主要是以下部分。

### 5-1. 重流程的初动稳定了

整理了 skill 的 `effort` 和 agent 的 `initialPrompt`，让重作业从一开始就更容易深入思考。

这在

- 实现
- 评审
- release

这类遗漏成本很高的场景中有效。

### 5-2. mirror 与运用记录齐备了

Codex 与 OpenCode 的 mirror 侧也做了更新，文档和测试的说明也一并对齐了。

这类一致性并不显眼，但能减少

- 只有一边是旧的
- 文档与实现错位
- 不同入口的前提不一致

这类事故。

不过，这里重要的是下一点。

作为 Codex 侧的重要论点看到的

- plugin-first workflow
- resume 时的 reasoning effort continuity

仍然作为「下一步强烈建议吸收的价值很高的项目」保留着。

所以关于 Codex，

> 已看过 latest stable 并完成了重要的梳理。  
> 但断言完全支持还为时过早。

是最诚实的说法。

## 6. 为什么反而用显得保守的说法

理由很简单。

在 AI 编码基盘中，如果把

- 真正确认过的事
- 还没确认的事
- 已经可用的东西
- 今后应该扩展的东西

混在一起说，之后一定会陷入困境。

用户想知道的，比起漂亮的宣传语，更是

- 现在能否放心使用
- 哪里还需要注意
- 下一步什么会变强

Harness 会用不含糊的方式来说明这些。

## 总结

用一句话概括现在的 Harness，

**Claude 可以相当有把握地说已支持最新，Codex 已看过 latest stable 并在前进，但还有下一阶段**。

关于 release 也是，

**状态相当好，但不说完美。回归在当前的自动验证中没有看到，但也不断言绝对为零。**

这种说法并不华丽。

但我认为，这样的诚实对运维工具来说更强。

## 简短告知文

如实梳理了 Harness 的现状。

- Claude 已相当有把握地支持到最新
- Codex 已看过 latest stable 并在前进中
- release 是相当好的状态
- 回归在自动验证中没有看到

但不轻率地说「完美」「完全支持」。  
包括这条界线在内写成了文章。

## Thread 方案

### 1/6

AI 编码类的宣传，很容易想说「已支持最新」「完全支持」。

但真正重要的，我认为是把
确认到了哪里、
从哪里开始还不能断言、
分开来说。

如实梳理了 Harness 的现状。

### 2/6

先说结论，

- release 是相当好的状态
- 没有看到已知的回归
- Claude 可以说已支持到最新
- Codex 已看过 latest stable 并做了反映，但还不说完全追随

就是这样。

### 3/6

Claude 侧可以相当积极地表述。

吸收了 2.1.80〜2.1.86 的重要更新，
- 减少 permission hook 的无谓开销
- 用 reactive hook 减少看丢前提变化
- 用 sandbox / env scrub 提升安全性

已经连接到这一步。

### 4/6

Codex 侧不会说「全部做到了」。

看过 latest stable 后，
- skill / agent 的初动品质
- mirror 一致性
- 下一步应吸收的价值轴

已经梳理完成。

但 plugin-first 和 resume continuity 是下一阶段。

### 5/6

关于回归，

基于自动验证没有看到。

但是，
不会说到
「绝对为零」
这一步。

我认为这类基础工具，在这里不夸大才能被更长久地信任。

### 6/6

比起华丽的说法，

- 现在能否放心使用
- 哪里还需要注意
- 下一步什么会变强

能说明这些的内容更重要。

Harness 的现状，就是以这样的形式写成了文章。

## 封面图 prompt

以白底为基础的高分辨率科技风信息图。中央是大标题「Claude Latest, Codex In Progress, Honest Release Status」。左侧「Claude 2.1.86 Ready」，右侧「Codex 0.117 Stable Tracked」。中央下方是「Release: Strong, Not Overclaimed」的横幅。三张卡片分别写「Latest Support」「No Known Regression in Automated Checks」「Honest Boundaries」。整体干净、有未来感，像 SaaS 发布资料那样整齐的氛围。配色为白、深蓝、青绿，辅色用一点橙色。文字易读，即使缩小显示也不糊。1:1，留白较多，噪点较少，不过度夸张。

## alt 文本

整理了 Claude 已支持最新、Codex 正在追踪 stable 最新、release 相当好但不过度宣称这 3 点的信息图。
