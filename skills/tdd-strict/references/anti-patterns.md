# TDD Anti-Patterns: 避けるべきパターン

## Red Flags: 即座にやり直しが必要

以下のパターンが発生した場合、**作業を中断してやり直し**が必要。

### 1. テスト前にコードを書いた

```
❌ 発生: 「とりあえず実装してみた」
✅ 対応: 該当コードを全削除 → テストから書き直し
```

### 2. テストが即座にパスした

```
❌ 発生: 新しいテストを書いたら、何もせずパスした
✅ 対応:
   - テストが正しいか確認
   - 既存コードで対応済みなら、テスト不要かも
   - テストが間違っていたら修正
```

### 3. 失敗理由を説明できない

```
❌ 発生: 「なぜ失敗したかわからないけど、とりあえず直した」
✅ 対応: 失敗を理解してから進む
```

### 4. 「今回だけ例外」

```
❌ 発生: 「この部分はテスト書かなくていいでしょ」
✅ 対応: 例外なし。テストを書く
```

---

## テスト品質の Anti-Patterns

### 1. The Giant: 巨大テスト

```typescript
// ❌ 1つのテストで複数のことを検証
test('user registration', () => {
  const user = createUser('test@example.com', 'password');
  expect(user.email).toBe('test@example.com');
  expect(user.id).toBeDefined();
  expect(user.createdAt).toBeDefined();
  expect(validatePassword(user.password)).toBe(true);
  expect(sendWelcomeEmail(user)).toBe(true);
  expect(db.find(user.id)).toEqual(user);
});

// ✅ 1テスト1アサーション
test('createUser sets email correctly', () => {
  const user = createUser('test@example.com', 'password');
  expect(user.email).toBe('test@example.com');
});

test('createUser generates unique id', () => {
  const user = createUser('test@example.com', 'password');
  expect(user.id).toBeDefined();
});
// ...
```

### 2. The Mockery: モック過多

```typescript
// ❌ 実装詳細をモックしすぎ
test('processOrder calls all dependencies', () => {
  const mockValidator = jest.fn();
  const mockCalculator = jest.fn();
  const mockDb = jest.fn();
  const mockEmail = jest.fn();

  processOrder(order, mockValidator, mockCalculator, mockDb, mockEmail);

  expect(mockValidator).toHaveBeenCalled();
  expect(mockCalculator).toHaveBeenCalled();
  expect(mockDb).toHaveBeenCalled();
  expect(mockEmail).toHaveBeenCalled();
});

// ✅ 振る舞いをテスト
test('processOrder saves order with calculated total', () => {
  const order = { items: [{ price: 100 }, { price: 200 }] };
  processOrder(order);
  expect(db.getLastSaved().total).toBe(300);
});
```

### 3. The Inspector: 実装詳細の検査

```typescript
// ❌ 内部実装をテスト
test('validateEmail uses regex', () => {
  expect(validateEmail.toString()).toContain('RegExp');
});

// ✅ 振る舞いをテスト
test('validateEmail rejects invalid format', () => {
  expect(validateEmail('not-an-email')).toBe(false);
});
```

### 4. The Sleeper: 時間依存テスト

```typescript
// ❌ タイミングに依存
test('debounce delays execution', async () => {
  debounce(callback, 100);
  await sleep(50);
  expect(callback).not.toHaveBeenCalled();
  await sleep(60);
  expect(callback).toHaveBeenCalled();
});

// ✅ タイマーをモック
test('debounce delays execution', () => {
  jest.useFakeTimers();
  debounce(callback, 100);
  jest.advanceTimersByTime(99);
  expect(callback).not.toHaveBeenCalled();
  jest.advanceTimersByTime(1);
  expect(callback).toHaveBeenCalled();
});
```

### 5. The Dependant: テスト間依存

```typescript
// ❌ テストの実行順序に依存
let sharedUser;

test('create user', () => {
  sharedUser = createUser('test@example.com');
  expect(sharedUser).toBeDefined();
});

test('update user', () => {
  updateUser(sharedUser.id, { name: 'New Name' });  // sharedUser が必要
  expect(getUser(sharedUser.id).name).toBe('New Name');
});

// ✅ 各テストが独立
test('updateUser changes name', () => {
  const user = createUser('test@example.com');
  updateUser(user.id, { name: 'New Name' });
  expect(getUser(user.id).name).toBe('New Name');
});
```

---

## 実装の Anti-Patterns

### 1. The Hardcoder: 永久ハードコード

```typescript
// ❌ テストケースだけ通るハードコード（そのまま放置）
function add(a, b) {
  if (a === 2 && b === 3) return 5;
  if (a === 1 && b === 1) return 2;
  return 0;
}

// ✅ 汎用的な実装
function add(a, b) {
  return a + b;
}
```

### 2. The Premature Optimizer: 早すぎる最適化

```typescript
// ❌ GREEN Phase で最適化
function fibonacci(n) {
  const memo = new Map();  // まだ必要ない
  function fib(n) {
    if (memo.has(n)) return memo.get(n);
    // ...
  }
}

// ✅ まず動くものを
function fibonacci(n) {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
}
// 最適化は後で（パフォーマンステストが失敗したら）
```

### 3. The Framework Builder: 早すぎる抽象化

```typescript
// ❌ 1つの機能のために汎用フレームワーク
interface Validator<T> {
  validate(input: T): ValidationResult<T>;
  configure(options: ValidatorOptions): void;
  extend(plugin: ValidatorPlugin): void;
}

// ✅ 今必要なものだけ
function validateEmail(email: string): boolean {
  return email.includes('@');
}
```

---

## プロセスの Anti-Patterns

### 1. Test-After Development (TAD)

```
❌ 実装 → テスト（後付け）
   問題: テストが実装を検証するだけ。設計を駆動しない

✅ テスト → 実装（TDD）
   利点: テストが設計を駆動する
```

### 2. Big Bang Testing

```
❌ 全機能実装 → 全テスト作成
   問題: バグの原因特定が困難

✅ 1機能ずつ RED-GREEN-REFACTOR
   利点: バグが入った瞬間にわかる
```

### 3. Skipping RED

```
❌ テスト書く → 実装（失敗確認をスキップ）
   問題: テストが正しいか不明

✅ テスト書く → 失敗確認 → 実装
   利点: テストの正しさを確認
```

---

## 検出チェックリスト

コードレビュー時に確認:

| チェック項目 | NG の兆候 |
|-------------|----------|
| テストカバレッジ | 新機能のテストがない |
| テストのタイミング | コミット履歴で実装が先 |
| テストの独立性 | `beforeAll` で共有状態 |
| モックの量 | モックが実コードより多い |
| テスト名 | `test1`, `test2` |
| アサーション数 | 1テストに10個以上 |
