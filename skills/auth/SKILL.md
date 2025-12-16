---
name: auth
description: >
  Implements authentication and payment features using Clerk, Supabase Auth, or Stripe.
  Use when user mentions ログイン, 認証, auth, authentication, Clerk, Supabase Auth, 決済, payment, Stripe, 課金, subscription.
  Triggers: ログイン, 認証, auth, Clerk, Supabase, 決済, Stripe, 課金, サブスクリプション.
  Do not use for deployment or analytics - use deploy skill instead.
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: auth
    tags: [auth, authentication, payments, clerk, supabase, stripe]
    alwaysApply: false
---

# Auth Skills

認証と決済機能の実装を担当するスキル群です。

## 含まれる小スキル

| スキル | 用途 |
|--------|------|
| auth-impl | Clerk/Supabase Auth による認証実装 |
| payments | Stripe による決済実装 |

## ルーティング

- 認証機能: auth-impl/doc.md
- 決済機能: payments/doc.md

## 実行手順

1. ユーザーのリクエストを分類(認証 or 決済)
2. 適切な小スキルの doc.md を読む
3. その内容に従って実装
