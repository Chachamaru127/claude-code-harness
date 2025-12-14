---
description: "[オプション] UIコンポーネント生成（shadcn/ui 等）"
---

# /component - UIコンポーネント生成

shadcn/uiベースのUIコンポーネントを生成します。

## バイブコーダー向け（こう言えばOK）

- 「**ヒーローセクションを作って**」→ `/component hero`
- 「**料金表を作って**」→ `/component pricing`
- 「**何を作ればいいか分からない**」→ 目的（LP/ダッシュボード等）を聞いて提案します

## できること（成果物）

- shadcn/ui + Tailwind 前提で **UIコンポーネントを生成**し、既存スタイルへ馴染ませる
- レスポンシブ/アクセシビリティを含めて“使える形”で整える

**機能**:
- ✅ shadcn/uiコンポーネントの自動インストール
- ✅ レスポンシブ対応
- ✅ アクセシビリティ対応
- ✅ Tailwind CSSカスタマイズ

---

## 使用するスキル

このコマンドは以下のスキルを活用します：

- `ccp-work-impl-feature` - コンポーネント実装
- `ccp-review-accessibility` - アクセシビリティチェック
- `ccp-verify-build` - ビルド検証

---

## 使い方

```
/component hero
```

→ Heroセクションを生成

```
/component pricing
```

→ 料金表を生成

---

## 実行フロー

### Step 1: コンポーネントタイプの確認

ユーザーの入力を確認。入力がない場合は質問：

> 🎯 **どのコンポーネントを作成しますか？**
>
> **マーケティング**:
> 1. hero - ヒーローセクション
> 2. features - 機能紹介
> 3. pricing - 料金表
> 4. testimonials - お客様の声
> 5. cta - Call to Action
> 6. faq - よくある質問
>
> **アプリケーション**:
> 7. dashboard - ダッシュボード
> 8. table - データテーブル
> 9. form - フォーム
> 10. modal - モーダル
> 11. sidebar - サイドバー
> 12. navbar - ナビゲーションバー
>
> 番号または名前で答えてください（例: 1 または hero）

**回答を待つ**

### Step 2: shadcn/uiのセットアップ確認

> 📦 **shadcn/uiはセットアップ済みですか？**
>
> 1. はい
> 2. いいえ（今すぐセットアップする）
>
> 番号で答えてください（デフォルト: 2）

**回答を待つ**

**「いいえ」の場合、shadcn/uiをセットアップ**:

```bash
npx shadcn-ui@latest init
```

### Step 3: 必要なshadcn/uiコンポーネントのインストール

選択したコンポーネントに応じて、必要なshadcn/uiコンポーネントを自動インストール：

**例: hero の場合**

```bash
npx shadcn-ui@latest add button
```

**例: pricing の場合**

```bash
npx shadcn-ui@latest add card button badge
```

**例: table の場合**

```bash
npx shadcn-ui@latest add table input select
```

### Step 4: コンポーネントファイルの生成

選択したコンポーネントに応じて、ファイルを生成：

---

## コンポーネント例

### 1. Hero

#### `components/marketing/hero.tsx`

```typescript
import { Button } from '@/components/ui/button'
import Link from 'next/link'

export function Hero() {
  return (
    <section className="relative overflow-hidden bg-gradient-to-b from-blue-50 to-white py-20 sm:py-32">
      <div className="container mx-auto px-4">
        <div className="mx-auto max-w-3xl text-center">
          <h1 className="text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl">
            あなたのビジネスを
            <span className="text-blue-600">次のレベルへ</span>
          </h1>
          <p className="mt-6 text-lg leading-8 text-gray-600">
            最新のテクノロジーで、ビジネスの成長を加速します。
            今すぐ無料で始めましょう。
          </p>
          <div className="mt-10 flex items-center justify-center gap-x-6">
            <Button asChild size="lg">
              <Link href="/signup">無料で始める</Link>
            </Button>
            <Button asChild variant="outline" size="lg">
              <Link href="/demo">デモを見る</Link>
            </Button>
          </div>
        </div>
      </div>
    </section>
  )
}
```

### 2. Pricing

#### `components/marketing/pricing.tsx`

```typescript
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Check } from 'lucide-react'

const plans = [
  {
    name: 'スターター',
    price: '¥0',
    description: '個人・小規模プロジェクト向け',
    features: [
      'プロジェクト数: 3',
      'ストレージ: 1GB',
      'メンバー: 1人',
      'サポート: コミュニティ',
    ],
    cta: '無料で始める',
    popular: false,
  },
  {
    name: 'プロ',
    price: '¥2,980',
    description: '成長中のチーム向け',
    features: [
      'プロジェクト数: 無制限',
      'ストレージ: 100GB',
      'メンバー: 10人',
      'サポート: メール',
      '優先サポート',
    ],
    cta: '今すぐ始める',
    popular: true,
  },
  {
    name: 'エンタープライズ',
    price: 'お問い合わせ',
    description: '大規模組織向け',
    features: [
      'プロジェクト数: 無制限',
      'ストレージ: 無制限',
      'メンバー: 無制限',
      'サポート: 24/7電話',
      'カスタム統合',
      'SLA保証',
    ],
    cta: 'お問い合わせ',
    popular: false,
  },
]

export function Pricing() {
  return (
    <section className="py-20">
      <div className="container mx-auto px-4">
        <div className="mx-auto max-w-3xl text-center">
          <h2 className="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
            シンプルで透明な料金プラン
          </h2>
          <p className="mt-4 text-lg text-gray-600">
            あなたのビジネスに最適なプランを選びましょう
          </p>
        </div>

        <div className="mt-16 grid gap-8 md:grid-cols-3">
          {plans.map((plan) => (
            <Card key={plan.name} className={plan.popular ? 'border-blue-600 shadow-lg' : ''}>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle>{plan.name}</CardTitle>
                  {plan.popular && <Badge>人気</Badge>}
                </div>
                <CardDescription>{plan.description}</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="mb-6">
                  <span className="text-4xl font-bold">{plan.price}</span>
                  {plan.price !== 'お問い合わせ' && <span className="text-gray-600">/月</span>}
                </div>
                <ul className="space-y-3">
                  {plan.features.map((feature) => (
                    <li key={feature} className="flex items-center gap-2">
                      <Check className="h-5 w-5 text-green-600" />
                      <span className="text-sm">{feature}</span>
                    </li>
                  ))}
                </ul>
              </CardContent>
              <CardFooter>
                <Button className="w-full" variant={plan.popular ? 'default' : 'outline'}>
                  {plan.cta}
                </Button>
              </CardFooter>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}
```

