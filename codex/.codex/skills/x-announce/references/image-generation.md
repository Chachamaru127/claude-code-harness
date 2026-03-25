# 画像生成パイプライン

Nano Banana Pro (Gemini 3 Pro Image Preview) API を使用した X 投稿画像の生成手順。

## API 仕様

| 項目 | 値 |
|------|-----|
| モデル | `gemini-3-pro-image-preview` |
| エンドポイント | `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent` |
| 認証 | `?key=${GEMINI_API_KEY}` クエリパラメータ |
| レスポンス形式 | `candidates[0].content.parts[].inlineData.data` (base64) |

## 核心: ロゴ画像の直接渡し

**ImageMagick 合成ではなく、Gemini にロゴ参照画像を渡して一体化デザインを生成する。**

これにより:
- ロゴのカラー（オレンジ #F97316）がデザイン全体に自然に反映
- ロゴの配置がレイアウトに統合される（後付け感なし）
- テキストとロゴの視覚的バランスが AI によって最適化

## 生成手順

### Step 1: ロゴの Base64 化

```bash
LOGO_B64=$(base64 -i docs/images/claude-harness-logo-with-text.png)
```

### Step 2: JSON リクエスト構築

各投稿ごとに以下の構造で JSON を構築:

```json
{
  "contents": [{
    "parts": [
      {
        "inlineData": {
          "mimeType": "image/png",
          "data": "${LOGO_B64}"
        }
      },
      {
        "text": "${PROMPT}"
      }
    ]
  }],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"]
  }
}
```

### Step 3: 共通プロンプトテンプレート

全画像で以下の共通指示を含める:

```
この画像はClaude Harnessの公式ロゴです。このロゴを左上に自然に配置して、
以下のX投稿用画像を生成してください。

サイズ: 2048x1024px、背景: 白、言語: 日本語、フォント: ゴシック体
カラーアクセント: オレンジ(#F97316)

重要:
- テキストは1回だけ表示（重複禁止）
- ロゴは提供画像をそのまま使用（新しく描画しない）
- プロフェッショナルでクリーンなデザイン
```

### Step 4: 画像ごとの個別プロンプト

| Post | デザインタイプ | 主な要素 |
|------|-------------|---------|
| 1 | タイポグラフィ主体 | バージョン番号（大）、ハイライト3点（アイコン付き箇条書き） |
| 2 | フローチャート図解 | 問題→解決策の分岐フロー |
| 3 | Before/After 対比 | 左: 問題状態、右: 解決状態 |
| 4 | カードレイアウト | 3つの改善点をカード風に配置 |
| 5 | まとめ + CTA | チェックリスト + GitHub CTA バナー |

### Step 5: 並列実行

```bash
API_KEY="${GEMINI_API_KEY}"
URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${API_KEY}"
OUTDIR="out/x-posts"

mkdir -p "$OUTDIR"

for i in 1 2 3 4 5; do
  (
    RESP=$(curl -s -X POST "${URL}" \
      -H "Content-Type: application/json" \
      -d @/tmp/gen_post${i}.json \
      --max-time 120)

    IMG_DATA=$(echo "$RESP" | jq -r \
      '.candidates[0].content.parts[] | select(.inlineData) | .inlineData.data' \
      2>/dev/null | head -1)

    if [ -n "$IMG_DATA" ] && [ "$IMG_DATA" != "null" ]; then
      echo "$IMG_DATA" | base64 -d > "${OUTDIR}/post${i}.png"
      echo "Post ${i}: SUCCESS"
    else
      echo "Post ${i}: FAILED"
    fi
  ) &
done
wait
```

## 品質チェック

生成後、各画像を `Read` で読み込んで以下を確認:

| チェック項目 | 基準 |
|------------|------|
| ロゴ表示 | 公式ロゴが左上に存在する |
| テキスト重複 | 同じテキストが2回以上表示されていない |
| 日本語 | テキストが日本語で記載されている |
| カラー | オレンジ (#F97316) がアクセントに使われている |
| 可読性 | テキストがはっきり読める |

NG の場合はプロンプトを微調整して再生成（最大2回リトライ）。

## トラブルシューティング

### モデルが見つからない

```
models/gemini-2.0-flash-exp is not found
```

→ モデル名が変更された可能性。以下で利用可能モデルを確認:

```bash
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=${API_KEY}" \
  | jq -r '.models[].name' | grep -i image
```

### GEMINI_API_KEY 未設定

環境変数が Bash サブプロセスに渡らない場合がある。
スキル実行時に直接 API キーを確認:

```bash
echo "GEMINI_API_KEY: ${GEMINI_API_KEY:-(not set)}"
```

未設定の場合は AskUserQuestion で取得。

### ロゴが AI に再描画される

プロンプトに以下を**必ず**含める:
> 「ロゴは提供画像をそのまま使用（新しく描画しない）」

これがないと AI が独自解釈でロゴを再生成してしまう。
