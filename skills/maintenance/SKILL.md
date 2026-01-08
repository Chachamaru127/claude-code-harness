---
name: maintenance
description: "Cleans up and organizes project files. Use when user mentions '整理', 'cleanup', 'アーカイブ', 'archive', '肥大化', 'Plans.md', 'session-log', or asks to clean up old tasks, archive completed items, or organize files. Do NOT load for: 実装作業, レビュー, 新機能開発, デプロイ."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: maintenance
    tags: [cleanup, archive, maintenance]
    alwaysApply: false
---

# Maintenance Skills

ファイルのメンテナンス・クリーンアップを担当するスキル群です。

---

## 発動条件

- 「ファイルを整理して」
- 「アーカイブして」
- 「古いタスクを移動して」
- 「整理して」「cleanup」

---

## 含まれる小スキル

| スキル | 用途 |
|--------|------|
| auto-cleanup | Plans.md, session-log 等の自動整理 |

---

## ルーティングロジック

### ファイル整理が必要な場合

→ `auto-cleanup/doc.md` を参照

---

## 実行手順

1. ユーザーのリクエストを確認
2. `auto-cleanup/doc.md` を読む
3. その内容に従って実行
