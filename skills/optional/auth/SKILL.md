---
name: ccp-auth
description: "認証機能の実装（Clerk / Supabase Auth 等）。ログイン機能を追加したい場合に使用します。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: optional
    tags: [auth, authentication, clerk, supabase, login]
    alwaysApply: false
---

# Auth Skill

Clerk または Supabase Auth を使用した認証機能を実装するスキル。

---

## トリガーフレーズ

- 「ログイン機能を付けて」
- 「認証を追加して」
- 「Clerkで認証を実装して」
- 「Supabase Authを設定して」
- 「Googleログインを追加して」

---

## 機能

- サインアップ/ログイン
- ソーシャルログイン（Google, GitHub）
- メール認証
- パスワードリセット
- ユーザープロフィール管理

---

## 実行フロー

1. プロジェクト構成を確認
2. Clerk または Supabase Auth を選択
3. 必要なパッケージをインストール
4. 認証設定ファイルを生成
5. ログイン/サインアップUIを作成
6. ミドルウェア/保護ルートを設定
