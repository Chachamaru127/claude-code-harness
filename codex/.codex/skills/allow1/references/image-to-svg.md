# Image-to-SVG 変換ガイド

ラスター画像（PNG / JPEG / WebP）を編集可能な SVG に変換するための詳細ガイド。

---

## エンドポイント

```
POST https://api.quiver.ai/v1/svgs/vectorizations
```

## 入力形式

### URL 指定

```json
{
  "model": "arrow-preview",
  "image": { "url": "https://example.com/logo.png" },
  "stream": false
}
```

### Base64 指定（ローカルファイル）

```bash
BASE64=$(base64 -i ./input.png)
curl -s https://api.quiver.ai/v1/svgs/vectorizations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"arrow-preview\",
    \"image\": { \"base64\": \"$BASE64\" },
    \"stream\": false
  }" | jq -r '.data[0].svg' > output.svg
```

**制限**: Base64 データは最大 **16MB**

---

## 主要パラメータ

### auto_crop（自動クロップ）

画像内の主要な被写体を自動検出し、余白をトリミングしてから推論を実行する。

```json
{
  "model": "arrow-preview",
  "image": { "url": "https://example.com/logo-with-whitespace.png" },
  "auto_crop": true
}
```

**推奨ケース**:
- ロゴ画像で余白が多い場合
- スクリーンショットからアイコンだけ抽出したい場合
- 写真の一部をベクタライズしたい場合

### target_size（リサイズ）

推論前に画像を正方形にリサイズする。大きい画像の処理速度向上や、小さい画像の品質向上に有効。

| 値 | 用途 |
|----|------|
| 128〜256 | アイコン・ファビコン（シンプルな形状） |
| 512 | 一般的なロゴ（推奨デフォルト） |
| 1024 | 詳細なイラスト |
| 2048〜4096 | 非常に高精細な変換 |

```json
{
  "model": "arrow-preview",
  "image": { "url": "https://example.com/detailed-illustration.png" },
  "target_size": 1024
}
```

---

## ユースケース別レシピ

### ロゴのベクタライズ

```bash
curl -s https://api.quiver.ai/v1/svgs/vectorizations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "arrow-preview",
    "image": { "url": "https://example.com/company-logo.png" },
    "auto_crop": true,
    "target_size": 512,
    "n": 2,
    "temperature": 0.3,
    "stream": false
  }' | jq -r '.data[0].svg' > logo.svg
```

### 写真からイラスト風 SVG

```bash
curl -s https://api.quiver.ai/v1/svgs/vectorizations \
  -H "Authorization: Bearer $ALLOW1_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "arrow-preview",
    "image": { "url": "https://example.com/photo.jpg" },
    "target_size": 1024,
    "n": 4,
    "temperature": 0.8,
    "stream": false
  }'
```

### ローカルファイルの一括変換

```bash
OUTPUT_DIR="./svg_output"
mkdir -p "$OUTPUT_DIR"

for IMG in ./images/*.png; do
  BASENAME=$(basename "$IMG" .png)
  BASE64=$(base64 -i "$IMG")

  curl -s https://api.quiver.ai/v1/svgs/vectorizations \
    -H "Authorization: Bearer $ALLOW1_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"arrow-preview\",
      \"image\": { \"base64\": \"$BASE64\" },
      \"auto_crop\": true,
      \"target_size\": 512,
      \"stream\": false
    }" | jq -r '.data[0].svg' > "$OUTPUT_DIR/${BASENAME}.svg"

  echo "Converted: $IMG -> $OUTPUT_DIR/${BASENAME}.svg"

  # レート制限対策: 3秒待機
  sleep 3
done
```

---

## 品質のコツ

### 入力画像の準備

| ポイント | 説明 |
|---------|------|
| **背景** | 透過 PNG か白背景が最良 |
| **コントラスト** | 主要要素と背景のコントラストを確保 |
| **解像度** | 最低 256x256px 推奨 |
| **ノイズ** | JPEG アーティファクトが多い場合は PNG に変換してから |
| **複雑さ** | 写真よりイラスト・ロゴの方が高品質な結果に |

### パラメータ調整

| 目的 | temperature | n | target_size |
|------|------------|---|-------------|
| 忠実な再現 | 0.2〜0.4 | 2 | 512〜1024 |
| バリエーション探索 | 0.6〜0.8 | 4〜8 | 512 |
| アート風変換 | 0.9〜1.5 | 4 | 1024 |

---

## 出力後の処理

### SVG の検証

```bash
# viewBox の確認
grep -o 'viewBox="[^"]*"' output.svg

# ファイルサイズ確認
ls -lh output.svg

# SVG が有効な XML か確認
xmllint --noout output.svg 2>&1 && echo "Valid SVG" || echo "Invalid SVG"
```

### SVGO で最適化（任意）

```bash
# SVGO がインストール済みの場合
npx svgo output.svg -o output.min.svg

# 最適化率を確認
echo "Before: $(wc -c < output.svg) bytes"
echo "After: $(wc -c < output.min.svg) bytes"
```
