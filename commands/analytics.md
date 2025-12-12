# /analytics - Analytics統合

Google Analytics または Vercel Analytics を統合します。

**機能**:
- ✅ ページビュー追跡
- ✅ イベント追跡
- ✅ コンバージョン追跡
- ✅ ユーザー行動分析

---

## 💡 バイブコーダー向けの使い方

**このコマンドは、クライアントに成果を報告するためのAnalyticsを簡単に導入できます。**

- ✅ ページビュー数を追跡
- ✅ ボタンクリックなどのイベントを記録
- ✅ コンバージョン率を測定
- ✅ クライアントにデータを共有

**受託開発で重要**: クライアントに「どれだけアクセスがあったか」を報告できます

---

## 使い方

```
/analytics google
```

→ Google Analyticsを統合

```
/analytics vercel
```

→ Vercel Analyticsを統合

---

## 実行フロー

### Step 1: Analyticsプロバイダーの確認

ユーザーの入力を確認。入力がない場合は質問：

> 🎯 **どのAnalyticsを使用しますか？**
>
> 1. Google Analytics（推奨: 無料、高機能）
> 2. Vercel Analytics（推奨: Vercelデプロイ時）
> 3. 両方
>
> 番号で答えてください（デフォルト: 1）

**回答を待つ**

---

## Google Analyticsの場合

### Step 2: Google Analyticsプロパティの作成ガイド

> 📦 **Google Analyticsプロパティを作成してください：**
>
> 1. https://analytics.google.com にアクセス
> 2. 「管理」→「プロパティを作成」
> 3. プロパティ名を入力
> 4. 「データストリーム」→「ウェブ」を選択
> 5. 測定IDをコピー: `G-XXXXXXXXXX`
>
> **完了したら「OK」と答えてください。**

**回答を待つ**

### Step 3: パッケージのインストール

```bash
npm install @next/third-parties
```

### Step 4: 環境変数の設定

#### `.env.local`

```env
NEXT_PUBLIC_GA_MEASUREMENT_ID=G-XXXXXXXXXX
```

### Step 5: Google Analyticsの設定

#### `app/layout.tsx`

```typescript
import { GoogleAnalytics } from '@next/third-parties/google'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>
        {children}
        <GoogleAnalytics gaId={process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID!} />
      </body>
    </html>
  )
}
```

### Step 6: イベント追跡の実装

#### `lib/analytics.ts`

```typescript
export const GA_MEASUREMENT_ID = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID

// ページビュー
export const pageview = (url: string) => {
  if (typeof window.gtag !== 'undefined') {
    window.gtag('config', GA_MEASUREMENT_ID!, {
      page_path: url,
    })
  }
}

// イベント
export const event = ({ action, category, label, value }: {
  action: string
  category: string
  label?: string
  value?: number
}) => {
  if (typeof window.gtag !== 'undefined') {
    window.gtag('event', action, {
      event_category: category,
      event_label: label,
      value: value,
    })
  }
}
```

### Step 7: イベント追跡の使用例

#### `components/cta-button.tsx`

```typescript
'use client'

import { Button } from '@/components/ui/button'
import { event } from '@/lib/analytics'

export function CTAButton() {
  const handleClick = () => {
    // イベント追跡
    event({
      action: 'click',
      category: 'CTA',
      label: '無料トライアル',
    })

    // 実際の処理
    window.location.href = '/signup'
  }

  return (
    <Button onClick={handleClick}>
      無料トライアルを始める
    </Button>
  )
}
```

---

## Vercel Analyticsの場合

### Step 2: Vercel Analyticsの有効化ガイド

> 📦 **Vercel Analyticsを有効化してください：**
>
> 1. Vercel Dashboard > プロジェクトを選択
> 2. 「Analytics」タブをクリック
> 3. 「Enable Analytics」をクリック
>
> **完了したら「OK」と答えてください。**

**回答を待つ**

### Step 3: パッケージのインストール

```bash
npm install @vercel/analytics
```

