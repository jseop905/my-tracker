---
name: test-driven-development
description: Drives development with tests. Use when implementing any logic, fixing any bug, or changing any behavior. Use when you need to prove that code works, when a bug report arrives, or when you're about to modify existing functionality.
---

# Test-Driven Development

## Overview

Write a failing test before writing the code that makes it pass. For bug fixes, reproduce the bug with a test before attempting a fix. Tests are proof — "seems right" is not done.

## The TDD Cycle

```
    RED                GREEN              REFACTOR
 Write a test    Write minimal code    Clean up the
 that fails  ──→  to make it pass  ──→  implementation  ──→  (repeat)
```

## The Prove-It Pattern (Bug Fixes)

```
Bug report arrives
       │
       ▼
  Write a test that demonstrates the bug
       │
       ▼
  Test FAILS (confirming the bug exists)
       │
       ▼
  Implement the fix
       │
       ▼
  Test PASSES (proving the fix works)
       │
       ▼
  Run full test suite (no regressions)
```

## The Test Pyramid

```
          ╱╲
         ╱  ╲         E2E Tests (~5%)
        ╱    ╲
       ╱──────╲
      ╱        ╲      Integration Tests (~15%)
     ╱          ╲
    ╱────────────╲
   ╱              ╲   Unit Tests (~80%)
  ╱                ╲
 ╱──────────────────╲
```

## Writing Good Tests

### Test State, Not Interactions
Assert on the *outcome*, not on which methods were called internally.

### DAMP Over DRY in Tests
Each test should tell a complete story without tracing through shared helpers.

### Prefer Real Implementations Over Mocks
```
Preference order:
1. Real implementation  → Highest confidence
2. Fake                 → In-memory version of a dependency
3. Stub                 → Returns canned data
4. Mock (interaction)   → Use sparingly
```

### Arrange-Act-Assert Pattern

```typescript
it('marks overdue tasks when deadline has passed', () => {
  // Arrange
  const task = createTask({ title: 'Test', deadline: new Date('2025-01-01') });
  // Act
  const result = checkOverdue(task, new Date('2025-01-02'));
  // Assert
  expect(result.isOverdue).toBe(true);
});
```

### One Assertion Per Concept
### Name Tests Descriptively

## Test Anti-Patterns

| Anti-Pattern | Fix |
|---|---|
| Testing implementation details | Test inputs and outputs |
| Flaky tests | Use deterministic assertions, isolate state |
| Testing framework code | Only test YOUR code |
| Snapshot abuse | Use sparingly, review every change |
| No test isolation | Each test sets up and tears down its own state |
| Mocking everything | Prefer real implementations |

## Verification

- [ ] Every new behavior has a corresponding test
- [ ] All tests pass
- [ ] Bug fixes include a reproduction test
- [ ] Test names describe the behavior being verified
- [ ] No tests were skipped or disabled
