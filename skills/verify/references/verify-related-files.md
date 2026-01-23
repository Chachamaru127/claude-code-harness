---
name: verify-related-files
description: "編集したファイルに関連するファイルの修正漏れをチェックする。実装完了後、コミット前に使用します。"
allowed-tools: [Read, Grep, Glob, Bash]
---

# Verify Related Files

実装後に編集ファイルを分析し、関連ファイルの修正漏れを検出するスキル。

---

## 目的

コード変更後に以下を自動検出して、修正漏れを防止：
- 関数シグネチャ変更 → 呼び出し元の未更新
- 型/interface変更 → 実装箇所の不整合
- export変更 → import文の未更新
- 設定値変更 → 環境別設定の非同期

---

## 入力

| 項目 | 説明 |
|------|------|
| `changed_files` | 編集されたファイルのリスト（git diffから取得） |
| `project_type` | プロジェクトタイプ（typescript, python, go, etc.） |

---

## 出力

| 項目 | 説明 |
|------|------|
| `related_files` | 影響を受ける可能性のあるファイルリスト |
| `severity` | 各ファイルの重要度（critical/warning/info） |
| `check_reason` | なぜ確認が必要か |

---

## 実行手順

### 1. 編集ファイルの取得

```bash
# ステージング済みの変更を取得
git diff --cached --name-only

# または作業ツリーの変更
git diff --name-only
```

### 2. 変更内容の分析

各編集ファイルについて以下を検出：

| 検出項目 | 検出方法 |
|---------|---------|
| 関数シグネチャ変更 | git diff で引数・戻り値の変更を検出 |
| export追加/削除 | `export` キーワードの差分 |
| 型/interface変更 | `interface`, `type` 定義の差分 |
| 定数/設定値変更 | 大文字定数、config オブジェクトの差分 |

### 3. 関連ファイルパターンの適用

#### TypeScript/JavaScript

| 変更パターン | 関連ファイル検索 |
|-------------|----------------|
| `export function foo()` 変更 | `grep "import.*foo"` で使用箇所 |
| `interface User` 変更 | `grep "User"` で型使用箇所 |
| `*.tsx` コンポーネント props 変更 | 親コンポーネントの props 渡し |
| `*.test.ts` なしの実装変更 | テストファイルの存在確認 |

```bash
# export された関数の使用箇所を検索
grep -r "import.*{.*functionName.*}" --include="*.ts" --include="*.tsx"

# 型の使用箇所を検索
grep -r ": TypeName" --include="*.ts" --include="*.tsx"
```

#### Python

| 変更パターン | 関連ファイル検索 |
|-------------|----------------|
| `def function()` シグネチャ変更 | `grep "from.*import function"` |
| `class Model` 変更 | `grep "Model"` で継承・使用箇所 |
| `__init__.py` の `__all__` 変更 | パッケージ利用箇所 |

#### 設定ファイル

| 変更ファイル | 関連ファイル |
|-------------|-------------|
| `.env` | `.env.local`, `.env.production`, `.env.example` |
| `config.ts` | `config.test.ts`, `config.prod.ts` |
| `VERSION` | `package.json`, `plugin.json`, `CHANGELOG.md` |
| `tsconfig.json` | `tsconfig.build.json`, `tsconfig.test.json` |

### 4. LSP活用（利用可能な場合）

LSP が有効な場合、より正確な関連ファイル検出が可能：

```
変更された関数/型を特定
    ↓
LSP find-references を実行
    ↓
全参照箇所をリスト化
    ↓
未編集の参照箇所を警告
```

**LSP 活用のメリット**:
- 正確なシンボル参照（文字列マッチではない）
- リネーム済みの参照も追跡可能
- 型推論による暗黙的な使用も検出

---

## チェックパターン詳細

### パターン1: 関数シグネチャ変更

```typescript
// Before
export function createUser(name: string): User

// After
export function createUser(name: string, email: string): User
```

**チェック内容**:
1. `createUser` の全呼び出し箇所を検索
2. 引数が1つの呼び出しを警告

**出力例**:
```
⚠️ 関数シグネチャ変更を検出: createUser

呼び出し箇所（要確認）:
├─ src/api/auth.ts:45 - createUser(name)  ← 引数不足の可能性
├─ src/routes/signup.ts:23 - createUser(userName)  ← 引数不足の可能性
└─ tests/user.test.ts:12 - createUser("test")  ← 引数不足の可能性
```

### パターン2: interface/型変更

```typescript
// Before
interface User {
  id: string;
  name: string;
}

// After
interface User {
  id: string;
  name: string;
  email: string;  // 追加
}
```

**チェック内容**:
1. `User` 型を使用する全箇所を検索
2. オブジェクト生成箇所で `email` がない箇所を警告

