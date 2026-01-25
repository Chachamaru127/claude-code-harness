# AGENTS.md - 開発ワークフロー

このプロジェクトは **Claude Code Harness** を使用した Solo 運用です。

## 開発フロー

```
Plan → Work → Review
```

1. **Plan**: `/plan-with-agent` でタスクを計画し Plans.md に記録
2. **Work**: `/work` で Plans.md のタスクを実行
3. **Review**: `/harness-review` で品質チェック

## 主要コマンド

| コマンド | 用途 |
|---------|------|
| `/plan-with-agent` | タスクを Plans.md に追加 |
| `/work` | タスクを実装（並列実行対応） |
| `/harness-review` | 変更内容をレビュー |
| `/sync-status` | 進捗確認と Plans.md 更新 |

## プロジェクト構成

```
eval-test-project/
├── src/           # ソースコード
├── CLAUDE.md      # Claude Code 設定
├── AGENTS.md      # このファイル（ワークフロー）
├── Plans.md       # タスク管理
└── .claude/       # 設定・メモリ
    ├── settings.json
    └── memory/
```

## 技術スタック

- **言語**: TypeScript
- **テスト**: Vitest
- **Lint**: ESLint
- **ビルド**: tsc

## コマンド

```bash
npm run build   # ビルド
npm run test    # テスト実行
npm run lint    # Lint チェック
```
