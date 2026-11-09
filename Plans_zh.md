# Claude Code Harness — Plans.md

最终归档：2026-07-23（Phase 62-116 → `.claude/memory/archive/Plans-2026-07-23-phase62-116.md`）
上次归档：2026-05-29（Phase 80/81/82/84 → `.claude/memory/archive/Plans-2026-05-29-phase80-84.md`）

---

## North Star（3 层志向）

整个 task ledger 所指向的到达点。按由旧到新排列（地基 → 顶点）。详细契约以 `spec.md` 为正本，这里只是参照块。

- **L1 专注判断**：AI 准备 plan / 实现 / 比较 / 验证 evidence，operator（人类）只做最终判断（`spec.md` Purpose / Users And Workflows）。
- **L2 工具无关（tool-agnostic）**：同一 Harness（R01-R13 guardrails + plan/work/review/release）在 Claude / Codex / Cursor 的「任何一方」都有效。1 个 policy engine 通过 native hook 裁决 3 个 host（是 routing 而非复制）。两个方向同等支持 — #1 由 harness 驱动（Lead 把其他工具 spawn 为 engine）/ #2 由 host 发起使用（从 Codex/Cursor「使用」harness）（`spec.md` Execution Backend Contract / Host Adapter）。
- **L3 协作（collaboration，将来的主战场）**：多个工具协作驱动同一项目，人类不再充当复制粘贴的快递员。Mode 1 = 完全自主编排（v1 固定 Lead=Claude，Codex/Cursor 没有对外 spawn API）。Mode 2 = 人类在席的 peer co-drive（live notice messaging）。完整的 peer-Lead 协作分阶段引入、暂时后置（Phase 92 Purpose / `spec.md` Mode 1/Mode 2）。

> ~~已知 follow-up: delivery hook gen 未接线~~ **已解决 (2026-07-21 更正)**：`GenerateDeliveryHooksJSON` 早在 Phase 105.9 [b82143fe] 就已接入 `harness gen`（这条备忘本身已经 stale）。identity placeholder no-op 在 Phase 121.2（`--from-env` runtime 解析）解决，Claude host 的 Stop 接线在 Phase 121.3 添加。Mode 2 的 turn 边界 delivery 会投递到 3 个 host（live monitor 是 opt-in、默认 OFF）。

---

## 📦 归档

已完成的 Phase 已切出到以下文件（git history 中也有留存）:

