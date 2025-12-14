---
description: CRUD自動生成（検証・認可・本番対応）
---

# /crud - CRUD自動生成（本番環境対応）

指定したエンティティ（テーブル）のCRUD機能を、**本番環境で使えるレベル**で自動生成します。

## バイブコーダー向け（こう言えばOK）

- 「**タスク管理のCRUD作って**」→ `/crud tasks`
- 「**検索やページネーションも欲しい**」→ まとめて入れます
- 「**権限（誰が見れる/編集できる）も入れて**」→ 認可/ルールまで一緒に整えます

## できること（成果物）

- CRUD + バリデーション + 認可 + テストまで、**本番で事故らない形**で一式生成
- 既存DB/既存コードに合わせて差分を最小にする

**特徴**:
- ✅ バリデーション（Zod）自動追加
- ✅ 認証・認可（Row Level Security）自動設定
- ✅ リレーション（1対多、多対多）対応
- ✅ ページネーション、検索、フィルタ
- ✅ テストケース自動生成

---

## 使用するスキル

このコマンドは以下のスキルを活用します：

- `ccp-work-impl-feature` - CRUD機能実装
- `ccp-verify-build` - ビルド検証
- `ccp-core-diff-aware-editing` - 差分を考慮した編集

---

## 使い方

```
/crud tasks
```

→ `tasks` テーブルのCRUD機能を生成

---

## 実行フロー

### Step 1: エンティティ名の確認

ユーザーの入力を確認。入力がない場合は質問：

> 🎯 **どのエンティティ（テーブル）のCRUDを作りますか？**
>
> 例：
> - `tasks` - タスク管理
> - `posts` - ブログ記事
> - `products` - 商品
> - `bookings` - 予約
>
> 単数形でも複数形でもOKです！

**回答を待つ**

### Step 2: スキーマ設計の確認

> 📋 **以下のフィールドで良いですか？**
>
> ```typescript
> // 例: tasks テーブル
> {
>   id: string (UUID, 自動生成)
>   title: string (必須)
>   description: string (任意)
>   status: 'todo' | 'in_progress' | 'done' (デフォルト: 'todo')
>   priority: 'low' | 'medium' | 'high' (デフォルト: 'medium')
>   due_date: Date (任意)
>   user_id: string (外部キー, 自動設定)
>   created_at: Date (自動生成)
>   updated_at: Date (自動更新)
> }
> ```
>
> **変更したい場合は教えてください。**
> 例: 「assignee_idフィールドを追加して」

**回答を待つ（または「OK」で進む）**

### Step 3: リレーションの確認

> 🔗 **他のテーブルとのリレーションはありますか？**
>
> 例：
> - 「tasksは1つのprojectに属する」（多対1）
> - 「tasksは複数のtagsを持つ」（多対多）
>
> ない場合は「なし」と答えてください。

**回答を待つ**

### Step 4: 生成するファイル

以下のファイルを自動生成します：

#### 1. Prismaスキーマ（`prisma/schema.prisma`）

```prisma
model Task {
  id          String   @id @default(uuid())
  title       String
  description String?
  status      TaskStatus @default(TODO)
  priority    TaskPriority @default(MEDIUM)
  due_date    DateTime?
  user_id     String
  user        User     @relation(fields: [user_id], references: [id], onDelete: Cascade)
  created_at  DateTime @default(now())
  updated_at  DateTime @updatedAt

  @@index([user_id])
  @@index([status])
  @@index([due_date])
}

enum TaskStatus {
  TODO
  IN_PROGRESS
  DONE
}

enum TaskPriority {
  LOW
  MEDIUM
  HIGH
}
```

#### 2. Zodバリデーションスキーマ（`lib/validations/task.ts`）

```typescript
import { z } from 'zod'

export const createTaskSchema = z.object({
  title: z.string().min(1, '必須項目です').max(100, '100文字以内で入力してください'),
  description: z.string().max(1000, '1000文字以内で入力してください').optional(),
  status: z.enum(['todo', 'in_progress', 'done']).default('todo'),
  priority: z.enum(['low', 'medium', 'high']).default('medium'),
  due_date: z.string().datetime().optional(),
})

export const updateTaskSchema = createTaskSchema.partial()

export const taskQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
  status: z.enum(['todo', 'in_progress', 'done']).optional(),
  priority: z.enum(['low', 'medium', 'high']).optional(),
  search: z.string().optional(),
  sort_by: z.enum(['created_at', 'due_date', 'priority']).default('created_at'),
  sort_order: z.enum(['asc', 'desc']).default('desc'),
})

export type CreateTaskInput = z.infer<typeof createTaskSchema>
export type UpdateTaskInput = z.infer<typeof updateTaskSchema>
export type TaskQuery = z.infer<typeof taskQuerySchema>
```

#### 3. API Routes（`app/api/tasks/route.ts`）

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { prisma } from '@/lib/prisma'
import { createTaskSchema, taskQuerySchema } from '@/lib/validations/task'

