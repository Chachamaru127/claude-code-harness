# ALLOW 1 (Quiver AI) API リファレンス

完全な API 仕様。OpenAPI spec (`https://api.quiver.ai/v1/openapi.json`) に基づく。

---

## 認証

```
Authorization: Bearer $ALLOW1_API_KEY
Content-Type: application/json
```

## エンドポイント一覧

| Method | Path | 説明 |
|--------|------|------|
| `GET` | `/v1/models` | 利用可能モデル一覧 |
| `GET` | `/v1/models/{model}` | モデル詳細取得 |
| `POST` | `/v1/svgs/generations` | Text-to-SVG 生成 |
| `POST` | `/v1/svgs/vectorizations` | Image-to-SVG 変換 |

---

## POST /v1/svgs/generations — Text-to-SVG

### リクエストボディ

| フィールド | 型 | 必須 | 制約 | 説明 |
|-----------|-----|------|------|------|
| `model` | string | Yes | minLength:1 | モデル ID（例: `arrow-preview`） |
| `prompt` | string | Yes | minLength:1 | 生成したい SVG の説明 |
| `instructions` | string | No | — | スタイル・フォーマットの指示 |
| `n` | integer | No | 1〜16, default:1 | 出力数 |
| `temperature` | number | No | 0〜2, default:1 | サンプリング温度 |
| `top_p` | number | No | 0〜1, default:1 | Nucleus サンプリング |
| `max_output_tokens` | integer | No | 1〜131072 | 最大出力トークン |
| `presence_penalty` | number | No | -2〜2, default:0 | 存在ペナルティ |
| `stream` | boolean | No | default:false | SSE ストリーミング |
| `references` | array | No | 最大 4 件 | 参照画像（ImageInputReference） |

### リクエスト例

```json
{
  "model": "arrow-preview",
  "prompt": "A minimalist mountain logo for a hiking app",
  "instructions": "Use flat design, monochrome palette, rounded corners",
  "n": 4,
  "temperature": 0.7,
  "top_p": 0.95,
  "max_output_tokens": 8192,
  "presence_penalty": 0.2,
  "stream": false,
  "references": [
    { "url": "https://example.com/reference-logo.png" }
  ]
}
```

### レスポンス（200 / 非ストリーミング）

```json
{
  "id": "resp_01J9AZ3XJ7D5S9ZV2Q5Z8E1A4N",
  "created": 1704067200,
  "data": [
    {
      "svg": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\">...</svg>",
      "mime_type": "image/svg+xml"
    }
  ],
  "usage": {
    "total_tokens": 1640,
    "input_tokens": 1200,
    "output_tokens": 440
  }
}
```

---

## POST /v1/svgs/vectorizations — Image-to-SVG

### リクエストボディ

| フィールド | 型 | 必須 | 制約 | 説明 |
|-----------|-----|------|------|------|
| `model` | string | Yes | minLength:1 | モデル ID |
| `image` | ImageInputReference | Yes | — | 入力画像（URL or base64） |
| `auto_crop` | boolean | No | default:false | 主要被写体に自動クロップ |
| `target_size` | integer | No | 128〜4096 | 推論前の正方形リサイズ（px） |
| `n` | integer | No | 1〜16 | 出力数 |
| `temperature` | number | No | 0〜2 | サンプリング温度 |
| `top_p` | number | No | 0〜1 | Nucleus サンプリング |
| `max_output_tokens` | integer | No | 1〜131072 | 最大出力トークン |
| `presence_penalty` | number | No | -2〜2 | 存在ペナルティ |
| `stream` | boolean | No | default:false | SSE ストリーミング |

### リクエスト例

```json
{
  "model": "arrow-preview",
  "image": { "url": "https://example.com/logo.png" },
  "auto_crop": true,
  "target_size": 1024,
  "n": 2,
  "temperature": 0.5,
  "stream": false
}
```

---

## ImageInputReference スキーマ

2 つの形式（anyOf）:

### URL 形式
```json
{ "url": "https://example.com/image.png" }
```

### Base64 形式
```json
{ "base64": "<base64エンコード文字列, 最大16MB>" }
```

---

## GET /v1/models — モデル一覧

### レスポンス

