# /setup-cursor

Cursor連携機能をセットアップします。このコマンドを実行すると、Cursorで計画・レビュー・タスク管理を行えるようになります。

## 概要

`claude-code-harness`はデフォルトでClaude Code単独モードですが、このコマンドでCursor連携を有効化できます。

**連携モード**:
- **計画**: CursorまたはClaude Codeのどちらでも可能
- **レビュー**: CursorまたはClaude Codeのどちらでも可能
- **実装**: Claude Code専用（Cursorでは実行不可）

## セットアップ手順

### Step 1: Cursor用コマンドの生成

以下のファイルを`.cursor/commands/`に生成します：

```bash
.cursor/
└── commands/
    ├── plan-with-cc.md         # 計画立案
    ├── review-cc-work.md       # レビュー
    ├── project-overview.md     # プロジェクト概要
    ├── handoff-to-claude.md    # Claude Codeへのタスク引き渡し
    └── start-session.md        # セッション開始
```

### Step 2: 共有ファイルの確認

以下のファイルがCursorとClaude Codeで共有されます：

- `Plans.md`: タスク管理（両方で読み書き可能）
- `AGENTS.md`: 開発フロー概要（参照用）

### Step 3: Cursorでの使用方法

Cursorを開いて以下のコマンドを実行：

```
/plan-with-cc
```

計画が完了したら、Claude Codeで実装：

```
/work
```

実装完了後、Cursorでレビュー：

```
/review-cc-work
```

## 実行

以下のコマンドを実行してセットアップを開始します：

```bash
# Cursor用ディレクトリを作成
mkdir -p .cursor/commands

# テンプレートからコマンドファイルをコピー
cp templates/cursor/commands/*.md .cursor/commands/

# 共有ファイルを作成（存在しない場合）
if [ ! -f "AGENTS.md" ]; then
    cat > AGENTS.md << 'EOF'
# 開発エージェント構成

## Cursor (計画・レビュー)
- タスクの計画立案
- コードレビュー
- プロジェクト管理

## Claude Code (実装)
- コード実装
- テスト作成
- デバッグ・修正
EOF
fi

echo "✅ Cursor連携のセットアップが完了しました"
echo ""
echo "次のステップ："
echo "1. Cursorを開く"
echo "2. /plan-with-cc を実行して計画を立てる"
echo "3. Claude Codeで /work を実行して実装する"
echo "4. Cursorで /review-cc-work を実行してレビューする"
```

## 注意事項

- 実装コマンド（`/work`）はClaude Code専用です
- Plans.mdは両方で編集可能ですが、競合を避けるため役割を明確に分けてください
- Cursor側からClaude Codeへのタスク引き渡しは、コピー＆ペーストで行います

## 無効化

Cursor連携を無効化する場合：

```bash
rm -rf .cursor/commands
```
