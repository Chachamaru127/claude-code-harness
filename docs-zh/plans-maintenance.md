# Plans Maintenance

最终更新: 2026-03-06

`Plans.md` 是正本，但长期不加控制地继续扩展，会导致"过去的已完成表述"与"当前的 repo 状态"产生偏差。
本文档是减少偏差的最小运作规则。

## Lightweight Rule

1. 在开始新的重大改善 phase 之前，仅将最近的 1〜2 个 phase 视为 active zone
2. 更早的已完成 phase，如有必要则退避到 `docs/plans-history/` 等历史放置处
3. 对于"已删除"、"迁移完成"等可能与 current tree 冲突的措辞，在后续 phase 状态发生变化时加入补正说明
4. 在更改 README / docs / `.gitignore` / build scripts 的处理方式时，在同一 commit 中也修正 `Plans.md` 的表述

## When to Archive

满足以下任一条件时，考虑 archive 旧的已完成 phase。

- `Plans.md` 的主要作业对象需要回溯 3 个 phase 以上才能理解
- "已删除"、"已整合"等词汇可能与 current repo 产生误解
- 每次 sync-status 时过去历史的读取成本令人在意

## Recommended Shape

- `Plans.md`: 仅包含当前的 active phase 和最近的完成 phase
- `docs/plans-history/`: 过去 phase 的固定快照
- `docs/distribution-scope.md`: 残留物和分发边界的 current truth

## Phase 21 Decision

- 本次不实施 archive，优先进行**消除误解的完成表述之修正**
- 建议在下一个大的 phase 添加之前，将 Phase 17 以前的已完成历史退避到 `docs/plans-history/`
