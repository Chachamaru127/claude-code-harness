---
name: ci-fix-failing-tests
description: "CI で失敗したテストを修正するためのガイド。CI失敗の原因が特定された後、自動修正を試みる場合に使用します。"
allowed-tools: ["Read", "Edit", "Bash"]
metadata:
  skillport:
    category: ci
    tags: [ci-cd, testing, fix]
    alwaysApply: false
---

# CI Fix Failing Tests

CI で失敗したテストを修正するスキル。
テストコードの修正、または本体コードの修正を行います。

---

## 入力

- **失敗テスト情報**: テスト名、エラーメッセージ
- **テストファイル**: 失敗したテストのソース
- **テスト対象コード**: テスト対象の実装

---

## 出力

- **修正されたコード**: テストまたは実装の修正
- **テスト通過の確認**

---

## 実行手順

### Step 1: 失敗テストの特定

```bash
# ローカルでテスト実行
npm test 2>&1 | tail -50

# 特定ファイルのテスト
npm test -- {{test-file}}
```

### Step 2: エラータイプの分類

#### タイプ A: アサーション失敗

```
Expected: "expected value"
Received: "actual value"
```

→ 実装が期待と異なる、またはテストの期待値が間違っている

#### タイプ B: タイムアウト

```
Timeout - Async callback was not invoked within the 5000ms timeout
```

→ 非同期処理が完了しない、または時間がかかりすぎる

#### タイプ C: 型エラー

```
TypeError: Cannot read properties of undefined
```

→ null/undefined のアクセス、または初期化の問題

#### タイプ D: モック関連

```
expected mockFn to have been called
```

→ モックの設定不足、または呼び出しが行われていない

### Step 3: 修正戦略の決定

```markdown
## 修正方針判断

1. **テストが正しい場合** → 実装を修正
2. **実装が正しい場合** → テストを修正
3. **両方修正が必要**   → 実装を優先

判断基準:
- 仕様・要件に照らしてどちらが正しいか
- 最近の変更は何か
- 他のテストへの影響
```

### Step 4: 修正の実装

#### アサーション失敗の修正

```typescript
// テストの期待値が間違っている場合
it('calculates correctly', () => {
  // 修正前
  expect(calculate(2, 3)).toBe(5)
  // 修正後（仕様が掛け算の場合）
  expect(calculate(2, 3)).toBe(6)
})

// 実装が間違っている場合
// → 実装ファイルを修正
```

#### タイムアウトの修正

```typescript
// タイムアウトを延長
it('fetches data', async () => {
  // ...
}, 10000)  // 10秒に延長

// または async/await を正しく使用
it('fetches data', async () => {
  await waitFor(() => {
    expect(screen.getByText('Data')).toBeInTheDocument()
  })
})
```

#### モック関連の修正

```typescript
// モックの設定を追加
vi.mock('../api', () => ({
  fetchData: vi.fn().mockResolvedValue({ data: 'mock' })
}))

// beforeEach でリセット
beforeEach(() => {
  vi.clearAllMocks()
})
```

### Step 5: 修正後の確認

```bash
# 失敗テストを再実行
npm test -- {{test-file}}

# 全テスト実行（リグレッション確認）
npm test
```

---

## 修正パターン集

### スナップショット更新

```bash
# スナップショットの更新
npm test -- -u

# 特定テストのみ
npm test -- {{test-file}} -u
```

### 非同期テストの修正

```typescript
// findBy を使用（自動待機）
const element = await screen.findByText('Text')

// waitFor を使用
await waitFor(() => {
  expect(mockFn).toHaveBeenCalled()
})
```

### モックデータの更新

```typescript
// 実装の変更に合わせてモックを更新
const mockData = {
  id: 1,
  name: 'Test',
  createdAt: new Date().toISOString()  // 新しいフィールド
}
```

---

## 修正後のチェックリスト

- [ ] 失敗していたテストが通過する
- [ ] 他のテストが壊れていない
- [ ] 実装の意図と一致している
- [ ] 過度に緩いテストになっていない

---

## 完了報告フォーマット

```markdown
## ✅ テスト修正完了

### 修正内容

| テスト | 問題 | 修正 |
|-------|------|------|
| `{{テスト名}}` | {{問題}} | {{修正内容}} |

### 確認結果

```
Tests: {{passed}} passed, {{total}} total
```

### 次のアクション

「コミットして」または「CI を再実行して」
```

---

## 注意事項

- **テストを削除しない**: 削除は最終手段
- **skip は一時的に**: 恒久的な skip は禁止
- **ルートコーズを特定**: 表面的な修正を避ける
