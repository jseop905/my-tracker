---
name: incremental-implementation
description: Delivers changes incrementally. Use when implementing any feature or change that touches more than one file. Use when you're about to write a large amount of code at once, or when a task feels too big to land in one step.
---

# Incremental Implementation

## Overview

Build in thin vertical slices — implement one piece, test it, verify it, then expand. Avoid implementing an entire feature in one pass. Each increment should leave the system in a working, testable state.

## The Increment Cycle

```
┌──────────────────────────────────────┐
│                                      │
│   Implement ──→ Test ──→ Verify ──┐  │
│       ▲                           │  │
│       └───── Commit ◄─────────────┘  │
│              │                       │
│              ▼                       │
│          Next slice                  │
│                                      │
└──────────────────────────────────────┘
```

## Slicing Strategies

### Vertical Slices (Preferred)

```
Slice 1: Create a task (DB + API + basic UI) → Tests pass
Slice 2: List tasks (query + API + UI) → Tests pass
Slice 3: Edit a task (update + API + UI) → Tests pass
Slice 4: Delete a task (delete + API + UI + confirmation) → Tests pass
```

### Contract-First Slicing

```
Slice 0: Define the API contract (types, interfaces)
Slice 1a: Implement backend against the contract
Slice 1b: Implement frontend against mock data
Slice 2: Integrate and test end-to-end
```

### Risk-First Slicing

Tackle the riskiest or most uncertain piece first.

## Implementation Rules

### Rule 0: Simplicity First

```
SIMPLICITY CHECK:
✗ Generic EventBus with middleware pipeline for one notification
✓ Simple function call

✗ Abstract factory pattern for two similar components
✓ Two straightforward components with shared utilities
```

Three similar lines of code is better than a premature abstraction.

### Rule 0.5: Scope Discipline

Touch only what the task requires.

```
NOTICED BUT NOT TOUCHING:
- src/utils/format.ts has an unused import (unrelated to this task)
→ Want me to create tasks for these?
```

### Rule 1: One Thing at a Time

Each increment changes one logical thing. Don't mix concerns:

**Bad:** One commit that adds a new component, refactors an existing one, and updates the build config.
**Good:** Three separate commits — one for each change.

### Rule 2: Keep It Compilable

After each increment, the project must build and existing tests must pass. Don't leave the codebase in a broken state between slices.

### Rule 3: Feature Flags for Incomplete Features

```typescript
const ENABLE_TASK_SHARING = process.env.FEATURE_TASK_SHARING === 'true';

if (ENABLE_TASK_SHARING) {
  // New sharing UI
}
```

This lets you merge small increments without exposing incomplete work.

### Rule 4: Safe Defaults

```typescript
export function createTask(data: TaskInput, options?: { notify?: boolean }) {
  const shouldNotify = options?.notify ?? false;
  // ...
}
```

### Rule 5: Rollback-Friendly

- Additive changes (new files, new functions) are easy to revert
- Modifications to existing code should be minimal and focused
- Database migrations should have corresponding rollback migrations
- Avoid deleting something in one commit and replacing it in the same commit — separate them

## Working with Agents

When directing an agent to implement incrementally:

```
"Let's implement Task 3 from the plan.

Start with just the database schema change and the API endpoint.
Don't touch the UI yet — we'll do that in the next increment.

After implementing, run `npm test` and `npm run build` to verify
nothing is broken."
```

Be explicit about what's in scope and what's NOT in scope for each increment.

## Red Flags

- More than 100 lines of code written without running tests
- Multiple unrelated changes in a single increment
- "Let me just quickly add this too" scope expansion
- Skipping the test/verify step to move faster
- Building abstractions before the third use case demands it
- Touching files outside the task scope "while I'm here"

## Increment Checklist

- [ ] The change does one thing and does it completely
- [ ] All existing tests still pass
- [ ] The build succeeds
- [ ] Type checking passes
- [ ] Linting passes
- [ ] The new functionality works as expected
- [ ] The change is committed with a descriptive message