### Step 4: Vercel Analyticsの設定

#### `app/layout.tsx`

```typescript
import { Analytics } from '@vercel/analytics/react'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>
        {children}
        <Analytics />
      </body>
    </html>
  )
}
```

### Step 5: イベント追跡の実装

#### `components/cta-button.tsx`

```typescript
'use client'

import { Button } from '@/components/ui/button'
import { track } from '@vercel/analytics'

export function CTAButton() {
  const handleClick = () => {
    // イベント追跡
    track('CTA Click', { label: '無料トライアル' })

    // 実際の処理
    window.location.href = '/signup'
  }

  return (
    <Button onClick={handleClick}>
      無料トライアルを始める
    </Button>
  )
}
```

---

## 共通: 追跡すべきイベント

### 1. コンバージョンイベント

```typescript
// サインアップ
event({ action: 'signup', category: 'conversion', label: 'email' })

// 購入
event({ action: 'purchase', category: 'conversion', value: 2980 })

// 問い合わせ
event({ action: 'contact', category: 'conversion', label: 'form' })
```

### 2. エンゲージメントイベント

```typescript
// ボタンクリック
event({ action: 'click', category: 'engagement', label: 'CTA' })

// ビデオ再生
event({ action: 'play', category: 'engagement', label: 'intro_video' })

// ダウンロード
event({ action: 'download', category: 'engagement', label: 'whitepaper' })
```

### 3. ナビゲーションイベント

```typescript
// 外部リンク
event({ action: 'outbound', category: 'navigation', label: 'github' })

// スクロール深度
event({ action: 'scroll', category: 'navigation', value: 75 })
```

---

## クライアント向けレポート

### Step 8: レポートテンプレートの作成

#### `.claude/analytics-report-template.md`

```markdown
# Analyticsレポート

**期間**: YYYY-MM-DD 〜 YYYY-MM-DD
**プロジェクト**: [プロジェクト名]

---

## サマリー

| 指標 | 値 |
|------|-----|
| ページビュー | XX,XXX |
| ユニークユーザー | X,XXX |
| 平均セッション時間 | X分XX秒 |
| 直帰率 | XX% |

---

## 主要ページ

| ページ | ページビュー | 割合 |
|--------|-------------|------|
| トップページ | XX,XXX | XX% |
| 製品ページ | X,XXX | XX% |
| 問い合わせ | XXX | XX% |

---

## コンバージョン

| イベント | 回数 | コンバージョン率 |
|---------|------|----------------|
| サインアップ | XXX | X.X% |
| 購入 | XX | X.X% |
| 問い合わせ | XX | X.X% |

---

## 推奨事項

1. **トップページの改善**: 直帰率が高いため、CTAを強化
2. **製品ページの最適化**: 滞在時間が短いため、コンテンツを充実
3. **問い合わせフォームの簡略化**: 入力項目を削減してコンバージョン率を向上

---

**次回レポート**: YYYY-MM-DD
```

---

## 次のアクションを案内

> ✅ **Analytics統合が完了しました！**
>
> 📄 **生成したファイル**:
> - `app/layout.tsx` - Analytics設定
> - `lib/analytics.ts` - イベント追跡関数
> - `.claude/analytics-report-template.md` - レポートテンプレート
>
> **次にやること：**
> 1. 環境変数を `.env.local` に追加
> 2. 動作確認: `npm run dev`
> 3. イベント追跡をテスト（ブラウザのコンソールで確認）
> 4. デプロイ後、Google Analytics Dashboardでデータを確認
>
> 💡 **クライアント向け**: 定期的にレポートを作成して共有しましょう。

---

## 注意事項

- **プライバシー**: Cookie同意バナーの設置を推奨（GDPR対応）
- **テスト**: 本番環境でのみ有効化（開発環境では無効化）
- **データ保持**: Google Analyticsのデータ保持期間を設定
- **レポート**: 月次でクライアントに報告

**このAnalytics統合で、データドリブンな改善が可能になります。**
