---
name: generate-claude-settings
description: "Claude Code の `.claude/settings.json` を安全ポリシー込みで作成/更新する（既存設定は非破壊マージ）。/init や /setup-cursor から呼び出して、権限ガードをチーム運用できる形に整備する。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
---

# Generate Claude Settings (Security + Merge)

## 目的

プロジェクトの `.claude/settings.json` を作成または更新し、以下を満たす状態にします。

- **既存設定は保持**（`hooks` / `env` / `model` / `enabledPlugins` 等を消さない）
- `permissions.allow|ask|deny` は **配列マージ + 重複排除**
- **bypassPermissions を前提とした運用**（危険操作のみ deny/ask で制御）
- 既存ファイルが壊れている場合は **バックアップを残して再生成**

## ⚠️ 重要: パーミッション構文の厳守

**このスキルを実行する際は、必ず正しいパーミッション構文を使用すること。**

プレフィックスマッチングには `:*` を使用（`*` 単独や ` *` は不可）：

- ✅ 正しい: `"Bash(npm run:*)"`, `"Bash(git status:*)"`
- ❌ 間違い: `"Bash(npm run *)"`, `"Bash(git status*)"`, `"Bash(npm run :*)"`

詳細は [Step 4](#step-4-新規生成既存なし退避後) の「パーミッション構文の注意点」を参照。

## bypassPermissions 前提の運用ポリシー

**重要**: Edit / Write を `permissions.ask` に入れると毎回確認が出て生産性が落ちます。
代わりに、bypassPermissions を有効にして危険操作のみを制御する方針を推奨します。

- `permissions.deny`: 機密ファイル読み取り（.env, secrets, SSH鍵）、危険なDB操作
- `permissions.ask`: ファイル削除、git push/reset/rebase/merge
- `permissions.allow`: MCP サーバーのワイルドカード許可（下記参照）
- **Edit / Write は ask に入れない**（確認が毎回出るのを避ける）

### MCP サーバーのワイルドカード許可

MCP サーバーのツールを一括許可するには `mcp__<server>__*` パターンを使用します。

```json
{
  "permissions": {
    "allow": [
      "mcp__supabase__*",
      "mcp__context7__*",
      "mcp__serena__*"
    ]
  }
}
```

| パターン | 許可される操作 |
|---------|---------------|
| `mcp__supabase__*` | Supabase MCP の全ツール（query, apply_migration 等） |
| `mcp__context7__*` | Context7 ドキュメント検索ツール |
| `mcp__serena__*` | Serena LSP 連携ツール |
| `mcp__playwright__*` | Playwright ブラウザ操作ツール |

### LSP 機能の活用

Claude Code の LSP 機能を活用するには、**公式LSPプラグイン（マーケットプレイス）** をインストールします。

```bash
# 例: TypeScript/JavaScript 用
claude plugin install typescript-lsp

# 例: Python 用
claude plugin install pyright-lsp

# 例: Rust 用
claude plugin install rust-analyzer-lsp
```

**LSP で利用可能な機能:**
- 定義ジャンプ (go-to-definition)
- 参照検索 (find-references)
- シンボルリネーム (rename)
- 診断情報 (diagnostics)

詳細: [docs/LSP_INTEGRATION.md](../../../docs/LSP_INTEGRATION.md) または `/lsp-setup` コマンドを実行してください。

**注意**: プロジェクトで使用する MCP サーバーに合わせて設定してください。

初回 init 後は、以下どちらかで bypassPermissions を有効化する導線を案内します：

- **推奨（プロジェクト限定・未コミット）**: `.claude/settings.local.json` に `permissions.defaultMode: "bypassPermissions"` を設定
- **一時的（セッション限定）**: `claude --dangerously-skip-permissions`

根拠（公式）: `settings.json` と `permissions`（ask/deny/disableBypassPermissionsMode）
https://code.claude.com/docs/ja/settings

---

## 対象ファイル

- 生成/更新先: `.claude/settings.json`
- ポリシーテンプレ: `templates/claude/settings.security.json.template`

---

## 実行手順（安全・非破壊）

### Step 0: 前提チェック

以下を確認します。

- `templates/claude/settings.security.json.template` が存在する
- `.claude/` がなければ作成（ディレクトリのみ）

### Step 1: 既存設定の有無を確認

- `.claude/settings.json` が **ない** → Step 4 でテンプレから生成
- `.claude/settings.json` が **ある** → Step 2 でパースできるか確認

### Step 2: JSONパース可否の判定

優先順で判定します。

1. `jq` がある場合: `jq empty .claude/settings.json`
2. `python3` がある場合: `python3 -m json.tool .claude/settings.json`

パースに失敗したら:

- `.claude/settings.json.bak`（またはタイムスタンプ付き）に退避
- Step 4 でテンプレから再生成

### Step 3: 既存設定とポリシーをマージ

**重要**: `/harness-update` から呼び出される場合、Phase 1.5 で破壊的変更（パーミッション構文修正、非推奨設定削除）が既に適用されています。

#### マージ方針

- **top-level**: 既存を優先しつつ、ポリシー側の `permissions` を統合
- `permissions.allow|ask|deny`: **ユニーク化して結合**（既存→ポリシーの順）
- `permissions.disableBypassPermissionsMode`: **設定しない**（bypassPermissions を許可）
  - **注意**: 既存設定にこのフィールドがある場合、削除すること（`/harness-update` では Phase 1.5 で削除済み）

#### 実装（推奨コマンド）

`jq` がある場合:

1. 既存とポリシーを読み込み
2. `allow/ask/deny` を配列として結合 → `unique`（順序は多少変わってOK）
3. `.claude/settings.json.tmp` に書き出し → 置換

`jq` がない場合（python3）:

1. `json.load` で既存/ポリシーを読み込み
2. `permissions` を辞書としてマージ
3. `allow/ask/deny` は list を `dict.fromkeys` 等で重複排除（順序維持）
4. `indent=2, sort_keys=false` で出力

**注意**: 既存の `hooks` は消さないこと。`permissions` 以外は原則、既存を尊重する。

### Step 4: 新規生成（既存なし・退避後）

- `templates/claude/settings.security.json.template` を `.claude/settings.json` にコピーして作成
- 必要なら、将来の拡張（hooks追加等）は「既存マージ」ルート（Step 3）で行う

**⚠️ 重要: パーミッション構文の注意点**

プレフィックスマッチングには必ず `:*` を使用すること（`*` 単独は不可）：

**正しい構文:**
```json
{
  "permissions": {
    "allow": [
      "Bash(npm run:*)",
      "Bash(pnpm:*)",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git branch:*)",
      "Bash(ls:*)",
      "Bash(cat:*)"
    ],
    "ask": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git checkout:*)",
      "Bash(rm:*)",
      "Bash(mv:*)"
    ],
    "deny": [
      "Bash(git push --force:*)",
      "Bash(git reset --hard:*)",
      "Bash(:*credentials:*)",
      "Bash(:*password:*)",
      "Bash(:*secret:*)"
    ]
  }
}
```

**間違った構文（絶対に使用しないこと）:**
```json
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",        // ❌ 間違い
      "Bash(pnpm *)",           // ❌ 間違い
      "Bash(git diff*)",        // ❌ 間違い
      "Bash(*credentials*)"     // ❌ 間違い
    ]
  }
}
```

**構文ルール:**
- プレフィックスマッチ: `Bash(command:*)` - コマンド以降の全てにマッチ
- 部分文字列マッチ: `Bash(:*substring:*)` - 任意の位置の文字列にマッチ
- スペースは含まない: `Bash(npm run:*)` は正しい、`Bash(npm run :*)` は間違い

---

## 期待する出力

- `.claude/settings.json` が存在し、JSONとしてパース可能
- `permissions.deny` に `.env` / `secrets` / SSH鍵系の `Read(...)` が含まれる
- `permissions.ask` に `Bash(rm:*)` / `Bash(git push:*)` 等が含まれる（**Edit / Write は含まない**）
- `permissions.disableBypassPermissionsMode` が **設定されていない**（bypassPermissions 許可）

---

## 失敗時の扱い

- パース不可の場合でも **必ずバックアップ**を残す
- 生成後に `jq empty` または `python -m json.tool` で妥当性を確認

---

## bypassPermissions 有効化の導線

### Step 5: ユーザーへの案内（生成後に表示）

設定ファイル生成後、以下のメッセージを表示してユーザーに案内します:

```
✅ .claude/settings.json を生成しました

📌 推奨（プロジェクト限定・未コミット）: `.claude/settings.local.json` で bypassPermissions を既定化できます。
   cp templates/claude/settings.local.json.template .claude/settings.local.json

一時的に試すだけなら:
   claude --dangerously-skip-permissions

⚠️ 注意: deny/ask に設定した危険操作（rm、git push等）は引き続き制御されます。
```

### オプション: settings.local.json の配置

Claude Code の設定優先順位は `.claude/settings.local.json`（ローカル）→ `.claude/settings.json`（共有）→ `~/.claude/settings.json`（ユーザー）です。
よって、bypassPermissions を「このプロジェクトだけ」有効にしたい場合は `.claude/settings.local.json` を推奨します。

```bash
# テンプレートをコピー
cp templates/claude/settings.local.json.template .claude/settings.local.json

# 必要に応じてカスタマイズ
# settings.local.json は settings.json より優先されます
```
