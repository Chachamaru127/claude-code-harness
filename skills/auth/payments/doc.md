---
name: ccp-payments
description: "決済機能の実装（Stripe）。サブスクや買い切り決済を追加したい場合に使用します。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: optional
    tags: [payments, stripe, subscription, checkout]
    alwaysApply: false
---

# Payments Skill

Stripeを使用した決済機能を実装するスキル。

---

## トリガーフレーズ

- 「決済を付けたい」
- 「Stripeを導入して」
- 「サブスクを実装して」
- 「買い切り決済を追加して」

---

## 機能

- サブスクリプション（月額/年額）
- 一回払い
- Webhook（決済完了通知）
- 顧客ポータル（プラン変更、キャンセル）

---

## 実行フロー

1. プロジェクト構成を確認
2. サブスク or 一回払いを選択
3. Stripe SDKをインストール
4. 決済ページを作成
5. Webhookエンドポイントを設定
6. 環境変数の設定をガイド
