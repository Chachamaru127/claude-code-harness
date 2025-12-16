---
name: ccp-generate-claude-settings
description: "Claude Code の `.claude/settings.json` を安全ポリシー込みで作成/更新する（既存設定は非破壊マージ）。/harness-init や /setup-cursor から呼び出して、権限ガードをチーム運用できる形に整備する。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: core
    tags: [settings, security, permissions, merge]
    alwaysApply: false
---

# Generate Claude Settings (Security + Merge)

## 目的

プロジェクトの `.claude/settings.json` を作成または更新し、以下を満たす状態にします。

- **既存設定は保持**（`hooks` / `env` / `model` / `enabledPlugins` 等を消さない）
- `permissions.allow|ask|deny` は **配列マージ + 重複排除**
- `permissions.disableBypassPermissionsMode` は **常に `"disable"`**（bypassPermissions を封じる）
- 既存ファイルが壊れている場合は **バックアップを残して再生成**

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

#### マージ方針

- **top-level**: 既存を優先しつつ、ポリシー側の `permissions` を統合
- `permissions.allow|ask|deny`: **ユニーク化して結合**（既存→ポリシーの順）
- `permissions.disableBypassPermissionsMode`: **必ず `"disable"` に上書き**

#### 実装（推奨コマンド）

`jq` がある場合:

1. 既存とポリシーを読み込み
2. `allow/ask/deny` を配列として結合 → `unique`（順序は多少変わってOK）
3. `disableBypassPermissionsMode` を `"disable"` で固定
4. `.claude/settings.json.tmp` に書き出し → 置換

`jq` がない場合（python3）:

1. `json.load` で既存/ポリシーを読み込み
2. `permissions` を辞書としてマージ
3. `allow/ask/deny` は list を `dict.fromkeys` 等で重複排除（順序維持）
4. `disableBypassPermissionsMode="disable"` を固定
5. `indent=2, sort_keys=false` で出力

**注意**: 既存の `hooks` は消さないこと。`permissions` 以外は原則、既存を尊重する。

### Step 4: 新規生成（既存なし・退避後）

- `templates/claude/settings.security.json.template` を `.claude/settings.json` にコピーして作成
- 必要なら、将来の拡張（hooks追加等）は「既存マージ」ルート（Step 3）で行う

---

## 期待する出力

- `.claude/settings.json` が存在し、JSONとしてパース可能
- `permissions.deny` に `.env` / `secrets` / SSH鍵系の `Read(...)` が含まれる
- `permissions.ask` に `Bash(rm:*)` / `Bash(git push:*)` 等が含まれる
- `permissions.disableBypassPermissionsMode` が `"disable"`

---

## 失敗時の扱い

- パース不可の場合でも **必ずバックアップ**を残す
- 生成後に `jq empty` または `python -m json.tool` で妥当性を確認


