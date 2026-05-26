---
name: notebookLM
description: "Generate NotebookLM YAML and slides. Document craftsman shows skill. Use when user mentions NotebookLM, YAML, slides, or presentations. Do NOT load for: implementation work, code fixes, reviews, or deployments."
description-en: "Generate NotebookLM YAML and slides. Document craftsman shows skill. Use when user mentions NotebookLM, YAML, slides, or presentations. Do NOT load for: implementation work, code fixes, reviews, or deployments."
description-ja: "NotebookLM用YAMLやスライドを生成。ドキュメント職人の腕の見せ所。Use when user mentions NotebookLM, YAML, slides, or presentations. Do NOT load for: implementation work, code fixes, reviews, or deployments."
allowed-tools: ["Read", "Write", "Edit"]
disable-model-invocation: true
user-invocable: false
argument-hint: "[yaml|slides]"
---

# NotebookLM Skill

ドキュメント生成を担当するスキル群です。

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **NotebookLM YAML** | See [references/notebooklm-yaml.md](${CLAUDE_SKILL_DIR}/references/notebooklm-yaml.md) |
| **スライド YAML** | See [references/notebooklm-slides.md](${CLAUDE_SKILL_DIR}/references/notebooklm-slides.md) |

## 実行手順

1. ユーザーのリクエストを分類
2. 上記の「機能詳細」から適切な参照ファイルを読む
3. その内容に従って生成

---

## 🔧 PDF ページ範囲読み取り（Claude Code 2.1.49+）

大型 PDF を効率的に扱うための機能です。

### ページ範囲指定で読み取り

```javascript
// ページ範囲指定で読み取り
Read({ file_path: "docs/spec.pdf", pages: "1-10" })

// 目次だけ確認
Read({ file_path: "docs/manual.pdf", pages: "1-3" })

// 特定のセクションのみ
Read({ file_path: "docs/api-reference.pdf", pages: "25-45" })
```

### ユースケース別の推奨アプローチ

| ケース | 推奨読み取り方法 | 理由 |
|--------|----------------|------|
| **100ページ超のPDF** | 目次(1-3) → 関連章のみ | トークン消費を最小化 |
| **仕様書レビュー** | セクション単位で範囲指定 | 必要な部分のみ精読 |
| **APIドキュメント** | エンドポイント一覧(目次)から開始 | 全体構造を把握してから詳細へ |
| **学術論文** | Abstract + 結論 → 本文 | 要点を先に把握 |
| **技術マニュアル** | 目次 + トラブルシューティング章 | 実用的な部分を優先 |

### NotebookLM YAML 生成時の活用例

```markdown
大型PDF（300ページの技術仕様書）からYAMLを生成する場合：

1. **目次を読む**（1-5ページ）
   Read({ file_path: "spec.pdf", pages: "1-5" })
   → 章立てを把握

2. **各章の冒頭を読む**（各章の最初の2ページ）
   Read({ file_path: "spec.pdf", pages: "10-11" })  // 第1章
   Read({ file_path: "spec.pdf", pages: "45-46" })  // 第2章
   → 各章の概要を把握

3. **重要セクションを精読**
   Read({ file_path: "spec.pdf", pages: "78-95" })  // APIリファレンス
   → 詳細な内容を抽出

この方法で、300ページすべてを読むことなく効率的にYAMLを生成できます。
```

### ベストプラクティス

| 原則 | 説明 |
|------|------|
| **段階的読み込み** | 目次 → 概要 → 詳細の順に読む |
| **関連ページのみ** | タスクに必要なページだけ指定 |
| **トークン節約** | 全ページ読み込みは最終手段 |
| **構造理解優先** | 目次で全体像を把握してから詳細へ |

### 従来の方法との比較

| 方法 | トークン消費 | 処理時間 | 精度 |
|------|------------|---------|------|
| **全ページ読み込み**（300ページ） | ~150,000 | 長い | 高 |
| **ページ範囲指定**（必要な30ページ） | ~15,000 | 短い | 高 |

→ **90%のトークン削減と処理時間短縮が可能**
