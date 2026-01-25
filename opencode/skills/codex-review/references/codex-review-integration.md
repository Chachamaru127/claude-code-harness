---
name: codex-review-integration
description: "Codex MCP を使用したレビュー実行手順"
allowed-tools: ["Read", "Bash"]
---

# Codex レビュー実行

Codex MCP を使用してコードレビューを実行する手順。

---

## 🎯 概要

Codex MCP が設定済みの場合、以下の方法でレビューを実行できます：

1. **`/review` 経由**: 自動的に Codex 統合
2. **直接呼び出し**: MCP ツールを直接使用

---

## 実行方法

### 方法1: /review 経由（推奨）

```
ユーザー: /review
    ↓
review スキル起動
    ↓
codex.enabled 確認 → true
    ↓
Claude + Codex 並列レビュー
    ↓
結果統合
```

### 方法2: 直接呼び出し

```bash
# MCP ツールを直接呼び出し（スキル内から）
mcp__codex__* を使用

# または Codex CLI を直接実行
codex exec --json "以下のコードをレビューしてください: ..."
```

---

## レビュープロンプト

### デフォルトプロンプト

```
日本語でコードレビューを行い、問題点と改善提案を出力してください
```

### カスタマイズ例

**セキュリティ重視**:
```yaml
review:
  codex:
    prompt: |
      以下の観点でセキュリティレビューを行ってください：
      1. 入力検証の不備
      2. 認証・認可の問題
      3. インジェクション脆弱性
      4. 機密情報の露出
      日本語で回答してください。
```

**パフォーマンス重視**:
```yaml
review:
  codex:
    prompt: |
      以下の観点でパフォーマンスレビューを行ってください：
      1. N+1クエリ
      2. 不要な再レンダリング
      3. メモリリーク
      4. 非効率なアルゴリズム
      日本語で回答してください。
```

---

## レビュー結果の形式

### Codex からの出力例

```json
{
  "review": {
    "summary": "3件の改善提案があります",
    "issues": [
      {
        "file": "src/api/users.ts",
        "line": 45,
        "severity": "high",
        "message": "SQL インジェクションの可能性"
      },
      {
        "file": "src/components/Form.tsx",
        "line": 12,
        "severity": "medium",
        "message": "useEffect の依存配列が不完全"
      }
    ],
    "suggestions": [
      "関数を分割して可読性を向上",
      "型定義を厳密化"
    ]
  }
}
```

### 統合フォーマット

```markdown
## 🤖 Codex レビュー結果

**サマリ**: 3件の改善提案

### 問題点

| ファイル | 行 | 重要度 | 内容 |
|---------|-----|--------|------|
| src/api/users.ts | 45 | 高 | SQL インジェクションの可能性 |
| src/components/Form.tsx | 12 | 中 | useEffect の依存配列が不完全 |

### 改善提案

1. 関数を分割して可読性を向上
2. 型定義を厳密化
```

---

## エラーハンドリング

### タイムアウト

```markdown
⚠️ Codex レビューがタイムアウトしました（60秒）

原因として考えられること:
- ファイルサイズが大きい
- Codex API が混雑している
- ネットワーク遅延

対応:
- 変更ファイルを絞り込んで再試行
- 時間を置いて再実行
```

### API エラー

```markdown
⚠️ Codex API エラー

エラーコード: 429 (Rate Limited)

対応:
- 少し時間を置いて再試行してください
- API 使用量を確認してください
```

---

## ベストプラクティス

### 効果的なレビューのために

1. **対象を絞る**: 大量のファイルより重要なファイルに集中
2. **観点を明確に**: プロンプトでレビュー観点を指定
3. **結果を比較**: Claude と Codex の指摘を比較して優先度判断

### 避けるべきこと

1. **全ファイル一括**: 大規模プロジェクトで全ファイルは非効率
2. **プロンプトなし**: デフォルトプロンプトは汎用的すぎる場合あり
3. **結果の盲信**: AI の指摘は参考情報、最終判断は人間

---

## 関連ドキュメント

- [codex-mcp-setup.md](./codex-mcp-setup.md) - セットアップ手順
- [review/SKILL.md](../../review/SKILL.md) - レビュースキル
- [review/references/codex-integration.md](../../review/references/codex-integration.md) - レビューへの統合
