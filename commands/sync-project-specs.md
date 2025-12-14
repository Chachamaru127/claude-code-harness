---
description: 仕様書/運用ドキュメント（Plans/AGENTS/Rules）をハーネス最新運用（PM↔Impl, pm:*）へ同期
---

# /sync-project-specs - 仕様書/運用ドキュメントを最新運用へ同期

このコマンドは、プロジェクト内の **仕様書/運用ドキュメント**（例: `Plans.md`, `AGENTS.md`, `.claude/rules/*`）を、
claude-code-harness の最新運用（**PM ↔ Impl**, `pm:*` マーカー、ハンドオフ2コマンド）に揃えます。

「忙しくて更新を忘れた」「途中で運用が変わった」「古いテンプレから始めた」時のリカバリ用です。

## バイブコーダー向け（こう言えばOK）

- 「**仕様書/運用ドキュメントを最新の運用に合わせて同期して**」→ このコマンド
- 「**pm:依頼中 / pm:確認済 の運用に揃えて**」→ マーカーと説明を統一します
- 「**手動変更は残して、必要な部分だけ直して**」→ 既存の文章は極力維持して差分だけ当てます

## できること（成果物）

- `Plans.md` の **マーカー凡例/状態遷移/運用説明** を PM↔Impl 前提に更新
- `AGENTS.md` の **役割分担** を PM（Cursor/PM Claude）↔ Impl（Claude Code）に更新
- `.claude/rules/workflow.md` / `.claude/rules/plans-management.md` の **運用ルール** を更新
- `cursor:*` マーカーは **互換として同義扱い**の説明を残す

## 同期対象（存在するものだけ）

- `Plans.md`
- `AGENTS.md`
- `CLAUDE.md`（運用説明がある場合のみ）
- `.claude/rules/workflow.md`
- `.claude/rules/plans-management.md`

## 同期内容（最小差分ポリシー）

1. **マーカーの正規化**
   - 正規: `pm:依頼中`, `pm:確認済`
   - 互換: `cursor:依頼中`, `cursor:確認済`（同義として扱う）
2. **状態遷移の明文化**
   - `pm:依頼中 → cc:WIP → cc:完了 → pm:確認済`
3. **ハンドオフ導線の追記**
   - PM→Impl: `/handoff-to-impl-claude`（PM Claude向け）
   - Impl→PM: `/handoff-to-pm-claude`
   - Cursor運用の場合は従来通り（`/handoff-to-claude`, `/handoff-to-cursor`）
4. **通知ファイルの説明**
   - `.claude/state/pm-notification.md`（互換: `.claude/state/cursor-notification.md`）

## 実行手順

### Step 1: 現状を収集（必須）

- 対象ファイルの存在確認と、該当セクションの抜粋を取得
- `Plans.md` のマーカー出現状況（pm/cursor/cc）を集計

### Step 2: 変更方針の宣言（必須）

ユーザーに以下を先に宣言：

- 既存の文章は原則残す（破壊的リライトはしない）
- 追加/置換は「運用に必要な最低限」に絞る
- 変更は差分で提示し、必要なら調整する

### Step 3: 同期（差分適用）

- `Plans.md`
  - マーカー凡例に `pm:*` を追加し、`cursor:*` を互換として明記
  - 状態遷移表記を PM↔Impl へ
- `AGENTS.md`
  - 役割分担を PM/Impl へ
  - Plans のマーカー表と遷移を PM↔Impl へ（互換注記あり）
- `.claude/rules/workflow.md` / `.claude/rules/plans-management.md`
  - `cursor:*` 表記を `pm:*` 正規＋互換注記へ
- `CLAUDE.md`
  - もし運用説明セクションがあるなら、PM↔Impl の導線を追記（既存を壊さない）

### Step 4: 仕上げ（必須）

- `/sync-status` で集計して、マーカーが意図通りか確認
- 必要なら `/remember` で「このプロジェクト固有の運用」を固定


