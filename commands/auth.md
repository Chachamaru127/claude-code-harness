# /auth - 認証機能の実装

Clerk または Supabase Auth を使用した認証機能を実装します。

**機能**:
- ✅ サインアップ/ログイン
- ✅ ソーシャルログイン（Google, GitHub）
- ✅ メール認証
- ✅ パスワードリセット
- ✅ ユーザープロフィール管理

---

## 使い方

```
/auth clerk
```

または

```
/auth supabase
```

→ 認証機能を実装

---

## 実行フロー

### Step 1: 認証プロバイダーの確認

ユーザーの入力を確認。入力がない場合は質問：

> 🎯 **どの認証プロバイダーを使用しますか？**
>
> 1. Clerk（推奨: 簡単、高機能）
> 2. Supabase Auth（推奨: Supabase使用時）
> 3. NextAuth.js（カスタマイズ重視）
>
> 番号で答えてください（デフォルト: 1）

**回答を待つ**

---

## Clerkの場合

### Step 2: Clerkプロジェクトの作成ガイド

> 📦 **Clerkプロジェクトを作成してください：**
>
> 1. https://clerk.com にアクセス
> 2. 「Start Building」をクリック
> 3. アプリケーション名を入力
> 4. 「Create application」をクリック
> 5. APIキーをコピー:
>    - `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
>    - `CLERK_SECRET_KEY`
>
> **完了したら「OK」と答えてください。**

**回答を待つ**

### Step 3: パッケージのインストール

```bash
npm install @clerk/nextjs
```

### Step 4: 環境変数の設定

#### `.env.local`

```env
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...
```

### Step 5: Clerk Providerの設定

#### `app/layout.tsx`

```typescript
import { ClerkProvider } from '@clerk/nextjs'
import { jaJP } from '@clerk/localizations'

export default function RootLayout({ children }: { children: React.Node }) {
  return (
    <ClerkProvider localization={jaJP}>
      <html lang="ja">
        <body>{children}</body>
      </html>
    </ClerkProvider>
  )
}
```

### Step 6: ミドルウェアの設定

#### `middleware.ts`

```typescript
import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'

const isPublicRoute = createRouteMatcher([
  '/',
  '/sign-in(.*)',
  '/sign-up(.*)',
  '/api/public(.*)',
])

export default clerkMiddleware((auth, request) => {
  if (!isPublicRoute(request)) {
    auth().protect()
  }
})

export const config = {
  matcher: [
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    '/(api|trpc)(.*)',
  ],
}
```

### Step 7: 認証ページの作成

#### `app/sign-in/[[...sign-in]]/page.tsx`

```typescript
import { SignIn } from '@clerk/nextjs'

export default function SignInPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <SignIn
        appearance={{
          elements: {
            rootBox: 'mx-auto',
            card: 'shadow-lg',
          },
        }}
      />
    </div>
  )
}
```

#### `app/sign-up/[[...sign-up]]/page.tsx`

```typescript
import { SignUp } from '@clerk/nextjs'

export default function SignUpPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <SignUp
        appearance={{
          elements: {
            rootBox: 'mx-auto',
            card: 'shadow-lg',
          },
        }}
      />
    </div>
  )
}
```

### Step 8: ユーザー情報の取得

#### `app/dashboard/page.tsx`

```typescript
import { auth, currentUser } from '@clerk/nextjs/server'
import { redirect } from 'next/navigation'

export default async function DashboardPage() {
  const { userId } = await auth()
  
  if (!userId) {
    redirect('/sign-in')
  }

  const user = await currentUser()

  return (
    <div>
      <h1>ダッシュボード</h1>
      <p>ようこそ、{user?.firstName}さん！</p>
      <p>メール: {user?.emailAddresses[0]?.emailAddress}</p>
    </div>
  )
}
```

### Step 9: クライアントコンポーネントでの使用

#### `components/user-button.tsx`

```typescript
'use client'

import { UserButton, useUser } from '@clerk/nextjs'

