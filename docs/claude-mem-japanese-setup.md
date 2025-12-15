# claude-mem プラグイン日本語化手順

claude-memプラグインの出力を日本語化する手順です。

## 前提条件

- Claude Code がインストール済み
- claude-mem プラグインがインストール済み（marketplace: `thedotmack`）

## 手順

### 1. prompts.ts の編集

ソースファイルを編集して日本語出力指示を追加します。

```bash
# ファイルの場所
~/.claude/plugins/marketplaces/thedotmack/src/sdk/prompts.ts
```

以下の3箇所に `LANGUAGE` セクションを追加：

#### 1.1 buildInitPrompt 関数内（観察記録用）

`OUTPUT FORMAT` セクションの直前に追加：

```typescript
LANGUAGE
--------
Write all output content (title, subtitle, facts, narrative) in Japanese (日本語).

OUTPUT FORMAT
-------------
```

#### 1.2 buildSummaryPrompt 関数内（サマリー用）

`OUTPUT FORMAT` セクションの直前に追加：

```typescript
LANGUAGE: Write all output content (request, investigated, learned, completed, next_steps, notes) in Japanese (日本語).

OUTPUT FORMAT
```

#### 1.3 buildContinuationPrompt 関数内（継続プロンプト用）

`OUTPUT FORMAT` セクションの直前に追加：

```typescript
LANGUAGE
--------
Write all output content (title, subtitle, facts, narrative) in Japanese (日本語).

OUTPUT FORMAT
```

### 2. ビルドとマーケットプレース同期

```bash
cd ~/.claude/plugins/marketplaces/thedotmack

# ビルド
npm run build

# マーケットプレース同期（キャッシュに反映）
npm run sync-marketplace
```

### 3. ワーカーの再起動

```bash
cd ~/.claude/plugins/marketplaces/thedotmack

# ワーカー停止
bun plugin/scripts/worker-cli.js stop

# 1秒待機
sleep 1

# ワーカー起動
bun plugin/scripts/worker-cli.js start
```

### 4. 動作確認

新しい Claude Code セッションを開始し、サマリーが日本語で表示されることを確認。

```bash
# ヘルスチェック（オプション）
curl http://127.0.0.1:37777/health
```

## オプション: 既存データの日本語化

既にデータベースに保存されている英語の記録を日本語に翻訳する場合：

### データベースの場所

```
~/.claude-mem/claude-mem.db
```

### テーブル構造

- `observations` - 観察記録（title, subtitle, facts, narrative）
- `session_summaries` - セッションサマリー（request, investigated, learned, completed, next_steps）

### 翻訳例（SQLite）

```bash
sqlite3 ~/.claude-mem/claude-mem.db "UPDATE observations SET
title = '日本語タイトル',
subtitle = '日本語サブタイトル',
facts = '[\"日本語ファクト1\",\"日本語ファクト2\"]'
WHERE id = 1;"
```

## 注意事項

- マーケットプレース同期（`npm run sync-marketplace:force`）を実行するとソースが上書きされる可能性があるため、変更後は再度編集が必要になる場合がある
- ワーカーログは `~/.claude-mem/logs/` に保存される
- 変更が反映されない場合は、Claude Code を完全に終了して再起動

## ファイル構成

```
~/.claude/
├── plugins/
│   ├── marketplaces/
│   │   └── thedotmack/           # ソースコード
│   │       └── src/sdk/prompts.ts # 編集対象
│   └── cache/
│       └── thedotmack/
│           └── claude-mem/
│               └── 7.1.14/       # ビルド済みファイル
│                   └── scripts/
│                       └── worker-service.cjs
└── settings.json                  # プラグイン設定

~/.claude-mem/
├── claude-mem.db                  # データベース
├── settings.json                  # claude-mem設定
├── logs/                          # ログディレクトリ
└── worker.pid                     # ワーカーPID
```
