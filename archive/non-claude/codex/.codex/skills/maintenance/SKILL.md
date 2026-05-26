---
name: maintenance
description: "File cleanup and archiving. Tidies up bloated Plans.md, session-log.md, old logs, and state files. Trigger: /maintenance, cleanup, archive, organize, split session-log. Do NOT load for: implementation, review, release, new feature development."
description-en: "File cleanup and archiving. Tidies up bloated Plans.md, session-log.md, old logs, and state files. Trigger: /maintenance, cleanup, archive, organize, split session-log. Do NOT load for: implementation, review, release, new feature development."
description-ja: "ファイル整理・アーカイブ・ログ圧縮を担当。散らかった Plans.md / session-log.md / 古いログ / state ファイルを整頓する。`/maintenance`, メンテ, 整理して, アーカイブして, 古いタスク移動, session-log 分割, ログ掃除 で起動。実装・レビュー・リリース・新機能開発には使わない。"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash"]
argument-hint: "[plans|session-log|logs|state|all] [--dry-run]"
user-invocable: true
effort: low
---

# Maintenance

散らかったファイルを整頓する単一目的スキル。auto-cleanup-hook が警告を出した時、
または定期的な家事として呼び出す。

> **前提**: 破壊的操作（アーカイブ移動・行削除）の前に Plans.md / session-log.md の
> 重要情報が SSOT (decisions.md / patterns.md) に昇格済みか確認する。
> 未同期なら `/memory sync` を先に走らせる。

## Quick Reference

| サブコマンド | 対象 | 典型トリガー |
|------------|------|-------------|
| `maintenance plans` | Plans.md 完了タスクのアーカイブ移動 | 「Plans.md 整理」「古いタスクを移動」 |
| `maintenance session-log` | session-log.md の月別分割 | 「session-log 分割」「ログが長い」 |
| `maintenance logs` | `.claude/logs/` の古いファイル削除 | 「ログ掃除」「30日以上前のログ消して」 |
| `maintenance state` | `agent-trace.jsonl` / `harness-usage.json` のトリム | 「trace 肥大」「state 圧縮」 |
| `maintenance all` | 上記4つを順に実行 | 「全部整理」「総掃除」 |

`--dry-run` を付けると何をするかだけ列挙して実行しない。自由記述の指示（例:
「古いアーカイブも消して」「この session-log だけ残して」）は Step 1 で
受け付けて Step 2 以降の処理パラメータに反映する。

## 実行手順

1. **ユーザー指示のパース**: サブコマンド + 自由記述（除外対象、保存先、日数閾値）を抽出
2. **SSOT 同期チェック**: `.claude/state/.ssot-synced-this-session` が無ければ
   `/memory sync` を促す（Plans.md を触る場合のみ必須）
3. **参照ファイルを開く**: `${CLAUDE_SKILL_DIR}/references/cleanup.md` を読み対応セクションを実行
4. **Before/After を報告**: 行数と削除件数を表示して完了

## サブコマンド詳細

対象ごとの実行手順・閾値・アーカイブ先は [cleanup.md](./references/cleanup.md) を参照。

## auto-cleanup-hook との連携

PostToolUse hook (`scripts/auto-cleanup-hook.sh` / Go 版 `auto_cleanup_hook.go`) は
Plans.md・session-log.md・CLAUDE.md の行数超過を検知すると
`/maintenance で古いタスクをアーカイブすることを推奨します` と feedback を返す。
この警告を見たら該当サブコマンドを実行する。

## 注意事項

- **進行中タスクは動かさない**: `cc:WIP`, `pm:依頼中`, `cursor:依頼中` はアーカイブ対象外
- **アーカイブ先ディレクトリは固定**: `.claude/memory/archive/` — 別の場所に移すときは
  ユーザーに確認する
- **バックアップ**: 200 行超のファイルを編集する前に `cp <file> <file>.bak.$(date +%s)` で
  ローカルバックアップを取る
- **CLAUDE.md は警告のみ**: 自動編集しない。分割提案だけ出す

## 関連スキル

- `memory` — Plans.md 整理前の SSOT 昇格（decisions.md / patterns.md 更新）
- `harness-setup` — セットアップ直後の定期メンテは `harness-setup` 経由でも呼べる
- `session-init` — セッション開始時のメンテ推奨通知を制御
