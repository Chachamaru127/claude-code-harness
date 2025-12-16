---
name: ccp-init-memory-ssot
description: "プロジェクトのSSOTメモリ（decisions/patterns）と任意のsession-logを初期化する。初回セットアップ時や、.claude/memory が未整備のプロジェクトで使用します。"
allowed-tools: ["Read", "Write"]
metadata:
  skillport:
    category: core
    tags: [memory, ssot, decisions, patterns, setup]
    alwaysApply: false
---

# Init Memory SSOT

`.claude/memory/` 配下の **SSOT** を初期化します。

- `decisions.md`（重要な意思決定のSSOT）
- `patterns.md`（再利用できる解法のSSOT）
- `session-log.md`（セッションログ。ローカル運用推奨）

詳細方針: `docs/MEMORY_POLICY.md`

---

## 実行手順

### Step 1: 既存ファイルの確認

- `.claude/memory/decisions.md`
- `.claude/memory/patterns.md`
- `.claude/memory/session-log.md`

存在するものは**上書きしない**。

### Step 2: テンプレートから初期化（存在しない場合のみ）

テンプレート:

- `templates/memory/decisions.md.template`
- `templates/memory/patterns.md.template`
- `templates/memory/session-log.md.template`

`{{DATE}}` は当日（例: `2025-12-13`）で置換して生成する。

### Step 3: 完了報告

- 作成したファイル一覧
- Git方針（`decisions/patterns`は共有推奨、`session-log/.claude/state`はローカル推奨）


