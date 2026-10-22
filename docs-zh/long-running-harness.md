# 长时间任务执行指南

本文档是关于在 Claude Code 中安全地推进 **一次无法完成的工作** 的实务指南。
这里所说的「长时间任务」，是指使用 `/loop` 和 `ScheduleWakeup` 逐步推进的工作。
本文档是 Phase 41.4.1 的产出物。

对象是 **Phase 41 的同一会话内运营**。跨 host 的自动再入在这一阶段不予处理。

参考: [skills/harness-loop/SKILL.md](../skills/harness-loop/SKILL.md) / [skills/harness-loop/references/flow.md](../skills/harness-loop/references/flow.md) / [docs/CLAUDE-feature-table.md](CLAUDE-feature-table.md)

---

## 1. 先把握整体图景

长时间任务通过反复执行以下 4 步来推进：

1. 决定现在要做的那 1 个工作单元
2. 小规模地实现或确认
3. 将结果作为 checkpoint 记录下来
4. 预约下一次 wake-up

这里最重要的是 **每次都以「新的视角」重新进入**。
不是把上一次的对话原样拖下来，而是用 resume pack 只重新注入必要的信息来恢复。

### 以 B1-B12 的 12 个轴看的对应表

| 轴 | 决定什么 | 在 Harness 中的应对 |
|---|---|---|
| B1 | 想达成什么 | 阅读 Plans.md 的目标任务和 DoD |
| B2 | 一次做到哪里 | 以 1 周期 = 1 个任务单位推进 |
| B3 | 从哪里开始 | 以 `/loop` 作为入口 |
| B4 | 如何恢复 | 用 `ScheduleWakeup` 预约下次 wake-up |
| B5 | 传递什么 | 用 `harness-mem resume-pack` 只取回必要信息 |
| B6 | 等多久 | 用 `pacing` 选择间隔 |
| B7 | 何时停止 | 用 `--max-cycles` 设置上限 |
| B8 | 如何避免冲突 | 用 lock 和幂等性 guard 防止多重启动 |
| B9 | 如何记录进度 | 用 `harness_mem_record_checkpoint` 记录 checkpoint |
| B10 | 是否顺利推进 | 用 plateau 检测找出停滞 |
| B11 | 范围到哪里 | Phase 41 限定在同一会话内 |
| B12 | 注意什么 | 理解 `bypassPermissions` 和 Plans.md flock 的局限 |

---

## 2. `/loop` + `ScheduleWakeup` 的用法

`/loop` 是向 Claude Code 传达「以继续工作为前提」的入口。
`ScheduleWakeup` 是预约下次恢复时刻的机制。

### 用法基础

```text
/loop all
/loop 41.1-41.3 --pacing ci
/loop all --pacing night
```

### 一次流程

1. 从 `Plans.md` 选出 1 个下一个目标任务
2. 只执行该任务所需的最小工作
3. 留下 checkpoint
4. 用 `ScheduleWakeup` 预约下一次 wake-up

### 预约的样貌

```text
ScheduleWakeup(
  delaySeconds=270,
  prompt="/harness-loop all --cycles-done 1 --pacing worker",
  reason="1 サイクル完了。次のタスクに進むため"
)
```

`delaySeconds` 是「多少秒后回来」。
太短会显得匆忙，太长则容易忘记上一次的流程。
实际上会控制在 60 〜 3600 秒的范围内。

---

## 3. pacing 预设的选择

`pacing` 是距下次 wake-up 间隔多久的设置。

| pacing | delaySeconds | 适用场景 | 一句话说明 |
|---|---:|---|---|
| `worker` | 270 | 想紧接着上一项工作继续 | 标准设置 |
| `ci` | 270 | 有等待 CI 结果的情况 | 保持较短的等待时间 |
| `plateau` | 1200 | 容易停滞不前的情况 | 稍微冷却得久一些 |
| `night` | 3600 | 想在夜间集中推进 | 最长的等待时间 |

