# /payments - 決済機能の実装

Stripeを使用した決済機能を実装します。

**機能**:
- ✅ サブスクリプション（月額/年額）
- ✅ 一回払い
- ✅ Webhook（決済完了通知）
- ✅ 顧客ポータル（プラン変更、キャンセル）

---

## 使い方

```
/payments subscription
```

→ サブスクリプション決済を実装

```
/payments one-time
```

→ 一回払い決済を実装

---

## 実行フロー

### Step 1: 決済タイプの確認

ユーザーの入力を確認。入力がない場合は質問：

> 🎯 **どの決済タイプを実装しますか？**
>
> 1. サブスクリプション（月額/年額課金）
> 2. 一回払い（買い切り）
> 3. 両方
>
> 番号で答えてください（デフォルト: 1）

**回答を待つ**

### Step 2: Stripeアカウントの作成ガイド

> 📦 **Stripeアカウントを作成してください：**
>
> 1. https://stripe.com にアクセス
> 2. 「今すぐ始める」をクリック
> 3. アカウント情報を入力
> 4. APIキーをコピー（Developers > API keys）:
>    - `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`（公開可能キー）
>    - `STRIPE_SECRET_KEY`（シークレットキー）
>
> **完了したら「OK」と答えてください。**

**回答を待つ**

### Step 3: パッケージのインストール

```bash
npm install stripe @stripe/stripe-js
```

### Step 4: 環境変数の設定

#### `.env.local`

```env
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

---

## サブスクリプションの場合

### Step 5: Stripe製品とプランの作成ガイド

> 💳 **Stripe Dashboardで製品を作成してください：**
>
> 1. Stripe Dashboard > Products > Add product
> 2. 製品名: 「プロプラン」
> 3. 価格: ¥2,980/月
> 4. 「Create product」をクリック
> 5. Price IDをコピー: `price_xxx`
>
> **複数のプランがある場合、それぞれ作成してください。**
>
> **完了したら「OK」と答えてください。**

**回答を待つ**

### Step 6: Stripeクライアントの設定

#### `lib/stripe/client.ts`

```typescript
import { loadStripe, Stripe } from '@stripe/stripe-js'

let stripePromise: Promise<Stripe | null>

export function getStripe() {
  if (!stripePromise) {
    stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)
  }
  return stripePromise
}
```

#### `lib/stripe/server.ts`

```typescript
import Stripe from 'stripe'

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2024-11-20.acacia',
  typescript: true,
})
```

### Step 7: チェックアウトAPIの作成

#### `app/api/checkout/route.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { stripe } from '@/lib/stripe/server'

export async function POST(req: NextRequest) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: '認証が必要です' }, { status: 401 })
    }

    const { priceId } = await req.json()

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: `${req.nextUrl.origin}/dashboard?success=true`,
      cancel_url: `${req.nextUrl.origin}/pricing?canceled=true`,
      metadata: {
        userId,
      },
    })

    return NextResponse.json({ sessionId: session.id })
  } catch (error) {
    console.error('Checkout error:', error)
    return NextResponse.json({ error: 'サーバーエラー' }, { status: 500 })
  }
}
```

### Step 8: チェックアウトボタンの作成

#### `components/checkout-button.tsx`

```typescript
'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { getStripe } from '@/lib/stripe/client'

interface CheckoutButtonProps {
  priceId: string
  children: React.ReactNode
}

export function CheckoutButton({ priceId, children }: CheckoutButtonProps) {
  const [loading, setLoading] = useState(false)

  const handleCheckout = async () => {
    setLoading(true)

    try {
      const res = await fetch('/api/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ priceId }),
      })

      const { sessionId } = await res.json()
      const stripe = await getStripe()
      await stripe?.redirectToCheckout({ sessionId })
    } catch (error) {
      console.error('Checkout error:', error)
      alert('決済処理に失敗しました')
    } finally {
      setLoading(false)
    }
  }

  return (
    <Button onClick={handleCheckout} disabled={loading}>
      {loading ? '処理中...' : children}
    </Button>
  )
}
```

### Step 9: Webhookの設定

#### `app/api/webhooks/stripe/route.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { stripe } from '@/lib/stripe/server'
import { headers } from 'next/headers'
import Stripe from 'stripe'

export async function POST(req: NextRequest) {
  const body = await req.text()
  const signature = (await headers()).get('stripe-signature')!

  let event: Stripe.Event

  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    )
  } catch (error) {
    console.error('Webhook signature verification failed:', error)
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 })
  }

  // イベント処理
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.Checkout.Session
      const userId = session.metadata?.userId

      // データベースに保存
      // await prisma.subscription.create({
      //   data: {
      //     userId,
      //     stripeCustomerId: session.customer as string,
      //     stripeSubscriptionId: session.subscription as string,
      //     status: 'active',
      //   },
      // })

      console.log('Subscription created:', userId)
      break
    }

    case 'customer.subscription.updated': {
      const subscription = event.data.object as Stripe.Subscription
      
      // データベースを更新
      // await prisma.subscription.update({
      //   where: { stripeSubscriptionId: subscription.id },
      //   data: { status: subscription.status },
      // })

      console.log('Subscription updated:', subscription.id)
      break
    }

    case 'customer.subscription.deleted': {
      const subscription = event.data.object as Stripe.Subscription

      // データベースを更新
      // await prisma.subscription.update({
      //   where: { stripeSubscriptionId: subscription.id },
      //   data: { status: 'canceled' },
      // })

      console.log('Subscription canceled:', subscription.id)
      break
    }

    default:
      console.log(`Unhandled event type: ${event.type}`)
  }

  return NextResponse.json({ received: true })
}
```

### Step 10: 顧客ポータルの設定

#### `app/api/portal/route.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { stripe } from '@/lib/stripe/server'

