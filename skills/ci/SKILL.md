---
name: ci
description: "Diagnoses and fixes CI/CD pipeline failures. Use when user mentions 'CI', 'GitHub Actions', 'GitLab CI', 'ビルドエラー', 'テスト失敗', 'パイプライン', 'CIが落ちた', or asks to analyze build/test failures."
allowed-tools: ["Read", "Grep", "Bash"]
metadata:
  skillport:
    category: ci
    tags: [ci-cd, github-actions, pipeline, debugging]
    alwaysApply: false
---

# CI/CD Skills

CI/CD パイプラインに関する問題を解決するスキル群です。

---

## 発動条件

- 「CIが落ちた」「GitHub Actionsが失敗」
- 「ビルドエラー」「テストが通らない」
- 「パイプラインを直して」

---

## 含まれる小スキル

| スキル | 用途 | トリガー |
|--------|------|----------|
| ccp-ci-analyze-failures | 失敗原因の分析 | 「ログを見て」「原因を調べて」 |
| ccp-ci-fix-failing-tests | テスト修正の提案 | 「テストを直して」「修正案を出して」 |

---

## ルーティングロジック

ユーザーの意図に応じて適切な小スキルを選択:

### 分析・調査が必要な場合

→ `ccp-ci-analyze-failures/doc.md` を参照

例:
- 「CIが落ちた原因を教えて」
- 「GitHub Actionsのログを見て」
- 「なんでビルドが失敗したの？」

### 修正・対応が必要な場合

→ `ccp-ci-fix-failing-tests/doc.md` を参照

例:
- 「テストを直して」
- 「エラーを修正して」
- 「パイプラインを通るようにして」

---

## 実行手順

1. ユーザーの意図を分類（分析 or 修正）
2. 複雑度を判定（下記参照）
3. 適切な小スキルの doc.md を読む、または ci-cd-fixer サブエージェント起動
4. 結果を確認し、必要に応じて再実行

## サブエージェント連携

以下の条件を満たす場合、Task tool で ci-cd-fixer を起動:

- 修正 → 再実行 → 失敗のループが **2回以上** 発生
- または、エラーが複数ファイルにまたがる複雑なケース

**起動パターン:**

```
Task tool:
  subagent_type="claude-code-harness:ci-cd-fixer"
  prompt="CI失敗を診断・修正してください。エラーログ: {error_log}"
```

ci-cd-fixer は安全第一で動作（デフォルト dry-run モード）。
詳細は `agents/ci-cd-fixer.md` を参照。
