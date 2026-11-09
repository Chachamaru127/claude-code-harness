# Claude Code 2.1.99-2.1.111 影响整理

简言之：
作为 Phase 44 的 docs 判断，对 `2.1.99` 到 `2.1.111` 的公开 changelog 进行了盘点，
将 Harness 的影响分类为 `A` 和 `C`，结果是 `B` 为 `0` 件。

打个比方：
就像收到一个新的工具箱时，"直接能用的工具"和"需要自己改造把手或收纳才能用的工具"进行分类整理的笔记。

## 前提

- 一次信息使用 Anthropic 公开 `claude-code` 仓库的 `CHANGELOG.md`
- 本文的分类是为了与 Phase 44 的计划对应
- `A`：Harness 侧需要显式追从的项目
- `C`：仅 Claude Code 本体更新就获得收益的项目
- `B`："仅写入"本次为 `0`

## 摘要

| 范围 | 判断 | 补充 |
|------|------|------|
| `2.1.99`, `2.1.100`, `2.1.102`, `2.1.103`, `2.1.104`, `2.1.106` | `C` | 公开 changelog 上无单独项目。Phase 44 中无追加对象 |
| `2.1.101` | `C` | 以 UX 改善和稳定性修复为主，Harness 固有代码追加不需要 |
| `2.1.105` | `A` | `PreCompact` hook 和 `monitors` manifest 需要 Harness 侧集成 |
| `2.1.107` | `C` | thinking 显示改善。Harness 自动继承 |
| `2.1.108` | `A` / `C` 混在 | 1 小时 prompt cache 需要显式追从，其他基本自动继承 |
| `2.1.109` | `C` | 仅 thinking indicator 改善 |
| `2.1.110` | `A` / `C` 混在 | permission 重新评估相关需要显式追从，其他基本自动继承 |
| `2.1.111` | `A` / `C` 混在 | `xhigh`、`/ultrareview`、Auto Mode flag 废除需要正式追从 |

## 版本别一览

| Version | 主要变更 | Harness 影响 | 分类 | Phase 44 追溯 |
|---------|----------|--------------|------|-------------------|
| `2.1.99` | 公开 changelog 上无单独项目 | 作为范围起点确认。Harness 无单独对应 | `C` | - |
| `2.1.100` | 公开 changelog 上无单独项目 | 无追加追从 | `C` | - |
| `2.1.101` | `/team-onboarding`、OS CA trust、`/ultraplan` 初始环境自动化、resume 稳定化等 | 现有 workflow 直接受益。Phase 44 无需新代码 | `C` | - |
| `2.1.102` | 公开 changelog 上无单独项目 | 无追加追从 | `C` | - |
| `2.1.103` | 公开 changelog 上无单独项目 | 无追加追从 | `C` | - |
| `2.1.104` | 公开 changelog 上无单独项目 | 无追加追从 | `C` | - |
| `2.1.105` | `PreCompact` hook、plugin `monitors` manifest、`/proactive` alias 等 | 需要在 `hooks.json` 和 plugin manifest 中实现集成 | `A` | `44.2.1`, `44.2.2` |
| `2.1.106` | 公开 changelog 上无单独项目 | 无追加追从 | `C` | - |
| `2.1.107` | thinking indicator 改善 | 自动继承显示改善 | `C` | - |
| `2.1.108` | `ENABLE_PROMPT_CACHING_1H`、recap、built-in slash command discovery 等 | 1 小时 cache 需要运维策略整備。其他基本自动继承 | `A/C` | `44.6.1`, `44.7.1` |
| `2.1.109` | extended-thinking indicator 改善 | 仅 UI 上的受益。无需追从代码 | `C` | - |
| `2.1.110` | permission deny 重新评估修复、`PreToolUse.additionalContext` 修复、`/tui`、resume/scheduled task 等 | 需要 guardrail 重新验证和 docs 更新。其他 UX 改善自动继承 | `A/C` | `44.3.1`, `44.11.1` |
| `2.1.111` | `xhigh`、`/ultrareview`、Auto mode no longer requires flag、`/effort` slider 等 | `xhigh` 和 `/ultrareview` 是正式追从对象。Auto Mode 的前提措辞也需要更新 | `A/C` | `44.5.1`, `44.8.1`, `44.11.1` |

## 重点备注

### `2.1.105`

- `PreCompact` hook 直接关系到 Harness 的长时间执行保护
- `monitors` manifest 是将 monitor 系脚本从"后加"变为"启动时自动 arm"的起点
- 两者都创造了 Harness 的附加值，所以是 `A`

### `2.1.108`

- `ENABLE_PROMPT_CACHING_1H` 不仅仅是能用，还需要"在哪个流程中启用"的政策
- 因此归为带 docs 和 policy 的 `A`
- 另一方面，recap 和 slash command discovery 的大部分是本体受益，所以是 `C`

### `2.1.110`

- `permissions.deny` 的重新评估修复直接影响 Harness 的 guardrail 说明和期望行为
- 不是"CC 修复了就结束"，还需要更新 Harness 的说明和测试观点，所以是 `A/C` 混在

### `2.1.111`

- `xhigh` 不是见外，而是正式对象
- `/ultrareview` 也不是见外，而是正式对象
- `Auto mode no longer requires --enable-auto-mode` 是为了不将 Auto Mode 的 docs 前提保持旧状的显式追从对象

## B 为零的理由

- 没有公开 changelog 的版本"不强行赋予意义来增加行数"
- 仅本体改善就结束的归为 `C`
- 仅将与 Harness 的判断/措辞/设置/hook 相关的归为 `A`

通过这种切分，避免了"仅写入 Feature Table"的 `B` 的产生。

## 具体例子

具体例子：
`2.1.111` 的 `xhigh` 不是简单地增加了新的 effort 名称。在 Harness 侧会影响 reviewer/advisor 的 thinking 强度政策和 docs 的说明，所以作为 `A` 处理。

## 为什么要这样整理

Phase 44 的目的不是"对 CC 的 changelog 进行摘要"，而是"明确 Harness 自己持有哪部分"。
