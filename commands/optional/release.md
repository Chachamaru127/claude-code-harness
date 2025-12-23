---
description: リリースプロセス自動化（CHANGELOG更新、バージョン更新、タグ作成）
description-en: Automate release process (CHANGELOG update, version bump, tag creation)
---

# /release - リリースプロセス自動化

claude-code-harness のリリースを自動化するコマンドです。

## 実行手順

### Step 1: 変更確認

以下を並列で実行：

1. **git status** で未コミット変更を確認
2. **git diff --stat** で変更ファイル一覧
3. **MEM SEARCH** で最近の作業内容を確認（キーワード: 直近の変更に関連するもの）

### Step 2: バージョン決定

現在のバージョンを確認：
```bash
cat VERSION
```

変更内容に応じてバージョンを決定：
- **patch** (x.y.Z): バグ修正、軽微な改善
- **minor** (x.Y.0): 新機能追加
- **major** (X.0.0): 破壊的変更

ユーザーに確認：「次のバージョンは何にしますか？ (例: 2.5.23)」

### Step 3: CHANGELOG.md 更新

CHANGELOG.md の `[Unreleased]` セクションの下に新バージョンのエントリを追加。

**フォーマット**（CLAUDE.md の記載ルールに従う）：

```markdown
## [X.Y.Z] - YYYY-MM-DD

### 🎯 あなたにとって何が変わるか

**一言サマリー（太字）**

#### Before
- 変更前の状態・体験

#### After
- 変更後の状態・体験
- ユーザーにとって何が嬉しいか

### 主な変更内容
- 技術的な変更の詳細

### VibeCoder 向けの使い方（任意）
| やりたいこと | 言い方 |
|-------------|--------|
| ... | ... |
```

### Step 4: バージョン更新

```bash
# VERSION ファイル更新
echo "X.Y.Z" > VERSION

# plugin.json 更新
jq '.version = "X.Y.Z"' .claude-plugin/plugin.json > /tmp/plugin.json && mv /tmp/plugin.json .claude-plugin/plugin.json
```

### Step 5: コミット & タグ

```bash
# ステージング
git add VERSION .claude-plugin/plugin.json CHANGELOG.md [変更されたファイル]

# コミット
git commit -m "release: vX.Y.Z - 一言説明

- 変更点1
- 変更点2

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

# タグ作成
git tag -a vX.Y.Z -m "Release vX.Y.Z: 一言説明"

# プッシュ
git push origin main && git push origin vX.Y.Z
```

### Step 6: キャッシュ同期

```bash
bash scripts/sync-plugin-cache.sh
```

### Step 7: 確認

```bash
git log --oneline -3
git tag | tail -5
cat ~/.claude/plugins/cache/claude-code-harness-marketplace/claude-code-harness/*/VERSION | sort -u
```

## 注意事項

- README.md は新機能追加時のみ更新（バグ修正では不要）
- `skills/test-*` などのテストディレクトリは含めない
- コミットメッセージは Conventional Commits に従う
