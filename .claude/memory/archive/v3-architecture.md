# v3 アーキテクチャ詳細

## ディレクトリ構造

```
claude-code-harness/
├── core/           # TypeScript コアエンジン
│   ├── src/
│   │   ├── index.ts          # stdin → route → stdout パイプライン
│   │   ├── types.ts          # 型定義（HookInput, HookResult 等）
│   │   ├── guardrails/       # ガードレールエンジン
│   │   │   ├── rules.ts      # 宣言的ルールテーブル (R01-R13)
│   │   │   ├── pre-tool.ts   # PreToolUse フック
│   │   │   ├── post-tool.ts  # PostToolUse フック
│   │   │   ├── permission.ts # PermissionRequest フック
│   │   │   └── tampering.ts  # 改ざん検出
│   │   └── state/            # セッション・タスク状態管理
│   │       ├── schema.ts     # DB スキーマ定義
│   │       ├── store.ts      # HarnessStore (SQLite)
│   │       └── migration.ts  # マイグレーション
│   ├── package.json          # standalone TypeScript package
│   └── tsconfig.json         # strict, NodeNext ESM
├── skills/         # 5動詞スキル（SSOT）
│   ├── plan/       # planning + plans-management + sync-status 統合
│   ├── execute/    # work + breezing + codex 統合
│   ├── review/     # harness-review + codex-review 統合
│   ├── release/    # release-har + handoff 統合
│   ├── setup/      # harness-init + harness-mem 統合
│   └── extensions/ # 拡張パック
├── agents/         # 3エージェント（11→3 統合）
│   ├── worker.md        # 実装担当
│   ├── reviewer.md      # レビュー担当（Read-only）
│   ├── scaffolder.md    # 足場・状態更新担当
│   └── team-composition.md  # チーム構成ガイド
├── hooks/          # 薄いシム（→ core/src/index.ts に委譲）
└── .claude/
    └── agent-memory/
        ├── claude-code-harness-worker/
        ├── claude-code-harness-reviewer/
        └── claude-code-harness-scaffolder/
```

## 5動詞スキル マッピング

| v3 スキル | 統合元（旧スキル） |
|----------|----------------|
| `plan` | planning, plans-management, sync-status |
| `execute` | work, impl, breezing, parallel-workflows, ci |
| `review` | harness-review, codex-review, verify, troubleshoot |
| `release` | release-har, x-release-harness, handoff |
| `setup` | setup, harness-init, harness-update, maintenance |

## 3エージェント マッピング

| v3 エージェント | 統合元（旧エージェント） |
|--------------|------------------|
| `worker` | task-worker, codex-implementer, error-recovery |
| `reviewer` | code-reviewer, plan-critic, plan-analyst |
| `scaffolder` | project-analyzer, project-scaffolder, project-state-updater |

## TypeScript 設定

- `exactOptionalPropertyTypes: true` — optional フィールドに conditional assignment を使う
- `noUncheckedIndexedAccess: true` — 配列アクセスは undefined チェック必須
- `NodeNext` モジュール解決 — ESM
- `better-sqlite3` は `optionalDependencies`（Node 24 compat）

## Mirror 構成

`codex/.codex/skills/` と `opencode/skills/` の5動詞スキルは `skills/` からの mirror コピー:

```bash
# skills/ が SSOT。codex, opencode は mirror
skills/plan -> codex/.codex/skills/plan
skills/execute -> opencode/skills/execute
# ...etc
```

`check-consistency.sh` が mirror の一致を検証する。