export function UserNav() {
  const { user } = useUser()

  return (
    <div className="flex items-center gap-4">
      <span>{user?.firstName}</span>
      <UserButton
        appearance={{
          elements: {
            avatarBox: 'w-10 h-10',
          },
        }}
      />
    </div>
  )
}
```

---

## Supabase Authの場合

### Step 2: Supabaseプロジェクトの作成ガイド

> 📦 **Supabaseプロジェクトを作成してください：**
>
> 1. https://supabase.com にアクセス
> 2. 「New project」をクリック
> 3. プロジェクト名、データベースパスワードを入力
> 4. APIキーをコピー:
>    - `NEXT_PUBLIC_SUPABASE_URL`
>    - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
>
> **完了したら「OK」と答えてください。**

**回答を待つ**

### Step 3: パッケージのインストール

```bash
npm install @supabase/supabase-js @supabase/ssr
```

### Step 4: 環境変数の設定

#### `.env.local`

```env
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Step 5: Supabaseクライアントの設定

#### `lib/supabase/client.ts`

```typescript
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
```

#### `lib/supabase/server.ts`

```typescript
import { createServerClient, type CookieOptions } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookieStore.get(name)?.value
        },
        set(name: string, value: string, options: CookieOptions) {
          try {
            cookieStore.set({ name, value, ...options })
          } catch (error) {
            // Server Component内では無視
          }
        },
        remove(name: string, options: CookieOptions) {
          try {
            cookieStore.set({ name, value: '', ...options })
          } catch (error) {
            // Server Component内では無視
          }
        },
      },
    }
  )
}
```

### Step 6: 認証ページの作成

#### `app/sign-in/page.tsx`

```typescript
'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useRouter } from 'next/navigation'

export default function SignInPage() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const supabase = createClient()

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })

    if (error) {
      alert(error.message)
    } else {
      router.push('/dashboard')
    }

    setLoading(false)
  }

  const handleGoogleSignIn = async () => {
    await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${location.origin}/auth/callback`,
      },
    })
  }

  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="w-full max-w-md space-y-8 p-8">
        <h2 className="text-center text-3xl font-bold">ログイン</h2>

        <form onSubmit={handleSignIn} className="space-y-6">
          <div>
            <Label htmlFor="email">メールアドレス</Label>
            <Input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>

          <div>
            <Label htmlFor="password">パスワード</Label>
            <Input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <Button type="submit" className="w-full" disabled={loading}>
            {loading ? 'ログイン中...' : 'ログイン'}
          </Button>
        </form>

        <div className="relative">
          <div className="absolute inset-0 flex items-center">
            <span className="w-full border-t" />
          </div>
          <div className="relative flex justify-center text-xs uppercase">
            <span className="bg-background px-2 text-muted-foreground">または</span>
          </div>
        </div>

        <Button onClick={handleGoogleSignIn} variant="outline" className="w-full">
          Googleでログイン
        </Button>
      </div>
    </div>
  )
}
```

#### `app/auth/callback/route.ts`

```typescript
import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  const next = searchParams.get('next') ?? '/dashboard'

  if (code) {
    const supabase = await createClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`)
    }
  }

  return NextResponse.redirect(`${origin}/sign-in`)
}
```

### Step 7: ユーザー情報の取得

#### `app/dashboard/page.tsx`

```typescript
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function DashboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/sign-in')
  }

  return (
    <div>
      <h1>ダッシュボード</h1>
      <p>ようこそ、{user.email}さん！</p>
    </div>
  )
}
```

---

## 共通: 次のアクションを案内

> ✅ **認証機能が完成しました！**
>
> 📄 **生成したファイル**:
> - `middleware.ts` - 認証ミドルウェア
> - `app/sign-in/page.tsx` - ログインページ
> - `app/sign-up/page.tsx` - サインアップページ
> - `lib/supabase/client.ts` または Clerk設定
>
> **次にやること：**
> 1. 環境変数を `.env.local` に追加
> 2. 動作確認: `npm run dev`
> 3. サインアップ/ログインをテスト
>
> 💡 **ヒント**: ソーシャルログインを有効化するには、各プロバイダーの設定が必要です。

---

## ソーシャルログインの設定

### Clerk

1. Clerk Dashboard > Configure > Social Connections
2. Google/GitHubを有効化
3. OAuth Redirect URLを設定

### Supabase

1. Supabase Dashboard > Authentication > Providers
2. Google/GitHubを有効化
3. Client IDとClient Secretを入力

---

## 注意事項

- **セキュリティ**: APIキーは `.env.local` に保存し、Gitにコミットしない
- **ミドルウェア**: 保護されたルートへのアクセスを制御
- **リダイレクト**: 認証後のリダイレクト先を適切に設定
- **エラーハンドリング**: ユーザーフレンドリーなエラーメッセージを表示

**この認証機能で、安全なユーザー管理が実現できます。**
