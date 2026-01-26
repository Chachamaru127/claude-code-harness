---
name: review-security
description: "コードのセキュリティ脆弱性をチェックするスキル。セキュリティレビューが要求された場合、本番デプロイ前、または機密情報を扱うコードの変更時に使用します。"
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Review Security

コードのセキュリティ脆弱性をチェックし、問題を報告するスキル。

---

## 目的

OWASP Top 10 を含む一般的なセキュリティ脆弱性を検出：
- インジェクション攻撃（SQL, コマンド, XSS）
- 認証・認可の問題
- 機密データの露出
- セキュリティの設定ミス

---

## 入力

| 項目 | 説明 |
|------|------|
| `files` | チェック対象ファイルのリスト |
| `code_content` | ファイルの内容 |

---

## 出力

| 項目 | 説明 |
|------|------|
| `security_issues` | 検出された問題のリスト |
| `security_score` | セキュリティスコア (A-F) |

---

## チェック項目

### 1. インジェクション

| チェック | 検出対象 |
|---------|----------|
| SQL インジェクション | 文字列連結でのクエリ構築 |
| コマンドインジェクション | 安全でないコマンド実行関数の使用 |
| XSS | 未サニタイズのHTML出力 |

### 2. 認証・認可

| チェック | 検出対象 |
|---------|----------|
| ハードコードされた認証情報 | パスワード、APIキーの直書き |
| 弱い認証 | 平文パスワード保存 |
| 認可チェック漏れ | 権限確認なしのリソースアクセス |

### 3. 機密データ

| チェック | 検出対象 |
|---------|----------|
| 機密情報のログ出力 | パスワード、トークンのログ |
| 安全でない通信 | HTTP での機密データ送信 |
| .env ファイルのコミット | git に含まれる機密ファイル |

### 4. 設定ミス

| チェック | 検出対象 |
|---------|----------|
| デバッグモード有効 | 本番での DEBUG=true |
| CORS 設定ミス | 過度に寛容なオリジン設定 |
| セキュリティヘッダー欠如 | CSP, X-Frame-Options の未設定 |

---

## スコアリング

| スコア | 基準 |
|--------|------|
| A | 問題なし |
| B | 軽微な問題 1-2 件 |
| C | 中程度の問題あり |
| D | 重大な問題あり |
| F | クリティカルな脆弱性あり |

---

## 出力例

```markdown
## セキュリティレビュー結果

**スコア**: B

### 検出された問題

| 重大度 | ファイル | 行 | 問題 |
|--------|---------|-----|------|
| 中 | src/api/users.ts | 45 | SQL インジェクションの可能性 |
| 低 | src/config.ts | 12 | ハードコードされた API URL |

### 推奨対策

1. **SQL インジェクション対策**
   - プレースホルダーを使用したクエリに変更
   - ORM のパラメータバインディングを活用

2. **設定の外部化**
   - API URL を環境変数に移動
```

---

### 5. Cookie セキュリティ

| チェック | 検出対象 | 重大度 |
|---------|----------|--------|
| HttpOnly 未設定 | 認証 Cookie が JS からアクセス可能（`document.cookie` で読める） | 高 |
| SameSite 未設定/None | CSRF 脆弱性のリスク、クロスサイトリクエスト許可 | 高 |
| Secure 未設定 | HTTP 経由での Cookie 送信（盗聴リスク） | 高 |
| Domain 過度に広い | サブドメイン間での不正アクセス（`.example.com` 等） | 中 |
| 有効期限が長すぎる | セッション Cookie に長期 Expires 設定 | 中 |

**検出パターン**:
```typescript
// ❌ 問題のある設定
res.cookie('session', token);  // オプションなし
res.cookie('auth', token, { httpOnly: false });
document.cookie = "session=...";  // クライアントサイドでの設定

// ✅ 安全な設定
res.cookie('session', token, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict',
  domain: 'example.com'  // 明示的に制限
});
```

### 6. レスポンスヘッダー

| ヘッダー | 必須度 | 検出対象 | 効果 |
|---------|--------|----------|------|
| `Strict-Transport-Security` | 必須 | HSTS 未設定（HTTP ダウングレード攻撃） | HTTPS 強制 |
| `X-Content-Type-Options: nosniff` | 必須 | MIME スニッフィング許可 | XSS 防止 |
| `Content-Security-Policy` | 推奨 | CSP 未設定（インラインスクリプト許可） | XSS 防止 |
| `X-Frame-Options` / CSP `frame-ancestors` | 推奨 | フレーム埋め込み許可 | クリックジャッキング防止 |
| `Referrer-Policy` | 推奨 | 未設定（リファラ漏洩） | プライバシー保護 |

