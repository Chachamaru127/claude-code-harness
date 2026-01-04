---
name: review-changes
description: "自分の変更をセルフレビューし、改善提案を出す。コード変更後のセルフレビューが必要な場合に使用します。"
allowed-tools: ["Read", "Grep", "Bash"]
metadata:
  skillport:
    category: worker
    tags: [review, quality, self-check]
    alwaysApply: false
---

# Review Changes

実装した変更をセルフレビューし、品質を確認するスキル。
コミット前やハンドオフ前に使用します。

---

## 入力

- **変更ファイル**: git diff で特定された変更
- **リポジトリコンテキスト**: コーディング規約、既存パターン

---

## 出力

- **レビュー結果**: 各観点での評価
- **改善提案**: 問題がある場合の修正提案

---

## レビュー観点

### 1. セキュリティ 🔒

- [ ] 機密情報（API キー等）がハードコードされていない
- [ ] 入力値のバリデーションが適切
- [ ] SQL インジェクション対策
- [ ] XSS 対策

### 2. パフォーマンス ⚡

- [ ] 不要な再レンダリングがない
- [ ] N+1 クエリがない
- [ ] 重い計算がメモ化されている

### 3. コード品質 📐

- [ ] 型が適切に定義されている
- [ ] エラーハンドリングがある
- [ ] 命名が適切
- [ ] 不要なコード・コメントがない

### 4. 一貫性 🎨

- [ ] 既存のコーディングスタイルに従っている
- [ ] ファイル構成が適切
- [ ] import の順序が統一されている

---

## 実行手順

### Step 1: 変更の確認

```bash
# 変更ファイル一覧
git diff --name-only HEAD~5

# 変更内容
git diff
```

### Step 2: 各観点でのチェック

#### セキュリティチェック

```bash
# ハードコードされた機密情報を探す
grep -rn "sk-\|api_key\|password\|secret" --include="*.ts" --include="*.tsx" | grep -v ".env"
```

#### パフォーマンスチェック

```typescript
// 問題のパターンを探す
// - useEffect の依存配列の問題
// - 毎レンダリングで新しいオブジェクト生成
// - 巨大な配列の filter/map チェーン
```

#### コード品質チェック

```bash
# TypeScript エラー
npx tsc --noEmit

# ESLint
npx eslint src/ --ext .ts,.tsx
```

### Step 3: レビュー結果の生成

```markdown
## 📊 セルフレビュー結果

**対象**: {{変更ファイル数}} ファイル
**総合評価**: {{A / B / C}}

### 観点別評価

| 観点 | 評価 | 備考 |
|------|------|------|
| セキュリティ | ✅ OK | - |
| パフォーマンス | ⚠️ 要確認 | {{詳細}} |
| コード品質 | ✅ OK | - |
| 一貫性 | ✅ OK | - |

### 改善が必要な箇所

1. **{{ファイル:行}}**
   - 問題: {{問題の説明}}
   - 改善案: {{具体的な修正方法}}

### 自動修正可能な項目

- [ ] ESLint の自動修正
- [ ] Prettier の適用
```

### Step 4: 改善の適用（任意）

```bash
# ESLint 自動修正
npx eslint --fix src/

# Prettier 適用
npx prettier --write src/
```

---

## 評価基準

| 評価 | 意味 | アクション |
|------|------|-----------|
| A | 問題なし | コミット可能 |
| B | 軽微な問題あり | 修正推奨だが続行可 |
| C | 重大な問題あり | 修正必須 |

---

## よくある問題と修正

### any 型の使用

```typescript
// ❌ 問題
function process(data: any) { ... }

// ✅ 修正
interface DataType { ... }
function process(data: DataType) { ... }
```

### 未処理の Promise

```typescript
// ❌ 問題
fetchData()

// ✅ 修正
fetchData().catch(console.error)
// または
await fetchData()
```

### 不要な再レンダリング

```typescript
// ❌ 問題
const items = data.filter(x => x.active).map(x => x.name)

// ✅ 修正
const items = useMemo(() =>
  data.filter(x => x.active).map(x => x.name),
  [data]
)
```

---

## 完了後のアクション

```markdown
## ✅ セルフレビュー完了

**評価**: {{A / B / C}}

{{問題なしの場合}}
コミットの準備ができました。
「コミットして」と言ってください。

{{問題ありの場合}}
上記の改善を適用しますか？
```

---

## 注意事項

- **完璧を目指さない**: 80% で十分
- **自動ツールを活用**: 手動チェックは最小限に
- **レビューは任意**: スキップしてコミットも可能
