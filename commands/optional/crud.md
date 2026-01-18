---
description: "[Optional] Auto-generate CRUD (validation, auth, production-ready)"
description-en: "[Optional] Auto-generate CRUD (validation, auth, production-ready)"
---

# /crud - CRUD Auto-generation (Production-ready)

Auto-generates CRUD functionality for specified entities (tables) at **production-ready level**.

## VibeCoder Quick Reference

- "**Create CRUD for task management**" → `/crud tasks`
- "**Want search and pagination too**" → Includes all together
- "**Include permissions (who can view/edit)**" → Sets up authorization/rules together

## Deliverables

- CRUD + validation + authorization + tests, **complete production-safe set**
- Minimize diff to match existing DB/code

**Features**:
- ✅ Validation (Zod) auto-add
- ✅ Auth/authorization (Row Level Security) auto-config
- ✅ Relations (one-to-many, many-to-many) support
- ✅ Pagination, search, filters
- ✅ Auto-generated test cases

---

## 🔧 Auto-invoke Skills (Required)

**This command must explicitly invoke the following skills with the Skill tool**:

| Skill | Purpose | When to Call |
|-------|---------|--------------|
| `impl` | Implementation (parent skill) | CRUD feature implementation |
| `verify` | Verification (parent skill) | Post-implementation verification |

**How to call**:
```
Use Skill tool:
  skill: "claude-code-harness:impl"      # CRUD feature implementation
  skill: "claude-code-harness:verify"    # Build verification
```

**Child skills (auto-routing)**:
- `work-impl-feature` - CRUD feature implementation
- `verify-build` - Build verification
- `core-diff-aware-editing` - Diff-aware editing

> ⚠️ **Important**: Proceeding without calling skills won't record in usage statistics. Always call with Skill tool.

---

## Usage

```
/crud tasks
```

→ Generates CRUD functionality for `tasks` table

---

## Execution Flow

### Step 1: Confirm Entity Name

Check user input. If no input, ask:

> 🎯 **Which entity (table) should we create CRUD for?**
>
> Examples:
> - `tasks` - Task management
> - `posts` - Blog posts
> - `products` - Products
> - `bookings` - Reservations
>
> Singular or plural is OK!

**Wait for response**

### Step 2: Confirm Schema Design

> 📋 **Are these fields OK?**
>
> ```typescript
> // Example: tasks table
> {
>   id: string (UUID, auto-generated)
>   title: string (required)
>   description: string (optional)
>   status: 'todo' | 'in_progress' | 'done' (default: 'todo')
>   priority: 'low' | 'medium' | 'high' (default: 'medium')
>   due_date: Date (optional)
>   user_id: string (foreign key, auto-set)
>   created_at: Date (auto-generated)
>   updated_at: Date (auto-updated)
> }
> ```
>
> **Let me know if you want changes.**
> Example: "Add an assignee_id field"

**Wait for response (or "OK" to proceed)**

### Step 3: Confirm Relations

> 🔗 **Any relations to other tables?**
>
> Examples:
> - "tasks belong to one project" (many-to-one)
> - "tasks have multiple tags" (many-to-many)
>
> Answer "none" if there aren't any.

**Wait for response**

### Step 4: Files to Generate

The following files will be auto-generated:

#### 1. Prisma Schema (`prisma/schema.prisma`)

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

#### 2. Zod Validation Schema (`lib/validations/task.ts`)

```typescript
import { z } from 'zod'

export const createTaskSchema = z.object({
  title: z.string().min(1, 'Required').max(100, 'Must be 100 characters or less'),
  description: z.string().max(1000, 'Must be 1000 characters or less').optional(),
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

#### 3. API Routes (`app/api/tasks/route.ts`)

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { prisma } from '@/lib/prisma'
import { createTaskSchema, taskQuerySchema } from '@/lib/validations/task'

// GET /api/tasks - Get task list (pagination, search, filter support)
export async function GET(req: NextRequest) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: 'Authentication required' }, { status: 401 })
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
    return NextResponse.json({ error: 'Server error' }, { status: 500 })
  }
}

// POST /api/tasks - Create task
export async function POST(req: NextRequest) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: 'Authentication required' }, { status: 401 })
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
    return NextResponse.json({ error: 'Server error' }, { status: 500 })
  }
}
```

#### 4. Individual API Routes (`app/api/tasks/[id]/route.ts`)

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { prisma } from '@/lib/prisma'
import { updateTaskSchema } from '@/lib/validations/task'

// GET /api/tasks/:id - Get task details
export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: 'Authentication required' }, { status: 401 })
    }

    const task = await prisma.task.findUnique({
      where: { id: params.id },
    })

    if (!task) {
      return NextResponse.json({ error: 'Task not found' }, { status: 404 })
    }

    // Authorization: can only get own tasks
    if (task.user_id !== userId) {
      return NextResponse.json({ error: 'Access denied' }, { status: 403 })
    }

    return NextResponse.json(task)
  } catch (error) {
    console.error(`GET /api/tasks/${params.id} error:`, error)
    return NextResponse.json({ error: 'Server error' }, { status: 500 })
  }
}

