---
name: ccp-core-diff-aware-editing
description: "最小限の差分でファイルを編集し、既存コードへの影響を最小化するファイル編集時に常に適用され、最小限の差分で変更を行います。ファイル編集時に常に適用され、最小限の差分で変更を行います。"
allowed-tools: ["Read", "Edit"]
metadata:
  skillport:
    category: core
    tags: [editing, diff, minimal-changes]
    alwaysApply: true
---

# Diff-Aware Editing

ファイル編集時に最小限の差分で変更を行うスキル。
既存コードの破壊を防ぎ、レビューしやすい変更を実現します。

---

## 基本原則

### 1. Read Before Edit

**必ず対象ファイルを読んでから編集する**

```
❌ 悪い例: Write ツールでファイル全体を上書き
✅ 良い例: Read → 内容確認 → Edit で必要部分のみ変更
```

### 2. 最小差分の優先

変更は必要最小限に留める：

- 既存のインデント・フォーマットを維持
- 既存のコメントは残す
- 使われているスタイルに合わせる

### 3. 意味のある単位で変更

```typescript
// ❌ 悪い例: 無関係な変更を混ぜる
// 関数の追加 + フォーマット変更 + import整理

// ✅ 良い例: 1つの変更に集中
// 関数の追加のみ
```

---

## Edit ツールの使い方

### パターン1: 単純な置換

```
old_string: "const value = 1"
new_string: "const value = 2"
```

### パターン2: コードブロックの追加

```
old_string: "// TODO: implement feature"
new_string: "// Feature implemented
const feature = () => {
  // implementation
}"
```

### パターン3: 関数の修正

```
old_string: "function getData() {
  return []
}"
new_string: "function getData() {
  const data = fetchData()
  return data
}"
```

---

## 避けるべきパターン

### 1. ファイル全体の書き換え

```
❌ Write ツールで 100 行のファイルを丸ごと書き直す
✅ Edit ツールで変更が必要な 5 行だけ修正
```

### 2. フォーマット変更の混入

```
❌ 機能追加と同時にインデントを変更
✅ 機能追加のみ。フォーマットは別コミットで
```

### 3. 不要な空行・コメントの追加

```
❌ 自分のスタイルを押し付ける
✅ 既存のスタイルに従う
```

---

## 編集前チェックリスト

1. [ ] 対象ファイルを Read で確認した
2. [ ] 変更が必要な箇所を特定した
3. [ ] 既存のスタイル（インデント、命名規則）を把握した
4. [ ] 変更が paths.allowed_modify に含まれるか確認した
5. [ ] 変更後の動作をイメージできた

---

## 編集後の確認

```bash
# 差分の確認
git diff

# 変更行数の確認（大きすぎないか）
git diff --stat

# 構文エラーがないか
npm run build 2>&1 | head -20
# または
npx tsc --noEmit
```

---

## 複数ファイルの編集

複数ファイルを編集する場合：

1. **依存関係の順序**: 型定義 → 実装 → テスト
2. **一貫性の確保**: 関連する変更は同時に行う
3. **中間状態でも動作**: 各編集後にビルドが通る状態を維持

---

## エラー時の対応

編集でエラーが発生した場合：

1. **元のコードを再確認**: Read で現在の状態を確認
2. **old_string の一致確認**: 空白・改行を正確に
3. **分割して試行**: 大きな変更は小さく分割
