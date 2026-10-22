# Positioning Notes

最终更新: 2026-03-06

若要对外简短表述，`claude-code-harness` 的价值不在于「增加 skill pack」，而在于 **能够带上 runtime enforcement 和 verification 去跑通 Plan -> Work -> Review**。

## Core Message

- Harness 把 `5 verb skills + TypeScript guardrail engine` 当作商品本体
- 价值不在于命令数量多，而在于 `guardrail`、`review`、`consistency`、`evidence` 作为一体同时生效
- `commands/` 或 `mcp-server/` 这样的 legacy / optional bucket 不是弱点，只要边界已明文化，就可以作为运用资产来解释

## Public Comparison Language

- 避免: 「压倒性优于竞品」「完胜」
- 使用: 「runtime enforcement 很强」「verification path 明确」「把 claims 与可复现证据绑定」
- 在竞品比较中，不否定对方的思想或采用实绩，把说明的着重点放在 Harness 的强项 guardrail / evidence / operator clarity 上

## Recommended One-liner

> 不仅仅是用 skill pack 扩展 Claude Code，而是让 Plan -> Work -> Review 能在 guardrail 和验证的支持下被运用的 harness。

## Proof Points

- TypeScript guardrail engine (`core/`)
- 5 verb skills (`skills/`)
- consistency check 与 plugin validation
- `/harness-work all` evidence pack