### 3. Dashboard

#### `components/app/dashboard.tsx`

```typescript
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Users, DollarSign, Activity, TrendingUp } from 'lucide-react'

const stats = [
  {
    title: 'ユーザー数',
    value: '2,543',
    change: '+12.5%',
    icon: Users,
  },
  {
    title: '売上',
    value: '¥1,234,567',
    change: '+8.2%',
    icon: DollarSign,
  },
  {
    title: 'アクティブ率',
    value: '73.2%',
    change: '+3.1%',
    icon: Activity,
  },
  {
    title: '成長率',
    value: '24.5%',
    change: '+5.4%',
    icon: TrendingUp,
  },
]

export function Dashboard() {
  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-3xl font-bold tracking-tight">ダッシュボード</h2>
        <p className="text-muted-foreground">ビジネスの概要を確認しましょう</p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat) => {
          const Icon = stat.icon
          return (
            <Card key={stat.title}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">{stat.title}</CardTitle>
                <Icon className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{stat.value}</div>
                <p className="text-xs text-muted-foreground">
                  <span className="text-green-600">{stat.change}</span> 前月比
                </p>
              </CardContent>
            </Card>
          )
        })}
      </div>
    </div>
  )
}
```

### 4. Form

#### `components/app/contact-form.tsx`

```typescript
'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Label } from '@/components/ui/label'
import { useToast } from '@/components/ui/use-toast'

export function ContactForm() {
  const { toast } = useToast()
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setLoading(true)

    const formData = new FormData(e.currentTarget)
    const data = {
      name: formData.get('name'),
      email: formData.get('email'),
      message: formData.get('message'),
    }

    try {
      const res = await fetch('/api/contact', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      })

      if (res.ok) {
        toast({
          title: '送信完了',
          description: 'お問い合わせを受け付けました。',
        })
        e.currentTarget.reset()
      } else {
        throw new Error('送信に失敗しました')
      }
    } catch (error) {
      toast({
        title: 'エラー',
        description: '送信に失敗しました。もう一度お試しください。',
        variant: 'destructive',
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div>
        <Label htmlFor="name">お名前</Label>
        <Input id="name" name="name" required />
      </div>

      <div>
        <Label htmlFor="email">メールアドレス</Label>
        <Input id="email" name="email" type="email" required />
      </div>

      <div>
        <Label htmlFor="message">メッセージ</Label>
        <Textarea id="message" name="message" rows={5} required />
      </div>

      <Button type="submit" disabled={loading}>
        {loading ? '送信中...' : '送信する'}
      </Button>
    </form>
  )
}
```

---

### Step 5: レスポンシブ対応の確認

> 📱 **レスポンシブ対応を確認してください：**
>
> 1. ブラウザの開発者ツールを開く（F12）
> 2. デバイスツールバーを有効化（Ctrl+Shift+M）
> 3. モバイル、タブレット、デスクトップで表示を確認
>
> **問題があれば教えてください。**

### Step 6: 次のアクションを案内

> ✅ **コンポーネントが完成しました！**
>
> 📄 **生成したファイル**:
> - `components/marketing/{{component}}.tsx` または `components/app/{{component}}.tsx`
>
> **次にやること：**
> 1. ページに追加: `app/page.tsx` で `import { Hero } from '@/components/marketing/hero'`
> 2. カスタマイズ: テキスト、色、レイアウトを調整
> 3. 動作確認: `npm run dev`
>
> 💡 **ヒント**: Tailwind CSSのクラスを変更することで、簡単にカスタマイズできます。

---

## カスタマイズ例

### 色の変更

```typescript
// 青 → 緑
className="text-blue-600" → className="text-green-600"
className="bg-blue-50" → className="bg-green-50"
```

### レイアウトの変更

```typescript
// 3カラム → 4カラム
className="md:grid-cols-3" → className="md:grid-cols-4"
```

### アニメーションの追加

```typescript
import { motion } from 'framer-motion'

<motion.div
  initial={{ opacity: 0, y: 20 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.5 }}
>
  {/* コンテンツ */}
</motion.div>
```

---

## 注意事項

- **shadcn/ui**: コンポーネントはプロジェクトにコピーされるため、自由にカスタマイズ可能
- **Tailwind CSS**: ユーティリティファーストのCSSフレームワーク
- **アクセシビリティ**: ARIA属性、キーボードナビゲーションに対応
- **レスポンシブ**: モバイルファーストで設計

**このコマンドで、プロフェッショナルなUIを迅速に構築できます。**
