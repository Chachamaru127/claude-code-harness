---
name: review-accessibility
description: "Webアクセシビリティ（a11y）をチェックするスキル。Webアプリケーションのアクセシビリティレビューが要求された場合に使用します。"
allowed-tools: ["Read", "Grep", "Bash"]
metadata:
  skillport:
    category: worker
    tags: [accessibility, a11y, wcag, review]
    alwaysApply: false
---

# Review Accessibility

Web アクセシビリティ（a11y）をチェックし、WCAG ガイドラインへの準拠を確認するスキル。

---

## 目的

以下のアクセシビリティ問題を検出：
- セマンティック HTML の使用
- ARIA 属性の適切な使用
- キーボード操作対応
- 色コントラスト
- スクリーンリーダー対応

---

## 入力

| 項目 | 説明 |
|------|------|
| `files` | チェック対象ファイルのリスト |
| `tech_stack` | フレームワーク（React, Vue など） |

---

## 出力

| 項目 | 説明 |
|------|------|
| `a11y_issues` | 検出された問題のリスト |
| `a11y_score` | アクセシビリティスコア (A-F) |

---

## チェック項目

### 1. セマンティック HTML

| チェック | 問題 | 改善 |
|---------|------|------|
| 見出し構造 | h1 → h3 のスキップ | 正しい順序に修正 |
| ランドマーク | `<div>` のみの使用 | `<nav>`, `<main>`, `<aside>` 使用 |
| リスト構造 | 手動でのリスト作成 | `<ul>`, `<ol>` 使用 |
| ボタン | `<div onclick>` | `<button>` 使用 |

### 2. 画像とメディア

| チェック | 問題 | 改善 |
|---------|------|------|
| alt 属性 | 欠落または空 | 意味のある説明を追加 |
| 装飾画像 | alt に説明 | `alt=""` または `aria-hidden` |
| 動画 | 字幕なし | キャプション追加 |

### 3. フォーム

| チェック | 問題 | 改善 |
|---------|------|------|
| ラベル | `<label>` 欠落 | `<label for="id">` 追加 |
| エラーメッセージ | 色のみで表示 | テキストでも表示 |
| 必須フィールド | 視覚的のみ | `aria-required` 追加 |

### 4. キーボード操作

| チェック | 問題 | 改善 |
|---------|------|------|
| フォーカス管理 | フォーカス不可要素 | `tabindex="0"` 追加 |
| フォーカス表示 | `outline: none` のみ | 代替スタイル追加 |
| キーボードトラップ | モーダルからの脱出不可 | ESC キー対応 |

### 5. ARIA

| チェック | 問題 | 改善 |
|---------|------|------|
| 冗長な ARIA | `<button role="button">` | 不要な role 削除 |
| 無効な ARIA | 存在しない ID 参照 | 正しい ID に修正 |
| 動的コンテンツ | 変更の通知なし | `aria-live` 追加 |

---

## スコアリング

| スコア | 基準 |
|--------|------|
| A | WCAG 2.1 AA 準拠 |
| B | 軽微な問題のみ |
| C | 中程度の問題あり |
| D | 重大なアクセシビリティ問題 |
| F | 基本的なアクセシビリティ欠如 |

---

## 出力例

```markdown
## アクセシビリティレビュー結果

**スコア**: C

### 検出された問題

| 重大度 | ファイル | 行 | 問題 | WCAG |
|--------|---------|-----|------|------|
| 高 | src/components/Button.tsx | 12 | div を button として使用 | 4.1.2 |
| 中 | src/components/Image.tsx | 8 | alt 属性が空 | 1.1.1 |
| 低 | src/components/Modal.tsx | 45 | ESC キーでの閉じる未対応 | 2.1.2 |

### 推奨改善

1. **セマンティックなボタン**
   ```tsx
   // Before
   <div onClick={handleClick} className="button">Click</div>

   // After
   <button onClick={handleClick} className="button">Click</button>
   ```

2. **画像の alt 属性**
   ```tsx
   // Before
   <img src={user.avatar} />

   // After
   <img src={user.avatar} alt={`${user.name}のアバター`} />
   ```
```

---

## 注意事項

- WCAG 2.1 AA を基準とする
- 技術スタック（React/Vue）に応じたチェック
- 自動チェックで検出できない問題は手動確認を推奨
