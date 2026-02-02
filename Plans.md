# Plans.md - generate-video品質向上計画

## 概要

generate-videoスキルの品質向上。プロダクトデモ重視、JSONスキーマ駆動、視覚演出強化。

## アーキテクチャ

```
分析 → シナリオ → Task並列(JSON+画像) → バリデーション → マージ → E2E検証 → render
```

## 出力構造

```
out/video-{YYYYMMDD}-{id}/
├── scenario.json / scenes/*.json / video-script.json
├── assets/ (manifest.json + 画像/音声)
└── output.mp4
```

---

## 技術決定事項

| 項目 | 仕様 |
|------|------|
| **SSOT** | `schemas/*.schema.json` → Zod自動生成 |
| **マージ** | sections[]順 + scene.order昇順、競合=Critical |
| **決定性** | SHA-256ハッシュ + seed + package-lock固定 |
| **バリデーション** | scene→scenario→E2E の3層ゲート |

---

## Phase 0: 基盤 `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 0.1 スキーマ自動生成 | `scripts/generate-schemas.js` | ✅ |
| 0.2 アセットマニフェスト | `schemas/assets.manifest.schema.json` | ✅ |
| 0.3 決定性テスト | `tests/determinism.test.js` | ✅ |

## Phase 1: スキーマ `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 1.1 scenario.schema | `schemas/scenario.schema.json` | ✅ |
| 1.2 scene.schema | `schemas/scene.schema.json` | ✅ |
| 1.3 video-script.schema | `schemas/video-script.schema.json` | ✅ |

## Phase 2: バリデーション `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 2.1 Zod生成 | `src/schemas/index.ts` | ✅ |
| 2.2 validate-scene | `scripts/validate-scene.js` | ✅ |
| 2.3 validate-scenario | `scripts/validate-scenario.js` | ✅ |
| 2.4 validate-video (E2E) | `scripts/validate-video.js` | ✅ |

## Phase 3: 並列生成 `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 3.1 generator更新 | `references/generator.md` | ✅ |
| 3.2 merge-scenes | `scripts/merge-scenes.js` | ✅ |

## Phase 4: 演出システム `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 4.1 direction.schema | `schemas/direction.schema.json` | ✅ |
| 4.2 animation.schema | `schemas/animation.schema.json` | ✅ |
| 4.3 emphasis.schema | `schemas/emphasis.schema.json` | ✅ |
| 4.4 演出ガイド | `references/direction-guide.md` | ✅ |

## Phase 5: 視覚コンポーネント `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 5.1 EmphasisBox | `remotion/components/EmphasisBox.tsx` | ✅ |
| 5.2 TransitionWrapper | `remotion/components/TransitionWrapper.tsx` | ✅ |
| 5.3 ProgressIndicator | `remotion/components/ProgressIndicator.tsx` | ✅ |
| 5.4 BackgroundLayer | `remotion/components/BackgroundLayer.tsx` | ✅ |

## Phase 6: 画像生成パターン `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 6.1 visual-patterns.schema | `schemas/visual-patterns.schema.json` | ✅ |
| 6.2 比較図パターン | `references/image-patterns.md#comparison` | ✅ |
| 6.3 概念図パターン | `references/image-patterns.md#concept` | ✅ |
| 6.4 フローパターン | `references/image-patterns.md#flow` | ✅ |
| 6.5 プロンプトテンプレート | `templates/image-prompts/` | ✅ |

## Phase 7: アセット基盤 `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 7.1 背景セット | `assets/backgrounds/backgrounds.json` | ✅ |
| 7.2 効果音セット | `assets/sounds/sounds.json` | ✅ |
| 7.3 asset-loader | `scripts/load-assets.js` | ✅ |
| 7.4 ユーザー上書き | `references/asset-customization.md` | ✅ |

## Phase 8: レンダリング `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 8.1 render-video | `scripts/render-video.js` | ✅ |
| 8.2 統合テスト | `tests/e2e/render.test.js` | ✅ |

## Phase 9: テンプレート `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 9.1 90秒ティザー | `templates/teaser-90s.json` | ✅ |
| 9.2 3分Intro | `templates/intro-3min.json` | ✅ |
| 9.3 レジストリ | `scripts/template-registry.js` | ✅ |

## Phase 10: 将来拡張（設計のみ）`cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 10.1 character.schema | `schemas/character.schema.json` | ✅ |
| 10.2 dialogue拡張フック | `references/generator.md` | ✅ |

---

## 完了基準

- [x] アーキテクチャ決定
- [x] 技術仕様定義
- [x] 演出システム設計
- [x] 画像パターン設計
- [x] 全Phase実装完了
- [x] Codexレビュー承認 (Quality: B, Architect: B+)

## 実装統計

| 項目 | 数値 |
|------|------|
| スキーマファイル | 10個 |
| スクリプト | 8個 |
| コンポーネント | 4個 |
| テストファイル | 6個 |
| テスト数 | 92件 |
