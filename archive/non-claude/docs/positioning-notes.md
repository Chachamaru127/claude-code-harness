# Positioning Notes

最終更新: 2026-03-06

公開向けに短く言うなら、`claude-code-harness` の価値は「skill pack を増やすこと」ではなく、**Plan -> Work -> Review を runtime enforcement と verification 付きで回せること**です。

## Core Message

- Harness は `5 verb skills + TypeScript guardrail engine` を商品本体として扱う
- 価値はコマンド数の多さではなく、`guardrail`, `review`, `consistency`, `evidence` が一体で効くこと
- `commands/` や `mcp-server/` のような legacy / optional bucket は弱みではなく、境界が明文化されていれば運用資産として説明できる

## Public Comparison Language

- 避ける: 「競合より圧倒的に上」「完全勝利」
- 使う: 「runtime enforcement が強い」「verification path が明確」「claims を再現証拠に結びつけている」
- 競合比較では、思想や採用実績を否定せず、Harness の強みを guardrail / evidence / operator clarity に寄せて説明する

## Recommended One-liner

> Claude Code を skill pack で拡張するだけでなく、Plan -> Work -> Review を guardrail と検証付きで運用できるようにするハーネス。

## Proof Points

- TypeScript guardrail engine (`core/`)
- 5 verb skills (`skills/`)
- consistency check と plugin validation
- `/harness-work all` evidence pack
