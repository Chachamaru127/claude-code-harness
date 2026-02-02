# Plans.md - generate-video品質向上計画

## 概要

generate-videoスキルの品質向上。プロダクトデモ重視、JSONスキーマ駆動、視覚演出強化。

## アーキテクチャ

```
分析 → シナリオ → Task並列(JSON+画像) → バリデーション → マージ → E2E検証 → render
```

## 技術決定事項

| 項目 | 仕様 |
|------|------|
| **SSOT** | `schemas/*.schema.json` → Zod自動生成 |
| **マージ** | sections[]順 + scene.order昇順、競合=Critical |
| **決定性** | SHA-256ハッシュ + seed + package-lock固定 |
| **バリデーション** | scene→scenario→E2E の3層ゲート |

---

## 完了済み Phase（0-10）

> 詳細: `.claude/archive/plans-phase0-10.md`

- Phase 0-10: 全36タスク完了 ✅
- Codex Review: Security A, Performance B, Quality B, Architect C

---

## Phase 11: アーキテクチャ改善 `cc:DONE`

> **目標**: Codex Architect スコアを C → A に改善

### 11.1 $ref 解決（型安全性） `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 11.1.1 json-schema-deref 導入 | `scripts/generate-schemas.js` | ✅ |
| 11.1.2 $ref 事前解決 | dereference 後に Zod 変換 | ✅ |
| 11.1.3 scenes 型復元 | `z.any()` → 実際の Scene 型 | ✅ |

### 11.2 命名・単位統一 `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 11.2.1 命名規約定義 | `references/naming-conventions.md` | ✅ |
| 11.2.2 時間単位統一 | 全スキーマ `_ms` に統一 | ✅ |
| 11.2.3 enum 統一 | `slide_in`/`cut` に統一 | ✅ |
| 11.2.4 ケース統一 | `snake_case` に統一 | ✅ |

### 11.3 マージ決定性 `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 11.3.1 タイブレーク定義 | `scene_id` 辞書順でタイブレーク | ✅ |
| 11.3.2 重複 order 検出 | 同一 section 内の order 重複を警告 | ✅ |
| 11.3.3 未知 section エラー化 | 警告 → 失敗に変更 | ✅ |

### 11.4 バリデーション統合 `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 11.4.1 merge-scenes 入口検証 | scenario 検証を必須化 | ✅ |
| 11.4.2 render-video 入口検証 | video-script 検証を必須化 | ✅ |
| 11.4.3 --skip-validation フラグ | 明示的スキップのみ許可 | ✅ |

### 11.5 コンポーネント/スキーマ同期 `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 11.5.1 型定義エクスポート | `src/types/components.ts` | ✅ |
| 11.5.2 TSX props 型適用 | コンポーネントに型適用 | ✅ |
| 11.5.3 変換レイヤー | `src/utils/converters.ts` | ✅ |

### 11.6 決定性テスト強化 `cc:DONE`

| Task | WHERE | Status |
|------|-------|--------|
| 11.6.1 sortScenes エクスポート | `merge-scenes.js` からエクスポート | ✅ |
| 11.6.2 ユニットテスト追加 | `tests/merge-scenes.test.js` | ✅ |
| 11.6.3 E2E テスト追加 | `tests/e2e/merge-e2e.test.js` | ✅ |

---

## 完了基準

- [x] アーキテクチャ決定
- [x] 技術仕様定義
- [x] 演出システム設計
- [x] 画像パターン設計
- [x] 全Phase実装完了
- [x] Codexレビュー承認 (Quality: B, Architect: B+)
- [x] Phase 11 完了（19タスク）
- [x] Codexレビュー最終承認（Architect: A, Security: B, Performance: B, Quality: B）

## 実装統計

| 項目 | 数値 |
|------|------|
| スキーマファイル | 10個 |
| スクリプト | 8個 |
| コンポーネント | 4個 |
| テストファイル | 10個 |
| テスト数 | 184件 |
