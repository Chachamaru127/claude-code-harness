---
description: 2エージェントワークフローの基本ルール
alwaysApply: true
---

# 2-Agent Workflow Rules

このプロジェクトは **PM ↔ Impl** の2ロールワークフローを採用しています。
PMは **Cursor** でも **PM Claude** でもOKです（ソロ運用では PM Claude を推奨）。

## 役割分担

| エージェント | 責務 |
|-------------|------|
| **PM（Cursor / PM Claude）** | 計画・レビュー・意思決定・（必要なら）本番デプロイ |
| **Impl（Claude Code / Impl Claude）** | 実装・テスト・コミット・（必要なら）staging |

## タスク管理

- タスクは `Plans.md` で一元管理
- マーカーでステータスを追跡:
  - `pm:依頼中` → PM から依頼（互換: `cursor:依頼中`）
  - `cc:WIP` → Claude Code 作業中
  - `cc:完了` → Claude Code 完了
  - `pm:確認済` → PM レビュー完了（互換: `cursor:確認済`）

## ハンドオフプロトコル

### PM → Impl
1. Plans.md にタスクを記載し `pm:依頼中` マーカー（互換: `cursor:依頼中`）
2. **PM Claude の場合**: `/handoff-to-impl-claude` で依頼文を生成
3. **Cursor の場合**: `/handoff-to-claude`（Cursor側コマンド）で依頼文を生成
4. Impl Claude（Claude Code）へ貼り付け

### Impl → PM
1. 作業完了後 `cc:完了` マーカーを付与
2. **PM Claude の場合**: `/handoff-to-pm-claude` で完了報告を生成
3. **Cursor の場合**: `/handoff-to-cursor` で完了報告を生成
4. PMへ貼り付けてレビュー依頼（レビュー後に `pm:確認済`）

## 禁止事項

- ❌ 開発用ファイルの外部公開（CLAUDE.md, AGENTS.md, Plans.md）
- ❌ 明示的な依頼なしの大規模リファクタリング
- ❌ テストなしの機能追加
- ❌ 本番環境への直接デプロイ（PM の承認必須）
