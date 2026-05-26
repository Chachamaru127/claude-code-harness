---
name: deploy
description: "Deploy to Vercel/Netlify. One-way ticket to production arranged. Use when user mentions deployment, Vercel, Netlify, analytics, or health checks. Do NOT load for: implementation work, local development, reviews, or setup."
description-en: "Deploy to Vercel/Netlify. One-way ticket to production arranged. Use when user mentions deployment, Vercel, Netlify, analytics, or health checks. Do NOT load for: implementation work, local development, reviews, or setup."
description-ja: "VercelやNetlifyへいざ出陣。本番環境への片道切符を手配します。Use when user mentions deployment, Vercel, Netlify, analytics, or health checks. Do NOT load for: implementation work, local development, reviews, or setup."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Monitor"]
disable-model-invocation: true
user-invocable: false
argument-hint: "[vercel|netlify|health]"
context: fork
---

# Deploy Skills

デプロイとモニタリングの設定を担当するスキル群です。

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **デプロイ設定** | See [references/deployment-setup.md](${CLAUDE_SKILL_DIR}/references/deployment-setup.md) |
| **アナリティクス** | See [references/analytics.md](${CLAUDE_SKILL_DIR}/references/analytics.md) |
| **環境診断** | See [references/health-checking.md](${CLAUDE_SKILL_DIR}/references/health-checking.md) |

## 実行手順

1. ユーザーのリクエストを分類
2. 上記の「機能詳細」から適切な参照ファイルを読む
3. その内容に従って設定
