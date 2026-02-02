# Plans.md - generate-video品質向上計画

## 概要

generate-videoスキルの品質向上。プロダクトデモ重視で、JSONスキーマ駆動の再現性確保。

## アーキテクチャ

```
分析 → シナリオ提案 → Task並列(JSON生成) → バリデーション → マージ → E2Eバリデーション → render
```

---

## パイプラインI/Oコントラクト

### ディレクトリ構造

```
out/video-{YYYYMMDD}-{id}/
├── scenario.json           # Phase: シナリオ提案
├── scenes/                 # Phase: 並列生成
│   ├── scene-001.json
│   ├── scene-002.json
│   └── ...
├── video-script.json       # Phase: マージ後
├── assets/                 # アセット
│   └── manifest.json       # ハッシュ管理
└── output.mp4              # 最終出力
```

### 命名規則

| ファイル | パターン | 例 |
|----------|----------|-----|
| シーンJSON | `scene-{NNN}.json` | `scene-001.json` |
| 生成画像 | `{scene_id}-{type}.webp` | `scene-001-highlight.webp` |
| 音声 | `{scene_id}.wav` | `scene-001.wav` |

---

## 技術決定事項

### スキーマソースオブトゥルース

- **SSOT**: `schemas/*.schema.json`
- **生成**: `npm run generate:schemas` → `src/schemas/*.ts` (Zod)
- **トリガー**: pre-commit hook + CI gate
- **バージョニング**: `$schema` に `"version": "1.0.0"` を含める

### マージ戦略

1. **順序**: `scenario.sections[]` 配列順（インデックス）を primary key とする
2. **ソート**: 各セクション内で `scene.order` 昇順
3. **競合**: 同一 `scene_id` → Critical error
4. **欠落**: セクションにシーンなし → Critical error
5. **重複order**: 同一セクション内で `order` 重複 → Critical error

### 決定性制御

| 項目 | 仕様 |
|------|------|
| ハッシュ | SHA-256、`assets/manifest.json` に格納 |
| シード | `metadata.seed` (integer)、全生成で使用 |
| 環境 | `package-lock.json` + Node 20 LTS + Remotion固定 |
| 検証 | `npm test` で決定性テスト実行 |

### バリデーション動作

| ステージ | 失敗時 | 出力 |
|----------|--------|------|
| validate-scene | 即座にエラー返却 | `{valid, errors[]}` |
| validate-scenario | 即座にエラー返却 | `{valid, errors[]}` |
| validate-video (E2E) | Critical → 停止、Warning → ログ続行 | `{valid, errors[], warnings[]}` |

---

## Phase 0: 基盤設計 `cc:TODO`

| Task | WHERE | 受入条件 |
|------|-------|----------|
| 0.1 スキーマ自動生成 | `scripts/generate-schemas.js` | `npm run generate:schemas` 動作 |
| 0.2 アセットマニフェスト | `schemas/assets.manifest.schema.json` | SHA-256ハッシュ生成・検証 |
| 0.3 決定性テスト | `tests/determinism.test.ts` | 同一入力→同一出力 |

## Phase 1: スキーマ設計 `cc:TODO`

| Task | WHERE | 受入条件 |
|------|-------|----------|
| 1.1 scenario.schema.json | `schemas/scenario.schema.json` | ajvバリデーション可 |
| 1.2 scene.schema.json | `schemas/scene.schema.json` | ajvバリデーション可 |
| 1.3 video-script.schema.json | `schemas/video-script.schema.json` | ajvバリデーション可 |

## Phase 2: バリデーション `cc:TODO`

| Task | WHERE | 受入条件 |
|------|-------|----------|
| 2.1 Zod自動生成 | `src/schemas/index.ts` | TypeScript型推論OK |
| 2.2 validate-scene.js | `scripts/validate-scene.js` | 不正JSONでエラー詳細 |
| 2.3 validate-scenario.js | `scripts/validate-scenario.js` | セクション整合性チェック |
| 2.4 validate-video.js | `scripts/validate-video.js` | E2Eゲート機能 |

## Phase 3: 並列JSON生成 `cc:TODO`

| Task | WHERE | 受入条件 |
|------|-------|----------|
| 3.1 generator更新 | `references/generator.md` | JSON出力に変更 |
| 3.2 merge-scenes.js | `scripts/merge-scenes.js` | 競合検出・順序保証 |
| 3.3 ドキュメント更新 | `references/generator.md` | 新フロー明記 |

## Phase 4: 視覚演出 `cc:TODO`

| Task | WHERE | 受入条件 |
|------|-------|----------|
| 4.1 Highlight | `remotion/components/Highlight.tsx` | Studio表示OK |
| 4.2 SectionIndicator | `remotion/components/SectionIndicator.tsx` | Studio表示OK |
| 4.3 ドキュメント | `references/visual-effects.md` | 使用方法明記 |

## Phase 5: レンダリング `cc:TODO`

| Task | WHERE | 受入条件 |
|------|-------|----------|
| 5.1 render-video.js | `scripts/render-video.js` | JSON→MP4生成 |
| 5.2 asset-loader.js | `scripts/asset-loader.js` | フォールバック動作 |
| 5.3 統合テスト | `tests/e2e/render.test.ts` | E2Eパス |

## Phase 6: テンプレート `cc:TODO`

| Task | WHERE | 受入条件 |
|------|-------|----------|
| 6.1 90秒ティザー | `templates/teaser-90s.json` | シナリオ生成可 |
| 6.2 3分Intro | `templates/intro-3min.json` | シナリオ生成可 |
| 6.3 レジストリ | `scripts/template-registry.js` | 未知テンプレでエラー |
| 6.4 planner更新 | `references/planner.md` | 選択フロー明記 |

## Phase 7: 将来拡張（設計のみ）`cc:TODO`

| Task | WHERE | 受入条件 |
|------|-------|----------|
| 7.1 characterスキーマ | `schemas/character.schema.json` | 拡張ポイント明記 |
| 7.2 dialogueフック | `references/generator.md` | 拡張ポイント文書化 |

---

## 完了基準

- [x] パイプラインI/Oコントラクト定義
- [x] スキーマSSOT戦略決定
- [x] マージ戦略・競合解決ルール定義
- [x] 決定性制御仕様定義
- [ ] 全タスク実装完了
- [ ] 決定性テストパス

## 詳細仕様

- スキーマ詳細: `docs/schema-spec.md`（実装時作成）
- バリデーション詳細: `docs/validation-spec.md`（実装時作成）
