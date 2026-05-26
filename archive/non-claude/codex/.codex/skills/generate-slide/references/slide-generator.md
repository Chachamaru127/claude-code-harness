# Slide Generator - Nano Banana Pro スライド画像生成

Nano Banana Pro（Google DeepMind）を使用して、プロジェクト紹介スライド画像を自動生成します。

---

## 概要

`/generate-slide` の Step 3 で実行される画像生成ロジックです。
3つのデザインパターンそれぞれで2枚ずつ生成し、品質チェック後にベスト1枚を選出します。

## 前提条件

- `GOOGLE_AI_API_KEY` 環境変数が設定済み
- Google AI Studio で Nano Banana Pro（Gemini 3 Pro Image Preview）が有効化済み

---

## API 仕様

> **共通仕様**: `generate-video/references/image-generator.md` と同一の Nano Banana Pro API を使用。

### エンドポイント

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent
```

### 認証

```bash
x-goog-api-key: ${GOOGLE_AI_API_KEY}
```

### リクエスト形式

```json
{
  "contents": [{
    "parts": [
      {"text": "<slide prompt here>"}
    ]
  }],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"],
    "imageConfig": {
      "aspectRatio": "16:9",
      "imageSize": "2K"
    }
  }
}
```

### レスポンス形式

```json
{
  "candidates": [{
    "content": {
      "parts": [
        {"text": "Description of the generated slide..."},
        {
          "inline_data": {
            "mime_type": "image/png",
            "data": "iVBORw0KGgoAAAANS..."
          }
        }
      ]
    }
  }]
}
```

---

## デフォルト設定

| 設定 | 値 | 説明 |
|------|-----|------|
| モデル | `gemini-3-pro-image-preview` | プロ品質（推奨） |
| アスペクト比 | `16:9` | プレゼンテーション標準 |
| 解像度 | `2K` | 2048px、標準品質 |
| responseModalities | `["TEXT", "IMAGE"]` | テキスト説明 + 画像 |

### アスペクト比オプション

| 比率 | 用途 |
|------|------|
| `16:9` | プレゼン・スクリーン（推奨） |
| `4:3` | 従来型プレゼン |
| `1:1` | SNS投稿、アイコン用 |

---

## 3つのデザインパターン

### Pattern A: Minimalist

**コンセプト**: 余白とタイポグラフィ主体。洗練された印象。

**プロンプトテンプレート**:

```
Create a minimalist project introduction slide for "{project_name}".

Project description: {project_description}
Key features: {features}

Design style:
- Clean whitespace-dominant layout
- Typography-driven hierarchy with bold project name
- Subtle accent color: {accent_color}
- {tone} aesthetic
- No cluttered elements, elegant simplicity
- Professional presentation quality, 2K resolution

Important: This is a single slide image, not a deck. Focus on clear visual hierarchy with the project name prominent and key value proposition visible.
```

**視覚イメージ**:
```
+------------------------------------------+
|                                          |
|                                          |
|        PROJECT NAME                      |
|        _______________                   |
|                                          |
|        One-line description              |
|                                          |
|        * Feature 1                       |
|        * Feature 2                       |
|        * Feature 3                       |
|                                          |
+------------------------------------------+
```

### Pattern B: Infographic

**コンセプト**: データやフローの可視化。情報量が多いが整理されている。

**プロンプトテンプレート**:

```
Create an infographic-style project introduction slide for "{project_name}".

Project description: {project_description}
Key features: {features}
Tech stack: {tech_stack}

Design style:
- Data visualization and structured layout
- Icons and visual elements for each feature
- Flow or architecture diagram elements
- Metrics and key numbers highlighted
- {tone} color palette with {accent_color} accents
- Professional infographic quality, 2K resolution

