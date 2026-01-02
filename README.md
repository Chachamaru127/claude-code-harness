# Claude harness

[English](README.en.md) | 日本語

![Claude harness](docs/images/claude-harness-logo-with-text.png)

**個人開発を、プロ品質へ | Elevate Solo Development to Pro Quality**

Claude Code を「Plan → Work → Review」の自律サイクルで運用し、
**迷い・雑さ・事故・忘却** を仕組みで防ぐ開発ハーネスです。

[![Version: 2.6.21](https://img.shields.io/badge/version-2.6.21-blue.svg)](VERSION)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.md)
[![Harness Score](https://img.shields.io/badge/harness_score-92%2F100-brightgreen.svg)](#採点基準)

---

## v2.6 の新機能 | What's New in v2.6

### 品質判定ゲートシステム（v2.6.2）| Quality Gate System

**適切な場面で適切な品質基準を自動提案**
*Auto-suggest appropriate quality standards at the right time*

| 判定タイプ | 対象 | 提案内容 |
|-----------|------|---------|
| **TDD** | `[feature]` タグ、`src/core/` | 「テストから書きますか？」 |
| **Security** | 認証/API/決済 | セキュリティチェックリスト表示 |
| **a11y** | UI コンポーネント | アクセシビリティチェック |
| **Performance** | DB クエリ、ループ処理 | N+1 警告 |

- 強制ではなく**提案**（VibeCoder にも優しい）
- `/plan-with-agent` で計画作成時に自動でマーカー付与

### Claude-mem 統合（v2.6.0）| Claude-mem Integration

```bash
/harness-mem  # Claude-mem を統合
```

**過去の失敗から学び、同じミスを繰り返さない**
*Learn from past mistakes and avoid repeating them*

- 過去のテスト改ざん警告・ビルドエラー解決策を自動参照
- `impl` / `review` / `verify` スキルが知見を活用
- 重要な学びは SSOT（decisions.md/patterns.md）に昇格可能

### Skill 階層リマインダー（v2.6.1）| Skill Hierarchy Reminder

親スキルを使うと、**関連する子スキルを自動で提案**。
*Auto-suggest related child skills when using a parent skill.*

「どのスキルを読めばいいか」で迷わなくなります。

### Cursor × Claude-mem 自動記録（v2.6.13）| Cursor Auto-Recording

```bash
/cursor-mem  # ワンコマンドでセットアップ
```

**Cursor での作業を自動記録し、Claude Code と作業履歴を共有**
*Auto-record Cursor work and share history with Claude Code*

- **自動記録**: プロンプト、ファイル編集、セッション完了を自動記録
- **双方向共有**: Claude Code ⇄ claude-mem ⇄ Cursor
- **2-Agent 運用**: PM（Cursor）と実装役（Claude Code）の連携を強化

詳細: [Cursor 統合ガイド](docs/guides/cursor-mem-integration.md)

**テスト: Cursor フック動作確認** - Cursor 統合フックの動作を確認済み（PreToolUse/PostToolUse が正常に動作）。

---

## 3行でわかる

| コマンド | 何をする | 結果 |
|----------|----------|------|
| `/plan-with-agent` | 壁打ち → 計画化 | **Plans.md** 作成 |
| `/work` | 計画を実行（並列対応） | 動くコード |
| `/harness-review` | 多観点レビュー | プロ品質 |

![Quick Overview](docs/images/quick-overview.png)

---

## 解決する4つの問題

| 問題 | 症状 | 解決策 |
|------|------|--------|
| **迷う** | 何をすべきかわからない | `/plan-with-agent` で整理 |
| **雑になる** | 品質が落ちる | `/harness-review` で多観点チェック |
| **事故る** | 危険な操作を実行 | Hooks で自動ガード |
| **忘れる** | 前提が抜ける | SSOT + Claude-mem で継続 |

![Four Walls](docs/images/four-walls.png)

---

## 5分で始める

### 1. インストール

```bash
cd /path/to/your-project
claude

# マーケットプレイスを追加 → インストール
/plugin marketplace add Chachamaru127/claude-code-harness
/plugin install claude-code-harness@claude-code-harness-marketplace
```

### 2. 初期化

```bash
/harness-init
```

### 3. 開発ループ

```bash
/plan-with-agent  # 計画
/work             # 実装
/harness-review   # レビュー
```

<details>
<summary>ローカルクローン（開発者向け）</summary>

```bash
git clone https://github.com/Chachamaru127/claude-code-harness.git ~/claude-plugins/claude-code-harness
cd /path/to/your-project
claude --plugin-dir ~/claude-plugins/claude-code-harness
```

</details>

---

## 誰のためのツールか

| ユーザー | メリット |
|----------|----------|
| **個人開発者** | 速さと品質を両立 |
| **フリーランス** | レビュー結果を納品物として提出 |
| **VibeCoder** | 自然言語で開発を回す |
| **Cursor 併用派** | 2-Agent 運用で役割分担 |

---

## 機能一覧

### 安全性（Hooks）

| 機能 | 説明 |
|------|------|
| **保護パスガード** | `.git/`・`.env`・秘密鍵への書き込みを拒否 |
| **危険コマンド確認** | `git push`・`rm -rf`・`sudo` は確認を要求 |
| **安全コマンド許可** | `git status`・`npm test` は自動許可 |

### 継続性（SSOT + Memory）

| 機能 | 説明 |
|------|------|
| **decisions.md** | 決定事項（Why）を蓄積 |
| **patterns.md** | 再利用パターン（How）を蓄積 |
| **Claude-mem 統合** | セッション跨ぎで過去の学びを活用 |

### 品質保証（3層防御）

| 層 | 仕組み | 強制力 |
|----|--------|--------|
| 第1層 | Rules（test-quality.md 等） | 良心ベース |
| 第2層 | Skills 内蔵ガードレール | 文脈的強制 |
| 第3層 | Hooks で改ざん検出 | 技術的強制 |

**禁止パターン**: `it.skip()` への変更、アサーション削除、形骸化実装

---

## コマンド早見表

### コア（Plan → Work → Review）

| コマンド | 用途 |
|----------|------|
| `/harness-init` | プロジェクト初期化 |
| `/plan-with-agent` | 計画作成 |
| `/work` | タスク実装（並列対応） |
| `/harness-review` | 多観点レビュー |
| `/skill-list` | スキル一覧 |

### 品質・運用

| コマンド | 用途 |
|----------|------|
| `/validate` | ビルド・テスト一括検証 |
| `/harness-update` | プラグイン更新 |
| `/cleanup` | Plans.md 等の整理 |
| `/sync-status` | 進捗確認 → 次アクション提案 |

### 知識・連携

| コマンド | 用途 |
|----------|------|
| `/remember` | 学習事項を Rules/Commands/Skills に記録 |
| `/harness-mem` | Claude-mem 統合セットアップ |
| `/cursor-mem` | Cursor × Claude-mem 自動記録セットアップ |
| `/handoff-to-cursor` | Cursor(PM) への完了報告 |

### スキル（会話で自動起動）

| スキル | トリガー例 |
|--------|-----------|
| `impl` | 「実装して」「機能追加」 |
| `review` | 「レビューして」「セキュリティチェック」 |
| `verify` | 「ビルドして」「エラー復旧」 |
| `auth` | 「ログイン機能」「Stripe決済」 |
| `deploy` | 「Vercelにデプロイ」 |
| `ui` | 「ヒーローを作って」 |

`/skill-list` で全67スキルを確認できます。

---

## Cursor 2-Agent 運用（任意）

「2-agent運用を始めたい」と言えば自動セットアップ。

| 役割 | 担当 |
|------|------|
| **Cursor (PM)** | 計画・レビュー・タスク管理 |
| **Claude Code (Worker)** | 実装・テスト・デバッグ |

**ワークフロー**:

```
Cursor: /plan-with-cc → /handoff-to-claude
Claude Code: /work → /handoff-to-cursor
Cursor: /review-cc-work → 承認 or 修正依頼
```

---

## アーキテクチャ

```
claude-code-harness/
├── commands/     # スラッシュコマンド（21）
├── skills/       # スキル（67 / 22カテゴリ）
├── agents/       # サブエージェント（6）
├── hooks/        # ライフサイクルフック
├── scripts/      # ガード・自動化スクリプト
├── templates/    # 生成テンプレート
└── docs/         # ドキュメント
```

### 3層設計

| 層 | ファイル | 役割 |
|----|----------|------|
| Profile | `profiles/claude-worker.yaml` | ペルソナ定義 |
| Workflow | `workflows/default/*.yaml` | 作業フロー |
| Skill | `skills/**/SKILL.md` | 具体的な機能 |

---

## 検証

```bash
# プラグイン構造の検証
./tests/validate-plugin.sh

# 整合性チェック
./scripts/ci/check-consistency.sh
```

---

## 採点基準

| カテゴリ | 配点 | スコア |
|----------|-----:|------:|
| オンボーディング | 15 | 14 |
| ワークフロー設計 | 20 | 19 |
| 安全性 | 15 | 15 |
| 継続性 | 10 | 9 |
| 自動化 | 10 | 9 |
| 拡張性 | 10 | 8 |
| 品質保証 | 10 | 8 |
| ドキュメント | 10 | 10 |
| **合計** | **100** | **92（S）** |

---

## ドキュメント

- [実装ガイド](IMPLEMENTATION_GUIDE.md)
- [開発フロー完全ガイド](DEVELOPMENT_FLOW_GUIDE.md)
- [メモリポリシー](docs/MEMORY_POLICY.md)
- [アーキテクチャ](docs/ARCHITECTURE.md)
- [Cursor統合](docs/CURSOR_INTEGRATION.md)
- [変更履歴](CHANGELOG.md) | [English](CHANGELOG.en.md)

---

## 謝辞

- **階層型スキル構造**: [AIまさお氏](https://note.com/masa_wunder) のフィードバックに基づいて実装
- **テスト改ざん防止**: [びーぐる氏](https://github.com/beagleworks)「Claude Codeにテストで楽をさせない技術」（Claude Code Meetup Tokyo 2025.12.22）

---

## 参考

- [Claude Code Plugins（公式）](https://docs.claude.com/en/docs/claude-code/plugins)
- [anthropics/claude-code](https://github.com/anthropics/claude-code)
- [davila7/claude-code-templates](https://github.com/davila7/claude-code-templates)

---

## ライセンス

**MIT License** - 使用・改変・配布・商用利用が自由です。

- [English](LICENSE.md) | [日本語](LICENSE.ja.md)

テスト3
