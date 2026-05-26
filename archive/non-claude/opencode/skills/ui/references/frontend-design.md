---
name: frontend-design-summary
description: "frontend-design の設計思考と美的指針の要約"
---

# Frontend Design Summary

UI の独自性と美的完成度を高めるための設計指針。
明示要求がある場合のみ適用する。

## 設計思考（最初に決める）
- Purpose: 誰の何を解決する UI か
- Tone: 大胆な方向性を 1 つ選ぶ（例: minimal / brutalist / editorial / playful）
- Constraints: 技術制約と a11y
- Differentiation: その UI の「記憶に残る 1 点」を決める

## 実装の品質基準
- Production-grade で実際に動く
- 視覚的に印象が強く、一貫した方向性
- 細部の詰め（余白、階層、状態）

## デザイン指針
- Typography: 目を引く display と読みやすい body のペア
- Color: 主役色と鋭いアクセントを明確に
- Motion: 大きな 1 回の演出に集中（分散しすぎない）
- Space: 余白 or 高密度を意図的に選ぶ
- Background: 雰囲気のあるレイヤーや質感（必要なら）

## 注意
- 方向性は「意図の強さ」が重要。派手さの有無ではない。
- 実装の複雑さはデザインの方向性に合わせる。

## Source
- external frontend-design skill (Anthropic)
