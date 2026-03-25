# バッチ生成ワークフロー

複数の SVG を効率的に生成するためのワークフロー。レート制限（20 req/60s）を考慮した設計。

---

## 基本方針

- **1 リクエスト = 1 クレジット**（n に依存しない）→ n を最大活用
- **レート制限**: 20 req / 60 sec → バッチ間に 3 秒のインターバル推奨
- **並列実行は非推奨**: レート制限が組織単位のため、直列実行が安全

---

## パターン 1: 単一プロンプト × 大量バリエーション

1 つのプロンプトから複数のバリエーションを生成。

```bash
# n=16（最大）で1リクエスト = 16バリエーション
curl -s https://api.quiver.ai/v1/svgs/generations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "arrow-preview",
    "prompt": "A logo for a fintech startup called PayFlow",
    "instructions": "Clean, modern, professional. Use blue and white palette.",
    "n": 16,
    "temperature": 0.8,
    "stream": false
  }' | jq -r '.data | to_entries[] | "\(.key)\t\(.value.svg)"' | \
  while IFS=$'\t' read -r idx svg; do
    echo "$svg" > "payflow_logo_${idx}.svg"
  done
```

---

## パターン 2: 複数プロンプト × 直列実行

異なるプロンプトを順番に実行。

```bash
#!/bin/bash
set -euo pipefail

OUTPUT_DIR="./batch_output"
mkdir -p "$OUTPUT_DIR"

PROMPTS=(
  "home icon for navigation bar"
  "settings gear icon"
  "user profile avatar icon"
  "notification bell icon"
  "search magnifying glass icon"
  "shopping cart icon"
)

INSTRUCTIONS="24x24 viewBox, stroke-based, 1.5px stroke width, round line caps, currentColor"
TOTAL=${#PROMPTS[@]}
SUCCESS=0
FAILED=0

for i in "${!PROMPTS[@]}"; do
  PROMPT="${PROMPTS[$i]}"
  FILENAME=$(echo "$PROMPT" | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 40)

  echo "[$((i+1))/$TOTAL] Generating: $PROMPT"

  RESPONSE=$(curl -s -w "\n%{http_code}" https://api.quiver.ai/v1/svgs/generations \
    -H "Authorization: Bearer $ALLOW1_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"arrow-preview\",
      \"prompt\": \"$PROMPT\",
      \"instructions\": \"$INSTRUCTIONS\",
      \"n\": 4,
      \"temperature\": 0.4,
      \"stream\": false
    }")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" = "200" ]; then
    # 各バリエーションを保存
    echo "$BODY" | jq -r '.data | to_entries[] | "\(.key)\t\(.value.svg)"' | \
      while IFS=$'\t' read -r idx svg; do
        echo "$svg" > "$OUTPUT_DIR/${FILENAME}_v${idx}.svg"
      done
    TOKENS=$(echo "$BODY" | jq '.usage.total_tokens')
    echo "  -> OK (${TOKENS} tokens)"
    SUCCESS=$((SUCCESS + 1))
  elif [ "$HTTP_CODE" = "429" ]; then
    echo "  -> Rate limited. Waiting 10s..."
    sleep 10
    # リトライ（簡易版: 1回のみ）
    RESPONSE=$(curl -s https://api.quiver.ai/v1/svgs/generations \
      -H "Authorization: Bearer $ALLOW1_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"arrow-preview\",
        \"prompt\": \"$PROMPT\",
        \"instructions\": \"$INSTRUCTIONS\",
        \"n\": 4,
        \"temperature\": 0.4,
        \"stream\": false
      }")
    echo "$RESPONSE" | jq -r '.data | to_entries[] | "\(.key)\t\(.value.svg)"' | \
      while IFS=$'\t' read -r idx svg; do
        echo "$svg" > "$OUTPUT_DIR/${FILENAME}_v${idx}.svg"
      done
    SUCCESS=$((SUCCESS + 1))
  else
    echo "  -> ERROR ($HTTP_CODE): $(echo "$BODY" | jq -r '.message // "Unknown"')"
    FAILED=$((FAILED + 1))
  fi

  # レート制限対策: 3秒インターバル
  if [ $i -lt $((TOTAL - 1)) ]; then
    sleep 3
  fi
done

echo ""
echo "=== Batch Complete ==="
echo "Success: $SUCCESS / $TOTAL"
echo "Failed:  $FAILED / $TOTAL"
echo "Output:  $OUTPUT_DIR/"
```

---

## パターン 3: 画像バッチ変換

ディレクトリ内の画像を一括で SVG に変換。

```bash
#!/bin/bash
set -euo pipefail

INPUT_DIR="./images"
OUTPUT_DIR="./svg_output"
mkdir -p "$OUTPUT_DIR"

TOTAL=$(find "$INPUT_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) | wc -l | tr -d ' ')
COUNT=0

find "$INPUT_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) | while read -r IMG; do
  COUNT=$((COUNT + 1))
  BASENAME=$(basename "$IMG" | sed 's/\.[^.]*$//')
  EXT="${IMG##*.}"

  echo "[$COUNT/$TOTAL] Converting: $(basename "$IMG")"

  BASE64=$(base64 -i "$IMG")

  RESPONSE=$(curl -s -w "\n%{http_code}" https://api.quiver.ai/v1/svgs/vectorizations \
    -H "Authorization: Bearer $ALLOW1_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"arrow-preview\",
      \"image\": { \"base64\": \"$BASE64\" },
      \"auto_crop\": true,
      \"target_size\": 512,
      \"n\": 1,
      \"temperature\": 0.3,
      \"stream\": false
    }")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" = "200" ]; then
    echo "$BODY" | jq -r '.data[0].svg' > "$OUTPUT_DIR/${BASENAME}.svg"
    echo "  -> OK: $OUTPUT_DIR/${BASENAME}.svg"
  else
    echo "  -> ERROR ($HTTP_CODE): $(echo "$BODY" | jq -r '.message // "Unknown"')"
  fi

  sleep 3
done
```

---

## レート制限の管理

### 残りクォータの確認

レスポンスヘッダから残りリクエスト数を取得:

```bash
curl -s -D - https://api.quiver.ai/v1/svgs/generations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"arrow-preview","prompt":"test","n":1,"stream":false}' \
  -o /dev/null 2>&1 | grep -i 'x-ratelimit'
```

### 安全なインターバル計算

```
20 req / 60 sec = 1 req / 3 sec
```

→ **3 秒インターバル**で安全に 20 req/min を維持。バースト時は 429 + `Retry-After` で自動調整。

---

## コスト最適化のコツ

| テクニック | 説明 |
|-----------|------|
| **n を最大活用** | 1 req = 1 credit なので n=16 が最もコスパ良い |
| **instructions で絞り込み** | 具体的な instructions でやり直しを減らす |
| **temperature を用途に合わせる** | 一貫性重視なら低め、探索なら高め |
| **auto_crop を活用** | 余白の多い画像は auto_crop で前処理を省く |
