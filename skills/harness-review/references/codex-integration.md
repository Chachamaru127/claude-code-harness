---
name: codex-integration
description: "レビュースキルへの Codex セカンドオピニオン統合手順"
allowed-tools: ["Read", "Bash"]
---

# Codex 統合レビュー

既存のレビューフローに Codex のセカンドオピニオンを統合する手順。

---

## 🎯 概要

Codex MCP が有効な場合、Claude のレビューに加えて Codex からもレビューを取得し、結果を統合して表示します。

```
/harness-review 実行
    ↓
設定確認: review.codex.enabled
    │
    ├── false → Claude 単独レビュー（従来通り）
    │
    └── true → Codex 統合レビュー
            │
            ├── Claude レビュー（並列）
            └── Codex MCP 呼び出し（並列）
                    ↓
            結果統合 → 出力
```

---

## 実行フロー

### Step 1: 設定確認

`.claude-code-harness.config.yaml` を確認:

```yaml
review:
  codex:
    enabled: true   # これが true の場合のみ Codex 統合
    auto: false     # false の場合は確認を求める
```

### Step 2: 確認プロンプト（auto: false の場合）

```markdown
🤖 Codex セカンドオピニオン

Codex にもレビューを依頼しますか？
- Claude と Codex の両方でレビューし、結果を統合します
- 追加で数秒〜数十秒かかります

[Y] はい / [N] いいえ
```

### Step 3: 並列レビュー実行

**Claude レビュー（従来通り）**:
- 品質判定ゲート
- 変更ファイル分析
- 重点領域のレビュー

**Codex MCP 呼び出し（並列）**:
```
MCP 呼び出し: mcp__codex__*
    prompt: "{設定ファイルのプロンプト}"
    files: "{変更ファイル一覧}"
```

### Step 4: 結果統合

両方のレビュー結果を統合して表示:

```markdown
## 📊 統合レビュー結果

### Claude のレビュー

| 観点 | 指摘数 | 重要度 |
|------|--------|--------|
| セキュリティ | 1 | 高 |
| 品質 | 3 | 中 |
| パフォーマンス | 0 | - |

**主な指摘**:
1. [高] SQL インジェクションの可能性 (src/api/users.ts:45)
2. [中] 未使用の import (src/components/Form.tsx:3)
3. ...

---

### Codex のレビュー（セカンドオピニオン）

| 観点 | 指摘数 |
|------|--------|
| コードスタイル | 2 |
| 設計パターン | 1 |

**主な指摘**:
1. 関数が長すぎる（50行超）→ 分割を推奨
2. 命名規則の不統一（camelCase と snake_case の混在）
3. Strategy パターンの適用を検討

---

### 統合サマリ

| 観点 | Claude | Codex | アクション |
|------|--------|-------|-----------|
| セキュリティ | ⚠️ 1件 | - | **対応必須** |
| コードスタイル | - | 2件 | 推奨 |
| 設計 | - | 1件 | 検討 |
| 品質 | 3件 | - | 推奨 |
```

---

## フォールバック処理

### Codex MCP エラー時

```markdown
⚠️ Codex レビューがスキップされました

理由: MCP 接続エラー
詳細: Connection timeout after 30s

Claude のレビュー結果のみを表示します。
```

**対応**:
1. Claude のレビュー結果はそのまま表示
2. エラーをログに記録
3. 次回実行時の参考情報を表示

### Codex 認証切れ

```markdown
⚠️ Codex 認証が必要です

以下のコマンドで再認証してください:
\`\`\`bash
codex login
\`\`\`
```

---

## パフォーマンス考慮

### 大規模変更時

変更ファイルが多い場合（10ファイル超）:

1. **チャンク分割**: 5ファイルずつに分割して Codex に送信
2. **優先度付け**: 変更行数の多いファイルを優先
3. **タイムアウト**: 60秒でタイムアウト、部分結果を表示

### 並列実行の最適化

```
Claude レビュー ─────┐
                     ├──→ 結果統合
Codex MCP 呼び出し ─┘

最大待機時間: max(Claude, Codex) ≈ Codex 待機時間
```

---

## VibeCoder 向け

```markdown
💡 セカンドオピニオンの使い方

**言い方**:
- 「他の AI にも見てもらって」
- 「Codex にもチェックさせて」
- 「ダブルチェックして」

**結果の見方**:
- Claude と Codex で同じ指摘 → 確実に対応が必要
- 片方だけの指摘 → 内容を確認して判断
- 矛盾する指摘 → 両方の理由を確認
```

---

## 関連ドキュメント

- [codex-review/SKILL.md](../../codex-review/SKILL.md) - Codex 統合スキル
- [codex-mcp-setup.md](../../codex-review/references/codex-mcp-setup.md) - セットアップ手順