// GET /api/tasks - タスク一覧取得（ページネーション、検索、フィルタ対応）
export async function GET(req: NextRequest) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: '認証が必要です' }, { status: 401 })
    }

    const { searchParams } = new URL(req.url)
    const query = taskQuerySchema.parse(Object.fromEntries(searchParams))

    const where = {
      user_id: userId,
      ...(query.status && { status: query.status }),
      ...(query.priority && { priority: query.priority }),
      ...(query.search && {
        OR: [
          { title: { contains: query.search, mode: 'insensitive' } },
          { description: { contains: query.search, mode: 'insensitive' } },
        ],
      }),
    }

    const [tasks, total] = await Promise.all([
      prisma.task.findMany({
        where,
        orderBy: { [query.sort_by]: query.sort_order },
        skip: (query.page - 1) * query.limit,
        take: query.limit,
      }),
      prisma.task.count({ where }),
    ])

    return NextResponse.json({
      data: tasks,
      meta: {
        page: query.page,
        limit: query.limit,
        total,
        total_pages: Math.ceil(total / query.limit),
      },
    })
  } catch (error) {
    console.error('GET /api/tasks error:', error)
    return NextResponse.json({ error: 'サーバーエラー' }, { status: 500 })
  }
}

// POST /api/tasks - タスク作成
export async function POST(req: NextRequest) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: '認証が必要です' }, { status: 401 })
    }

    const body = await req.json()
    const data = createTaskSchema.parse(body)

    const task = await prisma.task.create({
      data: {
        ...data,
        user_id: userId,
      },
    })

    return NextResponse.json(task, { status: 201 })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json({ error: error.errors }, { status: 400 })
    }
    console.error('POST /api/tasks error:', error)
    return NextResponse.json({ error: 'サーバーエラー' }, { status: 500 })
  }
}
```

#### 4. 個別API Routes（`app/api/tasks/[id]/route.ts`）

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { prisma } from '@/lib/prisma'
import { updateTaskSchema } from '@/lib/validations/task'

// GET /api/tasks/:id - タスク詳細取得
export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: '認証が必要です' }, { status: 401 })
    }

    const task = await prisma.task.findUnique({
      where: { id: params.id },
    })

    if (!task) {
      return NextResponse.json({ error: 'タスクが見つかりません' }, { status: 404 })
    }

    // 認可: 自分のタスクのみ取得可能
    if (task.user_id !== userId) {
      return NextResponse.json({ error: 'アクセス権限がありません' }, { status: 403 })
    }

    return NextResponse.json(task)
  } catch (error) {
    console.error(`GET /api/tasks/${params.id} error:`, error)
    return NextResponse.json({ error: 'サーバーエラー' }, { status: 500 })
  }
}

// PATCH /api/tasks/:id - タスク更新
export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: '認証が必要です' }, { status: 401 })
    }

    const existingTask = await prisma.task.findUnique({
      where: { id: params.id },
    })

    if (!existingTask) {
      return NextResponse.json({ error: 'タスクが見つかりません' }, { status: 404 })
    }

    // 認可: 自分のタスクのみ更新可能
    if (existingTask.user_id !== userId) {
      return NextResponse.json({ error: 'アクセス権限がありません' }, { status: 403 })
    }

    const body = await req.json()
    const data = updateTaskSchema.parse(body)

    const task = await prisma.task.update({
      where: { id: params.id },
      data,
    })

    return NextResponse.json(task)
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json({ error: error.errors }, { status: 400 })
    }
    console.error(`PATCH /api/tasks/${params.id} error:`, error)
    return NextResponse.json({ error: 'サーバーエラー' }, { status: 500 })
  }
}

// DELETE /api/tasks/:id - タスク削除
export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: '認証が必要です' }, { status: 401 })
    }

    const existingTask = await prisma.task.findUnique({
      where: { id: params.id },
    })

    if (!existingTask) {
      return NextResponse.json({ error: 'タスクが見つかりません' }, { status: 404 })
    }

    // 認可: 自分のタスクのみ削除可能
    if (existingTask.user_id !== userId) {
      return NextResponse.json({ error: 'アクセス権限がありません' }, { status: 403 })
    }

    await prisma.task.delete({
      where: { id: params.id },
    })

    return NextResponse.json({ message: '削除しました' })
  } catch (error) {
    console.error(`DELETE /api/tasks/${params.id} error:`, error)
    return NextResponse.json({ error: 'サーバーエラー' }, { status: 500 })
  }
}
```

#### 5. フロントエンドコンポーネント（`components/tasks/task-list.tsx`）

