---
name: init-requirements
description: "ユーザーの要望を短い質問で明確化し、feature_request を作成する。/plan-with-agent で user_prompt が空のときに使用。"
allowed-tools: ["Read"]
---

# Init Requirements

ユーザーの要望が曖昧または未入力の場合に、最小限の質問で要件を明確化するスキル。

---

## 入力

- **user_intent**: ユーザーの目的や背景（任意）

---

## 出力

```json
{
  "feature_request": "ユーザーの要望を1-2文で要約したもの"
}
```

---

## 実行手順

1. 目的・対象ユーザー・制約の3点を確認する  
2. 回答から `feature_request` を生成する  
3. 未回答の場合は仮の前提を置いて要約する  

---

## 質問テンプレート

- 目的: 「何を実現したいですか？」
- 対象: 「誰が使う想定ですか？」
- 制約: 「期限や技術制約はありますか？」

