# Limitations - cursor-cc-plugins

このドキュメントは、cursor-cc-plugins の制限事項と既知の問題を記載しています。

---

## 目次

1. [対応環境](#1-対応環境)
2. [CI/CD サポート](#2-cicd-サポート)
3. [Claude Code 制限](#3-claude-code-制限)
4. [技術スタック制限](#4-技術スタック制限)
5. [既知の問題](#5-既知の問題)
6. [回避策](#6-回避策)

---

## 1. 対応環境

### OS サポート

| OS | サポート状況 | 備考 |
|----|-------------|------|
| macOS | ✅ フルサポート | 開発・テスト環境 |
| Linux | ✅ フルサポート | Ubuntu/Debian 系で確認済み |
| Windows | ⚠️ 部分サポート | WSL2 経由を推奨 |

### Windows での制限

- **シェルコマンド**: 一部の bash コマンドが動作しない
- **推奨**: WSL2 (Windows Subsystem for Linux) を使用
- **代替**: Git Bash での動作は未検証

### 必須ツール

| ツール | 最低バージョン | 用途 |
|--------|---------------|------|
| Node.js | v18.0.0 | プロジェクト生成・ビルド |
| npm | v9.0.0 | パッケージ管理 |
| git | v2.30.0 | バージョン管理 |

### オプションツール

| ツール | 用途 | 必要な機能 |
|--------|------|-----------|
| gh (GitHub CLI) | CI自動修正 | ci-cd-fixer |
| pnpm/yarn | 代替パッケージマネージャー | プロジェクト生成 |

---

## 2. CI/CD サポート

### サポート状況

| プロバイダー | サポート | 自動修正 | 備考 |
|-------------|---------|---------|------|
| GitHub Actions | ✅ フル | ✅ 対応 | gh CLI 必須 |
| GitLab CI | ⚠️ 部分 | ❌ 未対応 | ログ取得のみ |
| CircleCI | ⚠️ 部分 | ❌ 未対応 | ログ取得のみ |
| Jenkins | ❌ 未対応 | ❌ 未対応 | 将来対応予定 |
| Azure Pipelines | ❌ 未対応 | ❌ 未対応 | 将来対応予定 |

### GitHub Actions 以外での制限

- **自動修正不可**: ci-cd-fixer の `apply-local` / `apply-and-push` モードは GitHub Actions のみ
- **ログ取得のみ**: 他のプロバイダーではエラーログの表示のみ
- **手動対応が必要**: 修正は手動で行う必要あり

---

## 3. Claude Code 制限

### Claude Code CLI vs Web

| 機能 | CLI | Web |
|------|-----|-----|
| ファイル操作 | ✅ | ⚠️ 制限あり |
| シェルコマンド | ✅ | ❌ 不可 |
| git 操作 | ✅ | ❌ 不可 |
| 外部 API 呼び出し | ✅ | ⚠️ 制限あり |

### Web 版での制限事項

Claude Code の Web 版（claude.ai）では以下の機能が**使用できません**：

1. **プロジェクト生成** (`/init`)
   - シェルコマンド（npx create-next-app 等）が実行不可
   - 回避策: 手動でプロジェクトを作成

2. **CI 自動修正** (`ci-cd-fixer`)
   - gh CLI が実行不可
   - 回避策: 修正コードを手動でコピー&ペースト

3. **ファイル書き込み**
   - 直接のファイル作成・編集が不可
   - 回避策: 生成されたコードを手動でコピー

### 推奨環境

**Claude Code CLI を使用してください。** Web 版はコードレビューや計画立案のみに使用することを推奨します。

---

## 4. 技術スタック制限

### デフォルトサポートスタック

| スタック | サポート | テンプレート |
|---------|---------|-------------|
| Next.js + Supabase | ✅ フル | あり |
| Next.js + Prisma | ✅ フル | あり |
| React + Vite | ⚠️ 部分 | 基本のみ |
| Vue.js | ⚠️ 部分 | 基本のみ |
| Rails | ❌ 未対応 | なし |
| Django | ❌ 未対応 | なし |
| Laravel | ❌ 未対応 | なし |

### 未対応スタックでの使用

`tech_choice_mode: "fixed"` で `base_stack` を指定しても、テンプレートがない場合：

- 基本的なディレクトリ構造のみ生成
- 詳細な設定は手動で行う必要あり
- Plans.md のタスクは汎用的なものになる

---

## 5. 既知の問題

### Issue #1: Cursor コマンドが作成されない

**症状**: `/setup-2agent` 実行後、Cursor 側のコマンドが1-2個しか作成されない

**原因**: ファイル書き込みのタイミング問題

**回避策**:
```bash
# 手動でファイルを確認・作成
ls -la .cursor/commands/
# 存在しない場合は /setup-2agent を再実行
```

### Issue #2: hooks 重複エラー

**症状**: `hooks.json` 読み込み時にエラー

**原因**: 複数のプラグインが同じ hook を登録

**回避策**:
```bash
# hooks.json を確認し、重複を削除
cat .claude/hooks/hooks.json | jq '.'
```

### Issue #3: Plans.md パースエラー

**症状**: タスクのステータスが正しく認識されない

**原因**: マークダウン形式の微妙な違い

**回避策**:
```markdown
# 正しい形式
- [ ] タスク名 `cc:TODO`
- [x] 完了タスク `cc:完了`

# 間違った形式
- [] タスク名  ← 空白なし
-[ ] タスク名  ← ハイフン後の空白なし
```

---

## 6. 回避策

### Windows ユーザー向け

```powershell
# WSL2 をインストール
wsl --install

# WSL2 内で Claude Code を使用
wsl
cd /mnt/c/Users/YourName/projects
claude
```

### CI プロバイダーが未対応の場合

```markdown
## 手動 CI 修正フロー

1. CI ログを確認
2. エラー内容を Claude Code にコピー
3. 「このエラーを修正して」と依頼
4. 生成された修正を手動で適用
5. コミット & プッシュ
```

### Claude Code Web 版を使う場合

```markdown
## Web 版での作業フロー

1. Cursor で計画を立てる
2. Web 版 Claude にコードレビューを依頼
3. 修正コードを手動でエディタにコピー
4. ローカルでテスト・コミット
```

---

## 将来の改善予定

- [ ] Jenkins / Azure Pipelines サポート
- [ ] Rails / Django テンプレート追加
- [ ] Windows ネイティブサポート改善
- [ ] Claude Code Web 版での制限緩和対応

---

## フィードバック

制限事項に関するフィードバックや改善提案は、GitHub Issues までお願いします：

- [GitHub Issues](https://github.com/Chachamaru127/cursor-cc-plugins/issues)

