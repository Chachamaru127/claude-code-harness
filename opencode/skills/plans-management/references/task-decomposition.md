# Task Decomposition: 2-5分タスク分解ガイド

## 概要

タスクを **2-5分で完了できる単位** に分解することで:
- 進捗が見える
- 頻繁にコミットできる
- バグの原因特定が容易
- 中断・再開が容易

---

## 粒度基準

| 粒度 | 目安時間 | 例 |
|------|---------|-----|
| **Atomic** | 2-5分 | 1つのテスト作成、1つの関数実装 |
| **Small** | 5-15分 | 1つのコンポーネント、1つのAPIエンドポイント |
| **Medium** | 15-30分 | 1つの機能（複数ファイル） |

**デフォルト: Atomic（2-5分）**

---

## TDD Strict モードでの分解パターン

### 基本パターン

1つの機能を以下のように分解:

```markdown
### Feature: {機能名}

#### Task 1: テスト作成 (5min) `[test]`
- [ ] テストファイル作成
- [ ] 正常系テスト 1件
- [ ] 異常系テスト 1-2件

#### Task 2: テスト失敗確認 (2min) `[verify]`
- [ ] テスト実行
- [ ] 正しい理由で失敗していることを確認

#### Task 3: 最小実装 (5min) `[impl]`
- [ ] テストを通す最小限のコード
- [ ] テスト成功を確認

#### Task 4: リファクタリング (5min) `[refactor]`
- [ ] コード整理
- [ ] テストがまだ通ることを確認

#### Task 5: コミット (2min) `[commit]`
- [ ] git add && git commit
```

### 例: ユーザー登録機能

```markdown
### Feature: ユーザー登録

#### Task 1.1: validateEmail テスト作成 (5min) `[test]`
- [ ] `src/validators/email.test.ts` 作成
- [ ] 正常系: 有効なメールアドレス
- [ ] 異常系: 空文字、@なし、不正形式

#### Task 1.2: validateEmail 実装 (5min) `[impl]`
- [ ] `src/validators/email.ts` 作成
- [ ] テストが通る最小実装

#### Task 1.3: validateEmail コミット (2min) `[commit]`
- [ ] `feat: add email validation`

#### Task 2.1: validatePassword テスト作成 (5min) `[test]`
- [ ] `src/validators/password.test.ts` 作成
- [ ] 正常系: 8文字以上、大小文字含む
- [ ] 異常系: 短すぎる、単純すぎる

#### Task 2.2: validatePassword 実装 (5min) `[impl]`
- [ ] `src/validators/password.ts` 作成
- [ ] テストが通る最小実装

#### Task 2.3: validatePassword コミット (2min) `[commit]`
- [ ] `feat: add password validation`

#### Task 3.1: createUser テスト作成 (5min) `[test]`
- [ ] `src/services/user.test.ts` 作成
- [ ] 正常系: ユーザー作成成功
- [ ] 異常系: 重複メール、バリデーションエラー

#### Task 3.2: createUser 実装 (10min) `[impl]`
- [ ] `src/services/user.ts` 作成
- [ ] バリデーション呼び出し
- [ ] DB 保存（モック or 実DB）

#### Task 3.3: createUser コミット (2min) `[commit]`
- [ ] `feat: add user creation service`

#### Task 4: 統合テスト (10min) `[test]`
- [ ] `src/services/user.integration.test.ts`
- [ ] 登録 → ログイン → プロフィール取得

#### Task 5: 統合コミット (2min) `[commit]`
- [ ] `feat: complete user registration flow`
```

---

## 分解のルール

### 1. 1タスク = 1コミット

```
❌ Task: ユーザー登録機能を実装
   → 大きすぎる、複数のことを含む

✅ Task: validateEmail のテスト作成
   → 1つのことだけ、すぐコミット可能
```

### 2. 依存関係を明示

```markdown
#### Task 2.2: validatePassword 実装 `[impl]`
**前提**: Task 2.1 完了
- [ ] ...
```

### 3. 検証ステップを含める

```
❌ Task: API エンドポイント作成
   → 検証が含まれていない

✅ Task: API エンドポイント作成
   - [ ] エンドポイント実装
   - [ ] curl で動作確認
   - [ ] テスト追加
```

### 4. ラベルで種類を明示

| ラベル | 意味 |
|--------|------|
| `[test]` | テスト作成 |
| `[impl]` | 実装 |
| `[refactor]` | リファクタリング |
| `[verify]` | 検証・確認 |
| `[commit]` | コミット |
| `[docs]` | ドキュメント |

---

## 自動分解のトリガー

Plans.md 生成時、以下の条件で自動的に Atomic 分解を適用:

| 条件 | 分解 |
|------|------|
| `tdd.mode: strict` | 必ず Atomic 分解 |
| `[feature:tdd]` マーカー | Atomic 分解 |
| `planning.task_granularity: atomic` | Atomic 分解 |

---

## 設定

```yaml
# .claude-code-harness.config.yaml
planning:
  task_granularity: "atomic"  # default: atomic
  # "atomic" - 2-5分タスク
  # "small" - 5-15分タスク
  # "medium" - 15-30分タスク
```

---

## チェックリスト

タスク分解時の確認:

- [ ] 各タスクは 5分以内で完了するか？
- [ ] 各タスクは 1つのことだけを行うか？
- [ ] 各タスクは独立してコミット可能か？
- [ ] 依存関係は明示されているか？
- [ ] 検証ステップが含まれているか？
- [ ] ラベルが付いているか？
