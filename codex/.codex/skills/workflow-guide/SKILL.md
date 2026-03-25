---
name: workflow-guide
description: "Cursor ↔ Claude Code 2-Agentワークフローのガイダンスを提供。Use when user asks about workflow, collaboration, or process. Do NOT load for: implementation work, workflow setup, or executing handoffs."
description-en: "Provides guidance on Cursor ↔ Claude Code 2-agent workflow. Use when user asks about workflow, collaboration, or process. Do NOT load for: implementation work, workflow setup, or executing handoffs."
description-ja: "Cursor ↔ Claude Code 2-Agentワークフローのガイダンスを提供。Use when user asks about workflow, collaboration, or process. Do NOT load for: implementation work, workflow setup, or executing handoffs."
allowed-tools: ["Read"]
user-invocable: false
---

# Workflow Guide Skill

Cursor ↔ Claude Code 2エージェントワークフローのガイダンスを提供するスキル。

---

## トリガーフレーズ

このスキルは以下のフレーズで起動します：

- 「ワークフローについて教えて」
- 「Cursor との連携方法は？」
- 「作業の流れを教えて」
- 「どうやって進めればいい？」
- "how does the workflow work?"
- "explain 2-agent workflow"

---

## 概要

このスキルは、Cursor（PM）と Claude Code（Worker）の役割分担と連携方法を説明します。

---

## 2エージェントワークフロー

### 役割分担

| エージェント | 役割 | 責務 |
|-------------|------|------|
| **Cursor** | PM（プロジェクトマネージャー） | タスク割り当て、レビュー、本番デプロイ判断 |
| **Claude Code** | Worker（作業者） | 実装、テスト、CI修正、staging デプロイ |

### ワークフロー図

```
┌─────────────────────────────────────────────────────────┐
│                    Cursor (PM)                          │
│  ・タスクを Plans.md に追加                              │
│  ・Claude Code に作業を依頼（/handoff-to-claude）            │
│  ・完了報告をレビュー                                    │
│  ・本番デプロイの判断                                    │
└─────────────────────┬───────────────────────────────────┘
                      │ タスク依頼
                      ▼
┌─────────────────────────────────────────────────────────┐
│                  Claude Code (Worker)                   │
│  ・/work でタスク実行（並列実行対応）                   │
│  ・実装 → テスト → コミット                             │
│  ・CI 失敗時は自動修正（3回まで）                        │
│  ・/handoff-to-cursor で完了報告                        │
└─────────────────────┬───────────────────────────────────┘
                      │ 完了報告
                      ▼
┌─────────────────────────────────────────────────────────┐
│                    Cursor (PM)                          │
│  ・変更内容を確認                                        │
│  ・staging 動作確認                                      │
│  ・本番デプロイ実行（承認後）                            │
└─────────────────────────────────────────────────────────┘
```

---

## Plans.md によるタスク管理

### マーカー一覧

| マーカー | 意味 | 設定者 |
|---------|------|--------|
| `pm:依頼中` | PM から依頼（互換: cursor:依頼中） | PM（Cursor/PM Claude） |
| `cc:TODO` | Claude Code 未着手 | どちらでも |
| `cc:WIP` | Claude Code 作業中 | Claude Code |
| `cc:完了` | Claude Code 完了 | Claude Code |
| `pm:確認済` | PM 確認完了（互換: cursor:確認済） | PM（Cursor/PM Claude） |
| `cursor:依頼中` | （互換）pm:依頼中 と同義 | Cursor |
| `cursor:確認済` | （互換）pm:確認済 と同義 | Cursor |
| `blocked` | ブロック中 | どちらでも |

### タスクの状態遷移

```
pm:依頼中 → cc:WIP → cc:完了 → pm:確認済
```

---

## 主要コマンド

### Claude Code 側

| コマンド | 用途 |
|---------|------|
| `/harness-init` | プロジェクトセットアップ |
| `/plan-with-agent` | 計画・タスク分解 |
| `/work` | タスク実行（並列実行対応） |
| `/handoff-to-cursor` | 完了報告（Cursor PMへ） |
| `/sync-status` | 状態確認 |

### スキル（会話で自動起動）

| スキル | トリガー例 |
|--------|-----------|
| `handoff-to-pm` | 「PMに完了報告」 |
| `handoff-to-impl` | 「実装役に渡して」 |

### Cursor 側（参考）

| コマンド | 用途 |
|---------|------|
| `/handoff-to-claude` | Claude Code にタスク依頼 |
| `/review-cc-work` | 完了報告のレビュー |

---

## CI/CD ルール

### Claude Code の責務範囲

- ✅ staging デプロイまで
- ✅ CI 失敗時の自動修正（3回まで）
- ❌ 本番デプロイは禁止

### 3回ルール

CI が 3回連続で失敗した場合：
1. 自動修正を中止
2. エスカレーションレポートを生成
3. Cursor に判断を委ねる

---

## よくある質問

### Q: Cursor がいない場合は？

A: 一人で作業する場合も、Plans.md でタスク管理することを推奨します。
本番デプロイは手動で慎重に行ってください。

### Q: タスクが不明確な場合は？

A: Cursor に確認を依頼するか、`/sync-status` で現状を整理してください。

### Q: CI が何度も失敗する場合は？

A: 3回以上は自動修正せず、Cursor にエスカレーションしてください。

---

## 関連ドキュメント

- AGENTS.md - 詳細な役割分担
- CLAUDE.md - Claude Code 固有の設定
- Plans.md - タスク管理ファイル
