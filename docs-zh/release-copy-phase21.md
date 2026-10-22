# Phase 21 Release Copy Drafts

最终更新: 2026-03-06

这是对外告知 Phase 21 时使用的草稿。 不要把 `trust repair`、`evidence pack`、
`positioning refresh` 混在一起，而是按一个主题一个主题分开使用。

## Draft 1: Trust Repair

我们整理了 `claude-code-harness` 的公开面。对齐了 README badge、缺失的 docs、发行范围的说明，减少了 README / Plans / docs 之间的自相矛盾。

## Draft 2: Evidence Pack

我们新增了 `/harness-work all` 的 success / failure fixture 和 smoke runner。准备的不只是主张，而是可以一边看 artifact 一边重新确认的路径。

## Draft 3: Positioning Refresh

我们把 Harness 的中心信息重新聚焦到 `5 verb skills + TypeScript guardrail engine`。把重点放在不只是增加 skill pack，而是能把 runtime enforcement 和 verification 作为一体来跑通这一点上。

## Current Recommendation

- 即使撞上 quota，也能通过 replay fallback 继续获取 evidence artifact
- 在完整的 success artifact 齐备之前，在 Draft 2 中表述为「已整備可复现的骨架」
- 避免像 `production-ready` 这样的强烈断言
- 若要给出竞品比较，请统一使用 `docs/positioning-notes.md` 的措辞