Important: This is a single slide image. Organize information visually with icons, sections, and clear data hierarchy. Make the project's value immediately understandable through visual structure.
```

**視覚イメージ**:
```
+------------------------------------------+
|  PROJECT NAME          [icon] [icon]     |
|  ================                        |
|                                          |
|  [Feature 1]    [Feature 2]    [Feat 3]  |
|  +----------+   +----------+   +------+  |
|  | icon     |   | icon     |   | icon |  |
|  | detail   |   | detail   |   | det  |  |
|  +----------+   +----------+   +------+  |
|                                          |
|  Tech: [TS] [Node] [React]    v1.0      |
+------------------------------------------+
```

### Pattern C: Hero Visual

**コンセプト**: 大きなビジュアルとキャッチコピーでインパクト重視。

**プロンプトテンプレート**:

```
Create a hero-style project introduction slide for "{project_name}".

Project description: {project_description}
Key value: {key_value_proposition}

Design style:
- Bold, impactful hero image as background
- Large catchy headline text
- Dramatic visual composition
- {tone} mood with cinematic lighting
- Strong visual metaphor representing the project's purpose
- Professional marketing quality, 2K resolution

Important: This is a single slide image. Prioritize visual impact and emotional resonance. The project name and core value should be immediately visible with a compelling visual backdrop.
```

**視覚イメージ**:
```
+------------------------------------------+
|                                          |
|    ==============================        |
|    ||  PROJECT NAME            ||        |
|    ||                          ||        |
|    ||  "Catchy tagline here"   ||        |
|    ||                          ||        |
|    ==============================        |
|                                          |
|         [ Bold Visual BG ]               |
|                                          |
+------------------------------------------+
```

---

## プロンプト構成

### 基本構造

```
[プロジェクト概要] + [デザインスタイル] + [品質指定] + [制約]
```

### トーン別の修飾語

| トーン | 修飾語 |
|--------|--------|
| テック | `dark theme, code-inspired, terminal aesthetic, neon accents` |
| カジュアル | `bright colors, friendly, playful, approachable` |
| コーポレート | `formal, trustworthy, blue tones, clean lines, business` |
| クリエイティブ | `bold, artistic, gradient, unconventional layout` |

### 品質向上キーワード

| キーワード | 効果 |
|-----------|------|
| `professional presentation quality` | プレゼン品質 |
| `clean design` | 不要要素の削減 |
| `2K resolution` | 高解像度 |
| `clear visual hierarchy` | 視覚的階層 |
| `modern aesthetic` | 現代的デザイン |

### 避けるべきプロンプト

| NG パターン | 理由 |
|------------|------|
| 曖昧な指示 | 「いい感じのスライド」→ 結果が不安定 |
| 過度に複雑 | 要素が多すぎると品質低下 |
| 長文テキスト指定 | AI 生成テキストは品質不安定。キーワード程度に留める |
| 著作権物 | ブランドロゴ等は生成不可 |

---

## Bash 実行例

### 環境変数確認

```bash
test -n "$GOOGLE_AI_API_KEY" && echo "GOOGLE_AI_API_KEY is set" || { echo "GOOGLE_AI_API_KEY is not set"; exit 1; }
```

### 出力ディレクトリ作成

```bash
mkdir -p out/slides/selected
```

### curl での画像生成

```bash
PROMPT='Create a minimalist project introduction slide for "My Project". Clean whitespace-dominant layout, typography-driven, professional presentation quality, 2K resolution.'

curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
  -H "x-goog-api-key: ${GOOGLE_AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"contents\": [{
      \"parts\": [
        {\"text\": \"${PROMPT}\"}
      ]
    }],
    \"generationConfig\": {
      \"responseModalities\": [\"TEXT\", \"IMAGE\"],
      \"imageConfig\": {
        \"aspectRatio\": \"16:9\",
        \"imageSize\": \"2K\"
      }
    }
  }" \
  -o /tmp/slide_response.json

# Base64 デコードして PNG 保存
cat /tmp/slide_response.json | jq -r '.candidates[0].content.parts[] | select(.inline_data) | .inline_data.data' | head -1 | base64 -d > out/slides/minimalist_1.png
```

> **注意**: 1回のリクエストで1枚の画像が生成されます。2枚必要な場合は2回リクエストを実行してください。

### 並列生成（6枚一括）

```bash
mkdir -p out/slides/selected

