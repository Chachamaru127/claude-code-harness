---
description: テストファイル作成・編集時のルール
paths: "**/*.{test,spec}.{ts,tsx,js,jsx}, **/test/**/*.*, **/tests/**/*.*, **/__tests__/**/*.*"
_harness_template: "rules/testing.md.template"
_harness_version: "2.5.27"
---

# Testing Rules

## テスト作成の原則

1. **境界テスト**: 入力の境界値を必ずテスト
2. **正常系・異常系**: 両方のケースをカバー
3. **独立性**: 各テストは他のテストに依存しない
4. **明確な命名**: テスト名で何をテストしているか分かる

## テストファイル構成

```
src/
├── feature/
│   ├── index.ts
│   └── index.test.ts  # 同じディレクトリに配置
tests/
├── integration/       # 統合テスト
└── e2e/               # E2Eテスト
```

## テスト命名規約

```typescript
describe('機能名', () => {
  it('should 期待する動作 when 条件', () => {
    // ...
  });
});
```

例:
- `should return user when valid ID is provided`
- `should throw error when email is invalid`

## カバレッジ目標

| 種類 | 目標 |
|------|------|
| ユニットテスト | 80%+ |
| 統合テスト | 主要フロー |
| E2Eテスト | クリティカルパス |

## 禁止事項

- ❌ 実装の内部詳細に依存したテスト
- ❌ 外部サービスへの実際の接続（モックを使用）
- ❌ テスト間の状態共有
- ❌ `any` や `// @ts-ignore` でのテスト回避
