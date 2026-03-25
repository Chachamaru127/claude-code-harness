---
name: allow1
description: "Generate and vectorize production-ready SVGs with Quiver AI (ALLOW 1). Use when user mentions SVG, logo, icon, vector, illustration, vectorize, allow1, quiver, or image-to-svg. Do NOT load for: raster image generation (PNG/JPG), video, or slide generation."
description-ja: "Quiver AI (ALLOW 1) でプロダクション品質の SVG を生成・ベクタライズ。SVG、ロゴ、アイコン、ベクター、イラスト、ベクタライズ、allow1、quiver で起動。ラスター画像生成・動画・スライドでは不使用。"
description-en: "Generate and vectorize production-ready SVGs with Quiver AI (ALLOW 1). Use when user mentions SVG, logo, icon, vector, illustration, vectorize, allow1, quiver, or image-to-svg."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "AskUserQuestion", "WebFetch"]
argument-hint: "[generate|vectorize|batch] [prompt or image path]"
---

# ALLOW 1 (Quiver AI) — SVG Generation & Vectorization Skill

Quiver AI の API を使って、テキストプロンプトからの SVG 生成（Text-to-SVG）と、ラスター画像の SVG 変換（Image-to-SVG）をプロフェッショナルレベルで実行します。

---

## 前提条件

- `ALLOW1_API_KEY` 環境変数が設定済み
- Base URL: `https://api.quiver.ai/v1`
- モデル: `arrow-preview`（現行の公開モデル）

## Quick Reference

- "**SVG を作って**" / "**ロゴを生成**" / "**アイコンを作成**" → Text-to-SVG
- "**画像を SVG に変換**" / "**ベクタライズ**" / "**トレース**" → Image-to-SVG
- "**allow1**" / "**quiver**" → このスキル全般
- "**バッチ SVG**" / "**複数 SVG**" → バッチ生成

## 機能一覧

| 機能 | サブコマンド | リファレンス |
|------|-------------|-------------|
| **Text-to-SVG 生成** | `generate` | [references/text-to-svg.md](${CLAUDE_SKILL_DIR}/references/text-to-svg.md) |
| **Image-to-SVG 変換** | `vectorize` | [references/image-to-svg.md](${CLAUDE_SKILL_DIR}/references/image-to-svg.md) |
| **バッチ生成** | `batch` | [references/batch-workflow.md](${CLAUDE_SKILL_DIR}/references/batch-workflow.md) |
| **API リファレンス** | — | [references/api-reference.md](${CLAUDE_SKILL_DIR}/references/api-reference.md) |
| **プロンプトガイド** | — | [references/prompt-guide.md](${CLAUDE_SKILL_DIR}/references/prompt-guide.md) |

---

## 実行フロー

```
/allow1 [generate|vectorize|batch] [prompt or image]
    |
    +--[Step 1] 環境チェック
    |   +-- $ALLOW1_API_KEY の存在確認
    |   +-- モデル一覧取得（GET /v1/models）で接続確認
    |
    +--[Step 2] 要件ヒアリング（必要に応じて AskUserQuestion）
    |   +-- 用途: ロゴ / アイコン / イラスト / UI パーツ
    |   +-- スタイル: ミニマル / フラット / 線画 / グラデーション
    |   +-- 出力数 (n): 1〜16（デフォルト 4）
    |   +-- 保存先パス
    |
    +--[Step 3] API 実行
    |   +-- generate: POST /v1/svgs/generations
    |   +-- vectorize: POST /v1/svgs/vectorizations
    |   +-- batch: 複数リクエストを直列実行（レート制限考慮）
    |
    +--[Step 4] 結果処理
    |   +-- SVG ファイルとして保存
    |   +-- トークン使用量レポート
    |   +-- 必要に応じてリトライ（429 / 5xx 系）
    |
    +--[Step 5] 最適化（オプション）
        +-- SVGO による最適化提案
        +-- viewBox / カラー調整のアドバイス
```

---

## 基本使用例

### Text-to-SVG

```bash
# シンプルなロゴ生成
/allow1 generate "A minimalist mountain logo for a hiking app"

# スタイル指示付き
/allow1 generate "Dashboard icon set" --style flat --n 8
```

### Image-to-SVG

```bash
# 画像ファイルをベクタライズ
/allow1 vectorize ./assets/logo.png

# URL から直接変換
/allow1 vectorize https://example.com/image.png --auto-crop
```

### バッチ生成

```bash
# 複数のアイコンを一括生成
/allow1 batch "home icon" "settings icon" "profile icon" "search icon"
```

---

## API 呼び出しパターン（curl）

### 環境変数チェック + 接続確認

```bash
# API キー確認
if [ -z "$ALLOW1_API_KEY" ]; then
  echo "ERROR: ALLOW1_API_KEY is not set"
  exit 1
fi

# 接続テスト（モデル一覧取得）
curl -s https://api.quiver.ai/v1/models \
  -H "Authorization: Bearer $ALLOW1_API_KEY" | jq .
```

### Text-to-SVG（非ストリーミング）

```bash
curl -s https://api.quiver.ai/v1/svgs/generations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "arrow-preview",
    "prompt": "A clean minimalist logo for a tech startup called Nexus",
    "instructions": "Use geometric shapes, monochrome palette, flat design",
    "n": 4,
    "temperature": 0.7,
    "stream": false
  }' | jq -r '.data[0].svg' > output.svg
```

### Image-to-SVG

```bash
curl -s https://api.quiver.ai/v1/svgs/vectorizations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "arrow-preview",
    "image": { "url": "https://example.com/logo.png" },
    "auto_crop": true,
    "target_size": 1024,
    "n": 1,
    "stream": false
  }' | jq -r '.data[0].svg' > vectorized.svg
```

### Base64 画像入力

```bash
BASE64=$(base64 -i ./input.png)
curl -s https://api.quiver.ai/v1/svgs/vectorizations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"arrow-preview\",
    \"image\": { \"base64\": \"$BASE64\" },
    \"auto_crop\": true,
    \"stream\": false
  }" | jq -r '.data[0].svg' > vectorized.svg
```

---

## レート制限とエラー対策

| 制限 | 値 |
|------|-----|
| リクエスト上限 | 20 req / 60 sec（組織単位） |
| レスポンスヘッダ | `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` |
| 429 時 | `Retry-After` ヘッダを尊重、指数バックオフ |
| 課金 | 1 リクエスト = 1 クレジット（n の値に関係なく） |

### エラーコード早見表

| HTTP | コード | 対処 |
|------|--------|------|
| 400 | `invalid_request` | リクエストパラメータを確認 |
| 401 | `invalid_api_key` | `$ALLOW1_API_KEY` を確認 |
| 402 | `insufficient_credits` | クレジット購入が必要 |
| 403 | `account_frozen` | アカウント状態を確認 |
| 429 | `rate_limit_exceeded` | `Retry-After` 秒待機 |
| 500/502/503 | サーバーエラー | 指数バックオフでリトライ |

---

## 関連スキル

- `generate-slide` — Nano Banana Pro によるスライド画像生成
- `generate-video` — Remotion による動画生成
- `ui` — UI コンポーネント生成（SVG アイコンの組み込みに）
