# Cross-Repo Handoff Workflow (claude-code-harness ↔ harness-mem)

claude-code-harness 和 sibling repo `harness-mem` 之间发生的责任边界调整・契约变更・实现移管的
可再现记录的 SSOT。

本文是 decisions.md D42 (`claude-code-harness ↔ harness-mem 责任边界 + Cross-repo Handoff Workflow`)
的可编纂 policy 部分抽出。decisions.md 是 per-developer 的 local SSOT (gitignore 对象)，
因此需要共享的 policy 放在本文件。

## 为什么需要这个规则

claude-code-harness Phase 65 Phase A 完走时的 review 中，
用户表示"本来应该在 harness-mem 侧实现的东西却在 claude-code-harness 侧实现了的话，
(i) 从 claude-code-harness 排除，(ii) 向 harness-mem 侧易懂地提 Issue"的运用期待。

实际情况是 (i) 已完成（Phase 60 的 managed companion 化、Phase 63 的 dead default 整理），
但 (ii) 不是 GitHub Issue，而是用 harness-mem repo 的 `Plans.md §NNN` 这个 sibling-repo Plans SSOT 方式运用。
GitHub Issue 仅有 #70 (Phase 49.1.2 follow-up) 1 件。

用户期待 (GitHub Issue) 和运用实际情况 (Plans.md SSOT) 的差分原因是"policy 未文档化"。
本规则将其固定为正式运用，防止再发。

## 3 层 Redaction 的责任边界 (Phase 65 cross-project safety)

| Layer | 内容 | 实现层 | 理由 |
|---|---|---|---|
| Layer 1 | privacy filter (`<private>` strip) + project scope (`strict_project: true`) | **harness-mem server 侧** | mem 出口统一 guard 全 client (CC / Codex / opencode)。`include_private=false` default |
| Layer 2a | 字典式固有名词 redaction (`client-redaction.yaml`) | **claude-code-harness client 侧** | project-local config 的解释是 presentation layer 的责任。server 有 schema 解释会让企业各自的 redaction policy 泄露到 server 设置面 |
| Layer 2b | NER (kuromoji 等 Japanese tokenizer) | **claude-code-harness client 侧** | 回避 server 依赖膨胀：ONNX embedding (multilingual-e5) 已经很重，追加 JP tokenizer 会损害 cold start (~5ms) 和 memory footprint |
| Layer 3 | HTML 生成前最终 scan | **claude-code-harness client 侧** | render-html.sh 是 client 才有（rendering pipeline 上只能放在 client） |

将来希望 server 侧 PII redaction 标志时，作为 `redact_profile` 参数的 opt-in 设计
在 harness-mem 侧 §111 以后重新探讨有余地。

### Phase 65.3 实现决定事项 (D43)

Phase 65.3 着手前与 mem 侧协调确定的使用约束：

| 约束 | 内容 | 依据 |
|---|---|---|
| MCP cross-project 是 N-call | `mcp__harness__harness_mem_search` 的 MCP schema 仅暴露 `project: string` 单值（`projects: [array]` 和 `strict_project: boolean` 不在 MCP 中）。cross-project 搜索是 client 侧对各 member 逐一 MCP call，在 client 侧 merge・dedupe | mem 侧 mcp-server schema 确认 (`mcp-server/src/tools/memory.ts:297-341`) |
| client-redaction.yaml 与 PiiRule 兼容 | client 侧 dict schema (`client-redaction.v1`) 与 mem 侧现有 `pii-filter.ts` 的 `PiiRule[]` schema 和字段名兼容（`rule_id`、`pattern`、`replace_with` 等）。完全共通化 (npm package) 是将来 follow-up | 回避重复实现 + 确保 Cross-client 一贯性节 upgrade path |
| `[REDACTED_*]` 双重置换 guard | server 侧 `event-recorder.ts:redactContent` 已将 email / API key / hex 置换为 `[REDACTED_*]`。client Layer 2 redact 对已存标记**不再置换**的 sentinel guard 是必需的 | 防止双重置换导致信息损坏 |
| applied_filters 注记方针 | mem 侧 `applied_filters` meta 未实现（仅内部 audit）。Phase 65.3.6 audit log 仅记录 Layer 2/3 (client)，Layer 1 (server) 明示注记为"依赖 server default + 内部 audit" | 确认 mem 侧未实现，本 Phase 不 blocking |

