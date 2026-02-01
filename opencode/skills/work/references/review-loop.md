# Review Loop

## Default Flow

**Review→Fix ループは Solo/2-Agent 共通**。Handoff は 2-Agent モードのみ実行。

```
/work --parallel 3
    ↓
┌─────────────────────────────────────────────────────────┐
│ Phase 1: Parallel Implementation                        │
├─────────────────────────────────────────────────────────┤
│  [task-worker A] Implement → Related-check              │
│  [task-worker B] Implement → Related-check              │
│  [task-worker C] Implement → Related-check              │
│                                                         │
│  ※Related-check: Verify no missed file updates         │
│  Each worker completes implementation                   │
└─────────────────────────────────────────────────────────┘
    ↓ Wait for all implementations complete
┌─────────────────────────────────────────────────────────┐
│ Phase 2: Review Loop (harness-review)  [Solo/2-Agent]   │
├─────────────────────────────────────────────────────────┤
│  Execute harness-review (context-aware)                 │
│    ├── Codex available: 4-parallel expert review       │
│    └── Otherwise: standard review                       │
│                                                         │
│  ※NG (Critical/High issues) → Fix → Re-review          │
│  ※Loop continues until OK (max --max-iterations)       │
└─────────────────────────────────────────────────────────┘
    ↓ Review OK (APPROVE: no Critical/High issues)
┌─────────────────────────────────────────────────────────┐
│ Phase 3: Auto-commit (default)         [Solo/2-Agent]   │
├─────────────────────────────────────────────────────────┤
│  ✅ All tasks implemented and reviewed                  │
│  📝 Auto-commit with generated message                  │
│                                                         │
│  Skip with: --no-commit or config auto_commit: false    │
└─────────────────────────────────────────────────────────┘
```

## Escalation

When task-worker can't resolve after 3 fixes, aggregate to parent and bulk confirm with user.

```
⚠️ Escalation (2 items)

Task A: Cannot convert type 'unknown' to 'User'
  → Suggestion: Check User type definition or add type guard

Task B: Test 'should validate email' failing
  → Suggestion: Fix regex pattern

How to proceed?
1. Apply suggestions and continue
2. Skip and move on
3. Fix manually
```

## Review OK Judgment

| 判定 | 条件 | アクション |
|------|------|-----------|
| APPROVE | Critical/High の指摘なし | → Phase 3 (commit) → Phase 4 (handoff) |
| REQUEST_CHANGES | Critical/High の指摘あり | → Fix → Re-review (loop) |