generate_slide() {
  local pattern=$1
  local index=$2
  local prompt=$3
  local aspect_ratio=${4:-"16:9"}
  local image_size=${5:-"2K"}

  curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
    -H "x-goog-api-key: ${GOOGLE_AI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"contents\": [{
        \"parts\": [
          {\"text\": \"${prompt}\"}
        ]
      }],
      \"generationConfig\": {
        \"responseModalities\": [\"TEXT\", \"IMAGE\"],
        \"imageConfig\": {
          \"aspectRatio\": \"${aspect_ratio}\",
          \"imageSize\": \"${image_size}\"
        }
      }
    }" \
    -o "/tmp/slide_${pattern}_${index}.json"

  # Base64 デコード
  cat "/tmp/slide_${pattern}_${index}.json" \
    | jq -r '.candidates[0].content.parts[] | select(.inline_data) | .inline_data.data' \
    | head -1 \
    | base64 -d > "out/slides/${pattern}_${index}.png"
}

# 並列実行（バックグラウンドジョブ）
generate_slide "minimalist" "1" "$MINIMALIST_PROMPT" &
generate_slide "minimalist" "2" "$MINIMALIST_PROMPT" &
generate_slide "infographic" "1" "$INFOGRAPHIC_PROMPT" &
generate_slide "infographic" "2" "$INFOGRAPHIC_PROMPT" &
generate_slide "hero" "1" "$HERO_PROMPT" &
generate_slide "hero" "2" "$HERO_PROMPT" &
wait

echo "6枚の生成が完了しました"
```

---

## 再生成時のプロンプト改善戦略

### 試行ごとの改善

| 試行 | 改善戦略 |
|------|---------|
| 1回目 | 初期プロンプトで生成 |
| 2回目 | 品質指摘を反映してプロンプト調整（具体的な修飾語を追加） |
| 3回目 | スタイルを大幅変更、より具体的な構図指示を追加 |

### 問題カテゴリ別の改善

| 問題 | 改善プロンプト追加 |
|------|-------------------|
| テキストが読めない | `no text elements, text-free design` を追加 |
| レイアウトが崩れている | `balanced composition, grid-based layout` を追加 |
| 情報量が不足 | 具体的な機能名・数値をプロンプトに明記 |
| プロフェッショナル感が低い | `corporate quality, polished, refined` を追加 |
| 色が合わない | 具体的な HEX カラーコードを指定 |

---

## エラーハンドリング

### API エラー

| エラーコード | 原因 | 対処 |
|-------------|------|------|
| `400` | 不正なプロンプト | プロンプト内容を確認・修正 |
| `401` | 認証失敗 | API キーを確認 |
| `429` | レート制限 | 60秒待機して再試行 |
| `500` | サーバーエラー | 30秒待機して再試行 |

### jq パースエラー

レスポンスに画像データが含まれない場合:

```bash
# レスポンス確認
cat /tmp/slide_response.json | jq '.candidates[0].content.parts | length'

# エラーメッセージ確認
cat /tmp/slide_response.json | jq '.error'
```

---

## コスト見積もり

### 1回の実行あたり

```
基本: 6枚 x ~$0.06 = ~$0.36（2K解像度）
最大（全パターンリトライ3回）: 18枚 x ~$0.06 = ~$1.08
```

### 解像度別コスト

| 解像度 | 1枚あたり | 6枚（基本） | 18枚（最大） |
|--------|----------|-------------|-------------|
| `1K` | ~$0.02 | ~$0.12 | ~$0.36 |
| `2K` | ~$0.06 | ~$0.36 | ~$1.08 |
| `4K` | ~$0.12 | ~$0.72 | ~$2.16 |

---

## 関連ドキュメント

- [slide-quality-check.md](./slide-quality-check.md) — 品質判定ロジック
- [generate-video/references/image-generator.md](../../generate-video/references/image-generator.md) — API 共通仕様（詳細）
- [generate-video/references/image-quality-check.md](../../generate-video/references/image-quality-check.md) — 動画用品質判定（参考）