### cache 边界的思路

Claude Code 有一个只能短暂记住最近流程的「短期缓存」。
`worker` 和 `ci` 的 270 秒，仍是能搭上这个短期缓存的长度。

另一方面，`plateau` 和 `night` 比较容易导致短期缓存失效，因此 **以 resume pack 为前提** 更安全。
也就是说，等待时间越长，就越应把设计倾向「重新注入必要信息」，而不是「靠自力回想」。

### 使用 1 小时缓存时

Claude Code `2.1.108` 之后，加上 `ENABLE_PROMPT_CACHING_1H=1` 即可 opt-in 比常规 5 分钟缓存更长的 **1 小时缓存**。

这适合「每次几乎都要重读相同前提，但下一次输入往往超过 5 分钟」的情形。
在本文档处理的长时任务中，它尤其适合以下场景：

1. 使用 `/harness-loop` 时每个周期都有等待
2. 跨越 `/resume` 或 `/continue` 反复使用相同前提
3. 中间穿插审查或 advisor consult，返回时超过 5 分钟

反之，若只是持续几十秒到几分钟的短往返，保留默认的 5 分钟缓存即已足够。

### 1h vs 5m cache 的选择基准

| 判定轴 | 选择 1h cache | 5m cache（默认）即可满足 |
|--------|----------------|------------------------|
| 预计会话长度 | **超过 30 分钟** | 30 分钟以内 |
| wake-up 间隔 | `plateau`（1200s）或 `night`（3600s） | `worker`/`ci`（270s） |
| 前提信息的复用 | 每个周期几乎都读同样的 SKILL.md・Plans.md | 前提每次都变的短往返 |
| 目标 skill | `/breezing` / `/harness-loop` 的多任务执行 | 单次的 `/work` 或对话 |

**判定规则**: 若预计会话长度 **超过 30 分钟**，则选择 1h cache。其他情况用默认的 5 分钟 cache 即可。

opt-in 步骤：

```bash
bash scripts/enable-1h-cache.sh
```

此命令会把 `ENABLE_PROMPT_CACHING_1H=1` 追加到 `env.local`（幂等）。
不会更改全局设置。已设置过的情况下不做任何事。

### 推荐的引入方针

在本 repo 中，**不做全会话常开**。
理由是 1 小时缓存虽然便利，但前提是额外成本，对短对话而言容易过度。

取而代之，使用长时任务专用的轻量启动 wrapper。

```bash
bash scripts/claude-longrun.sh
```

也可以直接传参：

```bash
bash scripts/claude-longrun.sh --resume
bash scripts/claude-longrun.sh --model claude-opus-4-6
```

此脚本只是内部加上 `ENABLE_PROMPT_CACHING_1H=1` 来启动 `claude`。
它不更改全局设置，因此不会扩大对常规工作的影响。

### 向子进程继承 env（与 Codex CLI 联动）

在通过 `/breezing --codex` 或 `scripts/codex-companion.sh task --write` 调用 Codex CLI 的情况下，
需要确认 `ENABLE_PROMPT_CACHING_1H` 是否会被子进程继承。

| 路径 | 是否继承 | 注意点 |
|------|------------|--------|
| `bash scripts/codex-companion.sh task --write "..."` | 是 | 常规 bash subprocess 会继承父 env |
| `bash scripts/codex-companion.sh review --base "${REF}"` | 是 | 同上 |
| `claude-longrun.sh` 启动的父进程 | 是 | scripts 在内部 export 后再启动 claude |
| `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` 生效时 | **有可能被 scrub** | 需要设计成 scrub 目标 env 列表不包含 `ENABLE_PROMPT_CACHING_1H` |

`.claude-plugin/settings.json` 中的 `env.CLAUDE_CODE_SUBPROCESS_ENV_SCRUB="1"` 目的是清除 subprocess 的污染性环境变量，
因此像 `ENABLE_PROMPT_CACHING_1H` 这样 Claude Code 自身的行为控制 env 本应被保留。
新增 hook script 或 wrapper 时，请显式保留 `export ENABLE_PROMPT_CACHING_1H`，或
采用不通过 `env -i bash` 丢弃 env 的实现。

