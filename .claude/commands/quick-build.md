---
name: quick-build
description: Implement the next task incrementally without TDD — build, verify, commit
---

Follow `.claude/skills/incremental-implementation.md`.

Pick the next pending task from the plan. For each task:

1. Read the task's acceptance criteria
2. Load relevant context (existing code, patterns, types)
3. Implement the code to meet the acceptance criteria
4. Run the full test suite to check for regressions
5. Run the build to verify compilation
6. Commit with a descriptive message
7. Mark the task complete and move to the next one

If any step fails, follow `.claude/skills/debugging-and-error-recovery.md`.
