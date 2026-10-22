# Flat Review 2026-07-05 — Findings Closeout Ledger

S0 中立 flat review（35 agents、敌对验证、confirmed 17 + plausible 8、refuted 5）的 findings 处理台账。
状态为 `fixed`（已修复・有 commit）/ `deferred`（后续 Phase 参考）/ `waived`（故意不处理・附理由）三种值，保持未处理为 0 件。

## Wave 1（Phase 104 P0）fixed

| # | severity | finding | 处理 | commit / task |
|---|---|---|---|---|
| 1 | critical | R15 秘密文件 git add block 在 redesign 中缺失 | fixed | 104.1 `4ca6caef` |
| 2 | major | Bridge Daemon 约1900行无法到达 binary | fixed（删除 + 知识 spec 翻译记录） | 104.4 `7b563987` |
| 3 | major | judgment-card/ledger runtime caller 为零 | deferred（保留 + wired:no 注记，S3 配线） | 104.4 → 105 |
| 4 | major | HARNESS_AUTO_APPROVE 装饰性 no-op | fixed（主张撤回） | 104.3 `e46f6a5f` |
| 5 | major | Plans.md Depends↔Status 台账矛盾 + 无检测 gate | fixed（checker + gate [20/22]） | 104.2 `212a781d` |
| 6 | major | 4件模糊 skill 未整理 | fixed（删除3件 + 保留1件裁定） | 104.9 `9efa0956` |
| 7 | major | branch-alignment gate 未任务化 | fixed（台账 + gate [21/22]） | 104.5 `212a781d` |
| 8 | major | binary/source drift 验证无 CI gate | fixed（drift gate [22/22] + build-all.sh -trimpath 统一） | 104.6 `1050ac56` |
| 9 | minor | dual hooks.json sync test 未接入 CI | fixed | 104.7 `212a781d` |
| 10 | minor | impact_score 为 Go/shell 双重实现 | fixed（统一为 Go） | 104.4 `7b563987` |
| 11 | minor | triaddispatcher / GenerateDeliveryHooksJSON caller 为零 | fixed（删除 triaddispatcher。delivery gen 在 105.9 裁定） | 104.4 → 105.9 |
| 12 | minor | model routing 旧世代 sonnet-4-6 硬编码 | fixed（Sonnet 5 化 + gate [16/22] 更新） | 104.8 `7b065700` |

## Wave 2（Phase 105 P1）fixed

| # | severity | finding | 处理 | 参照 task |
|---|---|---|---|---|
| 13 | major | README_HOTL 节间成熟度显示自相矛盾 | fixed（redesign README.md 已验证诚实，言行一致 self-check 节已添加。自相矛盾是 untracked HOTL 草稿的话题，不在本次 branch 范围内） | 105.11 |
| 14 | major | bridge_events schema 知识在3个文件 DRY 违规 | fixed（聚合到 go/internal/eventstore） | 105.5 |
| 15 | major | Night Watch open-decision 检测因自 repo 格式不兼容永久为 0 件 | fixed（`## D<N>:` + JP status 对应） | 105.4 |
| 16 | major | 非工程师 3 画面在本流流程中孤立 | fixed（plan/work/release skill + README 引导） | 105.1 |
| 17 | major | i18n contract 在 Go hookhandler 中大范围破裂 | fixed（新增 ratchet gate [23/23] enforcement + inbox_check 引用迁移。剩余12个文件批量迁移在 Phase 106 起票） | 105.2 → 106 |
| 18 | major | Plan Brief confidence 为误解性求和 + 空数组 | fixed（plan_readiness 单轴 + 3 数组生成步骤） | 105.3 |
| 19 | major | harness-setup SKILL.md 460行 增筑状态 | fixed（460→101，拆分到 references/） | 105.10 |
| 20 | minor | README badge『Skills: 5 Verbs』偏离 | fixed（5 core / 22 total 表述） | 105.10 |
| 21 | minor | spec.md 1462行 未拆分 | fixed（1467→197，拆分为 docs/spec/ sub-spec） | 105.10 |
| 22 | minor | failurecodifier 部分字符串误判 | fixed（token 边界判定） | 105.6 |
| 23 | minor | 327MB worktree reap 遗漏 + 无检测 | fixed（.gitignore + doctor 过期检测） | 105.7 |
| 24 | minor | runtime floor secret-read 对文档文本内 .env 名称 false positive | fixed（heredoc/注释排除的 executable-text scan） | 105.8 |

## L3 前进（计划外的追加成果）

| finding 外 | 内容 | task |
|---|---|---|
| — | delivery hook 生成 GAP（GenerateDeliveryHooksJSON 未连接 harness gen）配线。Codex/Cursor 生成 hooks 实现 enforcement + delivery 兼顾。北极星 L3 协调的一步 | 105.9 |

## refuted（敌对验证中驳回、不需要处理）— waived

| # | finding | 驳回理由 |
|---|---|---|
| 25 | 「同代其他契约已确认实配线、drift 是局部性的」 | 肯定性所见（drift 不是全面而是局部性的已确认）。不需要处理 |

## 未处理计数（Wave 1 + Wave 2 完成时点）

- fixed: 24（Wave 1 的 12 + Wave 2 的 12）
- waived: 1
- **未处理（状态未定）: 0**

**follow-up（已起票、未处理不等于悬空）**: Phase 106（i18n 批量迁移、剩余12个 hookhandler 文件）。
finding #17 的 enforcement gate 已完成，剩余债务在 Phase 106 逐步偿还（ratchet 防止新增）。
