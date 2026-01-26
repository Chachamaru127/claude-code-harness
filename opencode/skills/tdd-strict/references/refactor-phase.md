# REFACTOR Phase: コードを整理する

## 目的

**テストがグリーンのまま、コードを改善する**

機能は変えない。構造だけ改善。テストが壊れたら、リファクタリングが間違っている。

---

## 手順

### Step 1: 改善点を特定

```
チェック項目:
□ 重複コードはないか？
□ 変数名・関数名は適切か？
□ 関数は1つのことだけしているか？
□ ネストが深すぎないか？
□ マジックナンバーはないか？
```

### Step 2: 小さく変更

```typescript
// Before
function validateEmail(email: string): boolean {
  return email.includes('@') && email.includes('.');
}

function validateUrl(url: string): boolean {
  return url.includes('http') && url.includes('.');
}

// After: 共通部分を抽出
function contains(str: string, ...patterns: string[]): boolean {
  return patterns.every(p => str.includes(p));
}

function validateEmail(email: string): boolean {
  return contains(email, '@', '.');
}

function validateUrl(url: string): boolean {
  return contains(url, 'http', '.');
}
```

### Step 3: テスト実行

```bash
npm test
```

**必ずグリーンであること**を確認。

### Step 4: 壊れたら戻す

```bash
# テストが失敗した場合
git checkout -- src/validator.ts  # 変更を破棄
```

リファクタリングをやり直す。

### Step 5: コミット

```bash
git add .
git commit -m "refactor: extract contains helper for validation"
```

---

## リファクタリングの種類

### 1. 命名の改善

```typescript
// Before
function proc(d: any): any {
  const x = d.n;
  return x.toUpperCase();
}

// After
function formatUserName(user: User): string {
  const name = user.name;
  return name.toUpperCase();
}
```

### 2. 重複の除去 (DRY)

```typescript
// Before
function saveUser(user: User) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] Saving user`);
  db.save(user);
}

function deleteUser(id: string) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] Deleting user`);
  db.delete(id);
}

// After
function log(message: string) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${message}`);
}

function saveUser(user: User) {
  log('Saving user');
  db.save(user);
}

function deleteUser(id: string) {
  log('Deleting user');
  db.delete(id);
}
```

### 3. 関数の分割

```typescript
// Before: 1つの関数で複数のことをしている
function processOrder(order: Order) {
  // バリデーション
  if (!order.items.length) throw new Error('Empty');
  // 計算
  const total = order.items.reduce((s, i) => s + i.price, 0);
  // 保存
  db.save({ ...order, total });
  // 通知
  email.send(order.user, 'Order confirmed');
}

// After: 責務を分割
function validateOrder(order: Order): void {
  if (!order.items.length) throw new Error('Empty');
}

function calculateTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}

function processOrder(order: Order) {
  validateOrder(order);
  const total = calculateTotal(order.items);
  db.save({ ...order, total });
  email.send(order.user, 'Order confirmed');
}
```

### 4. 早期リターン

```typescript
// Before: ネストが深い
function getDiscount(user: User): number {
  if (user) {
    if (user.isPremium) {
      if (user.years > 5) {
        return 0.3;
      } else {
        return 0.2;
      }
    } else {
      return 0.1;
    }
  } else {
    return 0;
  }
}

// After: 早期リターンでフラット化
function getDiscount(user: User): number {
  if (!user) return 0;
  if (!user.isPremium) return 0.1;
  if (user.years > 5) return 0.3;
  return 0.2;
}
```

---

## やってはいけないこと

### 1. 機能追加

```
❌ REFACTOR Phase で新機能を追加
   → 新機能は RED Phase から始める
```

### 2. テストを変更

```
❌ テストが通るようにテストを修正
   → リファクタリングが間違っている証拠
```

### 3. 大きな変更を一度に

```
❌ 10箇所を一度にリファクタリング
   → 1箇所ずつ、テスト実行を挟む
```

---

## チェックリスト

REFACTOR Phase 完了条件:

- [ ] コードが改善された
- [ ] テストは変更していない
- [ ] 全テストがパスした
- [ ] コミットした
- [ ] **新機能は追加していない**

---

## REFACTOR Phase の心構え

1. **テストを信じる**: グリーンなら正しい
2. **小さく**: 1つずつ変更してテスト
3. **勇気を持つ**: テストがあるから安心して変更できる
4. **完璧を目指さない**: 「少し良くなった」で十分
