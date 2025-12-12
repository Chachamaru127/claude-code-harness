---
name: ccp-work-write-tests
description: "テストコードを作成する。/workコマンドでテストが必要な場合、またはコード実装後にテストが不足している場合に使用します。"
allowed-tools: [Read,Write,Edit,Bash]
metadata:
  skillport:
    category: worker
    tags: [testing, implementation, quality]
    alwaysApply: false
---

# Work Write Tests

実装した機能に対してテストコードを書くスキル。
コードの品質を保証し、リグレッションを防ぎます。

---

## 入力

- **テスト対象のコード**: 実装されたファイル
- **既存のテスト構造**: テストフレームワーク、ディレクトリ構成
- **テスト要件**: カバーすべきケース

---

## 出力

- **テストファイル**: 新規作成または追記
- **テスト実行結果**: 全テスト通過の確認

---

## 実行手順

### Step 1: テスト環境の確認

```bash
# テストフレームワークの確認
cat package.json | grep -E '"(jest|vitest|mocha|pytest)"'

# 既存テストの構造確認
ls -la __tests__/ tests/ src/**/*.test.* 2>/dev/null | head -10

# テスト実行コマンドの確認
npm test 2>&1 | head -5
```

### Step 2: テストケースの設計

対象コードに対して以下を考慮：

1. **正常系**: 期待通りの入力に対する動作
2. **境界値**: 最小/最大値、空配列など
3. **異常系**: エラーが起きるべきケース

### Step 3: テストの実装

#### Jest/Vitest の例

```typescript
// src/components/__tests__/FeatureName.test.tsx
import { render, screen } from '@testing-library/react'
import { FeatureName } from '../FeatureName'

describe('FeatureName', () => {
  it('renders correctly', () => {
    render(<FeatureName />)
    expect(screen.getByText('Expected Text')).toBeInTheDocument()
  })

  it('handles user interaction', async () => {
    render(<FeatureName />)
    await userEvent.click(screen.getByRole('button'))
    expect(screen.getByText('Result')).toBeInTheDocument()
  })
})
```

#### ユーティリティ関数のテスト

```typescript
// src/lib/__tests__/utils.test.ts
import { utilityFunction } from '../utils'

describe('utilityFunction', () => {
  it('returns expected output for valid input', () => {
    expect(utilityFunction('input')).toBe('expected')
  })

  it('handles edge cases', () => {
    expect(utilityFunction('')).toBe('')
    expect(utilityFunction(null)).toBeNull()
  })

  it('throws error for invalid input', () => {
    expect(() => utilityFunction(undefined)).toThrow()
  })
})
```

### Step 4: テストの実行

```bash
# 全テスト実行
npm test

# 特定ファイルのみ
npm test -- FeatureName.test.tsx

# カバレッジ付き
npm test -- --coverage
```

### Step 5: 結果の確認

```bash
# テスト結果の確認
npm test 2>&1 | tail -20

# カバレッジレポート確認
cat coverage/lcov-report/index.html | grep -A 5 "coverage"
```

---

## テストパターン集

### コンポーネントテスト

```typescript
// レンダリングテスト
it('renders without crashing', () => {
  render(<Component />)
})

// Props テスト
it('displays props correctly', () => {
  render(<Component title="Test" />)
  expect(screen.getByText('Test')).toBeInTheDocument()
})

// イベントテスト
it('handles click event', async () => {
  const onClick = vi.fn()
  render(<Component onClick={onClick} />)
  await userEvent.click(screen.getByRole('button'))
  expect(onClick).toHaveBeenCalled()
})
```

### API テスト

```typescript
// モックを使用
vi.mock('../lib/api', () => ({
  fetchData: vi.fn().mockResolvedValue({ data: 'mock' })
}))

it('fetches data correctly', async () => {
  const result = await fetchData()
  expect(result.data).toBe('mock')
})
```

### エラーハンドリングテスト

```typescript
it('handles errors gracefully', async () => {
  vi.spyOn(console, 'error').mockImplementation(() => {})

  render(<ComponentWithError />)

  expect(screen.getByText('Error occurred')).toBeInTheDocument()
})
```

---

## テスト命名規則

```typescript
// 推奨フォーマット
describe('対象', () => {
  it('〜のとき、〜する', () => {})
  it('〜の場合、〜を返す', () => {})
})

// 例
describe('Button', () => {
  it('クリックされたとき、onClickを呼び出す', () => {})
  it('disabledの場合、クリックを無視する', () => {})
})
```

---

## 完了報告フォーマット

```markdown
## ✅ テスト追加完了

**対象**: {{テスト対象ファイル}}

### 追加したテスト
| テストファイル | テストケース数 |
|--------------|--------------|
| `{{path}}` | {{件数}} |

### テスト結果
- 実行: ✅ {{total}} テスト中 {{passed}} 通過
- カバレッジ: {{percentage}}%

### 次のアクション
「レビューして」または「次のタスクへ」
```

---

## 注意事項

- **テストを後回しにしない**: 実装と同時に書く
- **過度なモックを避ける**: 実際の動作に近いテストを
- **テストの保守性**: 実装変更でテストが壊れにくく
