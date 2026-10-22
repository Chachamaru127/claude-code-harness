# Reports 索引

判断材料 HTML/PDF 列表（仅供追加）。

- [2026-07-07 新版本 Before/After](../docs/reports/2026-07-07-harness-new-version-before-after.html) — Wave 1+2 + 审查修改后的 redesign 主张=实体一致・6 findings 摘出修改・审查合格判定
- [2026-07-29 CCH 用户向け说明](../docs/reports/2026-07-29-cch-user-guide.html) — CCH 是什么工具（3 层的目标 / 4 工序 / 2 层安全网 / 3 主机 / 与通常开发的比较 / Phase 126 的变更）
- [2026-08-11 CCH 全体验证（交互式）](../docs/reports/2026-08-11-cch-verification.html) — 是否按规格运行的实测。向全部 15 条 guardrail 规则投入实际 payload 的判定表（可按规则单位筛选/详细显示）/ 13 项 context 的配线状况/运行中 binary 的来源（本 repo 8/10 vs 其他项目 8/9）/ gate 结果/与规格的偏差 7 件/下一步
- [2026-07-29 CCH 流程探索（交互式）](../docs/reports/2026-07-29-cch-flow-explorer.html) — 委托的工作经过哪里到达完成。5 流程（危险操作停止为止 / 计划 / 实现 / 审查 / 发布）× 25 步骤可按流程/步骤追踪。与静态版配合使用（静态版=是什么工具・比较・判断，探索版=如何流动）
- [2026-08-17 Phase 134-137 完走报告](../docs/reports/2026-08-17-phase134-137-completion.html) — 验证链配线修理 + writing lint + surface + 循环施策的实现与审查 3 往返 (APPROVE)、push/PR 判断材料
- [2026-08-17 CCH 产品说明书 v5.9](../docs/reports/2026-08-17-cch-product-guide-v5.9.html) — 初次接触・非专家向け、README 型的 landing 构成。解决什么 → 30 秒引入 → 5 动词 → 安全层 → v5.9 的验证链 → 比较 → 对应工具 → FAQ → 术语（嵌入 logo 与运行循环图）
- [2026-08-24 CCH Harness 设计审查（交互式）](../docs/reports/2026-08-24-cch-harness-review.html) — /muscle による外部吸收审查的判断材料。对 6 点担忧（HOTL / 过去的约束 / anti-slop / hook / 竞争 / Hermes 型自主改善）的实测回答，外部 11 要素的 4 分类判定表，采用提案 5 件，独立证伪路径的结果，4 流程（验证的锁 / 无人停止 / 记忆管道 / 学习循环）× 16 步骤，判断卡 3 张（D67 を開くか / 5 件を Plans へ / Phase 140 最优先）
- [2026-08-26 Phase 140/141 追加审查](../docs/reports/2026-08-26-phase140-141-plan-review.html) — 2026-08-24 审查的结论反映到 Plans.md 的 diff（明确优先顺序 + 新 Phase（审查时的工作名称为 Phase 141，由于与 main 同时运行的 shipped Phase 141「会话协调管道」的编号冲突，落地时改为 Phase 142）全 7 task）的 APPROVE 判定与变更点报告。3 文件 diff、测试 147 件 + 整合性检查 25 项 green，实现前的计划追加仅为的确认
- [2026-08-27 CCH 同步状况（交互式）](../docs/reports/2026-08-27-harness-sync-status.html) — harness-sync 的结果。Plans.md 与 git 的偏差 0 件、Phase 134〜142 的 49 task 中 32 完结（65%）、v5.13.1 公开完结。分发先 cache 5.13.1 的零件缺失（Agents (0)、agents / bin / templates 不在、hooks 退避到 marketplace 复制后运行）的区分与原因（CCH 自身的 SessionStart hook 未安装版的 cache 先创建，复制版号被写回。2026-08-29 用旧 script 再现，修理箇所为 scripts/sync-plugin-cache.sh 的 3 个缺陷）、4 流程（同步结果 / 分发的缺失 / 修理版 5.13.2 / Phase 140.1）× 18 步骤，判断卡 3 张（先出修理版吗 / 着手 140.1 / 顺序 140 → 142 → 138）
- [2026-09-06 CCH 产品说明书 v5.14.1（含本地更新）](../docs/reports/2026-09-06-cch-product-guide-v5.14.1.html) / 继承 v5.9 的固定设计。说明当前的委托方法、负责模型、执行与停止、安全检查的范围、对应环境。
- [2026-09-06 CCH 产品说明书 v5.15.0](../docs/reports/2026-09-06-cch-product-guide-v5.15.0.html) / 统一公开对象的规格版本号。从委托示例到确认结果，说明负责模型的详情与更新步骤的说明书。