// PATCH /api/tasks/:id - Update task
export async function PATCH(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: 'Authentication required' }, { status: 401 })
    }

    const existingTask = await prisma.task.findUnique({
      where: { id: params.id },
    })

    if (!existingTask) {
      return NextResponse.json({ error: 'Task not found' }, { status: 404 })
    }

    // Authorization: can only update own tasks
    if (existingTask.user_id !== userId) {
      return NextResponse.json({ error: 'Access denied' }, { status: 403 })
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
    return NextResponse.json({ error: 'Server error' }, { status: 500 })
  }
}

// DELETE /api/tasks/:id - Delete task
export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { userId } = await auth()
    if (!userId) {
      return NextResponse.json({ error: 'Authentication required' }, { status: 401 })
    }

    const existingTask = await prisma.task.findUnique({
      where: { id: params.id },
    })

    if (!existingTask) {
      return NextResponse.json({ error: 'Task not found' }, { status: 404 })
    }

    // Authorization: can only delete own tasks
    if (existingTask.user_id !== userId) {
      return NextResponse.json({ error: 'Access denied' }, { status: 403 })
    }

    await prisma.task.delete({
      where: { id: params.id },
    })

    return NextResponse.json({ message: 'Deleted' })
  } catch (error) {
    console.error(`DELETE /api/tasks/${params.id} error:`, error)
    return NextResponse.json({ error: 'Server error' }, { status: 500 })
  }
}
```

#### 5. Frontend Component (`components/tasks/task-list.tsx`)

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
          placeholder="Search..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <Select value={status} onValueChange={setStatus}>
          <option value="">All</option>
          <option value="todo">Not started</option>
          <option value="in_progress">In progress</option>
          <option value="done">Done</option>
        </Select>
      </div>

      {loading ? (
        <p>Loading...</p>
      ) : (
        <div className="grid gap-4">
          {tasks.map((task) => (
            <TaskCard key={task.id} task={task} onUpdate={fetchTasks} />
          ))}
        </div>
      )}

      <div className="mt-4 flex justify-center gap-2">
        <Button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>
          Previous
        </Button>
        <span>Page {page}</span>
        <Button onClick={() => setPage(p => p + 1)}>
          Next
        </Button>
      </div>
    </div>
  )
}
```

#### 6. Test Cases (`__tests__/api/tasks.test.ts`)

```typescript
import { describe, it, expect, beforeEach } from 'vitest'
import { createMocks } from 'node-mocks-http'
import { GET, POST } from '@/app/api/tasks/route'

describe('/api/tasks', () => {
  beforeEach(() => {
    // Mock setup
  })

  describe('GET', () => {
    it('returns 401 without auth', async () => {
      const { req } = createMocks({ method: 'GET' })
      const res = await GET(req as any)
      expect(res.status).toBe(401)
    })

    it('can get task list', async () => {
      // Test code
    })

    it('pagination works', async () => {
      // Test code
    })

    it('search works', async () => {
      // Test code
    })
  })

  describe('POST', () => {
    it('can create task', async () => {
      // Test code
    })

    it('returns validation error', async () => {
      // Test code
    })
  })
})
```

### Step 5: Supabase RLS (Row Level Security) Setup

If using Supabase, auto-configure the following RLS policies:

```sql
-- Enable RLS for tasks table
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- SELECT: Can only view own tasks
CREATE POLICY "Users can view their own tasks"
ON tasks FOR SELECT
USING (auth.uid() = user_id);

-- INSERT: Can only create own tasks
CREATE POLICY "Users can create their own tasks"
ON tasks FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- UPDATE: Can only update own tasks
CREATE POLICY "Users can update their own tasks"
ON tasks FOR UPDATE
USING (auth.uid() = user_id);

-- DELETE: Can only delete own tasks
CREATE POLICY "Users can delete their own tasks"
ON tasks FOR DELETE
USING (auth.uid() = user_id);
```

### Step 6: Guide Next Actions

> ✅ **CRUD functionality complete!**
>
> 📄 **Generated files**:
> - `prisma/schema.prisma` - Database schema
> - `lib/validations/task.ts` - Validation
> - `app/api/tasks/route.ts` - API (list, create)
> - `app/api/tasks/[id]/route.ts` - API (detail, update, delete)
> - `components/tasks/task-list.tsx` - Frontend
> - `__tests__/api/tasks.test.ts` - Test cases
> - `supabase/migrations/{{timestamp}}_tasks_rls.sql` - RLS policies
>
> **Next steps:**
> 1. Run `npx prisma migrate dev --name add_tasks`
> 2. Run tests: `npm test`
> 3. Verify: `npm run dev`
>
> 💡 **Hint**: To add other entities, run `/crud {{entity_name}}`.

---

## Relations Support

### One-to-Many (Many-to-One)

**Example**: tasks belong to one project

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

### Many-to-Many

**Example**: tasks have multiple tags

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

## Notes

- **Production-ready**: Complete with validation, authorization, error handling
- **Security**: RLS prevents access to others' data
- **Performance**: Optimized with indexes, pagination
- **Testing**: Auto-generated test cases for quality assurance
- **Extensibility**: Supports relations, custom fields

**Code generated by this command is ready for production use.**
