# RED Phase: 失敗するテストを書く

## 目的

**「何を作るか」をテストで表現する**

テストは仕様書。実装前にテストを書くことで：
- 作るものが明確になる
- API設計が先に決まる
- 完了条件が明確になる

---

## 手順

### Step 1: テストファイルを作成/開く

```bash
# 例: src/utils/validator.ts を実装する場合
# 先に src/utils/validator.test.ts を作成
```

命名規則:
| 実装ファイル | テストファイル |
|-------------|---------------|
| `foo.ts` | `foo.test.ts` |
| `foo.py` | `test_foo.py` |
| `Foo.java` | `FooTest.java` |

### Step 2: 1つのテストケースを書く

```typescript
// ❌ 悪い例: 複数のことを一度にテスト
test('validator works', () => {
  expect(validateEmail('test@example.com')).toBe(true);
  expect(validateEmail('')).toBe(false);
  expect(validateEmail('invalid')).toBe(false);
});

// ✅ 良い例: 1つのことだけテスト
test('validateEmail returns true for valid email', () => {
  expect(validateEmail('test@example.com')).toBe(true);
});
```

### Step 3: テストを実行

```bash
npm test
# または
pytest
# または
go test
```

### Step 4: 失敗を確認

**正しい失敗**:
```
✗ validateEmail returns true for valid email
  ReferenceError: validateEmail is not defined
```

**間違った失敗**（テスト自体のバグ）:
```
✗ SyntaxError: Unexpected token
✗ Error: Cannot find module './validator'
```

間違った失敗の場合 → テストを修正してから進む

---

## チェックリスト

RED Phase 完了条件:

- [ ] テストファイルが存在する
- [ ] テストが1つ以上ある
- [ ] テストを実行した
- [ ] **正しい理由で**失敗している
- [ ] 失敗理由を説明できる

---

## テスト命名ガイド

### 形式

```
test_[対象]_[条件]_[期待結果]
```

### 例

| 悪い名前 | 良い名前 |
|---------|---------|
| `test1` | `test_login_with_valid_credentials_returns_token` |
| `testValidator` | `test_validateEmail_with_empty_string_returns_false` |
| `it works` | `it should return user when id exists` |

---

## よくある間違い

### 1. テストを書く前に実装を考える

```
❌ 「どう実装しようかな...」→ テスト書く
✅ 「何ができればいいか？」→ テスト書く → 「どう実装しよう」
```

### 2. 複数のテストを一度に書く

```
❌ 10個のテストを先に全部書く
✅ 1つ書く → RED確認 → GREEN → 次のテスト
```

### 3. 実装の詳細をテストする

```typescript
// ❌ 実装の詳細に依存
test('uses regex for validation', () => {
  expect(validator.pattern).toMatch(/regex/);
});

// ✅ 振る舞いをテスト
test('validates email format correctly', () => {
  expect(validateEmail('test@example.com')).toBe(true);
});
```

---

## RED Phase の心構え

1. **テストは仕様書**: 「こう動いてほしい」を書く
2. **最小限から**: 1つの振る舞いだけテスト
3. **失敗を喜ぶ**: 失敗 = 正しく進んでいる証拠
4. **急がない**: RED を確認してから GREEN へ