export async function POST(req: NextRequest) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: '認証が必要です' }, { status: 401 })
    }

    // データベースからStripe Customer IDを取得
    // const subscription = await prisma.subscription.findUnique({
    //   where: { userId },
    // })

    const customerId = 'cus_xxx' // subscription.stripeCustomerId

    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: `${req.nextUrl.origin}/dashboard`,
    })

    return NextResponse.json({ url: session.url })
  } catch (error) {
    console.error('Portal error:', error)
    return NextResponse.json({ error: 'サーバーエラー' }, { status: 500 })
  }
}
```

#### `components/manage-subscription-button.tsx`

```typescript
'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'

export function ManageSubscriptionButton() {
  const [loading, setLoading] = useState(false)

  const handleManage = async () => {
    setLoading(true)

    try {
      const res = await fetch('/api/portal', { method: 'POST' })
      const { url } = await res.json()
      window.location.href = url
    } catch (error) {
      console.error('Portal error:', error)
      alert('処理に失敗しました')
    } finally {
      setLoading(false)
    }
  }

  return (
    <Button onClick={handleManage} disabled={loading} variant="outline">
      {loading ? '処理中...' : 'サブスクリプション管理'}
    </Button>
  )
}
```

---

## 一回払いの場合

### Step 5: チェックアウトAPIの作成

#### `app/api/checkout/route.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { stripe } from '@/lib/stripe/server'

export async function POST(req: NextRequest) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: '認証が必要です' }, { status: 401 })
    }

    const { amount, productName } = await req.json()

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'jpy',
            product_data: {
              name: productName,
            },
            unit_amount: amount,
          },
          quantity: 1,
        },
      ],
      success_url: `${req.nextUrl.origin}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${req.nextUrl.origin}/canceled`,
      metadata: {
        userId,
        productName,
      },
    })

    return NextResponse.json({ sessionId: session.id })
  } catch (error) {
    console.error('Checkout error:', error)
    return NextResponse.json({ error: 'サーバーエラー' }, { status: 500 })
  }
}
```

---

## 共通: Webhook設定ガイド

> 🔗 **Stripe Webhookを設定してください：**
>
> **ローカル開発の場合**:
> 1. Stripe CLIをインストール: https://stripe.com/docs/stripe-cli
> 2. ログイン: `stripe login`
> 3. Webhookを転送: `stripe listen --forward-to localhost:3000/api/webhooks/stripe`
> 4. Webhook Secretをコピーして `.env.local` に追加
>
> **本番環境の場合**:
> 1. Stripe Dashboard > Developers > Webhooks > Add endpoint
> 2. Endpoint URL: `https://yourdomain.com/api/webhooks/stripe`
> 3. イベントを選択:
>    - `checkout.session.completed`
>    - `customer.subscription.updated`
>    - `customer.subscription.deleted`
> 4. Webhook Secretをコピーして環境変数に追加
>
> **完了したら「OK」と答えてください。**

**回答を待つ**

---

## 次のアクションを案内

> ✅ **決済機能が完成しました！**
>
> 📄 **生成したファイル**:
> - `lib/stripe/client.ts` - Stripeクライアント
> - `lib/stripe/server.ts` - Stripeサーバー
> - `app/api/checkout/route.ts` - チェックアウトAPI
> - `app/api/webhooks/stripe/route.ts` - Webhook
> - `app/api/portal/route.ts` - 顧客ポータル（サブスクリプションのみ）
> - `components/checkout-button.tsx` - チェックアウトボタン
>
> **次にやること：**
> 1. 環境変数を `.env.local` に追加
> 2. Webhookを設定（上記ガイド参照）
> 3. テストカードで動作確認:
>    - カード番号: `4242 4242 4242 4242`
>    - 有効期限: 任意の未来の日付
>    - CVC: 任意の3桁
>
> 💡 **ヒント**: 本番環境に移行する前に、Stripeのテストモードで十分にテストしてください。

---

## テストカード

| カード番号 | 用途 |
|-----------|------|
| 4242 4242 4242 4242 | 成功 |
| 4000 0000 0000 0002 | 失敗（カード拒否） |
| 4000 0000 0000 9995 | 失敗（残高不足） |
| 4000 0025 0000 3155 | 3Dセキュア認証が必要 |

---

## 注意事項

- **テストモード**: 本番環境に移行する前に、十分にテスト
- **Webhook**: 決済完了の通知を受け取るために必須
- **セキュリティ**: APIキーは `.env.local` に保存し、Gitにコミットしない
- **手数料**: Stripeの手数料は3.6%（日本国内発行カード）

**この決済機能で、安全な課金システムが実現できます。**
