---
_harness_template: rules/skill-hierarchy.md
_harness_version: 2.6.1
---

# Skill の階層構造ガイドライン

## 概要

claude-code-harness のスキルは **親スキル（カテゴリ）** と **子スキル（具体的な機能）** の2層構造になっています。

```
skills/
├── impl/                      # 親スキル（SKILL.md）
│   ├── SKILL.md              # カテゴリ概要・ルーティング
│   └── work-impl-feature/    # 子スキル
│       └── doc.md            # 具体的な手順
├── harness-review/
│   ├── SKILL.md
│   ├── code-review/
│   │   └── doc.md
│   └── security-review/
│       └── doc.md
...
```

## 必須ルール

### 1. 親スキルを読んだら、子スキルも読む

Skill ツールで親スキルを起動した後、**ユーザーの意図に該当する子スキル（doc.md）も必ず Read すること**。

```
✅ 正しい流れ:
1. Skill ツールで "impl" を起動 → SKILL.md の内容を取得
2. ユーザーの意図を判断（例: 機能実装）
3. Read ツールで work-impl-feature/doc.md を読む
4. doc.md の手順に従って作業

❌ 間違い:
1. Skill ツールで "impl" を起動
2. SKILL.md だけ読んで作業開始（子スキルを無視）
```

### 2. 子スキルの選び方

| ユーザーの意図 | 起動するスキル | 読むべき子スキル |
|---------------|---------------|-----------------|
| 「機能を実装して」 | impl | work-impl-feature/doc.md |
| 「コードレビューして」 | harness-review | code-review/doc.md |
| 「セキュリティチェック」 | harness-review | security-review/doc.md |
| 「ビルドして」 | verify | build-verify/doc.md |

### 3. 複数の子スキルが該当する場合

ユーザーに確認するか、最も関連性の高いものを1つ選んで開始。

---

## なぜ重要か？

- 親 SKILL.md は「概要とルーティング」のみ
- 子 doc.md に「具体的な手順・チェックリスト・パターン集」がある
- 子スキルを読まないと、不完全な作業になる

---

## PostToolUse Hook との連携

Skill ツール使用後に自動でリマインダーが表示されます。
表示された子スキル一覧から、該当するものを Read してください。
