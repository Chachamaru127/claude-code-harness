---
name: crud
description: "Auto-generates production-ready CRUD functionality with validation, auth, and tests. Use when user mentions CRUD, entity generation, or wants to create API endpoints. Do NOT load for: UI component creation, form design, database schema discussions."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
argument-hint: "<entity-name>"
user-invocable: false
---

# CRUD Skill

Auto-generates CRUD functionality for specified entities (tables) at **production-ready level**.

## Quick Reference

- "**Create CRUD for task management**" → `/crud tasks`
- "**Want search and pagination too**" → Includes all together
- "**Include permissions (who can view/edit)**" → Sets up authorization/rules together

## Deliverables

- CRUD + validation + authorization + tests, **complete production-safe set**
- Minimize diff to match existing DB/code

**Features**:
- Validation (Zod) auto-add
- Auth/authorization (Row Level Security) auto-config
- Relations (one-to-many, many-to-many) support
- Pagination, search, filters
- Auto-generated test cases

---

## Auto-invoke Skills

**This skill must explicitly invoke the following skills with the Skill tool**:

| Skill | Purpose | When to Call |
|-------|---------|--------------|
| `impl` | Implementation (parent skill) | CRUD feature implementation |
| `verify` | Verification (parent skill) | Post-implementation verification |

---

## Execution Flow

See [references/execution-flow.md](references/execution-flow.md) for detailed steps.

### Phase 1: Entity Analysis

1. Parse entity name from $ARGUMENTS
2. Detect existing schema (Prisma, Drizzle, raw SQL)
3. Infer field types and relations

### Phase 2: CRUD Generation

1. Generate model/schema if needed
2. Create API endpoints (REST or tRPC)
3. Add validation schemas (Zod)
4. Configure authorization rules

### Phase 3: Test Generation

1. Create unit tests for each endpoint
2. Add integration tests
3. Generate test fixtures

### Phase 4: Verification

1. Run type check
2. Run tests
3. Verify build

---

## Supported Frameworks

| Framework | Detection | Generated Files |
|-----------|-----------|-----------------|
| **Next.js + Prisma** | `prisma/schema.prisma` | API routes, Prisma client |
| **Next.js + Drizzle** | `drizzle.config.ts` | API routes, Drizzle queries |
| **Express** | `express` in package.json | Controllers, routes |
| **Hono** | `hono` in package.json | Route handlers |

---

## Output Structure

```
src/
├── lib/
│   └── validations/
│       └── {entity}.ts        # Zod schemas
├── app/api/{entity}/
│   ├── route.ts              # GET (list), POST (create)
│   └── [id]/
│       └── route.ts          # GET, PUT, DELETE
└── tests/
    └── {entity}.test.ts      # Test cases
```

---

## Related Skills

- `impl` - Feature implementation
- `verify` - Build verification
- `auth` - Authentication/authorization
