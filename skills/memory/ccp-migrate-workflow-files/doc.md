---
name: ccp-migrate-workflow-files
description: "既存プロジェクトのAGENTS.md/CLAUDE.md/Plans.mdを、既存内容を精査して対話で引き継ぎ項目を確定しつつ、新フォーマットへ移行（バックアップ付き・Plansはタスク保持マージ）。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: core
    tags: [migrate, workflow, merge, preserve, agents, claude, plans]
    alwaysApply: false
---

# Migrate Workflow Files (Interactive Merge)

## 目的

既存プロジェクトで運用中の以下を、**既存内容を尊重しつつ新フォーマットへアップデート**します。

- `AGENTS.md`
- `CLAUDE.md`
- `Plans.md`

ポイント:

- **対話形式で引き継ぎ情報を確定**（勝手に捨てない / 勝手に上書きしない）
- 変更前に **必ずバックアップ** を残す
- `Plans.md` は `ccp-merge-plans` の方針で **タスクを保持しつつ構造を更新**

---

## 前提（重要）

このスキルは「初回適用時の安全」と「意図した動作（新フォーマット）」の両立のため、
**ユーザー合意→バックアップ→生成→差分確認**の順で進めます。

---

## 入力（このスキル内で自動検出してOK）

- `project_name`: `basename $(pwd)` で推定
- `date`: `YYYY-MM-DD`
- 既存ファイルの有無:
  - `AGENTS.md`
  - `CLAUDE.md`
  - `Plans.md`
- 新フォーマットの参照テンプレ:
  - `templates/AGENTS.md.template`
  - `templates/CLAUDE.md.template`
  - `templates/Plans.md.template`

---

## 実行フロー

### Step 0: 検出と合意取り（必須）

1. `Read` で既存 `AGENTS.md` / `CLAUDE.md` / `Plans.md` の存在を確認。
2. 存在する場合はユーザーへ確認:
   - **移行（新フォーマットへアップデート）してよいか**
   - 重要: 移行は **内容の再整理を含む**（= 多少の配置替えや言い回し変更が起こりうる）

ユーザーが NO の場合:

- このスキルは中止（何も書き換えない）
- 代わりに「`.claude/settings.json` の安全マージだけ」等の安全作業を提案

### Step 1: 既存内容の精査（要約）

各ファイルを `Read` し、以下を抽出して短く要約して提示する:

- **AGENTS.md**: 役割分担、ハンドオフ手順、禁止事項、環境/前提
- **CLAUDE.md**: 重要な制約（禁止事項/権限/ブランチ運用）、テスト手順、コミット規約、運用ルール
- **Plans.md**: タスク構造、マーカー運用、現在のWIP/依頼中タスク

### Step 2: 引き継ぎ項目の確定（対話）

要約をもとに、ユーザーに **保持/調整**したい項目を質問する（最大5〜10問で十分）:

- 絶対に残すべき制約（例: 本番デプロイ禁止、特定ディレクトリ禁止、セキュリティ要件）
- 役割分担（Solo/2-agent）の前提
- ブランチ運用（main/staging 等）
- テスト/ビルドの代表コマンド
- Plans のマーカー運用（既存ルールがあれば整合）

### Step 3: バックアップ作成（必須）

バックアップはプロジェクト内の `.claude-code-harness/backups/` にまとめる（gitに入れたくない場合が多い）。

例:

- `.claude-code-harness/backups/2025-12-13/AGENTS.md`
- `.claude-code-harness/backups/2025-12-13/CLAUDE.md`
- `.claude-code-harness/backups/2025-12-13/Plans.md`

`Bash` で `mkdir -p` と `cp` を使ってよい。

### Step 4: 新フォーマットの生成（マージ）

#### 4-1. Plans.md（タスク保持マージ）

`ccp-merge-plans` の方針で実行:

- 既存の 🔴🟡🟢📦 タスクを保持
- マーカー凡例・最終更新情報はテンプレ側に更新
- 解析不能ならバックアップを残してテンプレ採用

#### 4-2. AGENTS.md / CLAUDE.md（テンプレ + 引き継ぎブロック）

テンプレで骨格を作り、Step 2 で確定した項目を **新フォーマットの適切な場所に再配置**する。

最低限の方針:

- 既存の“重要ルール”は削らず、**「プロジェクト固有ルール（移行）」**のセクションとして残す
- 役割分担/フローはテンプレの形式に合わせて書き直す（意味は維持）

### Step 5: 差分確認と完了

- `git diff`（またはファイル差分）で変更点を短く要約
- 重要ポイント（権限/禁止事項/タスク状態）が意図通りか最終確認
- 問題があれば即修正

---

## 成果物（完了条件）

- 既存内容を踏まえた **新フォーマット版**の `AGENTS.md` / `CLAUDE.md` / `Plans.md`
- `.claude-code-harness/backups/` にバックアップが残っている
- Plans のタスクは消えていない（保持）


