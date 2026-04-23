---
name: code-review
description: Conduct a five-axis code review — correctness, readability, architecture, security, performance
---

Follow `.claude/skills/code-review-and-quality.md`. Use `.claude/agents/code-reviewer.md` as review persona.

Review the current changes (staged or recent commits) across all five axes:

1. **Correctness** — Does it match the spec? Edge cases handled? Tests adequate?
2. **Readability** — Clear names? Straightforward logic? Well-organized?
3. **Architecture** — Follows existing patterns? Clean boundaries? Right abstraction level?
4. **Security** — Input validated? Secrets safe? Auth checked? (See `.claude/references/security-checklist.md`)
5. **Performance** — No N+1 queries? No unbounded ops? (See `.claude/references/performance-checklist.md`)

Categorize findings as Critical, Important, or Suggestion.
Output a structured review with specific file:line references and fix recommendations.
