# Task Ownership & Lock

タスク所有権とロック機構の詳細。

## Overview

並列 Worker 実行時のファイル衝突を防ぐため、タスクごとに担当ファイルを宣言し、ロックで排他制御を行う。

## Task Ownership Declaration

### Plans.md Annotation Format

```markdown
- [ ] ログイン機能実装 `cc:TODO` `owns:src/auth/*,src/pages/login.tsx`
- [ ] API エンドポイント `cc:TODO` `owns:src/api/auth.ts`
- [ ] ユーザー管理 `cc:TODO` `owns:src/users/*`
```

### Ownership Rules

1. **明示的宣言**: タスクは担当ファイルを `owns:` で宣言
2. **グロブ対応**: `*` でディレクトリ内全ファイルを指定可能
3. **排他的所有**: 同一ファイルを複数タスクが同時編集不可
4. **共有ファイル例外**: `package.json`, `tsconfig.json` 等は sequential 実行

## Lock Mechanism

### Lock File Format

```json
{
  "path": "src/auth/login.ts",
  "worker": "worker-1",
  "acquired": "2026-02-02T10:00:00Z",
  "heartbeat": "2026-02-02T10:05:00Z"
}
```

保存先: `.claude/state/locks/{path-sha256-8}.lock.json`

### Path Normalization

| 項目 | ルール |
|------|--------|
| 基準 | リポジトリルート相対パス |
| `./` | 除去（`./src/auth.ts` → `src/auth.ts`） |
| 区切り文字 | `/` に統一 |
| 大小文字 | 変換なし（そのまま） |

### Lock Key Generation

パス正規化後、SHA256 の先頭8文字をキーとして使用。

例:
- `src/auth/login.ts` → `a1b2c3d4.lock.json`

### Lock Operations

| 操作 | 説明 |
|------|------|
| **Acquire** | 排他的作成（O_CREAT\|O_EXCL）、既存なら失敗 |
| **Heartbeat** | 10分ごとに `heartbeat` フィールドを更新 |
| **Release** | ロックファイル削除、`locks.log` に記録 |

### TTL & Automatic Release

- **TTL**: 30分
- **基準**: `heartbeat` フィールドの時刻
- **超過時**: 自動解放、`locks.log` に `expired` として記録

## Conflict Handling

### Pre-execution Check

Worker 起動前に所有権の重複をチェック。

### Conflict Resolution

| 状況 | 対応 |
|------|------|
| ロック取得失敗 | 待機キューに追加、先発完了後に再スケジュール |
| 所有権重複 | Orchestrator が検出、sequential 実行に変更 |
| 共有ファイル | sequential 実行（並列不可） |

## Shared Files

以下のファイルは共有ファイルとして扱い、並列編集を禁止:

- `package.json`
- `package-lock.json`
- `pnpm-lock.yaml`
- `yarn.lock`
- `tsconfig.json`
- `.eslintrc.*`
- `.prettierrc.*`

共有ファイルを含むタスクは sequential に実行される。

## Log Format

### locks.log

```
{ISO8601-UTC}\t{event}\t{path}\t{worker}
```

例:
```
2026-02-02T10:00:00Z	acquire	src/auth/login.ts	worker-1
2026-02-02T10:30:00Z	release	src/auth/login.ts	worker-1
2026-02-02T11:00:00Z	expired	src/api/users.ts	worker-2
```