---

## 4. wake-up 次数上限・lock・幂等性 guard

长时间任务可能在不知不觉中让同一处理被重复执行两次。
为防止这一点，用 3 层来守护。

### 4-1. 次数上限

用 `--max-cycles` 决定最多继续几次。
达到上限后，就在那里先停一下。

### 4-2. lock

为避免同一任务同时运行两次，获取 lock。
在本 repo 中使用 `.claude/state/locks/loop-session.lock.d`。

lock 是「这里已经在运行了」的标记。
如果已经存在 lock，新的执行就会停止。
这样可以防止并行执行造成的竞争。

### 4-3. 幂等性 guard

幂等性是指同一操作做两次也不会损坏的性质。
先放入像 `tests/validate-plugin.sh --quick` 这样的轻量检查，可以避免在损坏状态下勉强推进。

此外，lock 必须在结束时一定清理。
无论正常结束还是异常结束，都是为了不让残留影响下一次。

---

## 5. plateau 检测与 golden fixture

plateau 是看似在工作推进、实际上却在同一处打转的状态。
例如反复重复同一修正、判断材料没有增加却只是增加了再执行次数时，就会发生。

### 阈值的思路

实际判定要看 `scripts/detect-review-plateau.sh` 的结果。
在这里，比起「失败几次就停止」，更重视 **是否有新信息增加**。

### 什么应该做成 fixture

为防止回归的 golden fixture，放在 `tests/fixtures/` 下比较直观。
例如做成 `tests/fixtures/long-running-harness/` 这样长时任务专用的归类，会更容易找到。
特别是 plateau 相关的部分，固定化以下情形会很有帮助：

1. 失败原因每次都相同的 case
2. 即使改变条件判定也不变的 case
3. 看似在推进、实际停滞的 case

fixture 是「这个判定今后也应如此」的样本。
有了它，以后改动逻辑时更容易确认停滞检测没有被破坏。

---

## 6. Phase 41 的范围

本 Phase 41 处理的是 **在同一个 Claude Code 会话内完成的长时任务**。

要做的事收敛为以下 2 点。

1. 能在当前会话内安全地再入
2. 即使跨越 wake-up 也能继续同一项工作

不做的是跨 host 的自动再入。
那是将来 Phase 42 及以后再考虑的范围。

---

## 7. 已知约束

### 与 `bypassPermissions` 的关系

`/loop` 不是增加权限的机制。
它是在已有权限 guard 的前提下运作。
也就是说，即使使用 `bypassPermissions`，危险操作也不会变得无限制。

在长时间任务中，反而「不擅自做强硬的事」更重要。
只做必要的操作，只在必要的时机，只做必要的次数。

### Plans.md flock 的局限

`Plans.md` 可能有多个执行主体接触。
因此设计成用 flock 排队等待，但这是 **为了避免同时写坏同一文件** 的机制，并非万能。

特别是当别的会话或别的进程正在同时读取时，看到的状态有时会稍有延迟。
因此，读取 `Plans.md` 时应带着「现在看到的内容未必是最新的」这一前提，并与 checkpoint 和 contract 一同判断。

---

## 8. 快速查看链接

- 执行流程的详细说明: [skills/harness-loop/references/flow.md](../skills/harness-loop/references/flow.md)
- 命令入口: [skills/harness-loop/SKILL.md](../skills/harness-loop/SKILL.md)
- Claude Code 的功能一览: [docs/CLAUDE-feature-table.md](CLAUDE-feature-table.md)

> **Note (v4.2.0+)**: `HARNESS_WEBHOOK_URL` 作为环境变量设置。`harness.toml` 的 `[telemetry] webhook_url` 已废弃（2026-04-18 dead config 整理）。
