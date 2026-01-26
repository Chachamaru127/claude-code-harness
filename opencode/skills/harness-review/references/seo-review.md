---
name: review-seo
description: "SEO・OGP・メタ情報をチェックするスキル。ローンチ前レビュー、ページ追加時、またはSEO最適化が要求された場合に使用します。"
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Review SEO & OGP

SEO 最適化と OGP タグをチェックし、検索エンジン・SNS シェア品質を向上するスキル。

---

## 目的

以下の観点で SEO/OGP を評価：
- 検索エンジン最適化（title, description, canonical）
- ソーシャルメディア対応（OGP, Twitter Card）
- クローラビリティ（robots.txt, sitemap）
- 技術的 SEO（構造化データ, ページ速度）

---

## 入力

| 項目 | 説明 |
|------|------|
| `files` | チェック対象ファイルのリスト |
| `pages` | ページ一覧（静的/動的） |
| `public_dir` | public ディレクトリのパス |

---

## 出力

| 項目 | 説明 |
|------|------|
| `seo_issues` | 検出された問題のリスト |
| `seo_score` | SEO スコア (A-F) |

---

## チェック項目

### 1. 基本メタタグ

| チェック | 検出対象 | 重大度 |
|---------|----------|--------|
| `<title>` 欠落 | 全ページに設定されているか | 高 |
| `<title>` 重複 | 複数ページで同一タイトル | 中 |
| `<title>` 長さ | 60文字超過（検索結果で切れる） | 低 |
| `<meta name="description">` 欠落 | 重要ページに設定されているか | 中 |
| `<meta name="description">` 長さ | 160文字超過 | 低 |
| canonical URL 欠落 | 重要ページに `<link rel="canonical">` | 中 |
| viewport 未設定 | モバイル対応必須 | 高 |

**検出パターン**:
```tsx
// ❌ 問題: メタタグなし
export default function Page() {
  return <div>Content</div>;
}

// ✅ 改善: Next.js App Router
export const metadata = {
  title: 'ページタイトル | サイト名',
  description: 'ページの説明文（160文字以内）',
  alternates: { canonical: 'https://example.com/page' }
};

// ✅ 改善: HTML
<head>
  <title>ページタイトル | サイト名</title>
  <meta name="description" content="ページの説明文">
  <link rel="canonical" href="https://example.com/page">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
```

### 2. OGP（Open Graph Protocol）

| チェック | 検出対象 | 重大度 |
|---------|----------|--------|
| `og:title` 欠落 | シェア可能ページに設定されているか | 中 |
| `og:description` 欠落 | 適切な説明があるか | 中 |
| `og:image` 欠落 | 画像が設定されているか | 中 |
| `og:image` サイズ | 1200x630px 推奨 | 低 |
| `og:url` 不一致 | canonical と一致しているか | 低 |
| `og:type` 欠落 | `website`, `article` 等 | 低 |

**検出パターン**:
```tsx
// ✅ Next.js App Router
export const metadata = {
  openGraph: {
    title: 'ページタイトル',
    description: '説明文',
    url: 'https://example.com/page',
    siteName: 'サイト名',
    images: [{ url: 'https://example.com/og-image.png', width: 1200, height: 630 }],
    locale: 'ja_JP',
    type: 'website',
  },
};

// ✅ HTML
<meta property="og:title" content="ページタイトル">
<meta property="og:description" content="説明文">
<meta property="og:image" content="https://example.com/og-image.png">
<meta property="og:url" content="https://example.com/page">
<meta property="og:type" content="website">
```

### 3. Twitter Card

| チェック | 検出対象 | 重大度 |
|---------|----------|--------|
| `twitter:card` 欠落 | `summary_large_image` 推奨 | 低 |
| `twitter:title` 欠落 | OGP と重複可 | 低 |
| `twitter:description` 欠落 | OGP と重複可 | 低 |
| `twitter:image` 欠落 | OGP と重複可 | 低 |

**検出パターン**:
```tsx
// ✅ Next.js App Router
export const metadata = {
  twitter: {
    card: 'summary_large_image',
    title: 'ページタイトル',
    description: '説明文',
    images: ['https://example.com/twitter-image.png'],
  },
};
```

### 4. クローラビリティ

| チェック | 検出対象 | 重大度 |
|---------|----------|--------|
| robots.txt 欠落 | `public/robots.txt` が存在するか | 中 |
| robots.txt 全拒否 | `Disallow: /` で全ページブロック | 高 |
| sitemap.xml 欠落 | 存在するか | 低 |
| noindex 残存 | 開発中の `<meta name="robots" content="noindex">` | 高 |

**検出パターン**:
```bash
# チェック対象
public/robots.txt
public/sitemap.xml
app/robots.ts (Next.js)
app/sitemap.ts (Next.js)
```

```txt
# ✅ 推奨 robots.txt
User-agent: *
Allow: /
Sitemap: https://example.com/sitemap.xml

# ❌ 危険: 全拒否
User-agent: *
Disallow: /
```

### 5. HTTP ステータス

| チェック | 検出対象 | 重大度 |
|---------|----------|--------|
| エラーページ 200 | 404/500 が 200 を返す | 高 |
| リダイレクトチェーン | 3回以上のリダイレクト | 中 |
| soft 404 | 存在しないページが 200 を返す | 高 |

**検出パターン**:
```typescript
// ❌ 問題: エラーページが 200 を返す
export default function NotFound() {
  return <div>Page not found</div>;  // ステータス 200
}

// ✅ 改善: 正しいステータスコード
// app/not-found.tsx (Next.js App Router は自動で 404)
export default function NotFound() {
  return <div>Page not found</div>;
}
```

### 6. 構造化データ（オプション）

| チェック | 検出対象 | 重大度 |
|---------|----------|--------|
| JSON-LD 欠落 | 記事、商品、FAQ 等に推奨 | 低 |
| JSON-LD エラー | 構文エラー、必須フィールド欠落 | 中 |

---

## スコアリング

| スコア | 基準 |
|--------|------|
| A | 全項目クリア |
| B | 軽微な問題のみ（低重大度 1-2件） |
| C | 中程度の問題あり |
| D | 重大な問題あり（noindex 残存等） |
| F | 基本的な SEO 欠如 |

---

## 出力例

```markdown
## SEO/OGP レビュー結果

**スコア**: C

### 検出された問題

| 重大度 | ファイル | 問題 |
|--------|---------|------|
| 高 | app/layout.tsx | viewport meta 未設定 |
| 高 | public/robots.txt | 存在しない |
| 中 | app/about/page.tsx | title が他ページと重複 |
| 中 | app/blog/[slug]/page.tsx | OGP image 未設定 |
| 低 | app/page.tsx | description が 180 文字（160 推奨） |

### 推奨改善

1. **viewport 設定**
   ```tsx
   // app/layout.tsx
   export const metadata = {
     viewport: 'width=device-width, initial-scale=1.0',
   };
   ```

2. **robots.txt 作成**
   ```txt
   User-agent: *
   Allow: /
   Sitemap: https://example.com/sitemap.xml
   ```

3. **OGP 画像設定**
   - 1200x630px の画像を用意
   - 各ページに設定
```

---

## 注意事項

- フレームワーク固有の SEO 機能を考慮する（Next.js Metadata API, Remix meta 等）
- 動的ページ（`[slug]`）は代表的なパターンでチェック
- 構造化データは Google Rich Results Test で検証推奨
- Core Web Vitals はパフォーマンスレビューで別途チェック