将来 cross-project N-call 的延迟在实运营中成为问题时 **XR-005**（MCP schema 追加 `projects: [array]` + `strict_project: boolean`）作为 harness-mem §111 起票。

### Phase 65.3 完走报告 (2026-05-09)

Phase C 7 任务在 1 个会话内完走，Cross-Contract 变更零，claude-code-harness 内部完结。

| Phase | task | commit | 主要产物 | 测试 |
|---|---|---|---|---|
| C-1 | 65.3.1 | `4a014137` | `.claude/rules/cross-project-groups.yaml` SSOT + `scripts/load-cross-project-groups.sh` (yaml → JSON validator) + `docs/cross-project-groups-schema.md` | 21 PASS |
| C-2 | 65.3.2 | `5152bed2` | `.claude/rules/client-redaction.yaml` (PiiRule 兼容 schema) + `scripts/redact-by-dictionary.sh` Layer 2a + 双重置换 guard | 26 PASS |
| C-3 | 65.3.3 | `20a4478f` | `scripts/redact-by-ner.sh` Layer 2b (fugashi tokenizer + fail-open) | 22 PASS |
| C-4 | 65.3.4 | `0ae3f40a` | `scripts/render-html.sh --with-redaction` Layer 3 最终 scan + `scripts/final-scan-redaction.py` | 16 PASS |
| C-5 | 65.3.5 | `09377eb9` | `harness-plan-brief` / `harness-accept` SKILL.md 追加 `--cross-project-group <name>` flag opt-in (D43 Option α: MCP N-call) | 18 PASS |
| C-6 | 65.3.6 | `272a8f33` | `cross-project-audit.v1` audit log + `scripts/cross-project-audit-log.sh` + HTML 审计汇总显示 | 21 PASS |
| C-7 | 65.3.7 | `c05d6ef8` | e2e validation (3-member group + 全层贯通 + envelope + sentinel guard) | 21 PASS |

**累计**：7 feat commit + 7 chore commit = 14 commit、145 assertion 全 PASS、`./tests/validate-plugin.sh` 是 51 → 58 (+7)、`bash scripts/ci/check-consistency.sh` 全合格。

D43 4 判断包全部按初期设计发挥作用，设想外的约束和返工未发生。

**未起票 follow-up trigger 一览**（仅在触发条件达成时向 harness-mem §111 起票）：
- XR-005: MCP schema 追加 `projects: [array]` + `strict_project: boolean` — N-call 延迟在实运营中成为问题时
- (旧假称 §110-S110-006): `applied_filters` meta 实现 — 从 client 可视化 server-side filter 适用的需求出现时 ※实 §110 S110-006 作为本 Phase C closure record 已消费（见下）
- PiiRule 共通化 npm package：Cross-client 一贯性真正需要时（mem 侧 PiiRule schema reference 见下）

### Phase 65.3 closure ack (harness-mem 侧受领，2026-05-10)

harness-mem 会话将 Phase C 完走报告作为 **§110 内 S110-006**
受领（确认 Cross-Contract 变更零）。新 §111 不需要，统合到 §110 下的 SSOT 运用方针。

| 项目 | mem 侧 commit | 内容 |
|---|---|---|
| content commit | `8b34ecb` | S110-006 Phase C closure record + 6 invariant 冲突 review (0 件) + PiiRule reference 一览 |
| hash backfill | `ad4ba56` | S110-006 cc:完了 [8b34ecb] |
| (任意 follow-up) | (S110-007 候选) | envelope 契约中"signals 不含 PII"的 documentation 化 — 在 mem 侧接受范围，claude-code-harness 侧起票不要 |

