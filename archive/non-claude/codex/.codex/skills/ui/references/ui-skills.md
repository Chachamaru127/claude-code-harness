---
name: ui-skills-summary
description: "UI Skills の制約セット要約（実装品質優先）"
---

# UI Skills Summary

UI 実装で破綻しやすいポイントを防ぐための制約セット。

## Stack
- MUST: Tailwind CSS はデフォルト値を使う（既存カスタムか明示要求がある場合のみ例外）
- MUST: JavaScript のアニメーションが必要なら `motion/react` を使う
- SHOULD: Tailwind の入場/軽微アニメに `tw-animate-css`
- MUST: class 制御は `cn`（`clsx` + `tailwind-merge`）

## Components
- MUST: キーボード/フォーカス挙動はアクセシブルなプリミティブを使う
- MUST: 既存のプリミティブを優先
- NEVER: 同一の操作面でプリミティブを混在させない
- SHOULD: 互換があるなら Base UI を優先
- MUST: アイコンのみボタンには `aria-label`
- NEVER: キーボード/フォーカス挙動を手実装しない（明示要求がない限り）

## Interaction
- MUST: 破壊的操作は AlertDialog
- SHOULD: ローディングは構造的スケルトン
- NEVER: `h-screen` は使わず `h-dvh`
- MUST: fixed 要素は `safe-area-inset` を考慮
- MUST: エラーは操作箇所の近くに出す
- NEVER: input/textarea の貼り付けをブロックしない

## Animation
- NEVER: 明示要求がない限りアニメーション追加しない
- MUST: `transform` / `opacity` のみをアニメーション
- NEVER: `width/height/top/left/margin/padding` をアニメーション
- SHOULD: `background/color` のアニメは小さな局所 UI のみ
- SHOULD: 入口は `ease-out`
- NEVER: フィードバックは 200ms 超えない
- MUST: ループはオフスクリーンで停止
- SHOULD: `prefers-reduced-motion` を尊重
- NEVER: カスタム easing は明示要求がない限り禁止
- SHOULD: 大きな画像/全面面はアニメを避ける

## Typography
- MUST: 見出しは `text-balance`
- MUST: 本文は `text-pretty`
- MUST: 数値は `tabular-nums`
- SHOULD: 密な UI は `truncate` or `line-clamp`
- NEVER: `tracking-*` を勝手に変えない

## Layout
- MUST: 固定の `z-index` スケールを使う（任意の `z-*` は避ける）
- SHOULD: 正方形は `size-*`

## Performance
- NEVER: 大きな `blur()` / `backdrop-filter` をアニメしない
- NEVER: `will-change` を常時付与しない
- NEVER: `useEffect` で書かなくても良い処理は render で書く

## Design
- NEVER: 明示要求がない限りグラデーション禁止
- NEVER: 紫/多色グラデーション禁止
- NEVER: 主要な手掛かりに glow を使わない
- SHOULD: 影は Tailwind のデフォルトスケール
- MUST: 空状態には「次の一手」を 1 つ提示
- SHOULD: アクセント色は 1 つに絞る
- SHOULD: 新色より既存テーマ/トークンを優先

## Sources
- https://www.ui-skills.com/
- https://agent-skills.xyz/skills/baptistearno-typebot-io-ui-skills
