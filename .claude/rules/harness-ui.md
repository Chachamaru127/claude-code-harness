---
description: harness-ui (TypeScript/React) development rules
paths: "harness-ui/**/*.{ts,tsx,js,jsx}"
---

# harness-ui Development Rules

Rules applied when editing TypeScript/React code in the `harness-ui/` directory.

## Architecture

```
harness-ui/
├── src/
│   ├── client/          # React frontend
│   │   ├── components/  # UI components
│   │   └── main.tsx     # Entry point
│   ├── server/          # Hono backend
│   │   ├── routes/      # API endpoints
│   │   └── services/    # Business logic
│   ├── mcp/             # MCP server
│   └── shared/          # Shared type definitions
├── tests/
│   ├── unit/            # Unit tests
│   └── integration/     # Integration tests
└── e2e/                 # Playwright E2E tests
```

## TypeScript Conventions

### Type Definitions

```typescript
// ✅ Explicit type definitions
interface HookMetadata {
  name: string
  description: string
  timing: string
}

// ❌ No use of any
function process(data: any) { ... }  // NG
function process(data: unknown) { ... }  // OK
```

### Error Handling

```typescript
// ✅ Proper error handling
try {
  const result = await fetchData()
  return result
} catch (error) {
  console.error('Failed to fetch:', error)
  return null  // or throw new CustomError()
}

// ❌ Empty catch
catch {}  // NG
catch { return false }  // NG without reason
```

## React Conventions

### Components

```typescript
// ✅ Function components + explicit Props type
interface DashboardProps {
  projectPath: string
  onRefresh?: () => void
}

export function Dashboard({ projectPath, onRefresh }: DashboardProps) {
  // ...
}
```

### Hooks

- Custom hooks use `use` prefix
- Prevent unnecessary recalculations with `useMemo`, `useCallback`
- Specify `useEffect` dependency arrays accurately

## API Endpoints (Hono)

```typescript
// routes/ pattern
import { Hono } from 'hono'

const app = new Hono()

app.get('/api/resource', async (c) => {
  try {
    const data = await service.getData()
    return c.json(data)
  } catch (error) {
    return c.json({ error: 'Failed to fetch' }, 500)
  }
})
```

## Testing

### Unit Tests

```typescript
// tests/unit/*.test.ts
import { describe, it, expect } from 'vitest'

describe('ServiceName', () => {
  it('should handle normal case', () => {
    // Arrange
    // Act
    // Assert
  })
})
```

### Build Verification

After changes, always run:
```bash
cd harness-ui && npm run build
```

## Prohibited

- ❌ Committing `console.log` (use `console.debug` or remove)
- ❌ Hardcoded URLs/paths
- ❌ Use of `// @ts-ignore` (fix the types instead)