**6 invariant 冲突 review 结果**（mem 侧确认，冲突 0 件）：
- `<private>` strip / Layer 2/3 重复：无冲突（server 删除后从 client 不可见的设计）
- `[REDACTED_*]` sentinel format：无冲突（mem 侧大写 `EMAIL` / `KEY` / `SECRET` / `HEX`、client 侧 regex `[A-Za-z0-9_]+` 应对两者）
- envelope `validateProseContainsSignals`：实用上无冲突（S110-007 候选中 envelope 契约侧 documentation 化，claude-code-harness 侧 client-redaction.yaml 追加防御性注记应对）
- cross-project N-call rate limit：无冲突（mem 侧无 rate limit 设置，N=5-10 想定无问题）
- Cross-project privacy tag merge：无冲突（server 按 project 独立 filter，merge 是 client 职责）
- audit log structure：无冲突（Phase 65.3.6 client 侧完结）

### PiiRule schema 官方参照 (mem 侧 commit `8b34ecb` 共有，npm package 化起票时的参照点)

`mcp-server/src/pii/pii-filter.ts` 的 PiiRule 规格（将来 npm package 化起票时的参照点固定）：

| 类别 | 路径 | 内容 |
|---|---|---|
| TS SoT | `mcp-server/src/pii/pii-filter.ts:15-20` | `interface PiiRule { name: string; pattern: string; replacement: string }` |
| TS SoT | `mcp-server/src/pii/pii-filter.ts:22-24` | `interface PiiRulesFile { rules?: PiiRule[] }` |
| 函数 export | `mcp-server/src/pii/pii-filter.ts:33, 50, 69-85, 92` | `applyPiiFilter` / `loadPiiRules` / `DEFAULT_PII_RULES` / `getActivePiiRules` |
| .d.ts | `mcp-server/dist/pii/pii-filter.d.ts:1-6` | 编译版声明 |
| 环境变量 | `docs/environment-variables.md:102-111, 302-303` | `HARNESS_MEM_PII_FILTER` / `HARNESS_MEM_PII_RULES_PATH` |
| 公式仕様 doc | `docs/specs/vps-team-deploy-spec.md:57, 260-285` | TEAM-006 PII 过滤（例 JSON 是 `:270-275` inline） |
| Contract test | `mcp-server/tests/unit/pii-filter.test.ts:1-56` | 5 案例 (phone JP / email / LINE_ID / 复合 / 空规则) |
| Usage 例 | `mcp-server/src/tools/memory.ts:13, 1067-1068` | `record_checkpoint` 内应用 |

**重要 caveat**：README / OpenAPI 无 PiiRule component schema，无作为 JSON Schema 独立 export。
起票 npm package 化时**同时 scope 化 schema export 和官方 doc 整顿**（mem 侧劝诱）。

### Cross-client 一贯性的担保方针

"从 Codex 等其他 client 调用时 redact 也生效"的需求，通过**在 client 侧共通化 shared library (npm package or sub-module)** 的方针应对。server 侧 MCP API 出口不 redact 的理由：

- 将来 team sharing (`harness_mem_share_to_team`) 中"返回正确原文"的契约会破坏，失去可逆性
- 保持 server 为"presentation policy free"，不妨碍 client diversity (CC / Codex / opencode / 将来的 third-party client)

取而代之，harness-mem 根据需要提供在 `mcp__harness__harness_mem_search` 的 response meta 中
包含 `applied_filters`（例：`privacy_filter` / `project_scope`）的扩展（harness-mem §110 follow-up 或 §111 起票）。

## XR-Registry 的废除（operator 裁定 2026-07-16）

管理 repo `harness-governance-private` 的 XR-Registry.md 于 **2026-07-16 裁定废除**
（同 repo 发现 `.git` 破损，以 backup 整顿为契机选择废除）。此后：

- cross-repo 起票**统一为路径 A（harness-mem `Plans.md §NNN`）**。不进行 XR 编号的新采番
- 现有的 XR-000〜XR-005 记录文件作为历史记录保留（不新增参照）
- claude-code-harness ↔ harness-mem 的联动频率高。handoff 的目的地・DoD・evidence
  始终放在 harness-mem 侧 Plans.md，遵循本规则的路径 A 步骤

## Cross-repo Handoff 的 2 路径

claude-code-harness ↔ harness-mem 的 handoff 使用以下 2 路径切换。

### 路径 A: harness-mem repo 的 `Plans.md §NNN` (sibling-repo Plans SSOT)

