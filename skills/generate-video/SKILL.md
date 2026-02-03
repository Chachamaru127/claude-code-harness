---
name: generate-video
description: "Generates product demo videos, architecture explanations, and release note videos. Use when user mentions '/generate-video', video generation, product demos, or visual documentation. Do NOT load for: embedding video players, live demos, video playback features. Requires Remotion setup."
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task", "AskUserQuestion", "WebFetch"]
disable-model-invocation: true
argument-hint: "[demo|arch|release]"
---

# Generate Video Skill

プロダクト説明動画の自動生成を担当するスキル群です。

---

## 概要

`/generate-video` コマンドの内部で使用されるスキルです。
コードベース分析 → シナリオ提案 → 並列生成のフローを実行します。

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **ベストプラクティス** | See [references/best-practices.md](references/best-practices.md) |
| **コードベース分析** | See [references/analyzer.md](references/analyzer.md) |
| **シナリオプランニング** | See [references/planner.md](references/planner.md) |
| **並列シーン生成** | See [references/generator.md](references/generator.md) |
| **視覚効果ライブラリ** | See [references/visual-effects.md](references/visual-effects.md) |
| **AI画像生成** | See [references/image-generator.md](references/image-generator.md) |
| **画像品質判定** | See [references/image-quality-check.md](references/image-quality-check.md) |

## Prerequisites

- Remotion がセットアップ済み（`/remotion-setup`）
- Node.js 18+
- （オプション）`GOOGLE_AI_API_KEY` - AI画像生成用

## `/generate-video` フロー

```
/generate-video
    │
    ├─[Step 1] 分析（analyzer.md）
    │   ├─ フレームワーク検出
    │   ├─ 主要機能検出
    │   ├─ UIコンポーネント検出
    │   └─ プロジェクト資産解析（Plans.md, CHANGELOG等）
    │
    ├─[Step 2] シナリオ提案（planner.md）
    │   ├─ 動画タイプ自動判定
    │   ├─ シーン構成提案
    │   └─ ユーザー確認
    │
    ├─[Step 2.5] 素材生成（image-generator.md）← NEW
    │   ├─ 素材必要判定（イントロ、CTA等）
    │   ├─ Nano Banana Pro で2枚生成
    │   ├─ Claude が品質判定（image-quality-check.md）
    │   └─ OK → 採用 / NG → 再生成（最大3回）
    │
    └─[Step 3] 並列生成（generator.md）
        ├─ シーン並列生成（Task tool）
        ├─ 統合 + トランジション
        └─ 最終レンダリング
```

## 実行手順

1. ユーザーが `/generate-video` を実行
2. Remotion セットアップ確認
3. `analyzer.md` でコードベース分析
4. `planner.md` でシナリオ提案 + ユーザー確認
5. `generator.md` で並列生成
6. 完了報告

## 動画タイプ（ファネル別）

| タイプ | ファネル | 長さ目安 | 自動判定条件 | 構成の芯 |
|--------|----------|----------|--------------|----------|
| **LP/広告ティザー** | 認知〜興味 | 30-90秒 | 新規プロジェクト | 痛み→結果→CTA |
| **Introデモ** | 興味→検討 | 2-3分 | UI変更検出 | 1ユースケース完走 |
| **リリースノート** | 検討→確信 | 1-3分 | CHANGELOG更新 | Before/After重視 |
| **アーキテクチャ解説** | 確信→決裁 | 5-30分 | 大規模構造変更 | 実運用+証拠 |
| **オンボーディング** | 継続・活用 | 30秒-数分 | 初回セットアップ | Aha体験への最短パス |

> 詳細: [references/best-practices.md](references/best-practices.md)

## シーンテンプレート

### 90秒ティザー（LP/広告向け）

| 時間 | シーン | 内容 |
|------|--------|------|
| 0-5秒 | Hook | 痛み or 望む結果 |
| 5-15秒 | Problem+Promise | 対象ユーザーと約束 |
| 15-55秒 | Workflow | 象徴ワークフロー |
| 55-70秒 | Differentiator | 差別化の根拠 |
| 70-90秒 | CTA | 次の一手 |

### 3分Introデモ（検討向け）

| 時間 | シーン | 内容 |
|------|--------|------|
| 0-10秒 | Hook | 結論+痛み |
| 10-30秒 | UseCase | ユースケース宣言 |
| 30-140秒 | Demo | 実画面で完走 |
| 140-170秒 | Objection | よくある不安1つ潰す |
| 170-180秒 | CTA | 行動喚起 |

### 共通シーン

| シーン | 推奨時間 | 内容 |
|--------|----------|------|
| イントロ | 3-5秒 | ロゴ + タグライン |
| 機能デモ | 10-30秒 | Playwrightキャプチャ |
| アーキテクチャ図 | 10-20秒 | Mermaid → アニメーション |
| CTA | 3-5秒 | URL + 連絡先 |

> 詳細テンプレート: [references/best-practices.md](references/best-practices.md#テンプレート)

## 音声同期ルール（重要）

ナレーション付き動画では以下を厳守:

| ルール | 値 |
|--------|-----|
| 音声開始 | シーン開始 + 30f（1秒待機） |
| シーン長さ | 30f + 音声長さ + 20f余白 |
| トランジション | 15f（隣接シーンとオーバーラップ） |
| シーン開始計算 | 前シーン開始 + 前シーン長 - 15f |

**事前確認**: `ffprobe` で音声長さを確認してからシーン設計

> 詳細: [references/generator.md](references/generator.md#音声同期ルール重要)

## BGM サポート

| 項目 | 推奨値 |
|------|--------|
| ナレーションあり | bgmVolume: 0.20 - 0.30 |
| ナレーションなし | bgmVolume: 0.50 - 0.80 |
| ファイル配置 | `public/BGM/` |

> 詳細: [references/generator.md](references/generator.md#bgm-サポート)

## 字幕サポート

| ルール | 値 |
|--------|-----|
| 字幕開始 | 音声開始と同じ |
| 字幕duration | 音声長 + 10f |
| フォント | Base64埋め込み推奨 |

> 詳細: [references/generator.md](references/generator.md#字幕サポート)

## 視覚効果ライブラリ

インパクトのある動画向けエフェクト集:

| エフェクト | 用途 |
|-----------|------|
| GlitchText | Hook、タイトル |
| Particles | 背景、CTA収束 |
| ScanLine | 解析中演出 |
| ProgressBar | 並列処理表示 |
| 3D Parallax | カード表示 |

> 詳細: [references/visual-effects.md](references/visual-effects.md)

## Notes

- Remotion未セットアップの場合は `/remotion-setup` を案内
- 並列生成数はシーン数に応じて自動調整（max 5）
- 生成された動画は `out/` ディレクトリに出力
- AI生成画像は `out/assets/generated/` に保存
- `GOOGLE_AI_API_KEY` 未設定時は画像生成をスキップ（既存素材 or プレースホルダー使用）
