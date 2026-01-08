---
description: 利用可能なスキル一覧を概要付きで表示
description-en: Show available skills with descriptions
---

# /skill-list - スキル一覧

利用可能なスキルを一覧表示します。スキルは会話の中で自動的に呼び出されるため、明示的なコマンド実行は不要です。

> **Claude Code 2.1.0+**: スキルはホットリロード対応。追加・変更は即座に反映されます（再起動不要）。

---

## 使い方

```
/skill-list
```

または自然言語で：
- 「使えるスキルを教えて」
- 「スキル一覧」
- 「何ができる？」

---

## スキル一覧

実行時に以下の形式でスキル一覧を出力してください。

### 出力フォーマット

```markdown
## 利用可能なスキル

### Core（コア機能）

| スキル | 説明 | トリガー例 |
|--------|------|-----------|
| session-init | セッション開始時の環境確認 | 「作業開始」「状況確認して」 |
| plans-management | Plans.mdの管理 | 「タスクを追加して」 |
| session-memory | セッション間の記憶管理 | 自動 |
| parallel-workflows | 複数タスクの並列実行 | 「並列で実行して」 |
| troubleshoot | 問題診断と解決 | 「エラーを調べて」 |

### Optional（拡張機能）

| スキル | 説明 | トリガー例 |
|--------|------|-----------|
| analytics | Analytics統合（GA/Vercel） | 「アクセス解析を入れて」 |
| auth | 認証機能（Clerk/Supabase） | 「ログイン機能を付けて」 |
| auto-fix | レビュー指摘の自動修正 | 「指摘を自動修正して」 |
| component | UIコンポーネント生成 | 「ヒーローセクションを作って」 |
| deploy-setup | デプロイ設定（Vercel/Netlify） | 「デプロイできるようにして」 |
| feedback | フィードバック機能 | 「フィードバックフォームを追加」 |
| health-check | 環境診断 | 「環境をチェックして」 |
| notebooklm-yaml | NotebookLM用YAML生成 | 「スライドデザインYAMLを作って」 |
| payments | 決済機能（Stripe） | 「決済を付けたい」 |
| setup-cursor | Cursor連携セットアップ | 「2-agent運用を始めたい」 |

---

💡 **使い方**: スキルは会話の中で自動的に呼び出されます。
上記の「トリガー例」のように話しかけるだけでOKです。
```

---

## 実行手順

1. `skills/` ディレクトリを走査
2. 各スキルの `SKILL.md` から `name` と `description` を抽出
3. カテゴリ別（core / optional）に整理
4. 上記フォーマットで出力

---

## 実装（LLMへの指示）

以下のコマンドでスキル情報を取得：

```bash
# スキルディレクトリの一覧
find "${CLAUDE_PLUGIN_ROOT}/skills" -name "SKILL.md" -type f

# 各スキルの name と description を抽出
for f in $(find "${CLAUDE_PLUGIN_ROOT}/skills" -name "SKILL.md"); do
  echo "=== $f ==="
  grep -E "^name:|^description:" "$f" | head -2
done
```

取得した情報を上記フォーマットに整形して出力してください。