- [Phase 62-116](.claude/memory/archive/Plans-2026-07-23-phase62-116.md) — 追随 CC 2.1.112+ / 3-surface HTML / backend resolver + Cursor 升级 / Session Coordination / Zero-Base Redesign + Plan B stage a-c (Phase 92-103) / S1-S5 gate + v5.0.0-v5.1.0 发布线 (Phase 104-114) / LSP 接线 / test-wiring auditor。Breezing 自律完走契约 (2026-06-12 批准) 作为运用规约保留在本文件中
- [Phase 80/81/82/84](.claude/memory/archive/Plans-2026-05-29-phase80-84.md) — Claude 2.1.143-2.1.152 + Codex 0.131-0.134 upstream refresh / Cursor CCH Adapter candidate / cursor-agent CLI workflow smoke 验证 (candidate, 未分发) / harness-review closeout fixes + Cursor ACP boundary record
- [Phase 63/64/66-71/73-76/78/79](.claude/memory/archive/Plans-2026-05-29-phase63-79.md) — 整理 stale harness-mem 引用 / Plans archive-aware / 3-surface HTML 跨项目安全相关 / Open Issue 收尾 / Codex 0.130 / harness-review TeamAgent + 轻量版 / Hokage Core 边界 / R03 break-glass / Superpowers tool-first onboarding / repo-health gates / README 前门 / spec.md+Plans.md 共需 / Dependabot benchmark / harness-plan team gates
- [Phase 47-61](.claude/memory/archive/Plans-2026-05-08-phase47-61.md) — Session Monitor 主动监视 / XR-003 / 3-state 依赖测试规约 / 追随 CC 2.1.112-2.1.126 + Codex 0.121-0.128 upstream / Issue #105 English default + Japanese opt-in / External Issue 收尾 / Skill orchestration 设计契约 / harness-mem managed companion (v4.6.0-v4.7.0) / Sandbagging-Aware Weak-Supervision Harness
- [Phase 44 + 45 + 46](.claude/memory/archive/Plans-2026-04-19-phase44-46.md) — Opus 4.7 / 追随 CC 2.1.99-110 "Arcana" (v4.2.0) + Plugin Manifest 官方规范 + Worker 3 层防御 (#84-#87, v4.3.0)
- [Phase 37 + 41 + 42 + 43](.claude/memory/archive/Plans-2026-04-17-phase37-41-42-43.md) — Hokage 完整形态 / Long-Running Harness / Go hot-path 迁移 / Advisor Strategy
- [Phase 39 + 40 + 41.0](.claude/memory/archive/Plans-2026-04-15-phase39-40-41.0.md) — 评审体验改善 / Migration Residue Scanner / Long-Running Harness Spike

---

## 标记凡例

PM ↔ Impl 运用中使用的标准标记:

| 标记 | 含义 | 由谁添加 |
|---------|------|-----------|
| `pm:requested` / `pm:依頼中` | PM 已起票任务并向 Impl 委托 | PM |
| `cc:todo` / `cc:TODO` | Impl 未开始的任务 | Impl |
| `cc:wip` / `cc:WIP` | Impl（Claude Code）正在处理 | Impl |
| `cc:done` / `cc:完了` | Impl 已完成作业，等待 PM 确认 | Impl |
| `pm:approved` / `pm:確認済` | PM 已完成最终确认 | PM |
| `cc:withdrawn` | Impl 自主撤下的任务（superseded / 被别的任务吸收）。breezing 不 pickup cc:withdrawn | Impl |

**状态迁移**：新建与更新时的正规输出是 `pm:requested → cc:todo → cc:wip → cc:done → pm:approved`。既有的 `pm:依頼中 → cc:TODO → cc:WIP → cc:完了 → pm:確認済` 也保持 read-compatible。`cc:withdrawn` 是 terminal state（不再恢复）。

**向后兼容**：`cursor:依頼中` / `cursor:確認済` 视为 `pm:依頼中` / `pm:確認済` 的同义词（Cursor PM 运用时的写法）。

---

## Breezing 自律完走契约（2026-06-12 用户批准 — 实现章节运用规约）

为使 `/breezing all --cursor` **在没有中途人类判断的情况下跑完实现章节**而定的运用规约。基于用户指示（2026-06-12「中途被问到会答不上来，希望实现部分先做完。评审和检查之后一起做」）的事先批准记录。

**范围 2 分割**:
- **实现章节**（breezing 完跑对象）: 93.1.1 / 93.1.2 / 93.2.1 / 93.3.1-93.3.5 / 92.5.1-92.5.3 / 92.6.1-92.6.4 / 95.1.1-95.1.3 / 95.2.1-95.2.3 / 95.4.1 / 96.1.1-96.1.4 ＋ 旧 backlog（88.1 / 88.3 / 72.1.2-72.1.6 / 83.7）
- **验证章节**（用户 review 窗口，breezing 不触碰）: 93.3.6 / 95.5.1 / 96.1.5 / 96.1.6（均为 `[lane:release]` e2e・公开发布声明更新）＋ Phase 94（92.4.x，属 user GO 待定 scope 之外）

**mid-run 禁止提问 + 分支默认值**:
- 实现章节进行中不使用 AskUserQuestion。分支按以下默认值推进
- review REQUEST_CHANGES → 最多修 3 次 → 仍未收敛则在 Status 记 `blocked(理由)` 并 **继续下一个任务**（不停止）
- companion 启动失败 → 重试 1 次 → 仍失败则 blocked 并继续
- blocked 清单汇总到最终报告，交给用户 review

**Risk Gate 事先批准**（92.6.4 / 96.1.4，依据 2026-06-12 用户指示）: breezing 可以不停下来直接实现。但必须严格遵守 3 个条件：(i) 不改变 default-OFF / opt-in 设计（auto-approve 即使在 96.1.3 实现后也保持默认 OFF），(ii) 不向真实用户设置文件（`~/.claude/settings*.json`・真实 repo 的 `.claude/settings.local.json`）实际写入，只在 fixture/tempdir 内的 test 中验证，(iii) 不伴随 5 类 floor・fingerprint 封堵・deny 规则的弱化。需要偏离时只把那个任务标 blocked 后继续。

**共享文件 lane**（Invariant 1 运用）: 编辑 `skills/harness-work/` / `skills/breezing/` / `agents/*.md` 的任务要 **作为 prose lane 串行**: 92.5.3 → 88.1 → 88.3 → 72.1.2 → 72.1.3 → 72.1.4 → 72.1.5 → 72.1.6。可与 Go core lane（92.5.1-2 / 92.6.x / 95.1.x / 95.2.x / 96.1.x）并行。93.3.1 / 93.3.4 也会触碰 breezing/review SKILL，因此不与 prose lane 任务同时执行。`Plans.md` / `CHANGELOG.md` / `spec.md` 禁止 worker 编辑（由 Lead 在集成时编辑）。

**推荐 wave 顺序**（Depends 已对齐）: W1: 93.1.1 ∥ 93.1.2 ∥ 93.2.1 ∥ 83.7 → W2: 93.3.1 → (93.3.2 ∥ 93.3.4) → 93.3.3 → 93.3.5 → W3: 92.5.1 → 92.5.2 → 92.5.3 → W4: 92.6.1 → 92.6.2 → (92.6.3 ∥ 92.6.4) ∥ prose lane（88.1 → 88.3 → 72.1.2-72.1.6） → W5: (95.1.1 → 95.1.2 → 95.1.3) ∥ (95.2.2 → 95.2.1) → 95.2.3 → 95.4.1 → W6: (96.1.1 ∥ 96.1.4) → 96.1.2 → 96.1.3

**结束条件**: 实现章节的全部任务都是 `cc:done` 或 `blocked(理由)`。最终报告 = 全部 commit hash + blocked 清单 + 向验证章节（93.3.6 → 95.5.1 → 96.1.5 → 96.1.6）交接的步骤。

---


## Archived Phases

Phase 132-133 (2026-08-10 〜 2026-08-14、全 task `cc:done`) 已退避到
[.claude/memory/archive/Plans-2026-08-14-phase132-133.md](.claude/memory/archive/Plans-2026-08-14-phase132-133.md)。
其中经验已升级到 decisions.md D58-D61 与 patterns.md P41-P43。

Phase 125-131 (2026-07-26 〜 2026-08-08、全 task `cc:done`) 已退避到
[.claude/memory/archive/Plans-2026-08-08-phase125-131.md](.claude/memory/archive/Plans-2026-08-08-phase125-131.md)。
Phase 130 未作为 task 表起票，只在 CHANGELOG `[Unreleased]` 中记录。

Phase 119-124 (2026-07-19 〜 2026-07-25、全 task `cc:done`) 已退避到
[.claude/memory/archive/Plans-2026-07-30-phase119-124.md](.claude/memory/archive/Plans-2026-07-30-phase119-124.md)。
更早之前请参照 `.claude/memory/archive/Plans-*.md`。

## Phase 134: 验证链路接线修复 — HOTL 本体实现 (2026-08-15 起票)

**Purpose**: Phase 101 (U0-U7 验证 spike、全 `cc:done`) 的后续本体实现。验证机制大部分已实现，但在 3 处接缝断开: 入口（`reviewer_profile` 默认 `static`、risk_flags 不自动升级）/ 中间（`PENDING_BROWSER` 在 `combine_verdict()` 中无声降级）/ 出口（`harness-accept` 不机械读取执行 artifact，而由 LLM 重新申报）。此外 scope leash (`go/internal/scopeleash/`) 仍停留在 standalone spike 状态未接线。外部来源（Matt Pocock 的 evals 思想 / mugi_uno 的 Playwright Screencast / `しまぶー` 的再调查循环）的承接处。设计正本: `~/.claude/plans/cch-users-tachibanashuuta-downloads-ai-lively-eclipse.md`。

**设计原则**: (1) 增加 evidence 种类时，必须同时定义获取不到时的降级规则（在 Accept surface 上如何呈现）。(2) 每处接线都要附带「证明其在生效的观测点」(D58「接线了 ≠ 在生效」)。(3) fail-visible: 未验证不阻止，但也不当作 passed 处理，而是把 recommendation 倒向 wait/reject 一侧。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 134.1 | `[lane:gate]` 入口: risk_flags → reviewer_profile 自动升级 + ratchet。把升级表（security-sensitive→runtime 以上 / ux-regression→browser 以上 / data-migration→runtime 以上，强弱顺序 static<runtime<browser）实现到 `scripts/enrich-sprint-contract.sh` 的 `--risk` handler。在 `scripts/ensure-sprint-contract-ready.sh` 的 `--approve` 时重算最低 profile，低于则 fail-closed (exit 5)。故意固定为 static 时必须带 `--profile-override-reason`，并记入 `review.reviewer_notes` | (a) RED: 实测现状——仅 `--risk security-sensitive` 就能让 approve 放行 → 修正后 exit 5, (b) `--risk security-sensitive` → approve 时 profile 自动升到 runtime 以上 (jq 确认), (c) 升级表以外的 flag（例如 perf-sensitive）profile 不变的 negative test, (d) `bash tests/validate-plugin.sh` PASS | - | cc:done [c771707d; 升级表 + ratchet exit 5。RED 实测（仅 risk 就能让 approve 放行）→ GREEN。negative: perf-sensitive 不变] |
| 134.2 | `[lane:gate]` fail-visible producer: 在 `scripts/write-review-result.sh` 中加入 `pending_validations: [{layer, reason}]` 数组（additive、v1 兼容）。`browser_verdict` 为 PENDING_BROWSER/SKIPPED/DOWNGRADE_TO_STATIC 时累积 `{layer:"browser"}`，runtime artifact 为 SKIPPED 且 profile≠static 时累积 `{layer:"runtime"}`。不改 `combine_verdict()` 的 verdict 词汇 | (a) RED: 实测现状输出中没有 `pending_validations` 键, (b) PENDING_BROWSER fixture 下 `pending_validations[0].layer=="browser"`, (c) APPROVE/APPROVE 通常情形下 `pending_validations: []` 的 regression test, (d) 既有的 write-review-result 系测试 PASS | - | cc:done [c771707d; pending_validations additive 追加。PENDING_BROWSER/SKIPPED/DOWNGRADE_TO_STATIC 时记录 layer、APPROVE 通常系为 [] 的回归 test 附带] |
| 134.3 | `[lane:fast]` worker-report.v1 的持久化: 在 `agents/worker.md` 的完成时协议中补记「self_review 全部项目 `verified: true` + evidence 非空后，在 commit 之前 Write 到 `.claude/state/review/<task-id>.worker-report.json`」。残留 `verified: false` 时不写。镜像同步 | (a) worker.md 明确写出持久化步骤与命名规则, (b) `bash scripts/sync-skill-mirrors.sh --check` PASS（若有 agents 镜像则同步）, (c) `bash scripts/ci/check-consistency.sh` PASS | - | cc:done [c771707d; worker.md 中补记了 .claude/state/review/<task-id>.worker-report.json 的持久化步骤。残留 verified:false 时不写] |
| 134.4 | `[lane:gate]` 出口的 evidence 机械连接: 新增 `scripts/accept-collect-evidence.sh <task-id>`（read-only），读取 4 个 artifact（`.claude/state/review/<task-id>.worker-report.json` / `.claude/state/review-result.json` [仅 task.id 一致时采用] / `<task-id>.runtime-review.json` / `<task-id>.browser-result.json`）并返回规范化的 JSON。把 `skills/harness-accept/SKILL.md` 的 Step 4 改写为「从 artifact 引用（不创造新主张）。artifact 缺失或命中 pending_validations 的 criteria 记 `passed: false` + 把实际状态转记到 evidence + 追加 `unverified_caveats`」。在 Recommendation 逻辑中加入「命中 pending 的 criteria 有 1 条以上就不 ship（归并到 wait）」 | (a) artifact 齐备的任务中 evidence 变为对 artifact 的引用, (b) PENDING_BROWSER 状态下命中 criteria `passed: false` + recommendation 不为 ship, (c) 缺 worker-report 的旧任务也不报错退出、而是返回「无命中」的兼容 test, (d) acceptance-context.v1 schema 非破坏性 | 134.2, 134.3 | cc:done [c771707d; accept-collect-evidence.sh（read-only、task.id 新鲜度检查）。SKILL.md Step 4 改写为 artifact 引用 + pending 前缀规约。pending 修正后即使 80% 也归并为 wait（fixture 实测 RED→GREEN）] |
| 134.5 | `[lane:gate]` `[tdd:required]` scope leash 接线（U0 本体实现、开始 advisory）: 在生成 `go/internal/hookhandler/sprint_contract.go` 时调用 `scopeleash.InferScopeFromPlan`，把 `declared_scope` 烘焙进 sprint-contract.json。在 `go/internal/guardrail/pre_tool.go` 的 runtimefloor block 之后追加 Write/Edit/MultiEdit 的 scope 判定: `harness.toml [scope_leash] enforce_level = off\|warn\|enforce`（默认 warn）、空 scope 立即 skip、warn 时记录 `.claude/state/scope-leash.jsonl` + additionalContext、enforce 时 deny。DroppedScope 通过扩展既有 stop-evaluator handler 做 advisory 通知（不新注册 hook） | (a) declared_scope 在生成合同时被填入, (b) RED→GREEN: 实测接线前不生成 scope-leash.jsonl → warn 时被记录, (c) 仅 enforce 时 deny 的 positive/negative test, (d) 空 scope 完全不触发的误触发防止 test, (e) `cd go && go test ./...` PASS + gofmt/vet clean | - | cc:done [c771707d; declared_scope 烘焙 + evaluatePreTool 的 warn/enforce 判定（空 scope skip）。scope-leash.jsonl 记录与 enforce deny 经 test 实测。DroppedScope 走 stop-evaluator 扩展] |
| 134.6 | `[lane:fast]` Playwright Screencast evidence: 在 `scripts/browser-review-runner.sh` 的 playwright route 执行之后搜索 `test-results/**/*.webm`，把 `artifacts: [{kind:"video", path}]` 装入 `browser-review-result.v1`。降级规则: 没有录像 → `kind:"text"` + note「可能未设置 use.video」/ 非 playwright route → `artifacts: []`。`accept-collect-evidence.sh` 把 `kind:"video"` 导入 `demo_artifacts`，并在 `templates/html/accept.html.template` 中增加 video 渲染分支 | (a) 有录像时 `artifacts[].kind=="video"`, (b) 无录像时 `kind:"text"` + note（降级规则实测）, (c) Accept HTML 中出现 video 嵌入/链接的 render test | 134.2, 134.4 | cc:done [c771707d; playwright route 搜索 *.webm → artifacts[].kind=video、降级（无录像=text+note / 其他 route=[]）。accept HTML 嵌入 video。3 分支 fixture 实测] |
| 134.7 | `[lane:fast]` `[tdd:skip:docs-only]` 再调查循环: 在 harness-plan 的任务方案确定前一刻 + harness-review 的 verdict 确定前一刻，各插入一次「彻底再调查是否有更好的方案（也一并考虑 1 个圈外的另一系方案），没有就维持推荐方案」。阈值逻辑不变更。镜像同步 | (a) 对应 reference 中记载的再调查 1 次步骤与 Step 编号体系保持一致, (b) `bash scripts/sync-skill-mirrors.sh --check` PASS | - | cc:done [c771707d; 在 harness-plan / harness-review 中插入再调查 1 次（含圈外方案 1 个）。阈值逻辑不变更、mirror 已同步] |
| 134.8 | `[lane:gate]` 验证的验证: 新设 `scripts/ci/check-verification-chain-wiring.sh`（scopeleash import [go list -deps] / pending_validations 存在 / SKILL.md 的 collect-evidence 调用 / 升级表 / ratchet 共 5 点）。实效性契约测试 3 本: `tests/test-risk-flag-escalation.sh` / `tests/test-pending-browser-visible.sh`（PENDING_BROWSER → passed:false → 不 ship 的 end-to-end）/ `tests/test-scope-leash-fires-on-security-diff.sh`（向真实二进制投入 payload，实测 warn 记录 / enforce deny）。在 `tests/validate-plugin.sh` 中增加 section | (a) 3 本契约测试附接线前 RED / 接线后 GREEN 的实测记录, (b) `bash tests/validate-plugin.sh` 整体 PASS, (c) `bash scripts/ci/check-consistency.sh` PASS | 134.1-134.6 | cc:done [c771707d; check-verification-chain-wiring.sh（5 点）+ 3 本契约测试接线到 validate-plugin.sh section 22。各测试 RED（复现缺失）→ GREEN 实测。binary 重新构建后以真实二进制 probe] |

## Phase 135: 日语 writing lint (2026-08-15 起票)

**Purpose**: 把 yugen_matuni 方式（PostToolUse 在写入后立即照合 NG 模式 → 以 advisory 返回「整句重写 + 好模式」、在 Stop 时整体再检查、从指摘自动起草规则 → 人类一键批准）实现到 CCH。引擎 = CCH (`go/internal/writinglint/`)、字典数据 = 个人层 (`~/.claude/writing-lint/rules.jsonl`) 的分离。保持 failure-codifier 的人类批准原则（提案自动、升级只经人类 CLI）。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 135.1 | `[lane:gate]` `[tdd:required]` writinglint 引擎 + writing-rule.v1 schema: 在 `go/internal/writinglint/` 中实现 rule.go (id/pattern/good/scenes/enabled/severity) / dict.go (JSONL 载入 + 路径解析: config `writing_lint.dict_path` > env `CLAUDE_WRITING_LINT_DICT` > `~/.claude/writing-lint/rules.jsonl`) / scan.go (`ScanText`: 按 scene 筛选 → 正则照合) / structural.go (句末 3 连、敬体常体混用的纯函数)。新建 `templates/schemas/writing-rule.v1.json` | (a) 字典 fixture 的命中/scene 筛选/句末 3 连/混用 的 positive・negative fixture 测试 green, (b) `cd go && go test ./internal/writinglint/...` PASS + gofmt/vet clean | - | cc:done [c771707d; writinglint 包 (rule/dict/scan/structural) + writing-rule.v1。fixture positive/negative green] |
| 135.2 | `[lane:gate]` PostToolUse handler: `go/internal/hookhandler/posttooluse_writing_lint.go`（quality_pack 型）。对象为含平假名的 `.md`/`.txt`。专用排除表（`docs/` 计入对象，不复用 quality_pack 的 isExcludedPath）。config `writing_lint.enabled`（默认 false）/ `scene` / `structural`。additionalContext 中给出「整句重写 + 好模式」上限 5 条 + 明确超出数量、未检出字典时只诊断一次。advisory（固定 exit 0）。在 `main.go` 加 `case "writing-lint":`，并接入 hooks.json 2 个文件 + `sync-plugin-cache.sh` | (a) 字典命中的 `.md` fixture 中 additionalContext 出现警告 + 好模式, (b) `.go`/`.ts` 被 skip, (c) enabled:false（默认）时被 skip, (d) 用 `jq` 确认 hooks.json 2 个文件的 PostToolUse 一致 + `tests/test-hooks-sync.sh` PASS | 135.1 | cc:done [c771707d; PostToolUse writing-lint（advisory、默认 off、平假名门槛、上限 5 条、缺字典 diagnostics）。hooks 2 文件同步] |
| 135.3 | `[lane:gate]` Stop 整体再检查: `go/internal/hookhandler/stop_writing_lint.go`（stop_session_evaluator 型）。重新扫描 `.claude/state/changed-files.jsonl` 中的 `.md`，若 severity: major 仍有残留则首次 Stop 时 `decision:"block"`，再入 (`stop_hook_active`) 则只发 warning 并放行。只有 minor 时不 block。在 `main.go` 加 `case "writing-lint-stop":`，在 Stop 数组中加独立条目 + 2 文件同步 | (a) major 残留 fixture 下首次 block → 再入 approve 的测试 (TestStopWritingLint_ReentryAllowsStopWithWarning), (b) 只有 minor 时从首次起就不 block, (c) `cd go && go test ./internal/hookhandler/... -run WritingLint` PASS | 135.2 | cc:done [c771707d; stop_writing_lint（major 残留则首次 block、stop_hook_active 再入仅警告、minor 不 block）。附再入 test] |
| 135.4 | `[lane:fast]` 指摘→规则登记循环: `templates/schemas/writing-rule-proposal.v1.json`（status: pending/approved/rejected）。起草方是 skill (`skills/japanese-writing-drafter/`) —— 若在对话中检测到 operator 修正了日语表达，就把 proposal 追加到 `~/.claude/writing-lint/proposals.jsonl`（写入只经由该 skill）。批准用 `scripts/writing-rule-approve.sh --id` 一次一条升级到 rules.jsonl，用 `scripts/writing-rule-list.sh` 查看 pending 一览 | (a) pending 1 条 fixture → 执行 approve → rules.jsonl 生效 + status: approved 的测试, (b) 升级后再扫描能命中新规则的回归测试, (c) 不存在自动升级路径（只经人类 CLI） | 135.1 | cc:done [c771707d; japanese-writing-drafter skill + writing-rule-approve/list.sh。proposal→批准→rules.jsonl 生效→再扫描命中的回归 test。无自动升级路径] |
| 135.5 | `[lane:fast]` scene 切换 + schema 正式化: config `writing_lint.scene` 单一键（规则侧 `scenes: []` 为空则全量适用，code-comment 在 stretch 中明记为 scope 外）。在 `claude-code-harness.config.schema.json` 中同时收录 `writing_lint` 与既有的非官方 `quality_pack`（保持 additionalProperties: false），在 config template 中补记，并在 `tests/validate-plugin.sh` 中增加 schema 验证 | (a) 既有 config（含 quality_pack）用新 schema 校验 PASS, (b) 带 writing_lint 段的配置示例也 PASS, (c) `bash tests/validate-plugin.sh` PASS | 135.2 | cc:done [c771707d; writing_lint.scene + schema 正式收录 writing_lint / quality_pack。check-config-schema.sh 接线到 section 23（接线由 134.8 负责人实施）] |

## Phase 136: surface 樱桃采摘 (2026-08-15 起票)

**Purpose**: 不引入 `みのるん` html-share 的 AWS 基础设施，只樱桃采摘能便宜加到既有 cognitive-load 3 surface 上的想法。diagram-design 只取连接点 1 句话。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 136.1 | `[lane:fast]` 移动端 viewport: 把与 orchestration.html.template 相同的 viewport meta + 响应式最小 CSS 横向展开到 `templates/html/accept.html.template` / `plan-brief.html.template` / `progress.html.template` | (a) 用 `grep -l viewport templates/html/*.template` 确认 3 个目标都已添加, (b) `bash tests/validate-plugin.sh` PASS | - | cc:done [c771707d; accept/plan-brief/progress 横向展开 viewport + 响应式 CSS] |
| 136.2 | `[lane:fast]` 待批准队列显示: 在 progress surface 显示 writing lint pending proposal 条数 + 供复制的 `writing-rule-approve.sh --id X` 命令字符串（明记这不是可点击按钮）。向 `progress-snapshot.v1` 增加 optional 字段 `writing_lint_pending`（additive） | (a) pending fixture 渲染出的 HTML 中出现 approve 命令字符串, (b) pending 0 条时该 section 不显示, (c) schema 仅做 additive 变更 | 135.4, 136.1 | cc:done [c771707d; progress 增加待批准队列（条数 + 供复制的 approve 命令、0 条时隐藏）。progress-snapshot.v1 增加 additive 字段] |
| 136.3 | `[lane:fast]` `[tdd:skip:docs-only]` diagram-design 连接点: 在 surface 系 SKILL.md 中加 1 句话「若已安装 `diagram-design` skill 则用于绘图。未安装则保持静态布局」。无代码。镜像同步 | (a) 对应 SKILL.md 增加 1 句话, (b) `bash scripts/sync-skill-mirrors.sh --check` PASS | - | cc:done [c771707d; plan-brief SKILL.md 增加 diagram-design 连接点 1 句] |

## Phase 137: 循环工程化对策 (2026-08-15 起票)

**Purpose**: `まさお` 5 篇文章（eval-loop / run-goal-loop / 检品模式 / foyer / 注意力）中，只把对 CCH 有效的 3 个零件接到既有契约上。暂不全面引入 score 型 eval-loop（verdict 型 review loop 与续行判定契约会重复，对功能类产物过度 —— 原作者实测）。Goodhart 对策（基准弱化检测）与目标漂移对策（委托文再注入）在 CCH 既有实现（test-quality.md / sprint-contract）中已满足，因此只做相互参照。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 137.1 | `[lane:fast]` `[tdd:skip:docs-only]` 评分设计规约: 向 harness-plan 的 references 增加一条规约「把 DoD / acceptance_criteria 翻译成 3 层: 机器 ○× 的底线（测试・字数・exit code）/ LLM 观点评分（构成・诉求）/ 本质 doc 参照」。判定方法 =「打零工的人能否用 checklist 打 ○×」。检测到模糊形容词（好/像样的）时提示翻译。镜像同步 | (a) 增加 reference + 从 harness-plan SKILL.md 参照, (b) `bash scripts/sync-skill-mirrors.sh --check` PASS | - | cc:done [c771707d; criteria-design.md（3 层翻译 + 打零工 ○× 测试 + 提示翻译模糊形容词）。从 SKILL.md 参照] |
| 137.2 | `[lane:fast]` blind 受众检查（run-goal-loop 型）: 向 harness-accept 增加可选 step —— 在 ship 判定之前「不给评分基准・合格线・中途经过，交给 fresh fork 评价者」，只传委托文 + 产物 + 读者画像，让其返回「是否可信 / 是否有用」。只对说服类/文档类产物生效，功能类跳过。结果在 Accept surface 显示「与内侧评分的偏差」（偏差大则倒向 wait）。包含 accept.html.template / acceptance-context schema 增加受纳口。`blind-judge.md` 可考虑复用，不合适则新建 reference | (a) 内侧高分 + blind 低分的 fixture 下显示偏差且 recommendation 倒向 wait, (b) 功能类任务中该 step 被跳过, (c) schema 仅 additive | 134.4, 136.1 | cc:done [c771707d; 新建 blind-evaluator reference（blind-judge.md 专用于 review 语境故不复用）。仅说服类触发、偏差时倒向 wait。fixture: case-blind-divergence / case-functional-skip] |
| 137.3 | `[lane:fast]` `[tdd:skip:docs-only]` 评价者 4 契约的明文化: 在 `agents/reviewer.md` 中把「①用 fresh context 评分 ②不改写评分基准 ③绝对评价（不与上次比）④不要报告，自己打开实物」作为 4 条契约列出（①②④是既有实现的明文化，③是新增）。与 test-quality.md / test-wiring-auditor 建立相互参照。镜像同步 | (a) reviewer.md 中列出 4 契约, (b) 相互参照链接有效, (c) `bash scripts/ci/check-consistency.sh` PASS | - | cc:done [c771707d; reviewer.md 中列出评价者 4 契约（③绝对评价为新增）。与 test-quality / workflow-test-wiring 相互参照] |

## Phase 138: 通用 feedback 规则 + count 分级 + PR evidence pack (2026-08-15 起票)

**Purpose**: 吸收 2 个外部来源的变形。(1) zenn.dev/nozomi720 的 feedback 管理系统 —— 把指摘规则化并持久化，用指摘次数 count 给强制力分级，通过 UserPromptSubmit 注入 / PreToolUse 检查做机械强制。把「operator 不重复提同一条指摘」从 writing（Phase 135）推广到全部行为。实测例：「rm 必须作为单独命令」这条指摘在 prompt 里没约束住 worker（2026-08-15 实测 2 次）—— 有了 feedback rule 就会在 PreToolUse 被机械警告。(2) builders.ramp.com 的 "integrations that write themselves" —— 「LLM 负责起草规则与理解语义（构建时）、运行时则是确定论的（regex / 脚本）」这一分离原则，以及「信任执行记录（artifact）而非代码」= 向 PR 附上执行记录。

**设计原则 (Ramp)**: LLM 的职责只到起草规则与理解语义为止。运行时的判定限定为 regex / 整数比较 / exit code 等确定论。信任的依据不是代码的样子，而是针对真实 provider/真实二进制的执行记录。

**变形的治理判断 (D67)**: 不做基于 count 的**自动**强制力升级。count 只是「提议」升级，连 warn→ask 的升级也要经批准 CLI，deny 的升级只由 operator 手动执行（维持 deny-baseline / self-audit 的「deny 面人类 only」原则）。数据驱动规则的强制力上限是 ask（deny 只属于 Go compiled rules）。规则文件 AI 也能编辑，若把 deny 放进数据就等于开出被篡改以规避 deny 的攻击面。

**Depends**: Phase 135.4 (writing-rule proposal loop) 完成。以「把 writing 专用机制推广为通用 feedback」的形式实现，避免重复实现。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 138.1 | `[lane:gate]` feedback-rule.v1 schema + 基础: `templates/schemas/feedback-rule.v1.json`（id / pattern [regex] / check_type [command-regex \| file-adjacency] / good / count / severity [warn\|ask] / enabled / scope）。规则存放位置是个人层 `~/.claude/feedback/rules.jsonl`（与 writing lint 相同的 config > env > 默认路径解析）。违反日志 `.claude/state/feedback-violations.jsonl`（append-only、不自动更新 count）。proposal → 批准 CLI 把 135.4 的 writing-rule-approve.sh 通用化共用 | (a) schema + 路径解析 + 违反日志 的 fixture 测试 green, (b) 与 135.4 共用部分的回归测试 PASS, (c) `cd go && go test ./...` PASS + gofmt/vet clean | 135.4 | cc:todo |
| 138.2 | `[lane:gate]` `[tdd:required]` 数据驱动 PreToolUse guard: 读取已批准的 feedback rules，检查 Bash command regex / file-adjacency 的 handler（quality_pack / writing-lint 型）。判定按 severity 返回 warn（additionalContext）或 ask。**绝不返回 deny**（在实现层把上限 clamp 住，并用测试 pin 住）。违反时记录到 violations.jsonl | (a) warn rule 下 additionalContext + violations 记录, (b) ask rule 下 ask 判定, (c) 即使规则写成 severity: deny 也被 clamp 成 ask 的负性测试, (d) 规则 0 条・字典缺失时完全放行, (e) 真实二进制 probe（stdin payload）实测 warn/ask | 138.1 | cc:todo |
| 138.3 | `[lane:fast]` count 升级的提议机制: 从 violations.jsonl 汇总各 rule 的 count，达到阈值（3 次 = 提议升级 ask、5 次 = 向 operator 发 deny 检讨通知）时生成升级 proposal。应用只经批准 CLI。整合显示到 progress surface 的待批准队列 (136.2) | (a) count 3 的 fixture 下生成 ask 升级 proposal, (b) 不存在自动应用路径（只经批准 CLI）, (c) deny 不是 proposal，而是停在「operator 检讨通知」 | 138.1, 136.2 | cc:todo |
| 138.4 | `[lane:fast]` UserPromptSubmit 注入: 把 count ≥ 3 的确定规则在 budget (3000 字) 以内从 UserPromptSubmit hook 注入（按 count 降序，超出部分只通知条数）。用 budget 固定与 D66（不污染 context 的节制）的权衡 | (a) 确定规则的 fixture 下注入在 budget 内, (b) 目标 0 条时不注入, (c) hooks.json 2 个文件同步 + tests/test-hooks-sync.sh PASS | 138.1 | cc:todo |
| 138.5 | `[lane:fast]` PR evidence pack（Ramp「信任 artifact」）: 在 harness-release / review flow 创建 PR 时，自动把执行记录摘要（review-result verdict + pending_validations + RED→GREEN 实测记录 + 契约测试结果 + artifact 路径）附到 PR body。让评审者（人类 / codex）能依据执行记录而非代码的样子做判断 | (a) fixture 下 PR body 生成 evidence pack section, (b) artifact 缺失时明确标注「未验证」（与 fail-visible 同型）, (c) 既有 PR 创建 flow 无回归 | 134.2, 134.4 | cc:todo |
| 138.6 | `[lane:gate]` 验证的验证: `scripts/ci/check-feedback-rule-wiring.sh` + 实效性契约测试（用真实二进制 probe 实测 warn / ask / deny-clamp 3 系、UserPromptSubmit 注入的 budget 上限测试）。接线到 validate-plugin.sh | (a) 接线前 RED / 接线后 GREEN 的实测记录, (b) `bash tests/validate-plugin.sh` PASS, (c) `bash scripts/ci/check-consistency.sh` PASS | 138.1-138.5 | cc:todo |

**共享文件 lane (Invariant 1)**: `tests/validate-plugin.sh` 的 owner 是 134.8 / 135.5（按此顺序串行）。`Plans.md` / `CHANGELOG.md` 禁止 worker 编辑（由 Lead 在集成时编辑）。hooks.json 2 个文件的 owner 是 135.2 → 135.3（串行）。`skills/harness-accept/` 按 134.4 → 134.6 → 137.2 的顺序串行。prose lane（skills/agents md）可按 134.3 → 134.7 → 136.3 → 137.1 → 137.3 串行（文件不同也可并行）。生成物（binary / mirror）在集成后于 trunk 重新生成 1 次（Invariant 3）。

---

## Phase 139: D70 Codex Breezing worker route (2026-08-22 起票)

**Purpose**: 只把 Codex Breezing 的实现 Worker 固定到 managed `worker` role 的
`gpt-5.6-luna` / `max`，不与评审・Advisor・deep 及通用
`standard`（`gpt-5.6-sol` / `xhigh`）混线。Native Codex 用
`.codex/agents/worker.toml`、managed reviewer 用 `reviewer.toml`、companion 以
中央 tier 为正本。Codex 的 current default 也从 `lite` 的
`gpt-5.4-mini` / `low` 迁移到 `gpt-5.6-luna` / `low`。

**Current-default boundary**: 以 ChatGPT sign-in 退役指引和已批准的
user policy，作为把 Harness 的 current routed default 统一到新一代的判断依据。
这不是「上游强制退役已波及 API-key 使用者」的主张，
而是「更新 Harness routing default」的契约。provider/API/HOME/install 的操作
不包含在本 task 内。

**Spec result**: Spec delta —— 在 execution-backends / distribution 的 sub-spec 中，
新增一条狭窄的分发契约：`hosts.toml` → `harness gen` 生成 managed Codex worker/reviewer profiles，
setup 把它们激活到 user/project 的 `agents/{worker,reviewer}.toml`。
不改动 `spec.md` 的 North Star、HOTL、provider/API 边界、通用 `standard` 的含义。
D70 是 role routing、companion 的 effort 表达、镜像与验证接线的
运用契约，不新增模型质量・费用・真实环境的保证。

Native profile 的规格依据是 OpenAI 的 [Codex Subagents 设置](https://developers.openai.com/codex/subagents)。
本 Phase 的实现与 fixture 验证不执行 provider/API/HOME/install。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 139.1 | `[lane:gate]` `[tdd:required]` D70 worker route: managed `worker.toml` 用 `agent_type: worker` 选取，Native worker 为 `gpt-5.6-luna` / `max`，companion 的全部 Breezing call-site 固定 `CODEX_MODEL_TIER=worker`。通用 `standard` 为 `gpt-5.6-sol` / `xhigh`，`lite` / explorer 明确保持 Luna/low，不与 review / advisor / deep route 混线。managed `reviewer.toml` 作为与 worker 不同的 role 生成并激活。official companion 不接受的 max 以 fail-visible 方式规范化为原始 `codex exec -c model_reasoning_effort="max"` | 确认 worker/reviewer profile 的 name/description/developer instructions/model/effort、native spawn 形状、worker call-site 固定、lite 迁移、通用/review/advisor/deep 分离、invalid route 与非主写入在 provider/ledger 之前 fail-closed。未取得的 provider/API/HOME/install 证据不作主张 | D70 operator decision (`.claude/memory/decisions.md:431-448`) | cc:done [focused/full green; dual review APPROVE] |
| 139.2 | `[lane:gate]` `[tdd:required]` routed review transport: 每个 review 的 local app-server proxy 把 `model` / `review_model` / `model_reasoning_effort` 注入 `codex app-server --stdio`，并保持 official companion envelope。`review --commit` 在 provider dispatch 之前 fail-closed。只有 companion + proxy 成功时才记录为 orchestration ledger 的 successful delegation，reject / transport failure 不计入。TERM/INT 同时转发给 companion 与 proxy，最多等待 1 秒 → KILL → reap。明确 POSIX Unix socket 与 Windows named-pipe 的 fixture/static 边界 | 在最终 rerun 中确认 config 注入、official envelope、`--commit` reject、ledger 成功条件、子进程消失、signal lifecycle 的 focused checks。Windows live provider/app-server 视为未观测 | 139.1 | cc:done [focused/full green; dual review APPROVE] |
| 139.3 | `[lane:gate]` `[tdd:required]` Codex setup/distribution 契约: local/remote setup 的 config 与 backup destination preflight 先于 skills/rules/agents/project `AGENTS.md` 执行。Harness 自有的 legacy root `[notify]` 只对 setup form 与 distributed-template form 这 2 种形态做 backup + 原子迁移，custom/ambiguous 形态连 backup 也不做、直接 no-mutation fail。缺失 `[features] multi_agent = true` 与 `default_mode_request_user_input = true` 时补上，显式值保持不变。Claude/Codex dist 一并分发 worker/reviewer profile 与 review proxy 的 runtime-helper 闭包。Codex dist 还随带 fingerprint 执行所需的 `bin/harness` launcher・4 platform binary・`VERSION` | 确认 local/remote preflight、backup destination 失败时所有 target 不变、notify 的 2 种精确形态、custom/ambiguous no-mutation、feature 默认值、生成 profile 的激活、两个 host dist 的 helper 闭包、Codex dist 单体的无 provider routed task 启动。不执行 live HOME/install，不主张 Windows named-pipe live 支持 | 139.1, 139.2 | cc:done [focused/full green; dual review APPROVE] |

**D70 TDD evidence**: 把改动前的 baseline
`8d74739aaeee8dad3290828711189d9efc6a2787` 从 `git archive HEAD` 与
export-ignore 目标 subtree 的 `git archive HEAD:<subtree>` 恢复到临时区域，
只 overlay 现行 focused test 后重新执行 RED。实测 command / literal 如下。

- `bash tests/test-model-routing.sh` → `router help must advertise the dedicated worker tier`
- `bash tests/test-codex-package.sh` → `missing: codex/.codex/agents/worker.toml` / `reviewer.toml`
- `bash tests/test-codex-setup-local.sh` → `expected file to exist: .../agents/worker.toml`
- `bash tests/test-host-plugin-dist.sh` → `claude missing scripts/codex-companion.sh`
- `bash tests/test-breezing-codex-worker-route.sh` → `managed Codex worker agent profile is missing`
- `bash tests/test-codex-reviewer-route.sh` → `review companion argv must preserve pair: -c model="gpt-5.6-sol"`
- `bash tests/test-codex-setup-remote.sh` → `agents/worker.toml: No such file or directory`
- `bash tests/test-run-advisor-consultation.sh` / `bash tests/test-advisor-config.sh` → expected Sol, actual `gpt-5.4`
- `GOWORK=off go test ./cmd/harness ./internal/hostgen ...` → `AgentProfiles undefined` / `GenerateAgentProfile undefined`
- final review 中新增的 non-primary write fixture 在实际修正前确认了
  `bash tests/test-model-routing.sh` → `non-primary write rejection must not emit a delegation ledger entry`
  并把 guard 恢复到 ledger 之前后确认转为 GREEN

同一 focused tests 与 full checks 的 GREEN、final review、commit 各自在完成后
作为独立 evidence 确定。repo-supported `tdd-red-log` 是 runtime-only/gitignored 的，
因此 tracked RED 以本 Plans section 为正本。

**D70 GREEN / review evidence**: 在同一 worktree 重新执行 routing、worker、reviewer、
setup local/remote、Codex package 27/27、host distribution、Advisor、Codex loop 42/42、
Claude upstream integration 并转为 GREEN。`go test ./...`、`go vet ./...`、
`harness gen --check`、skill mirror、consistency、全 4 platform binary rebuild、
binary/source drift、ShellCheck、`git diff --check` 也均为 GREEN。`tests/validate-plugin.sh` 为
147 pass / 0 warning / 0 failure。AI residual scan 为 APPROVE / major 0。
Regression/Security reviewer 与 Skeptic reviewer 的最终判定均为 APPROVE / blocking 0。
provider/API、真实 HOME/install、真实 Windows named pipe、真实 provider model selection 均未执行・未观测。

**Current route evidence / boundary**: live routing 为 Codex `lite` 取
`gpt-5.6-luna` / `low`、通用 `standard`・review・advisor・deep 取
`gpt-5.6-sol` / `xhigh`、专用 worker 取 Luna/max。ChatGPT sign-in
退役指引与 user policy 是 current default 迁移的判断依据，
而不是「上游强制退役波及 API-key 使用者」的证据。Native
reviewer 的 managed `reviewer.toml` 与 effective Sol/xhigh 接线、
worker routing/help 等实现对象，已在 current worktree 通过 focused/full checks 与 dual review。
完成判定不只看 profile 是否存在，
还包括 setup/distribution、review transport、fail-closed、
lifecycle、ledger 的执行 evidence。

---

## Phase 140: guardrail defer 方式 — 把 ask 的「停止」换成「保留队列 + 续行」 (2026-08-22 起票)

**Purpose**: operator 裁定（2026-08-22）: 最坏的结果是无人值守 run 在确认提示处早早停住。因此把 ask 降级为专用于「人类在场的对话轮次」，无人值守时 (a) 看起来安全就用 warn 自走（v5.10.0 已实现），(b) 可能触及 operator 条件（影响生产 / 对 main 的不可逆 / root 之外）的操作**不执行、跳过并继续其他作业**，回来的 operator 一次性复审保留清单。机制核心: hook 的 deny 不停止 run（理由回传给 agent 并继续。2026-08-22 曾以 floor deny 2 次实测）。只有 ask 会停止。

**优先级 (operator 裁定 2026-08-25)**: 排在下一 sprint 最前面。比 Phase 142（源自外部吸收评审）先着手。

**顺序固定 (operator 裁定 2026-08-29)**: Phase 143（分发路径的 hotfix v5.13.2）→ 140 → 142 → 138。138 是 8/15 起票中最久未着手的，但 142 先准备好字典（142.4）与记忆（142.1），因此排在后面。依据: 2026-08-24 的设计评审（`docs/reports/2026-08-24-cch-harness-review.html`）判定 HOTL 剩下的漏洞中「无人值守 run 在 ask 处早早停止」是最大问题。vibe-kanban 用默认 `--dangerously-skip-permissions` 解决的问题，正是 CCH 在不取消确认的前提下要给出的答案。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 140.1 | 新增 `destructive_delete: defer`: 在 R05 的相当于确认的场景下返回 deny 而非 ask，并在 reason 中嵌入行动契约（「已放进保留队列 / 禁止重试 / 继续其他任务 / 结束时报告保留清单」）。该操作追加到 `.claude/state/deferred-ops.jsonl`（timestamp / session_id / rule_id / command / 判定理由） | (a) defer 配置下 deny + 队列 1 行的真实二进制 probe, (b) 同一命令重试时队列不重复且持续 deny, (c) 既有 ask/warn 行为无回归 | - | cc:done |
| 140.2 | 保留队列的批准 flow: `bin/harness deferred list / approve <id>` CLI。approve 用与既有 plan preapproval (`ConsumePlanPreapproval`) 相同的 consume 机制，放行「下一次 1 次」。在 progress surface 显示保留 N 条 + 供复制的 approve 命令（与 136.2 的待批准队列显示同型） | (a) approve 后重跑变为 allow 的 probe, (b) 未 approve 时仍是 deny, (c) surface 显示的 render test | 140.1 | cc:done [2b7f098d; deferred list/approve CLI + approved→consumed 一次性 consume + R05_DEFER_APPROVED advisory + policy=defer 记录 + deferred_ops_pending surface。probe 24/24] |
| 140.3 | 禁止 agent 自主停止的条文: 在 harness-release / breezing / harness-work 的 SKILL.md 中，以与 AUTOSTART pattern 相同的 literal 列举方式追加「不要因为等待 background 而停止（停止则 background 子进程不会留下）」「不要以『等待验证』『我去确认』结束一轮。要么同步执行等待，要么作为保留报告并继续往下走」。2026-08-22 的 release run 中出现过 2 次的停止模式即复现用例 | (a) 对应 SKILL.md 中有禁止条文, (b) mirror 同步 PASS | - | cc:done [43895fa1; 3 个 SKILL.md 以 literal 列举追加禁止条文 + mirror in-sync] |
| 140.4 | 判定 defer 是否推广到其他可配置 ask: R12（main push）默认保持 ask 作为 operator 例外。R04 已在 work-mode 覆盖。把判定结果与依据记入 decisions.md | (a) decisions.md 中有判定条目 | 140.1 | cc:done [43895fa1; D73 记入 decisions.md（defer 限于 R05、R12=configurable 三值 / R04=work-mode 已解决。明确 3 项成立条件）] |

---

## Phase 141: 会话协调流水线 — 消除混用・自动发送・可选验证 (2026-08-24 起票)

**Purpose**: 「让同一个项目里 mem 共享记忆，但在 CCH 侧让会话之间的往来彼此可见」（operator 2026-08-24）。**北极星是流水线的构建**，用它来做什么交给使用者决定。验证是因为发现「有些东西不送更好」才加上的，但**终究是后加的关卡，可以开关**。验证不通过也仍有路可走。

**现状 (2026-08-24 实测)**: 管道已在 Phase 92.6 实现（`go/internal/livemsg`、zero-dep sqlite、发送/接收/已读）。接收投递也已接线到 claude/codex/cursor/grok。**缺的是两端**: (1) agent 发送的入口一个都不存在（`inbox send` 仅为人类 CLI，skill/hook/tool 接线为零），(2) 名册在 Stop 一次后就消失（register 是 `once:true`、unregister 是 Stop = 每轮触发。实测在会话存续期间确认 0 行），(3) 有读取 `HARNESS_LIVEMSG_TEAM/AGENT` 的实现，却**没有任何写入主体**（3 个 companion 都不把 env 传给子进程）。

**要求 1 的更正（重要）**: 「两边都有就是 1 个」的重复**在出货物中并不存在**。`harness_session_*` MCP tool 在本 repo 没有实现，`opencode/README.md` 明确写着 "Development-Only"。实测到的 active.json 破坏，是因为在 operator 环境里运行了开发用 MCP。因此要求 1 不是「消除重复」，而是 **「即使 mem 与我们同居，CCH 侧也不会被弄坏」**。

**hermes 的处理**: `hosts.toml` 中没有 hermes 条目，hook 生成对象是 claude/codex/cursor/grok 4 个。hermes 只是候选文档。v1 先用 4 个 host 完成，hermes 在 141.9 中追加（hook 词汇是 snake_case 且与其他不同，因此是独立 task）。

**3 层结构（依赖自下而上单向）**: 第 1 层 流水线 (141.1-141.6) → 第 2 层 验证关卡 (141.7-141.8、可开关) → 第 3 层 记忆检索（mem 可选叠加，本 Phase 不触碰）。切掉第 2 层时第 1 层仍要能跑，这是验收条件。

**Spec delta**: 在 `spec.md` 的 Session Coordination Contract 中追加 3 点：(a) roster liveness 的更新契约（不在 Stop 删除，而在 SessionEnd 删除）、(b) agent 主动发送的存在与非命令式 envelope、(c) `[livemsg] verification` 的开关默认值。（141.10）

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 141.1 | `[lane:gate]` `[tdd:required]` **修好名册的寿命**。RED: 在 `go/internal/hookhandler/session_register_test.go` 中加入「register 之后即使击发 1 次 unregister，名册仍然保留」的失败测试。GREEN: 在 `hooks/hooks.json` 与 `.claude-plugin/hooks.json` 2 个文件中，把 `hook session-unregister` **从 Stop 迁到 SessionEnd**（SessionEnd 已有 `hook session-cleanup`，加进同一个块）。不改 `HandleSessionUnregister` 的代码（只改接线）。实测依据: Stop 每轮触发，只击发 1 次 `session-unregister` 就会让 `session list` 变成 0 行（2026-08-24 实测） | (a) RED→GREEN 的实测记录贴到 task 完成报告中, (b) `cd go && go test ./internal/hookhandler/... -count=1` PASS, (c) `bash tests/test-hooks-sync.sh` PASS（2 文件同步）, (d) 手动 probe: 击发相当于 Stop 的 register → unregister 后 `bin/harness session list` 仍留有行，击发相当于 SessionEnd 时则消失 | - | cc:完了 [b7e19fdf] |
| 141.2 | `[lane:gate]` `[tdd:required]` **把 register 改成每轮更新**。现状 `SessionStart` 的 `once:true` 导致只记名最初 1 次。在 `hooks/hooks.json` + `.claude-plugin/hooks.json` 的 Stop 块中加入 `hook session-register`（不带 once），每轮更新 mtime。`refreshSharedPresence` 对既有文件只做 `os.Chtimes`、**不覆盖内容**（`session_presence.go:95-99`），因此用 `session declare` 写入的 task/label 会保留。用 pin 测试固定这一保留行为 | (a) 「已 declare 的 presence card 在 register 重新执行后仍保持 task/label」的测试 green, (b) `cd go && go test ./internal/hookhandler/... -count=1` PASS, (c) hooks 2 文件同步测试 PASS, (d) 24h prune（`registerStaleCutoff`）的既有测试无回归 | 141.1 | cc:完了 [abd02de2] |
| 141.3 | `[lane:gate]` `[tdd:required]` **做出身份证明的 producer**。执行 `hook session-register` 时，把解析出的 team/agent 以 **export 形式**写入 CC 的 env file 路径（`CLAUDE_ENV_FILE`）（`export HARNESS_LIVEMSG_TEAM=...` / `export HARNESS_LIVEMSG_AGENT=...`）。裸 `KEY=VALUE` 传不到子进程 env，因此必须加 `export`。team 默认取 `harness.toml [livemsg] team` → 没有则取 repo 名。agent 取 hook payload 的 `session_id`。**不改 `deliveryidentity.Resolve()` 的优先级（env → breezing）** —— 只做填 env 的一侧 | (a) env file 写入 export 形式 2 行的测试 green, (b) `deliveryidentity.Resolve()` 能从 env 解析的集成测试 green, (c) breezing 执行中（`BREEZING_SESSION_ID` 已设定）时既有优先级胜出的负性测试, (d) `cd go && go test ./... -count=1` PASS | 141.1 | cc:完了 [42a63354] |
| 141.4 | `[lane:gate]` `[tdd:required]` **agent 发送的入口（skill）**。新建 `skills/session-send/SKILL.md`。frontmatter 为 `name` / `description`（触发词: 通知其他会话, 会话间联络, 发送交接, notify other session）/ `description-ja` / `allowed-tools: ["Bash"]`。正文包含 (i) 用 `bin/harness session list` 确认收件人的步骤、(ii) 执行 `bin/harness inbox send --team <t> --from <自己> --to <对方> --subject <主题> "<正文>"`、(iii) **可发送内容的判断基准**（完成通知 / 声明将触碰的范围 / 交接要发送。作业中的商量与猜测不发送 —— 以 1 行注明 CooperBench 的测量依据）。用 `scripts/sync-skill-mirrors.sh` 做镜像同步 | (a) `bin/harness validate skills` PASS, (b) `bash tests/validate-plugin.sh` PASS, (c) `./scripts/sync-skill-mirrors.sh --check` 为 in-sync（新建 skill 出现在镜像中也要目视确认 —— `mirror --check` 会漏看新建 skill 的已知漏洞）, (d) 手动 probe 记录: 通过 skill 实际收发 1 条 | 141.3 | cc:完了 [a170e7ed] |
| 141.5 | `[lane:fast]` `[tdd:required]` **统一 broadcast 的 scope**。`session_auto_broadcast.go` / `inbox_check.go` 使用的 `broadcast.md` 是 worktree 局部的，而 presence 是 git-common-dir 共享的。为消除「不同 worktree 的 Claude 彼此看得见却不收到通知」的不一致，把 broadcast 的存放位置也移到与 presence 相同的 **git-common-dir 父目录下的 `.claude/sessions/broadcast.md`**。复用与 `sharedLiveSessionsDirFromRoot`（`session_presence.go:44-54`）相同的解析函数 | (a) 从其他 worktree 写入的 broadcast 可读的测试 green, (b) 不在 git 中时照旧 fail-open 到 worktree 局部的负性测试, (c) `.last_inbox_read_*` marker 的既有测试无回归, (d) `cd go && go test ./internal/hookhandler/... -count=1` PASS | 141.1 | cc:完了 [9728fd9d] |
| 141.6 | `[lane:gate]` `[tdd:required]` **mem 同居时的非破坏保证**（要求 1）。读取 `.claude/sessions/active.json` 时，**不删除、保留并忽略**与 CCH 自身 schema（`short_id`/`last_seen`/`pid`/`status`）不匹配的条目（unknown-entry passthrough）。现状是 unmarshal 后缺失 → `last_seen=0` → 被 24h prune 删除，从而破坏 mem 侧的记录（2026-08-22 实测）。把 `writeActiveJSON` 改成基于 `map[string]json.RawMessage`，只更新自己认识的键再写回 | (a) 「其他 schema 的条目跨越 register/unregister/prune 后仍保留」的测试 green, (b) 自身 schema 的 24h prune 照旧运行的回归测试 PASS, (c) 实 probe: 用 mem MCP 注册 → 执行 CCH hook → 记录两边的条目都在, (d) `cd go && go test ./internal/hookhandler/... -count=1` PASS | 141.1 | cc:完了 [48ceffa7] |
| 141.7 | `[lane:gate]` `[tdd:required]` **验证关卡（开关）**。在 `harness.toml` 中新设 `[livemsg]` 表并设 `verification = "off" \| "on"`（**默认 off**）。解析采用与 `destructiveDelete` 相同的 5 级（env `HARNESS_LIVEMSG_VERIFICATION` → project YAML → project harness.toml → plugin harness.toml → 默认值）。在 `go/pkg/config/toml.go` 中添加 `LivemsgConfig`。**off 时发送路径不进入任何附加处理**（每次函数调用都跳过）这一点用测试 pin 住 | (a) off 时发送路径直接通过的测试 green, (b) on 时 gate 函数被调用的测试 green, (c) env override 优先级最高的 5 级优先级测试 green, (d) 未设置 `harness.toml` 的 repo 中默认为 off 的负性测试, (e) `cd go && go test ./... -count=1` PASS + gofmt/vet clean | 141.4 | cc:完了 [03f5efd8] |
| 141.8 | `[lane:gate]` `[tdd:required]` **验证的内容**。新建 `templates/schemas/livemsg-gate.v1.json`（`schema_version` / `verdict` enum `{SEND, HOLD}` / `reason` / `checked` 数组）。判定分 2 段: (i) **机械检查**（提及文件是否真实存在、用 `git rev-parse` 确认 commit 存在、主张与 `git status` 是否一致）用 Go 实现，(ii) 仅把机械无法判定的主张交给与 `agents/reviewer.md` 同型的 read-only agent。HOLD 时**不发送并把理由返回给发送侧**（不送到对方）。新建 `agents/livemsg-gate.md`，采用 `reviewer.md` 的 frontmatter 形式（`tools: [Read,Grep,Glob]` / `disallowedTools: [Write,Edit,Bash,Agent]`） | (a) 机械检查中提及不存在的文件会成为 HOLD 的测试 green, (b) HOLD 时收件方 inbox 一条都不进的负性测试, (c) HOLD 理由返回给发送侧的测试 green, (d) verification=off 时 gate 函数本身不被调用（与 141.7 的 pin 一致）, (e) schema validation 测试 PASS | 141.7 | cc:完了 [550b7359] |
| 141.9 | `[lane:fast]` `[tdd:required]` **把 hermes 作为第 5 个工具追加**。在 `hosts.toml` 中加入 `[hermes]`（`hook_event = "pre_tool_call"`, `delivery_strategy = "turn"`, `delivery_event_turn = "stop"`, `hook_path = "~/.hermes/config.yaml"` 因是 YAML 声明式而不属于生成对象，**只接线 delivery**）。hermes 的 hook 是 snake_case，有 `on_session_start` / `on_session_end` / `pre_tool_call` / `subagent_stop` 等，payload 含 `session_id`（已在自建 docs `website/docs/user-guide/features/hooks.md:79,83,84,440` 中确认）。在 `hostgen.go` 的 switch 中加入 hermes case | (a) `bin/harness gen` 输出 hermes 分支的测试 green, (b) `bin/harness gen --check` PASS, (c) 既有 4 个 host 的 golden fixture 无回归, (d) 未安装 hermes 的环境中生成 fail-open 的负性测试 | 141.3 | cc:完了 [1133b13d] |
| 141.10 | `[lane:gate]` `[tdd:skip:docs-only]` **Spec 反映与接线验证**。(i) 在 `spec.md` 的 Session Coordination Contract 中追加 3 点（roster liveness 的更新契约 / agent 主动发送的存在与非命令式 envelope / `[livemsg] verification` 默认 off）、(ii) 在 `docs/CLAUDE-feature-table.md` 的 Phase 89 行记下 Phase 141 的变更、(iii) 新设 `scripts/ci/check-session-pipeline-wiring.sh` 并接线到 `tests/validate-plugin.sh`（不触碰 `.github/workflows/` —— 依据 `.claude/rules/workflow-test-wiring.md` 的非对称规则） | (a) 接线前 RED / 接线后 GREEN 的实测记录, (b) `bash tests/validate-plugin.sh` PASS, (c) `bash scripts/ci/check-consistency.sh` PASS, (d) `bash scripts/plans-format-check.sh` PASS | 141.1-141.9 | cc:完了 [3b1fd1d6] |

> **141.8 补记 (2026-08-25)**: 上面的说明读起来像「只有机械无法判定的主张才交给 agent」，但实现中 `go/cmd/harness/inbox_send.go` 没有设置 `livemsggate.Options.Reviewer`，因此**判定角色（`agents/livemsg-gate.md`）并未接进发送路径**。实际运行的只有机械检查，判定角色未设置时记录 `not_observed` 并放行机械检查的结果。DoD (a)-(e) 在字面上全部满足，但这一差异已在 `docs/spec/operations-memory-and-collaboration.md` 与 `CHANGELOG.md` 中明确记录。判定角色的实际接线作为独立 task 起票。

**共享文件 lane (Invariant 1)**: `hooks/hooks.json` + `.claude-plugin/hooks.json` 的 owner 是 **141.1 → 141.2 串行 בלבד**（其他 task 不触碰）。`go/internal/hookhandler/session_register.go` 的 owner 是 141.6（141.1/141.2 只改接线不改代码）。`harness.toml` + `go/pkg/config/toml.go` 的 owner 是 141.7。`hosts.toml` + `hostgen.go` 的 owner 是 141.9。`spec.md` / `Plans.md` / `CHANGELOG.md` 禁止 worker 编辑（由 Lead 在集成时编辑）。生成物（`bin/harness` 的 4 platform binary、skill mirror）在集成后于 trunk 重新生成 1 次（Invariant 3）。

**推荐 wave 顺序**: W1: 141.1 → W2: 141.2 ∥ 141.3 ∥ 141.5 ∥ 141.6 → W3: 141.4 ∥ 141.9 → W4: 141.7 → W5: 141.8 → W6: 141.10

**验收的本质（不满足则 Phase 失败）**: (1) 会话存续期间 `bin/harness session list` 持续显示自己、(2) agent 能通过 skill 向其他会话发送并抵达对方的语境、(3) 在 `verification = "off"`（默认）下 (1)(2) 完整可用。

---

## Phase 142: 反映外部吸收评审 2026-08-24 — 记忆的修理 / 注入盘点 / 字典上线 / 规则退役提议 / native 重复检查 (2026-08-25 起票，评审时的工作名为 Phase 141。因与 main 上并行发布的 Phase 141「会话协调流水线」编号冲突，落地时改号为 Phase 142)

**Purpose**: 把 `/muscle` 的设计评审（`docs/reports/2026-08-24-cch-harness-review.html`、调查 4 条线 + 独立反证路径）中 operator 批准的 5 项列入计划。
评审结论是「治理层的设计是正确的（竞品 5 个产品都没有同等治理层）。问题在于运用的 3 个漏洞 = 记忆内容为空 / 日语 lint 的字典为空 / 无人值守 ask 停止（Phase 140）」。
对 Hermes Agent (NousResearch) 只取「可逆性的厚度决定自主的许可量」这一原理中 **安全的部分（usage telemetry + 退役提议）**。未经批准的自动采纳按 D67 维持不采纳（D71）。

**Spec result**: Spec skip reason —— 5 项都在既有契约（HOTL 不变条件 1/2/6、D62 fail-visible、D64 字典分离、D67 强制力上限、D68 信任执行记录）的范围内，不伴随 `spec.md` 的变更。142.2 的责任边界变更止于 handoff 起票，spec 变更在 handoff 批准后作为独立 task 起票。

**team_validation_mode**: subagent（调查 4 条线 + 独立反证 1 条线。已确定反证中 1 项不采纳、3 项缩小）。

**设计原则**: (1) 每处接线都附带「证明其在生效的观测点」(D58)。(2) 降级是 fail-visible (D62)。不停止，而是把「未注入」「未验证」可视化。(3) 数据驱动规则的强制力上限是 ask，不做自动升级・自动 archive・删除路径（D67 / D71）。(4) 盘点以计量优先 (P43)。安全装置类 hook 从削减候选中排除。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 142.1 | `[lane:gate]` `[tdd:required]` resume pack 质量门禁: 在 UserPromptSubmit 的 resume 注入路径（`scripts/userprompt-inject-policy.sh` / memory-bridge）中加入确定论的空判定。若 Decisions / Open Loops / Next Actions / Latest Exchange 全部相当于「not captured」「No ... captured」，或 Overview 只有 `elicitation_event: {}`，则判定为空，不注入正文，只在 additionalContext 中输出「resume pack 为空故未注入 (source session / generated_at)」1 行标记。阈值与词汇用脚本内常量固定 | (a) RED: 实测本会话中测到的空摘要 fixture（`Overview: elicitation_event: {}` / `User: not captured`）被原样注入的现状, (b) 空 fixture 下不注入正文 + 输出标记, (c) 有内容的 fixture 照旧以 32KB 上限注入（回归）, (d) 接线到 `tests/validate-plugin.sh` (D53) | - | cc:todo |
| 142.2 | `[lane:fast]` `[tdd:skip:docs-only]` 向 harness-mem 起 handoff: 按 `docs/rules/cross-repo-handoff.md` 的 workflow 写委托书。内容 = (i) session summary 变成空摘要（附 142.1 的 fixture）, (ii) ingest `ok:true` 却 `entries_imported: 0` (D55), (iii) `mem_search` 8 秒 timeout → `safe_lexical_fallback`, (iv) 责任边界审计: 把会话近旁的记忆集中到 CC native auto-memory（machine-local、默认 ON），harness-mem 只限于跨工具 / 跨机器检索的方案。**不做实现、不写入其他 repo** | (a) handoff 文档创建在规定位置并处于等待 operator 批准的状态, (b) 4 项各自附上实测 evidence（命令与输出）, (c) 记录到 `docs/reports/README.md` 之类的索引中 | 142.1 | cc:todo |
| 142.3 | `[lane:fast]` context 预算盘点: 在 `skills/maintenance` 中增加 `context` 子命令（实体是 `scripts/context-budget-audit.sh`）。按注入源分别实测大小（CLAUDE.md / rules / MEMORY.md / hooks 的 additionalContext / UserPromptSubmit injectors），并检测同一 directive 的重复注入（例如语言指示在 1 轮中出现 2 次），输出报告。**enforcement / guardrail 类 hook（pre-tool / permission / runtime floor）是固定从削减候选中排除的清单**，写在脚本内。不执行削减（只出报告） | (a) 生成实测报告，能复现本会话启动时约 94.7k token 的构成, (b) 语言 directive 双重注入 fixture 下能检测到重复, (c) guardrail 类 hook 不出现在候选中的 negative test, (d) `bash scripts/sync-skill-mirrors.sh --check` PASS | - | cc:todo |
| 142.4 | `[lane:fast]` 日语 writing lint 字典的 seeding: 用 `scripts/writing-rule-seed.sh` 把 `~/.claude/rules/japanese-writing-core.md` 中确定论的部分子集（LLM 空句列表、em 破折号、中点并列等可用 literal / 正则匹配的部分）生成为 `writing-rule-proposal.v1` 写入 `~/.claude/writing-lint/proposals.jsonl`。**不做自动批量批准**（批准仍用既有 `writing-rule-approve.sh --id` 一条一条来）。可能因上下文依赖而误检的词（如「重要」）不纳入 seed，作为候选保留并附理由。在 docs 中补记 `writing_lint.enabled` 的启用步骤 | (a) 执行 seed 生成 N 条 proposal，rules.jsonl 不被改写（无自动升级路径，用 135.4 的既有 test pin 住）, (b) 批准 1 条 → rules.jsonl 生效 → 再扫描能命中的回归（复用 135.4 test）, (c) 排除词清单带理由输出, (d) 启用步骤文档 | 135.4 | cc:todo |
| 142.5 | `[lane:gate]` `[tdd:required]` 规则 usage telemetry + 退役提议（Hermes curator 的安全部分）: 在 writing lint（将来也包括 feedback rules）命中时，把 `use_count` / `last_used_at` 记到个人层 sidecar（`~/.claude/writing-lint/.usage.json`，不改字典本体）。达到阈值（默认 90 天未使用、`use_count == 0` 时以登记后 90 天为宽限）时在 proposals.jsonl 中生成「archive 提议」。**执行只经批准 CLI，archive 是移动到 `.archive/` 且可恢复，不做删除路径**。把所有 mutation 记录到 append-only ledger（`~/.claude/writing-lint/.ledger.jsonl`，含 actor + before/after 哈希） | (a) 命中时 usage 被更新, (b) 90 天 fixture 下生成 archive 提议, (c) 不存在自动 archive / 自动删除路径的 negative test, (d) archive → restore 往返 test, (e) ledger 中留有 actor 与 hash, (f) `cd go && go test ./internal/writinglint/...` PASS + gofmt/vet clean | 142.4 | cc:todo |
| 142.6 | `[lane:fast]` `[tdd:skip:docs-only]` 把与 CC native 功能的重复检查常态化: 把 `docs/research/official-feature-inventory-2026-06.md` 更新到 2026-08 版（Dynamic Workflows / Agent Teams experimental 默认 OFF / worktree isolation 4 种检查 / `/code-review ultra` / auto-memory machine-local / 28 hook events / scheduled tasks 3 层）。每行注明既有的「CCH 作为便利采用 / 作为治理边界则不委托」判断。修正 `CLAUDE.md:14` 中的「Opus 4.7」表述为当前世代。在 upstream-update 系 skill 的步骤中加 1 行更新周期（跟随 CC minor） | (a) inventory 更新到 2026-08 版, (b) CLAUDE.md 表述修正, (c) `bash scripts/ci/check-consistency.sh` PASS, (d) 明记「委托而变薄」的判断不包含在本 task 内（一条一条另行起票） | - | cc:todo |
| 142.7 | `[lane:gate]` 验证的验证: 把 142.1 / 142.3 / 142.5 的实效性契约测试（空 resume 未注入 / 重复注入检测 / 无自动 archive 路径）接线到 `tests/validate-plugin.sh`。每个测试都附接线前 RED / 接线后 GREEN 的实测记录 | (a) 3 本契约测试附 RED→GREEN 记录, (b) `bash tests/validate-plugin.sh` 整体 PASS, (c) `bash scripts/ci/check-consistency.sh` PASS | 142.1, 142.3, 142.5 | cc:todo |

---

## Phase 143: 分发路径的修理 — 自建 hook script 破坏了 plugin cache 与 marketplace 副本 (2026-08-29 起票，hotfix v5.13.2)

**Purpose**: operator 裁定（2026-08-29、`docs/reports/2026-08-27-harness-sync-status.html` 的 3 张判断卡）: 修理版 5.13.2 要先于 Phase 140.1 发布。根因是 `scripts/sync-plugin-cache.sh`（SessionStart hook）的 3 个缺陷。(1) 先用同步内容（hooks / skills / scripts / output-styles / VERSION）单独创建尚未安装版本的 cache dir，Claude Code 直接使用它（5.8.0 / 5.9.0 / 5.13.0 / 5.13.1 都出现 Agents (0)、agents / bin / templates 缺失）。(2) 把其他 worktree 的 VERSION / plugin.json 写回 marketplace 副本，而 `claude plugin update` 用副本的 plugin.json 判断最新，于是回答「5.13.0 是最新」导致 5.13.1 进不来。(3) 删除副本中受版本控制的 `docs/research/*`，让 git 永久处于 dirty 状态。初版报告的推测「CC 只复制 manifest 中声明的部件」是被旧 script 的复现所否定（agents/ 无需声明就会被自动发现。CC docs plugins-reference）。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 143.1 | `[lane:gate]` `[tdd:required]` 修正 `scripts/sync-plugin-cache.sh` 的 3 个缺陷: cache dir 只更新既有目录（不新建）/ 副本只在 git HEAD 的 VERSION 一致时才同步，且不写 VERSION / plugin.json / marketplace.json / 私有路径的删除只作用于 cache 侧 / 把 `agents` 加入 critical_dirs。在 `tests/test-sync-plugin-cache.sh` 中加入 4 本契约测试（利用 validate-plugin.sh 的既有接线） | (a) 用旧 script 得到 RED（复现未安装版本 dir 被创建 / 副本 plugin.json + VERSION 被改写 / docs/research 被删除）→ 修正后 GREEN, (b) `bash tests/validate-plugin.sh` PASS | - | cc:done |
| 143.2 | v5.13.2 发布后的分发目标实测: 把副本的 plugin.json 恢复到 git 内容（在发布确认门禁取得 operator 批准）, 连续执行 `claude plugin marketplace update` → `claude plugin update` | (a) cache 5.13.2 中 agents 5 个 / bin / templates 齐全, (b) `claude plugin list` 为 5.13.2, (c) 结果记入 Plans.md 与 decisions.md D72 | 143.1 | cc:done | <!-- 2026-08-30 实测: installed 5.13.2、cache 5.13.2 是完整副本 (agents 5 / bin / templates)、claude plugin list 5.13.2。副本侧 CC 已经 clean (dirty 0)，restore 是 no-op -->

**共享文件 lane (Invariant 1)**: `tests/validate-plugin.sh` 的 owner 只有 142.7。`skills/maintenance/` 是 142.3，`skills/japanese-writing-drafter/` 与 `go/internal/writinglint/` 按 142.4 → 142.5 的顺序串行。`Plans.md` / `CHANGELOG.md` / `spec.md` 禁止 worker 编辑（由 Lead 在集成时编辑）。生成物（binary / mirror）在集成后于 trunk 重新生成 1 次（Invariant 3）。

**评审中提出但不含在本 Phase 的候选（未起票，等待 operator 判断）**: (i) runtime floor secret-read 的误检: jq 的字段引用语法命中了扩展名模式，导致只读命令被 deny（2026-08-24 1 次、2026-08-25 的 Plans.md 追加命令中 1 次、2026-08-26 本次发布作业中的 `git diff` grep 又 1 次，合计实测 3 次）。把命令字符串扫描限定为「位于文件参数位置的 token」的精细化是候选。**Phase 144 不解决这个**（单独的 `jq .key` 已经 PASS。file-arg 精细化是另一种设计）。(ii) 实测验证在分发目标（installed plugin）上 `.claude-plugin/settings.json` 的 permissions deny 可能没被读取。若没生效，就等于带着一份失效的 deny 名单。(iii) 基于 `docs/research/official-feature-inventory` 内容的机制层个别委托判断。

---

## Phase 144: secret-read 底层的对照 bug — `~/` 与 write-only `cat >` (2026-08-30 起票)

Purpose: 在 AISDR NQC 登录时，`cat > script <<'SH'` 与 `AISDR_ENV_FILE=~/LocalWork/.../.env bash script` 出现在同一条 Bash 字符串里，`RUNTIME_FLOOR:secret-read` 就会 deny。`HARNESS_RUNTIME_FLOOR_SECRET_ALLOW` 已经声明了 `/Users/.../LocalWork/`。底层的扫描对象仍是命令字符串本身（不看子进程）。不放宽 allowlist。不改成 deny→ask。

**Spec delta**:
- path: `spec.md`（Runtime Floor secret-read allowlist）+ `docs/runtime-floor-secret-allowlist.md`
- change: env allowlist 的对照不是 lexical 同一拼写，而是在命令 token 与声明两侧都把 `~/` 展开为 `UserHomeDir` 后再做 prefix 对照（这是拼写规范化，不是 named path 集合的扩大）。裸 `~` / `~/` 与 `/` 同样视为 invalid。只写模式（无位置输入也无 stdin redirect `<`）的 `cat >` / `cat >>` 不算 secret-read 动词。`cat FILE` / `cat FILE > out` / `cat FILE>/out` / `cat < FILE` 仍被 deny。
- why: 已声明的 work root 中 `~/` 与绝对路径不一致，会让官方 skill 以外的合法流水线卡住。部分字符串式的 `cat >` 排除会漏掉 `cat .env > out`。

**team_validation_mode**: subagent（Product / Architecture / Security / QA / Skeptic）。Required = tilde 两侧展开 + write-only cat 的操作数解析。Reject = deny→ask、子进程扫描、`$HOME` ExpandEnv、naive `cat >` 部分匹配、jq leftover (i) 的打包、Phase 142 的剩余项。

**formatter_baseline**: configured（`gofmt` / `go test` / `go vet`）。action: none。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 144.1 | `[lane:gate]` `[tdd:required]` secret-read 对照: (1) 在 `isAllowlistedSecretPath` 中把 token 与 allow 模式两侧都用相当于 `expandPathTarget` 的方式展开 `~/` 后再做 HasPrefix（HOME 解析失败时 fail-closed、落到 lexical。`$HOME` / `~user` 不动。裸 `~/` 无效）。(2) 只写模式的 `cat`（只有 stdout/heredoc redirect・位置参数 0・无 `<`）不算动词。用 `tokenize` 切分 `>`。解析失败则 deny。不扩大到 `cp`/`sed`/`grep` | 先实测 RED 再到 GREEN: (a) `cat ~/LocalWork/Code/app/.env` × allow=`$HOME/LocalWork/` → PASS, (b) `cat > script <<'SH'\necho start\nSH\nAISDR_ENV_FILE=~/LocalWork/.env bash script` 无 allow → PASS, (c) `cat .env` DENY, (d) `cat .env > out` 与 `cat .env>/tmp/x` DENY, (e) `cat ~/.ssh/id_rsa` × 同一 home 前缀 allow → DENY, (f) `cat > out .env` 与 `cat < .env` DENY, (g) `cd go && go test ./internal/runtimefloor/ -count=1` PASS, (h) `gofmt -l` 为空, (i) `go vet ./internal/runtimefloor/` 为空 | - | cc:完了 [4565555] |
| 144.2 | `[lane:fast]` `[tdd:skip:docs-only]` Spec/docs/CHANGELOG: 把 `spec.md` 的 secret-read allowlist 段落、`docs/runtime-floor-secret-allowlist.md` 中的「The environment match is lexical. Use the same absolute or `~/` spelling」替换为展开契约，在 CHANGELOG Unreleased 中记上 2 起误检（tilde / write-only cat） | (a) docs 写明「两侧展开 `~/`。named path 集合不会增加」, (b) 明记裸 `~/` 无效, (c) 明记 `cat .env > out` 仍被 deny, (d) `git diff --check` PASS | 144.1 | cc:完了 [888e45fd] |

## 事前确认
- 事项: 无（实现只涉及 fixture path。不读真实 `.env`。不做 push / 破坏性操作）
  理由: 144.1 是 `runtimefloor` 的单元测试与对照逻辑。144.2 是文档。
  scope: Phase 144 / Task 144.1-144.2

---

## Phase 145: Fable 5.1 与 GPT-6 astra 的 CCH 执行路径更新 (2026-09-05)

Purpose: 让在 CLI 本体选中的新模型也能在 CCH 的分工执行中使用，并核对实际设置、联动处理与分发目标。委托方的请求是本会话的「希望在我的环境里把 Fable、astra 也能在 CCH 中充分利用、完全更新」。不包含公开发布与权限扩张。

**Spec delta**: `spec.md` Current Frontier Model Integration、`docs/model-routing-policy.md`、`docs/spec/execution-backends-and-distribution.md`。Claude 的规划与协商用 Fable 5.1/high，Codex 的高级分工用 astra。保持既有的分工推理量与轻量 worker。完整传递显式模型、推理量与 Codex ultra。保留 Sonnet 的隔离评审。

**team_validation_mode**: subagent。`model_evidence` 负责一手资料，`routing_audit` 负责 Architecture/QA，`settings_audit` 负责 Product/Security/Skeptic。实际环境中确认了 Claude 2.1.261、Codex 0.153.4、CCH CLI 5.1.0、Claude plugin 5.14.1、Codex plugin 5.12.0 的差异。参考过往记录 `.claude/memory/patterns.md` P16/P20 与 D70 的接线契约，并用当前代码重新验证。

**采纳与否**: Required = 模型目录、native advisor/reviewer profile、companion 的显式指定与 ultra、advisor/loop 的执行路径、实际环境中的反映与回读、说明。Recommended = 传递完成条件与变更范围。Optional = Codex 的实验性 context_management。Reject = 所有 worker 的大型化、effort 的一律上调、安全设置的变更、公开发布、同一工作的付费比较。

**formatter_baseline**: configured (`bash -n`, ShellCheck, `gofmt`, `go test`, `go vet`)。无追加设置。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 145.1 | `[lane:gate]` `[tdd:required]` 更新 Claude/Codex 目录与 native profile、advisor 默认值 | 新 ID、分工分离、显式覆盖、生成 profile 的 focused tests 全部 PASS。旧设置的残留另行记载 | - | cc:done [Fable 5.1/Astra 目录、native profile、生成物与显式覆盖的回归 PASS] |
| 145.2 | `[lane:gate]` `[tdd:required]` companion 的 ultra 与显式 model/effort 的传播 | task 与 review 中 argv/config 都被保存。不支持的 mode 在 dispatch 之前停止。focused tests PASS | - | cc:done [frontier 25/25 PASS。核对 config/model/effort 与作业地点的传播、按 write 的别名、拒绝追加 root。Fable final APPROVE] |
| 145.3 | `[lane:gate]` `[tdd:required]` 核对 loop 与协商的执行路径 | route/override 一直传到实际调用。保持既有的完成判定与批准边界 | 145.1,145.2 | cc:done [advisor/loop focused tests PASS。核对实际目标 project 的设置解析、优先级、CLI 到达] |
| 145.4 | `[lane:fast]` `[tdd:skip:docs-only]` system card、设置、用法说明与规范的同步 | 区分一手资料的条件与页面、变更前后、实际设置、实测与未确认。CHANGELOG 与 skill mirror 保持一致 | 145.1,145.2,145.3 | cc:done [system card 的评价条件与页面、个别设置与运用说明、CHANGELOG/spec/mirror 同步] |
| 145.5 | `[lane:gate]` `[tdd:required]` 修正 Claude/Codex 分发物的辅助文件缺失，并核对这台 Mac 上的 CCH 更新与实际设置 | 分发物中协商与 loop worker 可运行。记录 active binary/plugin 的出处与哈希、模型解析、设置差异、恢复方法。不输出秘密值 | 145.1,145.2,145.3,145.4 | cc:done [反映 R5 的 59 个对象与 reviewer 参照 2 项、最终 R6 的 7 个入口。新增 CLI 的登记与 profile/skills/cache 已独立回读。保留手动 model/effort] |
| 145.6 | `[lane:gate]` `[tdd:skip:validation-review]` 必做验证与独立评审 | validate-plugin/check-consistency/ 适当的 focused tests 与独立 review APPROVE。明确 provider 是否实测 | 145.1,145.2,145.3,145.4,145.5 | cc:done [R6 validate152/0/0、consistency25、追加 setup21/21、source/activation 独立 APPROVE。区分真实 Fable 评审与 Astra 短时间实跑作为原路径的证据] |

**执行边界**: 对象是本地实现与验证，以及被委托的 CCH 使用环境更新。受保护设置的差异在冻结后，经过立花「已允许。」后只反映本次限定的 CCH 相关差异。批准记录在 `.claude/state/fable-astra/operator-approval-r5.json`。不扩展到秘密读取、追加计费、对外公开、权限设置变更的许可。

**TDD evidence**: `.claude/state/tdd-red-log/145.1.jsonl`（目录/validator 与 145.5 分发物）、`145.2.jsonl`（companion）、`145.3.jsonl`（advisor/loop）。145.1/145.2 的初次 raw log 未保存，因此注明是从观测 tool 输出重构而来。145.2 从初次 45 个失败与 3 个 capture error 开始，最终 25 个测试 PASS。追加 root 的修正保存了 raw RED 28 失败 → GREEN。更新生成 profile 后，Go 的 hostgen/hookhandler/cmd/harness 全部 PASS。

## Phase 146: Fable / astra 的指示向子 agent 的交接 (2026-09-05)

Purpose: 把追加请求的官方 prompting guide 与 CCH 全部 active prompt 面做对照。把成果、变更范围、完成条件、依据交给负责人，把已批准的工作推进到底。模型能力的改善量视为未测量。

**Spec delta**: `spec.md` Prompt Delivery Contract。把目的与方法分离，修正输入缺失与恢复时的信息丢失。保持既有的权限、按模型的 effort、Sonnet reviewer 隔离、TDD、有界评审、机器可读的返回格式。不包含新 API transport、默认 OFF 功能的启用、使用者设置的变更。

**team_validation_mode**: subagent。`routing_audit` 盘点全部 prompt 面，`model_evidence` 已对照指定 2 份资料与 Fable 5.1 的一手信息。shell runtime / Go runtime / workflow prompts 按所属文件分开并行实现，并做独立评审。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 146.1 | `[lane:gate]` `[tdd:required]` 保持 loop / advisor 的委托与恢复信息 | 选定的计划、完成条件、推定 scope、失败的具体依据都传到实际调用。未提供的批准不补造。恢复时还原上次的协商指示。RED / GREEN 与既有 loop 回归 PASS | - | cc:done [14 个输入投递案例与 49 个回归 PASS。按 run 恢复协商成功记录。实测修正长输出的 ARG_MAX，并保留全文证据与 8KiB 以内的参照摘要] |
| 146.2 | `[lane:gate]` `[tdd:required]` 修正 Go team worker 的指示缺失与 opt-in review 的返回契约 | task description 与修正意见传到实际 companion。把形式传达给 reviewer / brain，被否定的 APPROVE 不算成功。保持默认 OFF。RED / GREEN 与目标 Go tests PASS | - | cc:done [在 worker/reviewer/brain 中保持原指示与修正案。cwd 一致、strict JSON、race 验证与目标 Go 全 tests PASS。Go opt-in production 未支持另行记载] |
| 146.3 | `[lane:fast]` `[tdd:skip:prompt-only]` 审计全部 active prompt 面并调整分工指示 | 把 shared skills 23 本、Codex 差异 3 本、references、native agents / profiles、Go 内嵌 4 本、setup 常驻指示、hook 记入审计表。只改必要的文字，保持固定审计 prompt 与安全契约 | - | cc:done [workflow 84/84 审计、51 修正/33 保持。native/setup/embedded 审计、手动设置优先、mirror 重新生成后既有 checks PASS] |
| 146.4 | `[lane:gate]` `[tdd:required]` 向 browser reviewer 传递完成条件与目标信息 | 保持 schema / browser route，把契约的 DoD / 推定 scope / non-goals / notes / 上限 保持在 execution_instructions 中。用 3 个 route 的捕获做验证。不把推定 scope 当作批准 | - | cc:done [RED→GREEN、3 个 browser routes 与 schema 保持、EN/JA rendering PASS] |
| 146.5 | `[lane:gate]` `[tdd:skip:validation-review]` 重做分发、说明、验证与反映方案 | mirror / native profile / Mac binary / 新 staging 一致。必做验证与独立 review APPROVE。把个别设置的变更方案对齐到新的 prompt。准备时的批准状态与实际反映分开记录 | 146.1,146.2,146.3,146.4 | cc:done [在 R5 中完成反映方案后取得明示许可。loader 发现后的 R6 也达成 850 文件一致、全 152 项验证、独立 APPROVE、新启动的回读完成] |

**执行边界**: Phase 145 的 R3 保持为变更前的已验证候选。替换为 146 完成后的候选后再进入 145.5 的启用。原作业树、CJ-Plugin 正本、user config、既有 plugin cache 在本 Phase 不编辑。

**追加指示**: 「我动态改变的部分请保持可接受」。尊重使用者的明示 model / effort，以及反映前不在变更对象内的设置。146.5 的反映方案不退回旧审计值，只把 CCH 目标键的冲突可视化。这不是对设置反映本身的批准记录。

**最终状态**: `.claude/state/fable-astra/verification-r6.json`。Phase 145/146 共 11 个工序完成。经过立花「已允许。」后实施了受保护设置的限定反映。在 R5 回读中发现的 inline reviewer 优先参照 2 项已修正，setup 的复发防止已纳入 R6 并完成切换。59 项原记录、2 项补全、R6 的 7 个入口切换分别用独立 receipt 保存。最终观测到通常 Codex 为 `xhigh`、Orca 为 `high`，更新处理没有重新挑选。区分 native 子进程的权限继承与 companion review 的 read-only 执行。

## Phase 147: Fable / astra 更新的发布前评审与发布 (2026-09-06)

**目的**: 一起验证 Phase 145/146、最新规范的 README、日语产品指南，并确认到发布分发物。
**批准来源**: 2026-09-06 的请求「发布前先做 harness-review，没出 OK 就改完再评审。出了 OK 就按建议走 harness-release」。包含评审合格后的常规 PR、合并到 main、版本 tag、GitHub Release。
**范围**: `work/fable-astra-20260905` 的未发布变更。不包含原作业树中无关的变更与个人 CLI 设置。

| ID | Task | DoD | Depends | Status |
|----|------|-----|---------|--------|
| 147.1 | `[lane:gate]` `[tdd:required]` 独立评审、修正指摘、再评审 | 从 3 个视角确认原请求与差异。critical / major 为 0、独立 APPROVE、修正前后的验证记录 | - | cc:done [修正了依赖实际设置、cwd 别名、Linux 参数上限、巨大 status、lane 分类、cwd 回归的旧表述、GNU stat 的恢复缺陷。独立再评审 APPROVE。26/16/49 回归、Mac/Linux 的 routing 与 fresh/stale 恢复 PASS] |
| 147.2 | `[lane:release]` `[tdd:skip:validation-review]` 分发验证与作业提交 | plugin / consistency / mirror / release preflight 全部合格。记录警告依据，只提交对象变更 | 147.1 | cc:done [把评审过的 214 个文件记录到 16843659。clean preflight 24 合格/5 警告/0 失败，保存警告方针] |
| 147.3 | `[lane:release]` `[tdd:skip:release-metadata]` 发布推荐版本 | 同步全部 version 面。PR 的 CI 成功后合并到 main，并在可达的 commit 上创建 semver tag | 147.2 | cc:WIP |
| 147.4 | `[lane:release]` `[tdd:skip:release-verification]` 回读发布结果 | GitHub Release 已公开。确认 4 个环境的分发物、版本号、digest。保留完成标记与证据 | 147.3 | cc:TODO |

**完成条件**: main、tag、GitHub Release、4 个环境的分发物指向同一个 release，且没有未解决的 critical / major。
**验证记录**: `.claude/state/release-20260906/`。本地确认与发布后的确认分开记录。

## Phase 148: 面向使用者的日英 README 与变更履历的重构 (2026-10-13)

**目的**: 让非工程师也能判断用途、导入、可委托范围、更新时的影响。
**批准来源**: 把 README 与 CHANGELOG 以日英平实语言从 0 基础重写的请求。包含 harness-release 的执行。公开操作在完成产物与发布方案的单次确认之后。
**基准版**: origin/main `6c198b4c76f983d82a93048d67807b45551a6dc6`、VERSION 5.15.0。原作业树已陈旧且包含无关的未保存变更，因此使用专用 worktree。
**规范影响**: 仅文档。不改变 host tier、模型、权限、行为。
**触碰路径**: docs/images/readme/hero-motion-{en,ja}.*、docs/images/.gitignore、docs/research/readme-visual-asset-manifest.md、specs/2026-10-readme-motion/design.md、specs/2026-10-readme-motion/build-assets.py、README.md、README_ja.md、CHANGELOG.md、CHANGELOG_ja.md、CHANGELOG.md.archive-2026-10-13.md、codex/README.md（需要整合导入路径时）、spec.md、Plans.md、tests/test-readme-product-surface.sh（只改依赖编辑方针的文字期望值）、tests/test-claude-upstream-integration.sh（只作过往原文的确认处与固定 SHA 检查）、tests/test-public-claims-contract.sh（只改保持「按 task 指定测试」这一含义的文字期望值）。
**AC**: (1) 日英 README 说明使用目的、导入、第一次委托、判断、限制、费用、数据、恢复、更新。(2) 日英变更履历保留全部版本与日期、比较链接、对更新判断有效的条件。(3) 命令与对应范围同实际规范一致，且日英含义一致。(4) 原变更履历原样保留。(5) 既有的对象检查与独立评审合格。(6) 公开前把版本号、对象文件、main 反映与公开内容呈现给本人。
**追加指示**: 不假定读者读过 hero 与开头。改成用大的课题提示与 3 个视觉对应就能理解的结构，解释放到后面。
**非对象**: 产品行为、受保护设置、既有个人设置、无关报告。抹除履历、虚构的兼容性保证、抢在发布成功之前。
**team_validation_mode**: subagent。事先与 Astra 和 Fable 咨询、写作与别家系的判定、图纸检查。

| ID | Task | DoD | Depends | Status |
|----|------|-----|---------|--------|
| 148.1 | `[lane:fast]` `[tdd:skip:docs-only]` 确认实际规范与履历，重建日英文档 | 满足 AC1-4 的文字。保存过往原文 | - | cc:done [创建日英 4 个文档、SVG/GIF/静止版。逐条对照 159 版的原文条件并恢复。保留原文 SHA 与 149 比较链接。独立判定 APPROVE] |
| 148.2 | `[lane:gate]` `[tdd:skip:validation-review]` 文档验证与独立判定 | AC5。记录试验命令的退出码与判定 | 148.1 | cc:done [README/SVG R3 与 CHANGELOG R3 均为 Claude Opus 5.5 APPROVE。在 c43e49f18ba1ac10ddba9d050b7e1d8e8e20a79d 上以 clean 同一 SHA 实测 exit0。实效性的未验证条件也在日英中注明] |
| 148.3 | `[lane:release]` `[tdd:skip:release-preparation]` 发布准备 | AC6。备齐 preflight、变更履历升格方案、公开文字 | 148.2 | cc:done [在本地准备 patch5.15.1 的日英公开文字与公开步骤。VERSION 未变更。Claude2.1.296 的 manifest 验证与 tag dry-run 因保留名拒绝而 exit1。发布准备的产物保存在另行记录的 route-job 中] |
| 148.4 | `[lane:release]` `[tdd:skip:release-verification]` 批准后确认反映与公开 | 可从 main 到达的 tag、GitHub Release、分发物的回读 | 148.3 | cc:TODO [停止中: 分发名的变更属于新的产品判断。push/merge/tag/Release 均未实施。等 manifest 验证成功与本人公开确认后再继续] |

**停止条件**: 公开批准前不做 push、merge、tag、公开。不把 preflight 或独立判定的失败替换成成功。需要新的产品判断的变更不混入本次编辑。

**文档公开准备的记录**: route-job `20261013-202516-ep3t`。

**改名的公开准备**: Claude Code 2.1.296 会把 manifest 名 `claude-code-harness` 作为保留名拒绝。`claude plugin validate .claude-plugin/plugin.json` 与 `claude plugin tag .claude-plugin --dry-run` 都是 exit1。版本号变更、push、merge、tag、公开均未实施。改名与检查回避不混入本次文档编辑。


## Phase 149: 把分发 ID 改为 harness (2026-10-14)

**批准来源**: 对「把分发 ID 改为 harness 并整理既有使用者的更新步骤」这一提案，本人回复「可以」。
**基准版**: docs/user-first-bilingual `3e1fdb2c279e8a82c5cbc2107c891135b2cdcb68`。文档的验收已完成。
**目的**: 解除 Claude Code 的保留名拒绝，同时在新 ID 下仍正确保持设置生成与 hook 启动。
**非对象**: GitHub 仓库名、marketplace 名、内部设置与记忆的存放位置、保护规则、模型、既有个人设置的变更。不公开，不改写旧版履历。
**触碰路径**: 全部 4 个执行目标的分发 manifest、scripts/build-host-plugin-dist.sh 与 setup-cursor.sh/setup-grok.sh、harness.toml、.claude-plugin/plugin.json 与 marketplace.json、两个 hooks.json、go/internal/hostgen/hostgen.go、scripts/sync-plugin-cache.sh、引用分发 ID 的导入/检查/生成源、README 日英、现行 onboarding 日英、CHANGELOG 日英的 Unreleased、bin/harness-*（Go 差异的重新生成）、对应检查、Plans.md/spec.md、诊断脚本指引的 docs/local-harness-environment-cleanup.md。追加调查发现共享 marketplace 与全部 manifest 的 ID 必须一致，因此把分发 ID 在所有执行目标上统一。go/cmd/harness/migration_report.go、scripts/userprompt-track-command.sh、go/internal/hookhandler/userprompt_track_command.go、quick-install/codex-setup-local/opencode-setup-local 与相关检查也在对象内。旧命名空间只作为迁移输入被识别。共享 skills/Codex 差异/templates 与受版本控制的 Codex/OpenCode/Cursor 镜像、docs/team-composition.md 中的执行用命名空间也统一。tests/validate-plugin.sh 与 Cursor/Grok 的隔离检查使用临时 HOME 但使用真实 Node 本体。不改变模型与期待的行为。
**AC1**: 正本与生成的 manifest、marketplace entry 都指向 harness，在 Claude2.1.296 下 manifest 验证成功。VERSION 保持 5.15.0。
**AC2**: 设置生成不回退到旧 ID，从环境指定与新 ID 的 cache 启动 hook。设置生成源与分发 hook 一致。
**AC3**: 即使版本相同也不把新 ID 的 hook 覆盖到旧 ID 的 marketplace clone。不擅自创建既有 cache，不对真实 HOME 执行同步或导入。
**AC4**: 用日英说明 renames 带来的设置键迁移、按 scope 的新 ID 导入、旧版的 keep-data 手动路径、重新加载、旧设置的确认，并避免双重 hook。若与名称绑定的存储区的继承尚未确认则明确注明。
**AC5**: 回归检查与 4 个环境二进制的一致性、独立评审成功。只产出本地成果。公开另做单次确认。

| ID | Task | DoD | Depends | Status |
|----|------|-----|---------|--------|
| 149.1 | 确认 Astra/Fable 的变更范围 | 识别名称、路径、对既有使用者的影响 | - | cc:done [两次咨询均完成。识别出正本与 68 个 hook、同版不同 ID 的 cache、共享 marketplace、专用 DB 的迁移条件] |
| 149.2 | 变更正本、生成、启动与 cache 同步 | AC1-3、从 RED 到 GREEN 的回归证据 | 149.1 | cc:done [变更正本/生成/启动/cache。从旧 ID 与新命名空间的 RED 到 GREEN。全部 154 项与目标 19 项检查成功] |
| 149.3 | 备齐日英的更新步骤与二进制 | AC4-5 的对象检查 | 149.2 | cc:done [4 个环境重新生成。明确日英的迁移步骤与数据约束。在检查前后 clean 的同一 SHA 上验证为 0] |
| 149.4 | 独立判定与更新公开方案 | APPROVE 与同一 SHA 的试验。保持公开未实施的状态进入单次确认 | 149.3 | cc:done [产品差异 17718b96 由 Opus5.5 判定 PASS。记录同一 SHA 上验证为 0。公开前检查 24 成功/5 警告。修正现行的 cleanup 指引，隔离 user 范围的设置键迁移也成功。公开候选 5.16.0 的方案与日英文字已在本地准备。公开尚未批准] |

**Phase149 的公开边界**: 合并到 main 会让 marketplace 更新使用者收到改名通知，因此在 push 与 merge 之前先取得公开批准。保持 VERSION 5.15.0 不把改名单独送上 main。公开时把同步到 5.16.0 与 4 个二进制重新生成合并进行。产品独立判定中剩下的「其他 marketplace 上同名 harness」的报告拾取条件，以及隔离检查中 Node 目录优先，都记录进公开方案。


## Phase 150: v5.16.0 发布 (2026-10-15)

本人明确批准发布 v5.16.0。执行版本同步、日英 Unreleased 升格、4 个二进制重新生成、检查、push/PR/CI/main 合并、在可达的 main 上打 tag、Release 与分发物验证。产品与文档已独立 PASS 到 0fe2c1c1。

| ID | Task | DoD | Status |
|----|------|-----|--------|
| 150.1 | 版本同步与 4 个二进制 | 同步 5.16.0、日英同日、检查成功 | cc:WIP |
| 150.2 | PR 与 main 反映 | 必做 CI 成功、合并已批准的内容 | cc:TODO |
| 150.3 | tag 与公开验证 | main 可达 tag v5.16.0、确认 Release 正文与 4 个分发物 | cc:TODO |
