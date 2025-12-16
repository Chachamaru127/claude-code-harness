---
name: deploy
description: >
  Sets up deployment, analytics, and health monitoring for projects.
  Use when user mentions デプロイ, deploy, Vercel, Netlify, 公開, アナリティクス, analytics, GA, Google Analytics, 環境診断, health check.
  Triggers: デプロイ, deploy, Vercel, Netlify, 公開, アナリティクス, GA, 環境診断.
  Do not use for authentication or payments - use auth skill instead.
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: deploy
    tags: [deploy, vercel, netlify, analytics, health-check]
    alwaysApply: false
---

# Deploy Skills

デプロイとモニタリングの設定を担当するスキル群です。

## 含まれる小スキル

| スキル | 用途 |
|--------|------|
| deploy-setup | Vercel/Netlify デプロイ設定 |
| analytics | GA/Vercel Analytics 設定 |
| health-check | 環境診断 |

## ルーティング

- デプロイ設定: deploy-setup/doc.md
- アナリティクス: analytics/doc.md
- 環境診断: health-check/doc.md

## 実行手順

1. ユーザーのリクエストを分類
2. 適切な小スキルの doc.md を読む
3. その内容に従って設定
