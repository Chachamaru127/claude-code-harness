---
description: "[オプション] フィードバック収集機能の実装"
---

# /feedback - フィードバック収集機能の実装

アプリ内フィードバックフォームを実装します。

**機能**:
- ✅ フィードバックフォーム
- ✅ バグ報告
- ✅ 機能リクエスト
- ✅ 満足度調査

---

## 使用するスキル

このコマンドは以下のスキルを活用します：

- `ccp-work-impl-feature` - フィードバック機能実装
- `ccp-verify-build` - ビルド検証

---

## 💡 バイブコーダー向けの使い方

**このコマンドは、クライアントやユーザーからフィードバックを収集する機能を簡単に追加できます。**

- ✅ ユーザーの声を直接収集
- ✅ バグを早期発見
- ✅ 機能改善のヒントを取得
- ✅ クライアントに改善提案を提示

**受託開発で重要**: クライアントに「ユーザーの声を聞いている」ことをアピールできます

---

## 使い方

```
/feedback
```

→ 基本的なフィードバックフォームを実装

```
/feedback full
```

→ バグ報告、機能リクエスト、満足度調査を含む完全版

---

## 実行フロー

### Step 1: フィードバックタイプの確認

ユーザーの入力を確認。入力がない場合は質問：

> 🎯 **どのタイプのフィードバック機能を実装しますか？**
>
> 1. 基本（フィードバックフォームのみ）
> 2. 完全版（バグ報告、機能リクエスト、満足度調査）
>
> 番号で答えてください（デフォルト: 2）

**回答を待つ**

---

## 基本版の実装

### Step 2: フィードバックフォームの作成

#### `components/feedback-form.tsx`

```typescript
'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { Label } from '@/components/ui/label'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { MessageSquare } from 'lucide-react'

export function FeedbackForm() {
  const [feedback, setFeedback] = useState('')
  const [loading, setLoading] = useState(false)
  const [submitted, setSubmitted] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      const res = await fetch('/api/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ feedback }),
      })

      if (res.ok) {
        setSubmitted(true)
        setFeedback('')
      } else {
        alert('送信に失敗しました')
      }
    } catch (error) {
      console.error('Feedback error:', error)
      alert('送信に失敗しました')
    } finally {
      setLoading(false)
    }
  }

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="outline" size="icon">
          <MessageSquare className="h-4 w-4" />
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>フィードバックを送信</DialogTitle>
          <DialogDescription>
            ご意見・ご要望をお聞かせください
          </DialogDescription>
        </DialogHeader>

        {submitted ? (
          <div className="py-8 text-center">
            <p className="text-lg font-semibold text-green-600">
              ✅ フィードバックを送信しました
            </p>
            <p className="mt-2 text-sm text-muted-foreground">
              ご協力ありがとうございます
            </p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <Label htmlFor="feedback">フィードバック</Label>
              <Textarea
                id="feedback"
                value={feedback}
                onChange={(e) => setFeedback(e.target.value)}
                placeholder="ご意見・ご要望をお聞かせください"
                rows={5}
                required
              />
            </div>

            <Button type="submit" className="w-full" disabled={loading}>
              {loading ? '送信中...' : '送信'}
            </Button>
          </form>
        )}
      </DialogContent>
    </Dialog>
  )
}
```

### Step 3: APIエンドポイントの作成

#### `app/api/feedback/route.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'

export async function POST(req: NextRequest) {
  try {
    const { userId } = await auth()
    const { feedback } = await req.json()

    // データベースに保存
    // await prisma.feedback.create({
    //   data: {
    //     userId,
    //     feedback,
    //     createdAt: new Date(),
    //   },
    // })

    // または、メール送信
    // await sendEmail({
    //   to: 'feedback@example.com',
    //   subject: 'New Feedback',
    //   text: feedback,
    // })

    console.log('Feedback received:', { userId, feedback })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Feedback error:', error)
    return NextResponse.json({ error: 'サーバーエラー' }, { status: 500 })
  }
}
```

---

## 完全版の実装

### Step 2: 完全版フィードバックフォームの作成

#### `components/feedback-dialog.tsx`

```typescript
'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { Label } from '@/components/ui/label'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { MessageSquare, Bug, Lightbulb, Star } from 'lucide-react'