**出力例**:
```
⚠️ interface 変更を検出: User (フィールド追加: email)

影響箇所（要確認）:
├─ src/db/users.ts:30 - User オブジェクト生成
├─ src/api/response.ts:15 - User 型アサーション
└─ tests/fixtures/users.ts:5 - テストデータ
```

### パターン3: export削除

```typescript
// Before
export { createUser, deleteUser, updateUser }

// After
export { createUser, updateUser }  // deleteUser 削除
```

**チェック内容**:
1. `deleteUser` の import 文を検索
2. import している全ファイルを警告

**出力例**:
```
🚨 export 削除を検出: deleteUser

import しているファイル（修正必須）:
├─ src/api/admin.ts:3 - import { deleteUser } from './users'
└─ src/routes/user.ts:5 - import { deleteUser } from '@/users'
```

### パターン4: 設定ファイル同期

```
VERSION ファイルが変更された
```

**チェック内容**:
1. 関連ファイルの VERSION 値を比較
2. 不一致があれば警告

**出力例**:
```
⚠️ VERSION 変更を検出: 2.9.22 → 2.9.23

同期が必要なファイル:
├─ .claude-plugin/plugin.json - version: "2.9.22" ← 要更新
├─ package.json - version: "2.9.23" ✅ 同期済み
└─ CHANGELOG.md - 2.9.23 エントリ ← 要確認
```

---

## 重要度の判定

| 重要度 | 条件 | アクション |
|--------|------|-----------|
| `🚨 critical` | 必ずエラーになる変更（export削除、必須引数追加） | 修正必須、コミット前にブロック |
| `⚠️ warning` | エラーの可能性がある変更（オプショナル引数追加、型変更） | 確認を推奨 |
| `ℹ️ info` | 影響が軽微な変更（コメント、内部実装） | 参考情報として表示 |

---

## 結果出力フォーマット

### 問題なしの場合

```
✅ 関連ファイル検証完了

編集ファイル: 3件
├─ src/users.ts
├─ src/api/auth.ts
└─ tests/users.test.ts

関連ファイルチェック: 問題なし
→ コミットに進めます
```

### 要確認がある場合

```
📋 関連ファイル検証完了

編集ファイル: 2件
├─ src/users.ts (interface User 変更)
└─ src/api/auth.ts

⚠️ 要確認: 3件

1. [warning] src/db/users.ts:30
   User 型を使用 - email フィールド追加の影響確認

2. [warning] tests/fixtures/users.ts:5
   User テストデータ - email フィールド追加が必要な可能性

3. [info] docs/api.md
   User 型のドキュメント - 更新推奨

確認済みですか？
1. 確認済み、コミットに進む
2. 各ファイルを確認する
3. LSP find-references で詳細表示
```

### 修正必須がある場合

```
🚨 関連ファイル検証: 修正が必要です

編集ファイル: 1件
└─ src/utils/index.ts (export 削除: formatDate)

🚨 修正必須: 2件

1. [critical] src/components/DatePicker.tsx:3
   import { formatDate } from '@/utils'
   → formatDate は削除されました。import を修正してください。

2. [critical] src/pages/events.tsx:8
   import { formatDate } from '@/utils'
   → formatDate は削除されました。import を修正してください。

⛔ これらを修正するまでコミットできません。
修正しますか？
1. 自動で修正を試みる
2. 手動で修正する
```

---

## プロジェクト固有パターン

### harness プロジェクト

| 変更ファイル | 関連ファイルチェック |
|-------------|-------------------|
| `VERSION` | `plugin.json`, `CHANGELOG.md`, `CHANGELOG_ja.md` |
| `commands/**/*.md` | frontmatter形式、必須フィールド |
| `skills/**/SKILL.md` | references/ との整合性 |
| `hooks.json` | `.claude-plugin/hooks.json` との同期 |
| `*.config.yaml` | `*.config.schema.json` との整合性 |

### Next.js プロジェクト

| 変更ファイル | 関連ファイルチェック |
|-------------|-------------------|
| `app/**/page.tsx` | `layout.tsx`, メタデータ |
| `components/*.tsx` | Storybook (`*.stories.tsx`) |
| `lib/api.ts` | 型定義、テスト |

### Express/API プロジェクト

| 変更ファイル | 関連ファイルチェック |
|-------------|-------------------|
| `routes/*.ts` | OpenAPI spec、テスト |
| `models/*.ts` | マイグレーション、シーダー |
| `middleware/*.ts` | 適用箇所の確認 |

---

## 注意事項

- LSP が利用可能な場合は grep より LSP を優先する
- 大量の関連ファイルがある場合は重要度でフィルタリング
- CI/CD と連携して自動チェックも検討
- 偽陽性（関係ないのに警告）は許容、偽陰性（漏れ）は最小化
