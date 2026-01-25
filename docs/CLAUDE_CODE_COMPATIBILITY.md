# Claude Code 互換性マトリクス

このドキュメントは Claude Code Harness と Claude Code CLI の互換性を定義します。

## 現在の対応状況

| Harness バージョン | Claude Code 最小バージョン | 推奨バージョン | 備考 |
|-------------------|-------------------------|--------------|------|
| v2.9.0 | v2.1.1+ | v2.1.6+ | hooks, skills 基本機能 |
| v2.9.24 | v2.1.6+ | v2.1.19+ | Setup hook, plansDirectory, context_window, セッション間通信 |

## バージョン別機能対応

### v2.1.19 (2026-01-24)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| `CLAUDE_CODE_ENABLE_TASKS` env var | - | Harness 影響なし |
| `$ARGUMENTS[0]` 構文 | 互換 | Harness では未使用 |
| 権限/フックなしスキルは承認不要 | 有利 | Harness スキルの UX 向上 |
| バックグラウンドフック修正 | 有利 | Harness フックの安定性向上 |

### v2.1.18 (2026-01-23)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| `/keybindings` コマンド | - | Harness 影響なし（ターミナル機能） |

### v2.1.17 (2026-01-22)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| Task management system | 対応済み | TodoWrite ↔ Plans.md 同期 |

### v2.1.10 (2026-01-17)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| Setup hook event | 対応済み | `--init` / `--maintenance` フック |

### v2.1.9 (2026-01-16)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| PreToolUse additionalContext | 対応済み | 品質ガイドライン自動注入 |
| plansDirectory 設定 | 対応済み | Plans.md 配置カスタマイズ |
| ${CLAUDE_SESSION_ID} | 部分対応 | session-init.sh でマッピング |
| MCP auto:N syntax | 対応済み | [MCP_CONFIGURATION.md](./MCP_CONFIGURATION.md) 参照 |

### v2.1.7 (2026-01-14)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| MCP auto mode | 対応済み | ドキュメント簡略化 |
| showTurnDuration | - | Harness 影響なし |

### v2.1.6 (2026-01-13)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| Nested skills directory | 互換 | 将来的な構造変更で活用予定 |
| context_window percentage | 対応済み | harness-ui ダッシュボードで表示 |

### v2.1.3 (2026-01-09)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| Hook timeout 10分 | 対応済み | 重い処理のタイムアウト延長 |
| Commands/Skills 統合 | 互換 | 既存構造で対応 |

### v2.1.2 (2026-01-09)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| SessionStart agent_type | 対応済み | サブエージェント軽量初期化 |
| OSC 8 hyperlinks | - | ターミナル機能、Harness 影響なし |

### v2.0.74 (2025-12-19)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| LSP tool | 対応済み | impl/harness-review スキルで活用推奨 |

## 互換性チェック方法

```bash
# Claude Code バージョン確認
claude --version

# Harness バージョン確認
cat /path/to/harness/VERSION
```

## 非互換の可能性

### 破壊的変更はなし

現時点で Claude Code の変更による Harness の破壊的変更はありません。
ただし、以下の機能は新しいバージョンでのみ利用可能です:

- additionalContext（v2.1.9+）
- agent_type（v2.1.2+）
- LSP tool（v2.0.74+）

古いバージョンの Claude Code でも Harness は動作しますが、上記機能は無効化されます。

## 更新履歴

- 2026-01-24: v2.1.18〜v2.1.19 対応追加
- 2026-01-16: 初版作成（v2.1.2〜v2.1.9 対応）
