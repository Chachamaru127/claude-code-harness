# Plans.md - タスク管理

## 進行中のタスク

### ユーザー管理機能 <!-- cc:WIP -->

**要件**:
- ユーザーの作成・更新・削除ができる
- パスワードは安全に保存する（bcrypt ハッシュ化）
- 管理者権限の設定ができる

**タスク**:

1. [ ] **User 型定義を作成** `src/types/user.ts` <!-- cc:TODO -->
   - User インターフェース（id, email, hashedPassword, role, createdAt, updatedAt）
   - UserRole 型（admin, user）
   - CreateUserInput, UpdateUserInput 型

2. [ ] **パスワードユーティリティを作成** `src/utils/password.ts` <!-- cc:TODO -->
   - hashPassword(plain: string): Promise<string>
   - verifyPassword(plain: string, hashed: string): Promise<boolean>
   - bcrypt を使用（コスト係数12）

3. [ ] **UserService クラスを作成** `src/services/userService.ts` <!-- cc:TODO -->
   - create(input: CreateUserInput): Promise<User>
   - update(id: string, input: UpdateUserInput): Promise<User>
   - delete(id: string): Promise<void>
   - findById(id: string): Promise<User | null>
   - findByEmail(email: string): Promise<User | null>
   - setAdminRole(id: string, isAdmin: boolean): Promise<User>

4. [ ] **テストを作成** `src/__tests__/userService.test.ts` <!-- cc:TODO -->
   - ユーザー作成のテスト
   - パスワードハッシュ化のテスト
   - 権限設定のテスト
   - 削除のテスト

5. [ ] **ビルド・テスト実行で動作確認** <!-- cc:TODO -->

## 完了済み

- [x] プロジェクト初期化（/init）

---

## マーカー凡例

| マーカー | 状態 | 説明 |
|---------|------|------|
| `cc:TODO` | 未着手 | Claude Code が実行予定 |
| `cc:WIP` | 作業中 | Claude Code が実装中 |
| `cc:blocked` | ブロック中 | 依存タスク待ち |

## 使い方

1. 「〇〇を作りたい」→ `/plan-with-agent` でタスク追加
2. `/work` でタスクを実行
3. `/harness-review` で品質確認
