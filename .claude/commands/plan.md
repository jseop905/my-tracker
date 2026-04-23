---
name: plan
description: Break work into small verifiable tasks with acceptance criteria and dependency ordering
---

Follow `.claude/skills/planning-and-task-breakdown.md`.

Read the existing spec (docs/SPEC.md or equivalent). Then:

1. Enter plan mode — read only, no code changes
2. `docs/wiki/`가 있으면 wiki 문서(architecture.md, modules.md 등)를 읽어 영향 범위를 특정한다. wiki가 없으면 CLAUDE.md의 프로젝트 구조를 기준으로 관련 코드 섹션만 읽는다.
3. Identify the dependency graph between components
3. Slice work vertically (one complete path per task, not horizontal layers)
4. Write tasks with acceptance criteria and verification steps
5. Add checkpoints between phases
6. Present the plan for human review

Save the plan to docs/tasks/plan.md and task list to docs/tasks/todo.md. 출력 디렉토리가 없으면 먼저 생성한다.
