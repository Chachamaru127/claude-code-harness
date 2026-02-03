# Changelog

このプロジェクトのすべての注目すべき変更は、このファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/spec/v2.0.0.html) に準拠しています。

> **📝 記載ルール**: ユーザー体験に影響する変更を中心に記載。内部修正は簡潔に。

## [Unreleased]

---

## [2.17.3] - 2026-02-03

### 🎯 あなたにとって何が変わるか

**Ultrawork がレビュー後に自動で自己修正ループに入るようになりました**

| Before | After |
|--------|-------|
| レビュー後に手動でプロンプト入力が必要 | APPROVE まで自動修正ループ |
| Codex 有無を手動で指定 | Codex MCP 自動検出 + フォールバック |
| 改善方法が不明確 | 「🎯 How to Achieve A」で改善指針を明示 |

### Added

- **自己修正ループ**: `/harness-review` 実行後、APPROVE になるまで自動で修正を繰り返す
  - リトライ状態管理（`ultrawork-retry.json`）で進捗追跡
  - REJECT/STOP は即停止して手動介入を促す
  - 最大3回のリトライ後に STOP

- **検証全実行規則**: 存在する検証スクリプトを優先順で全て実行し、失敗で即停止

- **改善指針テンプレート**: 「🎯 How to Achieve A」セクションで A 評価達成方法を明示
  - Decision 別統一フォーマット（APPROVE/REQUEST CHANGES/REJECT/STOP）

### Changed

- **Codex 自動検出**: Codex MCP が利用可能な場合は自動で Codex モードに切り替え
  - 利用不可の場合はサブエージェント並列にフォールバック
  - `timeout_ms`（ミリ秒単位）でタイムアウト設定可能

- **差分計算改善**: `merge-base` 基準で変更ファイル数を算出
  - staged/unstaged 差分も含む
  - 初回コミット/マージにも対応

- **review_aspects 検出**: パスベースの正規表現で決定的に判定

---

## [2.17.2] - 2026-02-03

### 🎯 あなたにとって何が変わるか

**Codex Worker 完了時に Plans.md が自動更新されるようになりました**

| Before | After |
|--------|-------|
| 作業完了後に手動で Plans.md を更新 | スキルが自動で `cc:done` に更新 |

### Added

- **Plans.md 自動更新**: Codex Worker スキル完了時に必ずタスク完了処理を実行
  - 該当タスクを自動特定
  - `[ ]` → `[x]`, `cc:WIP` → `cc:done` に更新
  - タスクが見つからない場合はユーザーに確認

### Internal

- Codex Worker スクリプト品質改善（共通ライブラリ化、セキュリティ強化）

---

## [2.16.20] - 2026-02-03

### Added

- `ultrawork` スキルに Options テーブルと Quick Reference 例を追加（`--codex`, `--parallel`, `--worktree-base`）

### Internal

- スキルルーティングルールを `skills/routing-rules.md` に一元化（SSOT パターン導入）
- `codex-review` と `codex-worker` のルーティングを決定的に（文脈判定を排除）

---

## [2.16.19] - 2026-02-03

### Fixed

- Stop フックの reason が2回表示される問題を軽減（キーワードのみ出力に変更）

---

## [2.16.17] - 2026-02-03

### 🎯 あなたにとって何が変わるか

**スキルの使い方ヒントがオートコンプリートに表示されるようになりました**

| Before | After |
|--------|-------|
| `/harness-review` | `/harness-review [code|plan|scope]` |
| `/troubleshoot` | `/troubleshoot [build|test|runtime]` |

### Added

- 17スキルに使い方ヒント（`argument-hint`）を追加
- セッション間通知機能（複数セッション連携時に便利）

### Internal

- CI/テスト/ドキュメントを Skills 移行後の構造に更新

---

## [2.16.14] - 2026-02-02

### 🎯 あなたにとって何が変わるか

**実装を依頼すると、自動的に Plans.md に登録されます**

| Before | After |
|--------|-------|
| 口頭依頼が Plans.md に残らない | すべてのタスクが Plans.md に記録 |
| 進捗が追いにくい | `/sync-status` で全体把握可能 |

---

## [2.16.11] - 2026-02-02

### 🎯 あなたにとって何が変わるか

**コマンドがスキルに統合されました（使い方は変わりません）**

| Before | After |
|--------|-------|
| `/work`, `/harness-review` がコマンドとして存在 | 同じ名前でスキルとして動作 |
| 内部スキル (impl, verify) がメニューに表示 | 非表示に（ノイズ軽減） |
| `dev-browser`, `docs`, `video` | `agent-browser`, `notebookLM`, `generate-video` に改名 |

### Internal

- README を VibeCoder 向けにリライト（トラブルシューティング・アンインストール追加）
- CI スクリプトを Skills 構造に対応

---

## [2.16.5] - 2026-01-31

### 🎯 あなたにとって何が変わるか

**`/generate-video` が AI 画像生成・BGM・字幕・視覚効果に対応**

| Before | After |
|--------|-------|
| 画像素材は手動で用意 | AI が自動生成（Nano Banana Pro） |
| BGM・字幕なし | 著作権フリー BGM、日本語字幕対応 |
| 基本トランジションのみ | GlitchText, Particles 等のエフェクト |

---

## [2.16.0] - 2026-01-31

### 🎯 あなたにとって何が変わるか

**`/ultrawork` で rm -rf と git push の確認回数が減りました（実験的機能）**

| Before | After |
|--------|-------|
| rm -rf で毎回確認 | 計画時に許可したパスのみ自動承認 |
| git push で毎回確認 | ultrawork 中は自動承認（force除く） |

---

## [2.15.0] - 2026-01-26

### 🎯 あなたにとって何が変わるか

**OpenCode との完全互換モードを追加**

| Before | After |
|--------|-------|
| OpenCode 向けに別途設定が必要 | `/setup-opencode` で自動セットアップ |
| skills/ 構造が異なる | 同一スキルが両環境で動作 |

---

## [2.14.0] - 2026-01-16

### 🎯 あなたにとって何が変わるか

**`/work --full` で並列タスク実行が可能に**

| Before | After |
|--------|-------|
| タスクを1つずつ実行 | `--parallel 3` で最大3並列実行 |
| 完了報告を手動で確認 | 各 worker が自律的にセルフレビュー |

---

## [2.13.0] - 2026-01-14

### 🎯 あなたにとって何が変わるか

**Codex MCP による並列レビューを追加**

| Before | After |
|--------|-------|
| Claude 単体でレビュー | Codex 4エキスパートが並列でレビュー |
| 一度に1観点 | セキュリティ/品質/パフォーマンス/a11y を同時チェック |

---

## [2.12.0] - 2026-01-10

### Added

- **Harness UI ダッシュボード** (`/harness-ui`) - ブラウザで進捗確認
- **ブラウザ自動化** (`agent-browser`) - ページ操作・スクリーンショット

---

## [2.11.0] - 2026-01-08

### Added

- **セッション間メッセージング** - 複数 Claude Code セッション間でメッセージ送受信
- **CRUD 自動生成** (`crud` スキル) - Zod バリデーション付きエンドポイント生成

---

## [2.10.0] - 2026-01-04

### Added

- **LSP 統合** - Go-to-definition, Find-references で正確なコード理解
- **AST-Grep 統合** - 構造的なコードパターン検索

---

## 過去バージョン

v2.9.x 以前の詳細は [GitHub Releases](https://github.com/Chachamaru127/claude-code-harness/releases) を参照してください。
