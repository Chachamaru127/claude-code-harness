---
name: ccp-feedback
description: "フィードバック収集機能の実装。ユーザーからの声を集めたい場合に使用します。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
metadata:
  skillport:
    category: optional
    tags: [feedback, form, user-feedback, bug-report]
    alwaysApply: false
---

# Feedback Skill

アプリ内フィードバックフォームを実装するスキル。

---

## トリガーフレーズ

- 「フィードバック機能を追加して」
- 「ユーザーの声を集めたい」
- 「バグ報告フォームを作って」
- 「お問い合わせフォームを追加して」

---

## 機能

- フィードバックフォーム
- バグ報告
- 機能リクエスト
- 満足度調査

---

## 実行フロー

1. プロジェクト構成を確認
2. フィードバックの種類を選択
3. フォームUIを作成
4. APIエンドポイントを作成
5. データ保存先を設定
