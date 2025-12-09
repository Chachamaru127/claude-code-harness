# cursor-cc-plugins

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)

**2つのAIがチームを組んで、あなたの開発をサポート。**

Cursor が「何を作るか」を一緒に考え、Claude Code が「実際に作る」。
まるでPMとエンジニアがペアで働くように、2つのAIが役割分担してプロジェクトを進めます。

[English](README.md) | 日本語

![Cursor が計画、Claude Code が構築](docs/images/workflow-ja.png)

---

## これは何？

```
あなた: 「ブログアプリを作りたい」

    ↓ Cursor (PM役) が計画を立てる

Cursor: 「タスクを整理しました。Claude Code に依頼しますね」

    ↓ あなたが Claude Code に渡す

Claude Code (実装役): 「実装しました！レビューをお願いします」

    ↓ あなたが Cursor に戻す

Cursor: 「レビューOK。本番にデプロイしましょう」
```

**1つのAIだけでは難しかった「企画→実装→レビュー」のサイクルが、2つのAIの連携で可能に。**

---

## 3ステップで始める

### Step 1: インストール

Claude Code で以下を実行：

```bash
/plugin marketplace add Chachamaru127/cursor-cc-plugins
/plugin install cursor-cc-plugins
```

### Step 2: セットアップ ⭐ これが最初！

```bash
/setup-2agent
```

このコマンドで必要なファイルが全て作成されます。

### Step 3: Cursor で相談開始

**ここからは Cursor を開いてください。**

```
あなた → Cursor: 「ECサイトを作りたいんだけど」

Cursor: 「いいですね！まずは必要な機能を整理しましょう...」
```

Cursor が計画を立て、実装が必要になったら Claude Code に依頼します。

---

## 開発の流れ

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   1. Cursor に相談                                          │
│      「〇〇を作りたい」「〇〇機能を追加したい」              │
│              │                                              │
│              ▼                                              │
│   2. Cursor がタスクを整理                                  │
│      → /assign-to-cc でタスクを出力                        │
│              │                                              │
│              ▼                                              │
│   3. タスクを Claude Code にコピー                          │
│      (あなたがコピー&ペーストで橋渡し)                      │
│              │                                              │
│              ▼                                              │
│   4. Claude Code が実装                                     │
│      → /handoff-to-cursor で完了報告                       │
│              │                                              │
│              ▼                                              │
│   5. 完了報告を Cursor にコピー                             │
│      (あなたがコピー&ペーストで橋渡し)                      │
│              │                                              │
│              ▼                                              │
│   6. Cursor がレビュー                                      │
│      → 問題なければ本番デプロイ判断                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**ポイント**: Cursor と Claude Code は直接通信しません。**あなたがコピー&ペーストで橋渡し**します。これにより何が起きているか常に把握でき、安全です。

---

## なぜ2つのAIを使うのか？

### 具体例で比較

**1つのAIだけの場合:**
```
あなた: 「ログイン機能を追加して」
AI: 「実装しました！」
あなた: 「...これで大丈夫なのかな？」（自分でチェックする必要あり）
```

**2-Agent (このプラグイン) の場合:**
```
あなた → Cursor: 「ログイン機能を追加して」
Cursor: 「セキュリティ要件も含めてタスク整理しました」
    ↓
Claude Code: 「実装しました」
    ↓
Cursor: 「レビューしました。SQLインジェクション対策もOK。デプロイしましょう」
```

### 比較表

| 項目 | 1つのAIだけ | 2-Agent |
|------|------------|---------|
| 企画 | 曖昧になりがち | Cursor が整理 |
| 実装 | 実装のみに集中 | Claude Code が担当 |
| レビュー | 自分で自分を確認 | **別のAIが客観チェック** |
| 品質 | バラつきあり | 一定の品質を維持 |

---

## 覚えるコマンドは2つだけ

最初に覚えるのはこれだけ：

| コマンド | どこで | 何をする |
|---------|--------|----------|
| `/setup-2agent` | Claude Code | **最初に1回だけ実行**。必要なファイルを作成 |
| `/start-task` | Claude Code | Cursor からのタスクを受け取って作業開始 |

あとは自然に Cursor と Claude Code が案内してくれます。

### 補足：新しいプロジェクトを作る場合

既存プロジェクトに導入する場合は `/setup-2agent` だけでOK。

**ゼロから新しいアプリを作る場合**は、`/setup-2agent` の後に：
```bash
/init
```
で新規プロジェクトを作成できます。

---

## Cursor がない場合（Solo モード）

Cursor を使えない環境では、Claude Code だけでも使えます。

```bash
# インストール後、直接話しかけるだけ
「Todoアプリを作りたい」
```

ただし、Solo モードは簡易版です：
- レビューは自分で行う必要がある
- 本番デプロイ判断は手動
- 企画から実装まで1つのAIで完結

**本格的なプロジェクトには 2-Agent モードを推奨します。**

> 詳細: [docs/usage-solo.md](docs/usage-solo.md)

---

## もっと詳しく

| ドキュメント | 内容 |
|-------------|------|
| [2-Agent 詳細ガイド](docs/usage-2agent.md) | ワークフローの詳細、会話例 |
| [Solo モードガイド](docs/usage-solo.md) | Claude Code のみで使う場合 |
| [チーム導入ガイド](docs/ADMIN_GUIDE.md) | セーフティ設定、チーム運用 |
| [アーキテクチャ](docs/ARCHITECTURE.md) | 技術的な詳細 |

---

## FAQ

### Q: `/setup-2agent` と `/init` の違いは？

| コマンド | 目的 | いつ使う |
|---------|------|---------|
| `/setup-2agent` | プラグインの準備 | **最初に1回** |
| `/init` | 新規プロジェクト作成 | 新しいアプリを作る時だけ |

### Q: v2 から更新したら壊れる？

いいえ。v2 のコマンドはそのまま動きます。

```bash
/plugin update cursor-cc-plugins
/setup-2agent  # 更新を検出して適用
```

---

## リンク

- [GitHub](https://github.com/Chachamaru127/cursor-cc-plugins)
- [問題を報告](https://github.com/Chachamaru127/cursor-cc-plugins/issues)
- [Claude Code ドキュメント](https://docs.anthropic.com/en/docs/claude-code)

---

MIT License
