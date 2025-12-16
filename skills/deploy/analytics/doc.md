---
name: ccp-analytics
description: "Analytics統合（GA/Vercel Analytics 等）。アクセス解析を導入したい場合に使用します。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: optional
    tags: [analytics, google-analytics, vercel-analytics, tracking]
    alwaysApply: false
---

# Analytics Skill

Google Analytics または Vercel Analytics を統合するスキル。

---

## トリガーフレーズ

- 「アクセス解析を入れて」
- 「Google Analyticsを設定して」
- 「Vercel Analyticsを追加して」
- 「ページビューを追跡したい」

---

## 機能

- ページビュー追跡
- イベント追跡
- コンバージョン追跡
- ユーザー行動分析

---

## 実行フロー

1. プロジェクト構成を確認（Next.js / React / etc）
2. Google Analytics または Vercel Analytics を選択
3. 必要なパッケージをインストール
4. 設定ファイルを生成
5. イベント追跡関数を作成
