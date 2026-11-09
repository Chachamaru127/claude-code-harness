# Opus 4.7 影响整理

一句话总结： 在 Opus 4.7 中，`literal instruction following` 和 `xhigh`、
`/ultrareview`、Auto Mode 扩展对 Harness 来说是实务上的关键，需要重写 docs・agents・skills 的前提。

打个比方： 这是同一个驾驶员，但车的方向盘反应变灵敏了。因为转
弯比之前更精准，若指示依然含糊，也就更容易径直朝非预期方向前进。

## 如何阅读本文档

- 一手信息是 `Claude Code 2.1.111` changelog 和 Phase 44 的计划
- 整理出与 Opus 4.7 相关的、Harness 应当关注的 8 个项目
- `有影响` 表示 Harness 侧需要明确跟随
- `无影响` 表示自动继承或不在本次 scope 内

## 8 个项目的映射

| 項目 | 影響 | 影響箇所 | 対応方針 |
|------|------|----------|----------|
| literal instruction following | 有影响 | `agents/`, `skills/`, `CLAUDE.md`, docs | 减少模糊表述，将判断条件具体化 |
| `xhigh` effort | 有影响 | `skills/`, `agents/`, `docs/effort-level-policy.md` | 明确记录作为正式对象的采用判断 |
| task budgets | 有影响 | docs, 将来的 `skills/` | 本 phase 仅作为调查备忘。不立即实现 |
| tokenizer 改善 | 无影响 | 整体 | 作为本体改善自动继承 |
| vision 2576px | 有影响 | review 系 docs / references | 明确记载高分辨率 review 的运用上限 |
| memory 改善 | 有影响 | `session-memory`, docs | 更新长时 session 与恢复质量的说明 |
| `/ultrareview` | 有影响 | `skills/harness-review/`, docs | 明确记载与 `harness-review` 的关系而非竞争 |
| Auto Mode 拡大 | 有影响 | docs, guardrails 方针 | 舍弃 `--enable-auto-mode` 前提 |

## 分项备忘

### 1. literal instruction following

- Opus 4.7 相比「大致补全含糊指示」，更倾向「按写下来的内容忠实执行」
- 因此在 Harness 的 agent prompt 中，需要把以下内容更加具体化
  - 何时停止
  - 报告什么
  - 触碰哪些文件
  - 禁止什么

具体例子： 「按需确认」相比「只在破坏性操
作之前确认」，与 Opus 4.7 更契合。

### 2. `xhigh` effort

- `xhigh` 位于 `high` 和 `max` 之间
- 在 docs 侧作为正式对象处理，而非「暂缓候选」
- 但 Claude Code frontmatter 与 API effort 的对应关系不保证始终一致，因此需要运用策略文档

### 3. task budgets

- task budgets 很有吸引力，但 Harness 已经有 `max_consults` 和 cost 管理
- 贸然引入容易造成双重管理，因此在 Phase 44 中止步于研究备忘是妥当的

### 4. tokenizer 改善

- 这是同样内容 token 消耗略有改善方向的改进
- 不需要 Harness 独自的代码改动，因此在 docs 中作为「自动继承」处理

### 5. vision 2576px

- 图片 review 中可安全处理的上限放宽后，设计图和 PDF 的读取精度会提高
- 但这并非「越大越好」，超过上限时的事前 resize 运用仍然必要

### 6. memory 改善

- 对长对话的恢复质量和长时运行的稳定性有效果
- 在 Harness 中，需要让 `session-memory` 和 long-running docs 的说明与现实相符

### 7. `/ultrareview`

- `/ultrareview` 是在 cloud 上运行多 agent 并行 review 的专用 review
- 与 Harness 的 `/harness-review` 角色略有不同
- Harness 侧的价值如下
  - 与 Plans.md 联动
  - sprint contract / scope review
  - Codex adversarial review

也就是说，这不是「删掉哪一个」的问题，而是「何时用哪一个」的问题。

### 8. Auto Mode 拡大

- 在 `2.1.111` 中，Auto Mode 不再以 `--enable-auto-mode` 为前提
- 因此若 docs 中残留旧的启用步骤，就会造成误导
- 本次 docs 更新中舍弃这一前提