**検出パターン**:
```typescript
// チェック対象: レスポンスヘッダー設定箇所
// - middleware.ts
// - server.ts / app.ts
// - next.config.js (headers)
// - vercel.json / netlify.toml

// ❌ 問題: ヘッダー未設定
app.use((req, res, next) => next());

// ✅ 推奨: セキュリティヘッダー設定
app.use(helmet());  // または個別設定
res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
res.setHeader('X-Content-Type-Options', 'nosniff');
res.setHeader('X-Frame-Options', 'DENY');
```

### 7. リダイレクト・ファイルアップロード

#### オープンリダイレクト

| チェック | 検出対象 | 重大度 |
|---------|----------|--------|
| 未検証リダイレクト | ユーザー入力を直接 `redirect()` に渡す | 高 |
| URL パラメータの利用 | `?returnUrl=` `?next=` `?redirect=` | 高 |
| 外部ドメインへのリダイレクト | 許可リストなしでの外部リダイレクト | 高 |

**検出パターン**:
```typescript
// ❌ 危険: 未検証リダイレクト
const returnUrl = req.query.returnUrl;
res.redirect(returnUrl);

// ✅ 安全: ホワイトリスト検証
const allowedHosts = ['example.com', 'app.example.com'];
const url = new URL(returnUrl, 'https://example.com');
if (allowedHosts.includes(url.hostname)) {
  res.redirect(returnUrl);
}
```

#### ファイルアップロード

| チェック | 検出対象 | 重大度 |
|---------|----------|--------|
| MIME タイプ未検証 | Content-Type のみ信頼（偽装可能） | 高 |
| 拡張子未検証 | `.php`, `.exe` 等の危険な拡張子許可 | 高 |
| ファイルサイズ未検証 | 無制限アップロード（DoS リスク） | 中 |
| パストラバーサル | `../` を含むファイル名の未サニタイズ | 高 |
| マジックバイト未検証 | ファイルヘッダーの検証なし | 中 |

**検出パターン**:
```typescript
// ❌ 危険: 未検証アップロード
app.post('/upload', (req, res) => {
  const file = req.files.upload;
  file.mv(`./uploads/${file.name}`);  // パストラバーサル可能
});

// ✅ 安全: 複数層の検証
const allowedMimeTypes = ['image/jpeg', 'image/png', 'application/pdf'];
const allowedExtensions = ['.jpg', '.jpeg', '.png', '.pdf'];
const maxFileSize = 10 * 1024 * 1024;  // 10MB

// 1. サイズチェック
if (file.size > maxFileSize) throw new Error('File too large');

// 2. 拡張子チェック
const ext = path.extname(file.name).toLowerCase();
if (!allowedExtensions.includes(ext)) throw new Error('Invalid extension');

// 3. MIME タイプチェック（マジックバイト推奨）
if (!allowedMimeTypes.includes(file.mimetype)) throw new Error('Invalid type');

// 4. ファイル名サニタイズ
const safeName = crypto.randomUUID() + ext;
```

### 8. 決済セキュリティ

| チェック | 検出対象 | 重大度 |
|---------|----------|--------|
| 重複課金 | 冪等性キーの未使用 | 高 |
| 金額改ざん | クライアントサイドでの金額決定 | 高 |
| 状態不整合 | 決済プロバイダとアプリ状態の不一致 | 高 |
| Webhook 未検証 | 署名検証なしの Webhook 処理 | 高 |

**検出パターン**:
```typescript
// ❌ 危険: クライアントから金額を受け取る
const { amount, productId } = req.body;
await stripe.paymentIntents.create({ amount });

// ✅ 安全: サーバーサイドで金額を決定
const product = await db.products.findUnique({ where: { id: productId } });
await stripe.paymentIntents.create({
  amount: product.price,
  idempotencyKey: `order_${orderId}`  // 冪等性キー
});

// ✅ Webhook 署名検証
const sig = req.headers['stripe-signature'];
const event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
```

---

## 注意事項

- false positive を減らすためコンテキストを考慮する
- セキュリティ問題は優先度高で報告する
- 修正方法も合わせて提示する
- フレームワーク固有のセキュリティ機能を考慮する（Next.js, Express, etc.）