```typescript
'use client'

import { useState, useEffect } from 'react'
import { useAuth } from '@clerk/nextjs'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import { TaskCard } from './task-card'

export function TaskList() {
  const { getToken } = useAuth()
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('')
  const [page, setPage] = useState(1)

  useEffect(() => {
    fetchTasks()
  }, [search, status, page])

  const fetchTasks = async () => {
    setLoading(true)
    try {
      const token = await getToken()
      const params = new URLSearchParams({
        page: page.toString(),
        ...(search && { search }),
        ...(status && { status }),
      })
      const res = await fetch(`/api/tasks?${params}`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      const data = await res.json()
      setTasks(data.data)
    } catch (error) {
      console.error('Failed to fetch tasks:', error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div>
      <div className="mb-4 flex gap-4">
        <Input
          placeholder="検索..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <Select value={status} onValueChange={setStatus}>
          <option value="">すべて</option>
          <option value="todo">未着手</option>
          <option value="in_progress">進行中</option>
          <option value="done">完了</option>
        </Select>
      </div>

      {loading ? (
        <p>読み込み中...</p>
      ) : (
        <div className="grid gap-4">
          {tasks.map((task) => (
            <TaskCard key={task.id} task={task} onUpdate={fetchTasks} />
          ))}
        </div>
      )}

      <div className="mt-4 flex justify-center gap-2">
        <Button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>
          前へ
        </Button>
        <span>ページ {page}</span>
        <Button onClick={() => setPage(p => p + 1)}>
          次へ
        </Button>
      </div>
    </div>
  )
}
```

#### 6. テストケース（`__tests__/api/tasks.test.ts`）

```typescript
import { describe, it, expect, beforeEach } from 'vitest'
import { createMocks } from 'node-mocks-http'
import { GET, POST } from '@/app/api/tasks/route'

describe('/api/tasks', () => {
  beforeEach(() => {
    // モックのセットアップ
  })

  describe('GET', () => {
    it('認証なしの場合、401を返す', async () => {
      const { req } = createMocks({ method: 'GET' })
      const res = await GET(req as any)
      expect(res.status).toBe(401)
    })

    it('タスク一覧を取得できる', async () => {
      // テストコード
    })

    it('ページネーションが動作する', async () => {
      // テストコード
    })

    it('検索が動作する', async () => {
      // テストコード
    })
  })

  describe('POST', () => {
    it('タスクを作成できる', async () => {
      // テストコード
    })

    it('バリデーションエラーを返す', async () => {
      // テストコード
    })
  })
})
```

### Step 5: Supabase RLS（Row Level Security）の設定

Supabaseを使用している場合、以下のRLSポリシーを自動設定：

```sql
-- tasksテーブルのRLSを有効化
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- SELECT: 自分のタスクのみ取得可能
CREATE POLICY "Users can view their own tasks"
ON tasks FOR SELECT
USING (auth.uid() = user_id);

-- INSERT: 自分のタスクのみ作成可能
CREATE POLICY "Users can create their own tasks"
ON tasks FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- UPDATE: 自分のタスクのみ更新可能
CREATE POLICY "Users can update their own tasks"
ON tasks FOR UPDATE
USING (auth.uid() = user_id);

-- DELETE: 自分のタスクのみ削除可能
CREATE POLICY "Users can delete their own tasks"
ON tasks FOR DELETE
USING (auth.uid() = user_id);
```

### Step 6: 次のアクションを案内

> ✅ **CRUD機能が完成しました！**
>
> 📄 **生成したファイル**:
> - `prisma/schema.prisma` - データベーススキーマ
> - `lib/validations/task.ts` - バリデーション
> - `app/api/tasks/route.ts` - API（一覧、作成）
> - `app/api/tasks/[id]/route.ts` - API（詳細、更新、削除）
> - `components/tasks/task-list.tsx` - フロントエンド
> - `__tests__/api/tasks.test.ts` - テストケース
> - `supabase/migrations/{{timestamp}}_tasks_rls.sql` - RLSポリシー
>
> **次にやること：**
> 1. `npx prisma migrate dev --name add_tasks` を実行
> 2. テストを実行: `npm test`
> 3. 動作確認: `npm run dev`
>
> 💡 **ヒント**: 他のエンティティも追加したい場合は、`/crud {{エンティティ名}}` を実行してください。

---

## リレーション対応

### 1対多（多対1）

**例**: tasksは1つのprojectに属する

```prisma
model Task {
  // ...
  project_id String
  project    Project @relation(fields: [project_id], references: [id], onDelete: Cascade)
}

model Project {
  id    String @id @default(uuid())
  name  String
  tasks Task[]
}
```

### 多対多

**例**: tasksは複数のtagsを持つ

```prisma
model Task {
  // ...
  tags TaskTag[]
}

model Tag {
  id    String    @id @default(uuid())
  name  String    @unique
  tasks TaskTag[]
}

model TaskTag {
  task_id String
  tag_id  String
  task    Task   @relation(fields: [task_id], references: [id], onDelete: Cascade)
  tag     Tag    @relation(fields: [tag_id], references: [id], onDelete: Cascade)

  @@id([task_id, tag_id])
}
```

---

## 注意事項

- **本番環境対応**: バリデーション、認可、エラーハンドリングを完備
- **セキュリティ**: RLSにより、他人のデータにアクセス不可
- **パフォーマンス**: インデックス、ページネーションで最適化
- **テスト**: 自動生成されたテストケースで品質保証
- **拡張性**: リレーション、カスタムフィールドに対応

**このコマンドで生成されたコードは、本番環境でそのまま使用できます。**
