# `/ultrareview` 与 `/harness-review` 的协作方针

Phase 44.8.1 确定的方针文档。

---

## 1. `/ultrareview` 的行为

`/ultrareview` 是 Claude Code 2.1.111 新增的 **built-in slash command**。
Claude Code 2.1.120 以后，还提供了供 CI 或 script 使用的
`claude ultrareview [target] --json`。

| 属性 | 内容 |
|------|------|
| 会话类型 | single-turn dedicated review session |
| 执行主体 | CC 原生（Harness agent 之外） |
| 输入 | 当前工作树差分（自动收集） |
| 输出 | 内联的自然语言评审结果 |
| 输出 schema | 未定义（CC 内部格式） |
| CLI 入口 | `claude ultrareview [target] --json`（用于 CI / ad-hoc second-opinion） |
| Plans.md 联动 | 无 |
| sprint-contract 验证 | 无 |
| Codex adversarial review | 无 |
| Reviewer agent 调用 | 无 |

`/ultrareview` 是「用户直接向 CC 请求 ad-hoc 评审」的 entrypoint，
在 Harness 的自动化流程（Plan → Work → Review）之外运行。
`claude ultrareview [target] --json` 也处于相同定位，是从 CI 辅助调用的入口，
并非 `/harness-review` 的替代。

---

## 2. 与 `/harness-review` 的差异

| 视角 | `/ultrareview` | `/harness-review` |
|------|----------------|-------------------|
| 执行主体 | CC 原生 | Harness skill (context: fork) |
| 会话 | single-turn | multi-step（Step 0〜4） |
| Plans.md 联动 | 无 | 有（cc:WIP 确认・cc:完了 更新） |
| sprint-contract 验证 | 无 | 有（`.claude/state/contracts/<task>.sprint-contract.json`） |
| Codex adversarial review | 无 | 有（`--dual` flag 时） |
| Reviewer agent | 无 | 有（`reviewer` agent、输出 `review-result.v1`） |
| 输出 schema | 非定义 | `review-result.v1`（机器可读 JSON） |
| AI Residuals 扫描 | 无 | 有（`scripts/review-ai-residuals.sh`） |
| 修正循环 | 无 | 有（REQUEST_CHANGES 时、最多 3 次） |
| Security 专用模式 | 无 | 有（`--security`、OWASP Top 10） |
| UI Rubric 模式 | 无 | 有（`--ui-rubric`、4 轴评分） |
| 目标用户 | 用户直接使用 | Lead / breezing 流程的自动调用 |

### 2.1 `claude ultrareview [target] --json` 的定位

`claude ultrareview [target] --json` 是非交互 CI 或手边 script 调用
CC 原生 ad-hoc review 的 CLI 入口。

Harness 中按如下方式处理。

| 用途 | 判断 |
|------|------|
| PR CI 中的辅助评审 | 可使用。作为 second-opinion 对待 |
| `/harness-review --dual` 的替代 | 不可。不替换 Codex adversarial review 与 `review-result.v1` |
| REQUEST_CHANGES 修正循环的判定 | 不可。输出 schema 不是 Harness 契约 |
| 在手边粗略查看大差分 | 可使用。作为 ad-hoc review 对待 |

---

## 3. 确定方针: **(B) 优先 `/harness-review` — Harness flow 内不调用 `/ultrareview`**

### 3.1 rationale

**与维持的纪律的一致性**: `.claude/rules/claude-5-prompt-standard.md` 规定
「`/ultrareview` 是调用侧的 review entrypoint。agent 定义侧以 `review-result.v1` 为契约」。
Harness 的 Reviewer agent・harness-review skill 以 `review-result.v1` 为输出契约。
在其中调用 `/ultrareview`，会丧失 `review-result.v1` 的机器可读保证。

**schema 不一致**: `/ultrareview` 的输出是 CC 内部格式，
不包含 `review-result.v1` 的 `verdict`、`critical_issues`、`major_issues` 字段。
Harness 的修正循环・commit guard・sprint-contract 验证全部依赖 `review-result.v1`，
而 schema 转换的开销无法被正当化。

**职责分离**: `/ultrareview` 是用户向 CC 进行 ad-hoc 请求的 entrypoint。
Harness flow 内的自动评审由 `reviewer` agent（`review-result.v1`）和
`codex-companion.sh review` 覆盖。两者用途不同，并存没有问题。

**回退的安全性**: `codex-companion.sh review` 不可用时，
回退到 `reviewer` agent（static / runtime / browser profile）。
追加 `/ultrareview` 会增加回退路径，使调试变得困难。

### 3.2 使用区分指南

| 场景 | 推荐命令 |
|--------|------------|
| PR 合并前的综合确认（Harness 外） | `/ultrareview` |
| CI 中的辅助 second-opinion | `claude ultrareview [target] --json` |
| Harness Plan→Work 后的自动评审 | `/harness-review`（自动调用） |
| 附带 Codex 第二意见的评审 | `/harness-review --dual` |
| 安全集中审计 | `/harness-review --security` |
| UI 品质评分 | `/harness-review --ui-rubric` |

---

## 4. 今后的应对

- `/ultrareview` 在作为 CC built-in 成熟的阶段再评估（下次评估 Phase: 45 以后）
- 在 Harness 内调用 `/ultrareview`，需等到向 `review-result.v1` 的 schema 转换层
  在 `scripts/codex-companion.sh` 中实现之后（现阶段未实现）
- 方针变更与 `.claude/rules/claude-5-prompt-standard.md`（维持的纪律 5）的修订同时进行

---

*决定: Phase 44.8.1 / 2026-04-18*