export function FeedbackDialog() {
  const [loading, setLoading] = useState(false)
  const [submitted, setSubmitted] = useState(false)

  const handleSubmit = async (type: string, data: any) => {
    setLoading(true)

    try {
      const res = await fetch('/api/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ type, ...data }),
      })

      if (res.ok) {
        setSubmitted(true)
      } else {
        alert('送信に失敗しました')
      }
    } catch (error) {
      console.error('Feedback error:', error)
      alert('送信に失敗しました')
    } finally {
      setLoading(false)
    }
  }

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="outline">
          <MessageSquare className="mr-2 h-4 w-4" />
          フィードバック
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>フィードバック</DialogTitle>
          <DialogDescription>
            ご意見・ご要望をお聞かせください
          </DialogDescription>
        </DialogHeader>

        {submitted ? (
          <div className="py-8 text-center">
            <p className="text-lg font-semibold text-green-600">
              ✅ フィードバックを送信しました
            </p>
            <p className="mt-2 text-sm text-muted-foreground">
              ご協力ありがとうございます
            </p>
          </div>
        ) : (
          <Tabs defaultValue="feedback">
            <TabsList className="grid w-full grid-cols-4">
              <TabsTrigger value="feedback">
                <MessageSquare className="mr-2 h-4 w-4" />
                フィードバック
              </TabsTrigger>
              <TabsTrigger value="bug">
                <Bug className="mr-2 h-4 w-4" />
                バグ報告
              </TabsTrigger>
              <TabsTrigger value="feature">
                <Lightbulb className="mr-2 h-4 w-4" />
                機能リクエスト
              </TabsTrigger>
              <TabsTrigger value="rating">
                <Star className="mr-2 h-4 w-4" />
                満足度
              </TabsTrigger>
            </TabsList>

            <TabsContent value="feedback">
              <FeedbackTab onSubmit={(data) => handleSubmit('feedback', data)} loading={loading} />
            </TabsContent>

            <TabsContent value="bug">
              <BugReportTab onSubmit={(data) => handleSubmit('bug', data)} loading={loading} />
            </TabsContent>

            <TabsContent value="feature">
              <FeatureRequestTab onSubmit={(data) => handleSubmit('feature', data)} loading={loading} />
            </TabsContent>

            <TabsContent value="rating">
              <RatingTab onSubmit={(data) => handleSubmit('rating', data)} loading={loading} />
            </TabsContent>
          </Tabs>
        )}
      </DialogContent>
    </Dialog>
  )
}

function FeedbackTab({ onSubmit, loading }: { onSubmit: (data: any) => void; loading: boolean }) {
  const [feedback, setFeedback] = useState('')

  return (
    <form onSubmit={(e) => { e.preventDefault(); onSubmit({ feedback }) }} className="space-y-4">
      <div>
        <Label htmlFor="feedback">フィードバック</Label>
        <Textarea
          id="feedback"
          value={feedback}
          onChange={(e) => setFeedback(e.target.value)}
          placeholder="ご意見・ご要望をお聞かせください"
          rows={5}
          required
        />
      </div>
      <Button type="submit" className="w-full" disabled={loading}>
        {loading ? '送信中...' : '送信'}
      </Button>
    </form>
  )
}