## 对 Harness 的结论

| 領域 | 結論 |
|------|------|
| docs | 最优先更新 |
| agents | 减少模糊表述，对应 literal |
| skills | 明确记录 `xhigh` 和 `/ultrareview` 的处理方式 |
| hooks / guardrails | 更新 Auto Mode 与 permission 周边的说明 |
| code | 像 tokenizer 这样的本体收益不要强行触碰 |

## 为什么采取这一方针

Opus 4.7 的变化本质上是「能做的事稍微变多了」之外，「与指示打交道的
方式变了」。 因此，首先改正 docs 和 prompt 设计，性价比最高。

---

## Phase 44 追溯表

以便反查 Phase 44 的各子 phase 分别负责上述 8 个项目中的哪一个。 与 `Plans.md`
的 Phase 44 定义以及 `docs/cc-2.1.99-2.1.110-impact.md` 保持一致。

| # | 项目 | 影响权重 | 主负责 Phase | 辅助 Phase |
|---|------|---------|------------|-----------|
| 1 | literal instruction following | **High** | **44.4.1 (agents)** + **44.4.2 (skills)** | 44.11.1 (Feature Table 追記) |
| 2 | `xhigh` effort | Medium | **44.5.1** | 44.11.1 |
| 3 | task budgets (public beta) | Low | **44.10.1**（仅调查） | — |
| 4 | tokenizer 1.0-1.35× | Low | —（自动继承） | 并入 44.6.1 的 1h cache 效果测定 / 在 44.11.1 补 1 段 |
| 5 | vision 2576px | Low | **44.9.1 (Optional)** | 44.11.1 |
| 6 | file-system memory 强化 | Medium | **44.4.1**（归入 agent memory 描述的 audit） | 下个周期的 memory 维护 |
| 7 | `/ultrareview` | Medium | **44.8.1** | 44.7.1 (built-in slash via Skill tool) |
| 8 | Auto Mode 扩大 | Low | —（本 Phase 不采用） | 44.12.1（仅在 smoke test 中确认行为） |

### 最優先着手点

**44.4（literal prompt re-tune）最为优先**。在 Opus 4.7 中，4.6 时代被隐式补全的行为最可能崩坏。其他项目即使延后也不会致命，但放着 44.4 不做，Worker / Reviewer / Advisor 的行为会变得不稳定。

### 44.4 执行指引

1. **用 grep 列出模糊用语**: 在 `agents/` 和 `skills/` 下搜索 `いい感じに` / `必要に応じて` / `適切に` / `ちゃんと` / `なるべく` / `可能であれば` / `良しなに` / `自動的に`
2. **逐条替换列举结果**: 替换为具体的判断基准（阈值・marker・文件名・命令名）
3. **化为 audit checklist**: 在 `.claude/rules/opus-4-7-prompt-audit.md` 中记录 before/after 示例和剩余项
4. **同步 Codex mirror**: `agents-codex/` 和 `skills-codex/` 也按同一标准整理

### 本 Phase 明确不触碰的内容

以下虽与 Opus 4.7 相关，但作为 Phase 44
的射程之外。 留待后续 Phase 或下一个发布周期再讨论。

- **Task Budgets 的正式采用** — 因为是 public beta，放到下个周期
- **全面切换到 Auto Mode** — 因为读不出行为差异，维持 `bypassPermissions`
- **`decisions.md` / `patterns.md` 的全面维护** — 在下个 memory 维护周期处理
- **将新模型 ID 作为 Harness 默认** — 不做对 `claude-opus-4-7` 的显式 frontmatter 固定。遵从 CC 的 model picker / config

---

## 参照

- 一手信息: https://www.anthropic.com/news/claude-opus-4-7
- Claude Code 侧的变化: [cc-2.1.99-2.1.110-impact.md](./cc-2.1.99-2.1.110-impact.md)
- Phase 44 定义: [../Plans.md](../Plans.md) 的 "Phase 44: Opus 4.7 / Claude Code 2.1.99-2.1.110 追従"
- 分类规则: [../.claude/rules/cc-update-policy.md](../.claude/rules/cc-update-policy.md)
