---
name: test
description: Run TDD workflow — write failing tests, implement, verify. For bugs, use the Prove-It pattern.
---

Follow `.claude/skills/test-driven-development.md`.
Adopt the `.claude/agents/test-engineer.md` persona for test strategy and quality decisions.

For new features:
1. Write tests that describe the expected behavior (they should FAIL)
2. Implement the code to make them pass
3. Refactor while keeping tests green

For bug fixes (Prove-It pattern):
1. Write a test that reproduces the bug (must FAIL)
2. Confirm the test fails
3. Implement the fix
4. Confirm the test passes
5. Run the full test suite for regressions

For testing patterns and examples, see `.claude/references/testing-patterns.md`.