**用途**：需要详细 DoD 的 Cross-Contract changes、跨多会话参照的 handoff

**例**：
- §106 (companion contract handoff、Phase 60 起票、cc:完了)
- §107 (checkpoint cold-start handoff、cc:完了)
- §110 (Cross-repo Handoff Workflow Codification、本规则的相对侧、harness-mem 侧 codification 完成)

**步骤**：
1. claude-code-harness 侧判断"应该向 mem 侧移管实现"时，在 Plans.md 追加 section（例：§111）
2. 在 section 内列举需要的 DoD（接受条件、技术约束、需要参照的 claude-code-harness 侧 commit hash）
3. 在**同一 PR 中排除**claude-code-harness 侧相关箇所（skills/scripts/docs）（Phase 60 的 `1f4d9133`、`5373d50d` 模式）
4. 需要时在本规则 `docs/rules/cross-repo-handoff.md` 的表中追加新行

### 路径 B: GitHub Issue

**用途**：跨 Cross-Runtime long-running follow-ups（跨多会话・多 PR 的検討、需要外部参加者露出）

**例**：harness-mem #70 (Phase 49.1.2 follow-up)

**步骤**：
1. 用 `gh issue create --repo Chachamaru127/harness-mem --title "..." --body "..."` 起票
2. 从 claude-code-harness 侧仅保留 `# See harness-mem#NN` 的注释（不实现）
3. mem 侧 issue 被 close 后，更新 claude-code-harness 侧本规则的参照

## 判断轴（使用哪个）

| 观点 | A: Plans.md §NNN | B: GitHub Issue |
|---|---|---|
| 需要详细 DoD 吗 | ✓ 可写详细 DoD | △ Issue body 是流动的 |
| 跨多会话参照吗 | ✓ Plans.md 是永续 SSOT | △ Issue 时间经过后难读 |
| 需要外部参加者露出吗 | △ 仅 repo collaborator 可见 | ✓ public repo 时外部可见 |
| 是无实害的 closeout-only 吗 | ✓ 轻量 | △ 立 issue 会产生 closeout 工数 |
| 是 long-running cross-runtime 吗 | △ Plans.md cross-runtime 弱 | ✓ Issue 合适 |

犹豫时 **路径 A (Plans.md §NNN)** 为 default。理由：过去 4 件 handoff 中 3 件（Phase 60、63、65）
用 Plans.md SSOT 完成，有运用实绩。GitHub Issue 仅有 #70 1 件。

## 过去的边界调整实绩（不 retroactive 起票）

以下过去 handoff 因本规则确定"Plans.md §NNN 与 GitHub Issue 等价"，**不进行 retroactive GitHub Issue 起票**：

- Phase 60 (managed companion 化) — harness-mem Plans.md §106
- Phase 63 (dead default 整理) — harness-mem Plans.md §107
- Phase 65.3 (3 层 redaction 的 owner 确认) — 本规则表 + harness-mem Plans.md §110

将来边界变更时从本规则的 2 路径中选择。

## 相关

- claude-code-harness `.claude/memory/decisions.md` D42（本规则的 local SSOT 源、gitignore 对象）
- claude-code-harness `docs/rules/migration-policy.md`（Phase 60 删除概念的手続记录）
- harness-mem `docs/claude-harness-companion-contract.md:84-96`（Cross-repo Handoff Workflow 部分、mem 侧相对侧）
- harness-mem `.claude/memory/patterns.md:230`（P7 Non-Application Conditions 追加 Plans.md SSOT 例外）
- harness-mem Plans.md §110（Cross-repo Handoff Workflow Codification、本规则的相对侧）

## 重新审视条件

- **Trigger A**: server 侧提供 PII redaction opt-in API（例：`redact_profile` 参数）在 harness-mem §111+ 实现时 — 重新探讨 Layer 2 的 owner
- **Trigger B**: 为 Cross-client 一贯性的 shared library npm 化时 — 更新 Cross-client 一贯性节
- **Trigger C**: harness-mem `mcp__harness__harness_mem_search` 的 response meta 追加 `applied_filters` 时 — 更新 Layer 1 验证路径
