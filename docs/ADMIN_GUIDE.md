# Admin Guide - cursor-cc-plugins

このドキュメントは、チームや組織に cursor-cc-plugins を導入する管理者向けのガイドです。

---

## 目次

1. [セキュリティと権限](#1-セキュリティと権限)
2. [設定ファイルの管理](#2-設定ファイルの管理)
3. [推奨構成](#3-推奨構成)
4. [機能ごとのリスク評価](#4-機能ごとのリスク評価)
5. [トラブルシューティング](#5-トラブルシューティング)

---

## 1. セキュリティと権限

### このプラグインが要求する権限

| 権限 | 使用機能 | デフォルト | 制御方法 |
|------|---------|-----------|---------|
| ファイル読み取り | 全機能 | ✅ 有効 | - |
| ファイル書き込み | /init, /work, error-recovery | ✅ 有効 | paths.allowed_modify |
| git commit | ci-cd-fixer, /work | ❌ 無効 | git.allow_auto_commit |
| git push | ci-cd-fixer | ❌ 無効 | git.allow_auto_push |
| npm install | error-recovery | ✅ 有効 | destructive_commands.allow_npm_install |
| rm -rf | ci-cd-fixer | ❌ 無効 | destructive_commands.allow_rm_rf |
| gh CLI | ci-cd-fixer | 必須 | ci.require_gh_cli |
| Web検索 | /init | ✅ 有効 | scaffolding.allow_web_search |

### 破壊的コマンドの一覧

以下のコマンドは、明示的に許可しない限り実行されません：

```bash
# ❌ デフォルトで無効
rm -rf node_modules
rm -rf package-lock.json
git push
git commit（自動）

# ✅ デフォルトで有効（制限付き）
npm install（確認あり）
npx eslint --fix（paths.allowed_modify 内のみ）
```

---

## 2. 設定ファイルの管理

### 設定ファイルの場所

```
プロジェクトルート/
├── cursor-cc.config.json    # プロジェクト固有の設定
└── ...
```

### 推奨: チーム共通設定

`cursor-cc.config.json` をリポジトリにコミットして、チーム全員で同じ設定を使用：

```json
{
  "$schema": "./cursor-cc.config.schema.json",
  "version": "1.0",

  "safety": {
    "mode": "apply-local",
    "require_confirmation": true,
    "max_auto_retries": 3
  },

  "git": {
    "allow_auto_commit": false,
    "allow_auto_push": false,
    "protected_branches": ["main", "master", "production", "release/*"]
  },

  "paths": {
    "allowed_modify": ["src/", "app/", "components/", "lib/", "test/"],
    "protected": [".github/", ".gitlab/", "infra/", "k8s/", ".env", ".env.*"]
  },

  "ci": {
    "provider": "github_actions",
    "enable_auto_fix": false
  },

  "scaffolding": {
    "tech_choice_mode": "fixed",
    "base_stack": "next-supabase"
  }
}
```

### 設定の上書き優先順位

1. **プロジェクトの cursor-cc.config.json**（最優先）
2. **ユーザーのグローバル設定**（あれば）
3. **デフォルト値**（最も安全）

---

## 3. 推奨構成

### 個人開発向け（最小制限）

```json
{
  "safety": { "mode": "apply-local" },
  "git": { "allow_auto_commit": true },
  "ci": { "enable_auto_fix": true }
}
```

### チーム開発向け（バランス型）

```json
{
  "safety": {
    "mode": "apply-local",
    "require_confirmation": true
  },
  "git": {
    "allow_auto_commit": false,
    "protected_branches": ["main", "develop"]
  },
  "ci": { "enable_auto_fix": false },
  "scaffolding": { "tech_choice_mode": "ask" }
}
```

### エンタープライズ向け（最大制限）

```json
{
  "safety": {
    "mode": "dry-run",
    "require_confirmation": true
  },
  "git": {
    "allow_auto_commit": false,
    "allow_auto_push": false,
    "protected_branches": ["main", "master", "release/*", "hotfix/*"]
  },
  "paths": {
    "allowed_modify": ["src/"],
    "protected": [".github/", "infra/", "k8s/", "terraform/", ".env*", "secrets/"]
  },
  "ci": { "enable_auto_fix": false },
  "destructive_commands": {
    "allow_rm_rf": false,
    "allow_npm_install": false
  },
  "scaffolding": {
    "tech_choice_mode": "fixed",
    "base_stack": "your-company-stack",
    "allow_web_search": false
  }
}
```

---

## 4. 機能ごとのリスク評価

### 低リスク（推奨）

| 機能 | 説明 | リスク |
|------|------|-------|
| /init | プロジェクト作成 | 🟢 低 |
| /plan | タスク計画 | 🟢 低 |
| /sync-status | 状態確認 | 🟢 低 |
| /health-check | 環境診断 | 🟢 低 |
| /review | コードレビュー（読み取りのみ） | 🟢 低 |

### 中リスク（確認推奨）

| 機能 | 説明 | リスク | 制御方法 |
|------|------|-------|---------|
| /work | コード変更 | 🟡 中 | paths.allowed_modify |
| error-recovery | エラー自動修正 | 🟡 中 | require_confirmation |

### 高リスク（慎重に有効化）

| 機能 | 説明 | リスク | 制御方法 |
|------|------|-------|---------|
| ci-cd-fixer (apply-local) | ローカル修正 | 🟠 高 | ci.enable_auto_fix |
| ci-cd-fixer (apply-and-push) | 自動push | 🔴 最高 | git.allow_auto_push |
| rm -rf 許可 | node_modules削除 | 🔴 最高 | destructive_commands.allow_rm_rf |

---

## 5. トラブルシューティング

### 「権限がない」エラー

```
⚠️ .github/ は保護されたパスのため、手動で対応してください
```

**原因**: 対象パスが `paths.protected` に含まれている

**対応**:
1. 意図的な保護 → 手動で変更
2. 保護を解除したい → `paths.protected` から削除

### 「gh CLI が見つかりません」

```
🛑 CI自動修正を中止します。手動で対応してください。
```

**原因**: GitHub CLI がインストールされていない

**対応**:
```bash
# macOS
brew install gh

# Windows
winget install --id GitHub.cli

# Ubuntu
sudo apt install gh
```

### 「dry-run モードです」

```
📝 dry-run モードのため、実際の変更は行いません
```

**原因**: デフォルト設定（安全側）

**対応**:
```json
{
  "safety": { "mode": "apply-local" }
}
```

### 「保護されたブランチです」

```
🛑 保護されたブランチ（main）では自動 push できません
```

**原因**: `git.protected_branches` に含まれているブランチで作業中

**対応**:
1. feature ブランチで作業する
2. または手動で push する

---

## 監査ログ

すべての操作は以下の形式でレポートされます：

```markdown
## 📊 操作レポート

**実行日時**: 2024-01-15 10:30:00
**動作モード**: apply-local
**結果**: success

### 実行されたアクション
| # | アクション | 結果 |
|---|-----------|------|
| 1 | ESLint修正 | ✅ 成功 |
| 2 | git commit | ⏭️ スキップ（無効） |

### 変更されたファイル
| ファイル | 変更内容 |
|---------|---------|
| src/index.ts | ESLint修正 |
```

この情報を使って、誰が何を実行したかを追跡できます。

---

## サポート

- [GitHub Issues](https://github.com/Chachamaru127/cursor-cc-plugins/issues)
- [設定スキーマ](../cursor-cc.config.schema.json)
- [設定例](../cursor-cc.config.example.json)
