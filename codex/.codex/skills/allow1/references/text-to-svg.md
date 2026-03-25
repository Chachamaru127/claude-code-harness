# Text-to-SVG 生成ガイド

テキストプロンプトからプロダクション品質の SVG を生成するための詳細ガイド。

---

## エンドポイント

```
POST https://api.quiver.ai/v1/svgs/generations
```

## 基本パターン

### 1. シンプルなロゴ生成

```bash
curl -s https://api.quiver.ai/v1/svgs/generations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "arrow-preview",
    "prompt": "A minimalist logo for a coffee shop called Brew",
    "n": 4,
    "temperature": 0.8,
    "stream": false
  }' | jq -r '.data[].svg' > logos.svg
```

### 2. instructions 付きの制御された生成

```bash
curl -s https://api.quiver.ai/v1/svgs/generations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "arrow-preview",
    "prompt": "Dashboard navigation icons: home, settings, profile, notifications",
    "instructions": "Flat design, 24x24 viewBox, stroke-based, 2px stroke width, currentColor for fills",
    "n": 4,
    "temperature": 0.4,
    "stream": false
  }'
```

### 3. リファレンス画像付き生成

```bash
curl -s https://api.quiver.ai/v1/svgs/generations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "arrow-preview",
    "prompt": "Recreate this logo in a more modern style",
    "references": [
      { "url": "https://example.com/existing-logo.png" }
    ],
    "n": 4,
    "temperature": 0.6,
    "stream": false
  }'
```

---

## パラメータ調整ガイド

### temperature（サンプリング温度）

| 値 | ユースケース |
|----|-------------|
| 0.2〜0.4 | アイコンセット（一貫性重視） |
| 0.5〜0.7 | ロゴ生成（バランス型） |
| 0.8〜1.2 | クリエイティブ探索（多様性重視） |
| 1.3〜2.0 | 実験的・アート寄り |

### n（出力数）

- **1 クレジット/リクエスト**（n に依存しない）ので、n は大きめが効率的
- 推奨: ロゴ = 4〜8、アイコン = 2〜4、探索 = 8〜16
- 最大 16

### presence_penalty（存在ペナルティ）

| 値 | 効果 |
|----|------|
| 0 | デフォルト（繰り返し許容） |
| 0.2〜0.5 | 軽微な多様性向上 |
| 0.5〜1.0 | パターンの繰り返し抑制 |
| -0.5〜-1.0 | 一貫したパターン強化 |

---

## 出力の保存と処理

### 個別ファイルに保存

```bash
RESPONSE=$(curl -s https://api.quiver.ai/v1/svgs/generations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "arrow-preview",
    "prompt": "A tech startup logo",
    "n": 4,
    "stream": false
  }')

# 各 SVG を個別ファイルに保存
echo "$RESPONSE" | jq -r '.data | to_entries[] | "\(.key)\t\(.value.svg)"' | \
  while IFS=$'\t' read -r idx svg; do
    echo "$svg" > "output_${idx}.svg"
  done

# トークン使用量を表示
echo "$RESPONSE" | jq '.usage'
```

### jq でレスポンスから N 番目の SVG を取得

```bash
# 最初の SVG
echo "$RESPONSE" | jq -r '.data[0].svg'

# 全 SVG の viewBox を確認
echo "$RESPONSE" | jq -r '.data[].svg' | grep -o 'viewBox="[^"]*"'
```

---

## ストリーミング生成

リアルタイムにプログレスを表示したい場合:

```bash
curl -s -N https://api.quiver.ai/v1/svgs/generations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "arrow-preview",
    "prompt": "A detailed illustration of a city skyline",
    "n": 1,
    "stream": true
  }'
```

### SSE イベント解析

```
event: reasoning
data: {"type":"reasoning","text":"Designing a skyline with..."}

event: draft
data: {"type":"draft","svg":"<svg><!-- partial -->...</svg>"}

event: content
data: {"type":"content","id":"resp_01J...","svg":"<svg>...</svg>","usage":{...}}

data: [DONE]
```

---

## ユースケース別レシピ

### ロゴ生成（ブランド用）

```json
{
  "model": "arrow-preview",
  "prompt": "A professional logo for [brand name], a [industry] company. The logo should convey [values]",
  "instructions": "Clean vector paths, limited color palette (max 3 colors), scalable from 16px to billboard size",
  "n": 8,
  "temperature": 0.7,
  "presence_penalty": 0.3
}
```

### アイコンセット（UI 用）

```json
{
  "model": "arrow-preview",
  "prompt": "A set of navigation icons: [icon1], [icon2], [icon3]",
  "instructions": "24x24 viewBox, stroke-based design, 1.5px stroke width, round line caps, currentColor",
  "n": 4,
  "temperature": 0.3,
  "presence_penalty": -0.2
}
```

### イラスト（マーケティング用）

```json
{
  "model": "arrow-preview",
  "prompt": "An illustration showing [scene] for a [context] landing page",
  "instructions": "Flat illustration style, warm color palette, no text, suitable for hero section",
  "n": 4,
  "temperature": 0.9,
  "max_output_tokens": 16384
}
```

### ファビコン / アプリアイコン

```json
{
  "model": "arrow-preview",
  "prompt": "A simple, recognizable favicon for [app name]",
  "instructions": "Must be clear at 16x16px, single shape, bold colors, no fine details",
  "n": 8,
  "temperature": 0.6
}
```

---

## エラーハンドリング

```bash
RESPONSE=$(curl -s -w "\n%{http_code}" https://api.quiver.ai/v1/svgs/generations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

case $HTTP_CODE in
  200) echo "$BODY" | jq -r '.data[0].svg' > output.svg ;;
  401) echo "ERROR: API key invalid. Check \$ALLOW1_API_KEY" ;;
  402) echo "ERROR: Insufficient credits. Purchase at app.quiver.ai/settings/billing" ;;
  429)
    RETRY_AFTER=$(echo "$BODY" | jq -r '.message // "60"')
    echo "Rate limited. Retrying after pause..."
    sleep 5
    # retry logic here
    ;;
  *) echo "ERROR ($HTTP_CODE): $(echo "$BODY" | jq -r '.message // "Unknown error"')" ;;
esac
```
