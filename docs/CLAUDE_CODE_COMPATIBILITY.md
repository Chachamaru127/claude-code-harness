# Claude Code 互換性マトリクス

このドキュメントは Claude Code Harness と Claude Code CLI の互換性を定義します。

## 現在の対応状況

| Harness バージョン | Claude Code 最小バージョン | 推奨バージョン | 備考 |
|-------------------|-------------------------|--------------|------|
| v2.9.0 | v2.1.1+ | v2.1.6+ | hooks, skills 基本機能 |
| v2.9.24 | v2.1.6+ | v2.1.21+ | Setup hook, plansDirectory, context_window, セッション間通信 |
| **v2.14.9** | v2.1.6+ | **v2.1.21+** | 4観点並列レビュー、auto-commit、OpenCode対応、MCP code intelligence |

## バージョン別機能対応

### v2.1.22 (2026-01-28)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| 非対話モード (`-p`) の structured outputs 修正 | - | Harness 影響なし |

### v2.1.21 (2026-01-28)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| ファイル操作ツール優先（Read/Edit/Write > cat/sed/awk） | 有利 | PostToolUse `Write\|Edit` フックの発火頻度が増加 = 品質ガード範囲拡大。`Bash(cat:*)` 権限の発火頻度は低下するが維持 |
| 全角数字入力対応（日本語 IME） | 有利 | 日本語ユーザーの選択肢入力が改善 |
| セッション中断後の再開時 API エラー修正 | 有利 | session-resume.sh の安定性向上 |
| auto-compact の早期発火修正 | 有利 | 大出力トークンモデルでのコンテキスト保持が改善 |
| Task ID の再利用問題修正 | - | Harness は TodoWrite を使用、影響なし |
| シェル補完キャッシュ修正 | - | Harness 影響なし |
| 読み取り/検索プログレスインジケーター改善 | - | UX 改善（Harness 影響なし） |
| [VSCode] Python venv 自動アクティベーション | - | VSCode 拡張機能のみ |
| [VSCode] ボタン背景色修正 | - | VSCode 拡張機能のみ |
| [VSCode] Windows ファイル検索修正 | - | VSCode 拡張機能のみ |

### v2.1.20 (2026-01-27)

| 機能 | Harness 対応 | 備考 |
|------|-------------|------|
| Background agent 起動前の権限プロンプト | 要注意 | `/work` 並列実行時に権限承認が必要。`permissions.allow` で事前承認推奨 |
| Setup hook `--init-only` フラグ | 対応済み | hooks.json に `init-only` マッチャー追加 |
| `Bash(*)` ワイルドカードが `Bash` と同等 | 互換 | harness-update の破壊的変更検知で除外対応 |
| PR レビューステータスインジケーター | - | プロンプトフッターに PR 状態表示（Harness 影響なし） |
| `CLAUDE.md` 追加ディレクトリ読み込み | 互換 | `--add-dir` + `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` でモノレポ対応 |
| Task 削除（TaskUpdate ツール） | - | Harness は TodoWrite を使用、影響なし |
| Session compaction 修正 | 有利 | セッション resume の安定性向上 |
| Agent がユーザーメッセージを無視する問題修正 | 有利 | 並列 task-worker 実行中のユーザー介入が可能に |
| CJK/emoji レンダリング修正 | 有利 | 日本語表示の改善 |
| MCP Unicode JSON パース修正 | 有利 | Codex MCP 呼び出しの安定性向上 |
| Config バックアップのタイムスタンプ付きローテーション | 互換 | Claude Code 側で設定バックアップを5世代管理 |
| `/commit-push-pr` Slack 自動投稿 | - | MCP 経由で PR URL を Slack 投稿（Harness の auto-commit と補完関係） |

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

- 2026-01-30: Harness v2.14.9 対応追加（4観点並列レビュー、auto-commit、OpenCode対応）
- 2026-01-28: v2.1.21〜v2.1.22 対応追加（ファイル操作ツール優先、全角数字入力、セッション再開修正）
- 2026-01-27: v2.1.20 対応追加（init-only フック、権限プロンプト対応、Bash(*) ワイルドカード）
- 2026-01-24: v2.1.18〜v2.1.19 対応追加
- 2026-01-16: 初版作成（v2.1.2〜v2.1.9 対応）