```json
{
  "object": "list",
  "data": [
    {
      "id": "arrow-preview",
      "object": "model",
      "name": "Arrow",
      "created": 1704067200,
      "owned_by": "quiver",
      "input_modalities": ["text", "image"],
      "output_modalities": ["svg"],
      "context_length": 131072,
      "max_output_length": 131072,
      "pricing": {
        "prompt": "0.000001",
        "completion": "0.000002",
        "image": "0",
        "request": "0"
      },
      "supported_operations": ["svg_generate", "svg_vectorize"],
      "supported_sampling_parameters": ["temperature", "top_p", "stop", "presence_penalty"]
    }
  ]
}
```

---

## ストリーミング（SSE）

`stream: true` を指定すると Server-Sent Events で応答。

### イベントタイプ

| type | 説明 |
|------|------|
| `reasoning` | モデルの推論過程テキスト |
| `draft` | 部分的な SVG（プログレス表示用） |
| `content` | 完成した SVG |

### ストリーム終了

```
data: [DONE]
```

### イベントデータ構造

```json
{
  "type": "content",
  "id": "resp_01J...",
  "svg": "<svg>...</svg>",
  "text": "",
  "usage": {
    "total_tokens": 1640,
    "input_tokens": 1200,
    "output_tokens": 440
  }
}
```

---

## エラーレスポンス

```json
{
  "status": 429,
  "code": "rate_limit_exceeded",
  "message": "Rate limit exceeded",
  "request_id": "req_01J9AZ3XJ7D5S9ZV2Q5Z8E1A4N"
}
```

### エラーコード一覧

| HTTP | code | 説明 | 対処 |
|------|------|------|------|
| 400 | `invalid_request` | パラメータ不正 | リクエスト内容を確認 |
| 401 | `invalid_api_key` | API キー不正 | `$ALLOW1_API_KEY` を確認 |
| 401 | `unauthorized` | 認証失敗 | キーの有効期限を確認 |
| 402 | `insufficient_credits` | クレジット不足 | クレジット購入 |
| 403 | `account_frozen` | アカウント凍結 | サポートに連絡 |
| 404 | `model_not_found` | モデル不存在 | モデル名を確認 |
| 429 | `rate_limit_exceeded` | レート制限超過 | `Retry-After` 秒待機 |
| 429 | `weekly_limit_exceeded` | 週間制限超過 | 次週まで待機 or プラン変更 |
| 500 | `internal_error` | サーバー内部エラー | リトライ |
| 502 | `upstream_error` | 推論サーバーエラー | リトライ |
| 503 | — | バックエンド到達不可 | 時間をおいてリトライ |

---

## レート制限

| 項目 | 値 |
|------|-----|
| 上限 | 20 リクエスト / 60 秒（組織単位） |
| 対象 | `POST /v1/svgs/generations`, `POST /v1/svgs/vectorizations` |
| ヘッダ | `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` |
| 429 時 | `Retry-After` ヘッダで待機秒数を確認 |

## 課金

- 1 リクエスト = 1 クレジット（`n` の値に関係なく）
- `n=4` でも `n=1` でも同じ 1 クレジット → **n は大きめに設定するのがコスパ良い**

---

## Node.js SDK

```bash
npm install @quiverai/sdk
```

```typescript
import { QuiverAI } from "@quiverai/sdk";

const client = new QuiverAI({
  bearerAuth: process.env.ALLOW1_API_KEY,
});

// Text-to-SVG
const result = await client.createSVGs.generateSVG({
  model: "arrow-preview",
  prompt: "A minimalist logo",
  temperature: 0.7,
});

// Image-to-SVG
const vectorized = await client.vectorizeSVG.vectorizeSVG({
  model: "arrow-preview",
  image: { url: "https://example.com/image.png" },
});

// Models
const models = await client.models.listModels();
const model = await client.models.getModel({ model: "arrow-preview" });
```

### SDK エラーハンドリング

```typescript
import * as errors from "@quiverai/sdk/sdk/models/errors";

try {
  const result = await client.createSVGs.generateSVG({ ... });
} catch (error) {
  if (error instanceof errors.QuiverAiError) {
    console.error(`${error.statusCode}: ${error.message}`);
  }
}
```
