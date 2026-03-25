---
name: x-announce
description: "Generate X (Twitter) announcement thread with images for Harness releases. Use when user mentions: X post, tweet, announce release, SNS announce. Do NOT load for: GitHub release notes, CHANGELOG editing."
description-ja: "Harness リリースの X (Twitter) 告知スレッドを画像付きで自動生成。投稿テキスト5本 + Gemini画像5枚を1発出力。"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion"]
argument-hint: "[version|latest]"
---

# X Announce — リリース告知スレッド自動生成

CHANGELOG.md から最新リリース情報を自動抽出し、X (Twitter) 投稿スレッド（テキスト5本 + 画像5枚）を1発で生成するスキル。

## Quick Reference

- "**Xで告知して**" → this skill
- "**リリースをツイートして**" → this skill
- "**SNS投稿作って**" → this skill

## 前提条件

| 要件 | 説明 |
|------|------|
| `GEMINI_API_KEY` 環境変数 | Nano Banana Pro (Gemini 3 Pro Image Preview) API キー |
| 公式ロゴ | `docs/images/claude-harness-logo-with-text.png` |
| CHANGELOG.md | 最新リリースエントリが記載済み |

## 出力先

```
out/x-posts/
├── post1.png ~ post5.png    # 投稿画像（ロゴ統合済み）
├── thread.md                # 投稿テキスト全文（コピペ用）
└── generation-log.md        # 生成ログ（プロンプト・スコア）
```

## 実行フロー

```
/x-announce [version|latest]
    │
    ├─[Step 1] リリース情報の自動抽出
    │   ├── CHANGELOG.md から対象バージョンのエントリを抽出
    │   ├── CC統合パターン判定（"CC のアプデ / Harness での活用" 形式か）
    │   └── 主要変更点を 3〜5 個のハイライトに要約
    │
    ├─[Step 2] 投稿テキスト生成（5本スレッド）
    │   ├── Post 1: 告知（バージョン + ハイライト3点）
    │   ├── Post 2-4: 各機能の詳細（問題 → 解決策）
    │   └── Post 5: まとめ + CTA（GitHub リンク）
    │
    ├─[Step 3] 画像生成（Gemini API × 5枚並列）
    │   ├── 公式ロゴを参照画像として Gemini に直接渡す
    │   ├── 5枚を並列で curl 実行
    │   └── 各画像を Read で品質確認
    │
    └─[Step 4] 出力
        ├── out/x-posts/ に画像 + テキスト保存
        └── ユーザーにプレビュー提示
```

## 機能詳細

| 機能 | Reference |
|------|-----------|
| **投稿テンプレート** | See [post-templates.md](${CLAUDE_SKILL_DIR}/references/post-templates.md) |
| **画像生成パイプライン** | See [image-generation.md](${CLAUDE_SKILL_DIR}/references/image-generation.md) |

## 関連スキル

- `harness-release` — CHANGELOG・バージョンバンプ・GitHub Release（先に実行）
- `generate-slide` — プロジェクト紹介スライド生成（別用途）
