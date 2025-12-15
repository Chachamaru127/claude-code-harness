---
name: ccp-deploy-setup
description: "デプロイ自動化設定（Vercel/Netlify 等）。プロジェクトを公開したい場合に使用します。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: optional
    tags: [deploy, vercel, netlify, ci-cd, hosting]
    alwaysApply: false
---

# Deploy Setup Skill

Vercel/Netlifyへのデプロイを自動化するスキル。

---

## トリガーフレーズ

- 「デプロイできるようにして」
- 「Vercelに出したい」
- 「Netlifyにデプロイしたい」
- 「本番環境を設定して」

---

## 機能

- Vercel/Netlifyプロジェクトの作成ガイド
- 環境変数の設定ガイド
- GitHub Actionsによる自動デプロイ
- プレビューデプロイ（Pull Request）

---

## 実行フロー

1. プロジェクト構成を確認
2. Vercel または Netlify を選択
3. 設定ファイルを生成（vercel.json / netlify.toml）
4. 環境変数の設定をガイド
5. デプロイ検証