function BugReportTab({ onSubmit, loading }: { onSubmit: (data: any) => void; loading: boolean }) {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [severity, setSeverity] = useState('medium')

  return (
    <form onSubmit={(e) => { e.preventDefault(); onSubmit({ title, description, severity }) }} className="space-y-4">
      <div>
        <Label htmlFor="bug-title">タイトル</Label>
        <Input
          id="bug-title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="バグの概要"
          required
        />
      </div>
      <div>
        <Label htmlFor="bug-description">詳細</Label>
        <Textarea
          id="bug-description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="バグの詳細、再現手順など"
          rows={5}
          required
        />
      </div>
      <div>
        <Label htmlFor="severity">重要度</Label>
        <Select value={severity} onValueChange={setSeverity}>
          <SelectTrigger>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="low">低</SelectItem>
            <SelectItem value="medium">中</SelectItem>
            <SelectItem value="high">高</SelectItem>
            <SelectItem value="critical">緊急</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <Button type="submit" className="w-full" disabled={loading}>
        {loading ? '送信中...' : '送信'}
      </Button>
    </form>
  )
}

function FeatureRequestTab({ onSubmit, loading }: { onSubmit: (data: any) => void; loading: boolean }) {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [priority, setPriority] = useState('medium')

  return (
    <form onSubmit={(e) => { e.preventDefault(); onSubmit({ title, description, priority }) }} className="space-y-4">
      <div>
        <Label htmlFor="feature-title">タイトル</Label>
        <Input
          id="feature-title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="機能の概要"
          required
        />
      </div>
      <div>
        <Label htmlFor="feature-description">詳細</Label>
        <Textarea
          id="feature-description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="機能の詳細、ユースケースなど"
          rows={5}
          required
        />
      </div>
      <div>
        <Label htmlFor="priority">優先度</Label>
        <Select value={priority} onValueChange={setPriority}>
          <SelectTrigger>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="low">低</SelectItem>
            <SelectItem value="medium">中</SelectItem>
            <SelectItem value="high">高</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <Button type="submit" className="w-full" disabled={loading}>
        {loading ? '送信中...' : '送信'}
      </Button>
    </form>
  )
}

function RatingTab({ onSubmit, loading }: { onSubmit: (data: any) => void; loading: boolean }) {
  const [rating, setRating] = useState(0)
  const [comment, setComment] = useState('')

  return (
    <form onSubmit={(e) => { e.preventDefault(); onSubmit({ rating, comment }) }} className="space-y-4">
      <div>
        <Label>満足度</Label>
        <div className="flex gap-2 mt-2">
          {[1, 2, 3, 4, 5].map((star) => (
            <button
              key={star}
              type="button"
              onClick={() => setRating(star)}
              className={`text-3xl ${star <= rating ? 'text-yellow-500' : 'text-gray-300'}`}
            >
              ★
            </button>
          ))}
        </div>
      </div>
      <div>
        <Label htmlFor="rating-comment">コメント（任意）</Label>
        <Textarea
          id="rating-comment"
          value={comment}
          onChange={(e) => setComment(e.target.value)}
          placeholder="ご意見をお聞かせください"
          rows={3}
        />
      </div>
      <Button type="submit" className="w-full" disabled={loading || rating === 0}>
        {loading ? '送信中...' : '送信'}
      </Button>
    </form>
  )
}
```

---

## 次のアクションを案内

> ✅ **フィードバック機能が完成しました！**
>
> 📄 **生成したファイル**:
> - `components/feedback-dialog.tsx` - フィードバックフォーム
> - `app/api/feedback/route.ts` - APIエンドポイント
>
> **次にやること：**
> 1. レイアウトにフィードバックボタンを追加
> 2. データベーススキーマを作成（Prisma）
> 3. 動作確認: `npm run dev`
> 4. フィードバックを定期的に確認
>
> 💡 **クライアント向け**: 収集したフィードバックを定期レポートとして共有しましょう。

---

## 注意事項

- **プライバシー**: 個人情報の取り扱いに注意
- **スパム対策**: reCAPTCHAの導入を推奨
- **通知**: 新しいフィードバックをメールで通知
- **分析**: 定期的にフィードバックを分析して改善

**このフィードバック機能で、ユーザーの声を活かした改善が可能になります。**
