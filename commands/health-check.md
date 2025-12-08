# /health-check - 環境診断

プラグインを使用する前に、環境が正しくセットアップされているかを診断します。

---

## このコマンドの特徴

- 🔍 **環境チェック**: 必要なツールの存在確認
- ⚙️ **設定検証**: cursor-cc.config.json の妥当性チェック
- 📋 **機能診断**: どの機能が使用可能かをレポート
- 💡 **推奨事項**: 問題がある場合の解決策を提示

---

## 使い方

```
/health-check
```

または自然言語で：
- 「環境をチェックして」
- 「診断して」
- 「使える機能を教えて」

---

## チェック項目

### 1. 必須ツール

```bash
# Git
command -v git >/dev/null 2>&1 && echo "✅ git" || echo "❌ git"

# Node.js / npm
command -v node >/dev/null 2>&1 && echo "✅ node $(node -v)" || echo "❌ node"
command -v npm >/dev/null 2>&1 && echo "✅ npm $(npm -v)" || echo "❌ npm"
```

### 2. オプションツール

```bash
# GitHub CLI（CI自動修正に必要）
command -v gh >/dev/null 2>&1 && echo "✅ gh $(gh --version | head -1)" || echo "⚠️ gh (CI自動修正に必要)"

# pnpm / yarn（検出されれば表示）
command -v pnpm >/dev/null 2>&1 && echo "✅ pnpm $(pnpm -v)"
command -v yarn >/dev/null 2>&1 && echo "✅ yarn $(yarn -v)"
```

### 3. プロジェクト構造

```bash
# 必須ファイル
[ -f package.json ] && echo "✅ package.json" || echo "⚠️ package.json (なし)"
[ -d .git ] && echo "✅ Git リポジトリ" || echo "⚠️ Git 未初期化"

# ワークフローファイル
[ -f Plans.md ] && echo "✅ Plans.md" || echo "📝 Plans.md (なし - /init で作成)"
[ -f AGENTS.md ] && echo "✅ AGENTS.md" || echo "📝 AGENTS.md (なし - /init で作成)"
[ -f CLAUDE.md ] && echo "✅ CLAUDE.md" || echo "📝 CLAUDE.md (なし - /init で作成)"
```

### 4. CI設定

```bash
# GitHub Actions
[ -d .github/workflows ] && echo "✅ GitHub Actions 検出" && CI_PROVIDER="github_actions"

# GitLab CI
[ -f .gitlab-ci.yml ] && echo "✅ GitLab CI 検出" && CI_PROVIDER="gitlab_ci"

# CircleCI
[ -d .circleci ] && echo "✅ CircleCI 検出" && CI_PROVIDER="circleci"

# なし
[ -z "$CI_PROVIDER" ] && echo "📝 CI 未設定"
```

### 5. 設定ファイル

```bash
# cursor-cc.config.json
if [ -f cursor-cc.config.json ]; then
  echo "✅ cursor-cc.config.json 検出"
  # JSON の妥当性チェック
  if node -e "JSON.parse(require('fs').readFileSync('cursor-cc.config.json'))" 2>/dev/null; then
    echo "  ✅ JSON 形式: 有効"
  else
    echo "  ❌ JSON 形式: 無効（修正が必要）"
  fi
else
  echo "📝 cursor-cc.config.json (なし - デフォルト設定を使用)"
fi
```

---

## 出力フォーマット

```markdown
## 🏥 環境診断レポート

**診断日時**: {{datetime}}
**プロジェクト**: {{project_name}}

---

### 必須ツール

| ツール | 状態 | バージョン |
|-------|------|-----------|
| git | ✅ 検出 | 2.39.0 |
| node | ✅ 検出 | v20.10.0 |
| npm | ✅ 検出 | 10.2.3 |

### オプションツール

| ツール | 状態 | 備考 |
|-------|------|------|
| gh | ⚠️ 未検出 | CI自動修正に必要 |
| pnpm | ✅ 検出 | 8.12.0 |

### プロジェクト構造

| ファイル | 状態 | 備考 |
|---------|------|------|
| package.json | ✅ 存在 | Next.js プロジェクト |
| .git/ | ✅ 存在 | - |
| Plans.md | ❌ なし | /init で作成可能 |
| AGENTS.md | ❌ なし | /init で作成可能 |

### CI設定

| プロバイダー | 状態 | 備考 |
|-------------|------|------|
| GitHub Actions | ✅ 検出 | .github/workflows/ |
| GitLab CI | ❌ なし | - |
| CircleCI | ❌ なし | - |

### 設定ファイル

| ファイル | 状態 | 備考 |
|---------|------|------|
| cursor-cc.config.json | ⚠️ なし | デフォルト設定を使用 |

---

### 機能の使用可否

| 機能 | 状態 | 理由 |
|------|------|------|
| /init | ✅ 使用可能 | 必須ツールあり |
| /plan | ✅ 使用可能 | - |
| /work | ✅ 使用可能 | - |
| /review | ✅ 使用可能 | - |
| CI自動修正 | ⚠️ 制限あり | gh CLI が必要 |
| エラー回復 | ✅ 使用可能 | - |

---

### 推奨アクション

1. **gh CLI をインストール**（CI自動修正を使う場合）
   ```bash
   # macOS
   brew install gh

   # Windows
   winget install --id GitHub.cli
   ```

2. **cursor-cc.config.json を作成**（カスタマイズする場合）
   ```bash
   cp cursor-cc.config.example.json cursor-cc.config.json
   ```

3. **ワークフローファイルを作成**（初回のみ）
   ```
   /init
   ```

---

### 現在の設定（有効な値）

| 設定 | 値 | 説明 |
|------|-----|------|
| safety.mode | dry-run | 変更を実行しない（デフォルト） |
| git.allow_auto_push | false | 自動pushしない（デフォルト） |
| ci.enable_auto_fix | false | CI自動修正しない（デフォルト） |

---

**診断完了** - 問題がある場合は上記の推奨アクションを実行してください。
```

---

## エラー時の出力

```markdown
## 🚨 環境診断: 問題あり

以下の問題が検出されました：

### 重大な問題（修正必須）

1. **git が見つかりません**
   ```bash
   # インストール方法
   # macOS: brew install git
   # Ubuntu: sudo apt install git
   # Windows: https://git-scm.com/download/win
   ```

2. **node が見つかりません**
   ```bash
   # 推奨: nvm を使用
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
   nvm install --lts
   ```

### 警告（推奨）

1. **cursor-cc.config.json の JSON 形式が無効です**
   - 修正方法: JSON バリデーターで確認してください
   - オンラインツール: https://jsonlint.com/

---

**プラグインを使用する前に、重大な問題を修正してください。**
```

---

## VibeCoder 向け使い方

| 状況 | 言い方 |
|------|--------|
| 初めて使う | 「環境をチェックして」 |
| エラーが出る | 「何が足りない？」 |
| 設定を確認したい | 「今の設定を見せて」 |

---

## 注意事項

- **非破壊的**: このコマンドは何も変更しません（読み取り専用）
- **診断のみ**: 問題を検出するだけで、自動修正はしません
- **推奨事項**: 解決方法を提示しますが、実行はユーザーの判断
