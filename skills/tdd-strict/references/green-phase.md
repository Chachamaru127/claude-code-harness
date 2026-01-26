# GREEN Phase: テストを通す最小限のコードを書く

## 目的

**テストを通す「だけ」のコードを書く**

美しさ、効率、拡張性は後。今は「動く」ことだけを目指す。

---

## 手順

### Step 1: 最小限の実装を書く

```typescript
// テスト
test('validateEmail returns true for valid email', () => {
  expect(validateEmail('test@example.com')).toBe(true);
});

// ❌ 過剰な実装（GREEN Phase では NG）
function validateEmail(email: string): boolean {
  const regex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  if (!email || typeof email !== 'string') {
    throw new Error('Invalid input');
  }
  return regex.test(email.trim().toLowerCase());
}

// ✅ 最小限の実装（GREEN Phase の正解）
function validateEmail(email: string): boolean {
  return email.includes('@');
}
```

### Step 2: テストを実行

```bash
npm test
```

### Step 3: 全パスを確認

```
✓ validateEmail returns true for valid email

Tests: 1 passed
```

### Step 4: 既存テストも確認

新しいコードが既存機能を壊していないか確認:

```bash
npm test  # 全テスト実行
```

---

## 「最小限」とは？

### 原則: YAGNI (You Ain't Gonna Need It)

今必要なものだけ作る。将来必要「かもしれない」ものは作らない。

| 今のテスト | 最小限の実装 |
|-----------|-------------|
| `'a@b.com'` が valid | `return email.includes('@')` |
| `''` が invalid | `return email.length > 0 && email.includes('@')` |
| `'invalid'` が invalid | すでに上で対応済み |

### 「ハードコード」は許される？

**YES、ただし一時的に**

```typescript
// テスト
test('add returns sum of two numbers', () => {
  expect(add(2, 3)).toBe(5);
});

// GREEN Phase: ハードコードでも OK
function add(a: number, b: number): number {
  return 5;  // 今はこれで通る
}

// 次のテストで汎用化を強制される
test('add returns sum for different numbers', () => {
  expect(add(1, 1)).toBe(2);  // これで return 5 は壊れる
});

// 汎用実装に進化
function add(a: number, b: number): number {
  return a + b;
}
```

---

## チェックリスト

GREEN Phase 完了条件:

- [ ] 実装コードを書いた
- [ ] テストを実行した
- [ ] 新しいテストがパスした
- [ ] 既存のテストも全てパスした
- [ ] **必要以上のコードを書いていない**

---

## よくある間違い

### 1. 過剰実装

```typescript
// テスト: validateEmail('a@b.com') === true

// ❌ 過剰: エラーハンドリング、ログ、型チェック...
function validateEmail(email: string): boolean {
  if (!email) throw new Error('Email required');
  console.log('Validating:', email);
  // ... 50行の実装
}

// ✅ 最小限: テストを通すだけ
function validateEmail(email: string): boolean {
  return email.includes('@');
}
```

### 2. 先回りした設計

```typescript
// テスト: 1つのバリデーション

// ❌ まだ必要ない抽象化
interface Validator<T> {
  validate(input: T): ValidationResult;
  // ...
}

// ✅ 今必要なものだけ
function validateEmail(email: string): boolean {
  return email.includes('@');
}
```

### 3. リファクタリングを混ぜる

```
❌ GREEN Phase で:
  - テスト通す
  - 変数名変える
  - 関数を分割する
  - コメント追加する

✅ GREEN Phase では:
  - テスト通す
  - 終わり（整理は REFACTOR Phase で）
```

---

## GREEN Phase の心構え

1. **動けばいい**: 美しさは後
2. **最小限**: 1行で済むなら1行
3. **急がない**: 過剰実装は技術的負債
4. **テストを信じる**: テストが通れば正しい
