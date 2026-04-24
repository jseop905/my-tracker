# 실행 계획: my-tracker v1 (docs/PLAN.md 순차 실행)

## Context

`docs/PLAN.md` 는 이미 v1 을 15개의 설계 단계 태스크로 분해하고 각 태스크별 인수 조건을 정의해두었다. 이 문서는 각 태스크를 하나씩 (`/build` 로) 집어들 수 있도록, **순서·사용자 차단 지점·오픈 이슈에 대한 기본값** 을 명시한 **실행 계획** 이다.

계획 수립 시점의 저장소 상태:
- Next.js 16.2.4 + React 19 + Tailwind v4 스캐폴드만 있음 (`app/layout.tsx`, `app/page.tsx` 는 기본 템플릿).
- `node_modules/` 미설치 → Task 0 에서 처리.
- `components/`, `lib/`, `types/`, `supabase/`, `docs/wiki/`, `.env.*` 모두 없음. 라우트 그룹도 없음.
- 런타임 의존성 전무 (Supabase / Zod / react-hook-form / date-fns / shadcn 모두 미설치).
- `CLAUDE.md` 는 아직 `[프로젝트 이름]` 템플릿 그대로 — Task 1 에서 채움.

이 계획은 PLAN.md 의 인수 조건을 다시 쓰지 않는다 — 그 쪽을 참조하고, **실행 스캐폴딩**(순서, 차단 지점, 기본값, 체크포인트)만 추가한다.

---

## Pre-work (Task 0)

- **Task 0 — `pnpm install`**
  - 로컬에 Next 16 툴체인 설치.
  - 검증: `pnpm typecheck` (보일러플레이트 상태), `pnpm lint`, `pnpm build`.
  - 설치 후 `node_modules/next/dist/docs/` 가 생기므로, `AGENTS.md` 지시대로 Next 16 관련 코드 작성 전에 그 문서를 참조한다.

---

## 순서 개요

```
Task 0    pnpm install (사전 작업)
Phase 1   Task 1  CLAUDE.md 채움       ──┐
          Task 2  Supabase 프로젝트 [사용자]│
          Task 3  Supabase 클라이언트 + MW │ Foundation
          Task 4  DB 스키마 + RLS         │
          Task 5  Vercel 연결      [사용자]┘
Checkpoint 1
Phase 2   Task 6  로그인/로그아웃 + 가드
Phase 3   Task 7  (app) 레이아웃 + 사이드바
Phase 4-6 Task 8  accounts   ┐  서로 독립
          Task 9  cards      │  나열된 순서대로 진행
          Task 10 categories ┘  (간단한 것부터)
Phase 7   Task 11 fixed_expenses (8+9+10 필요)
          Task 12 calendar       (11 필요)
Phase 8   Task 13 savings     ┐ 독립, 순서 교환 가능
Phase 9   Task 14 investments ┘
Phase 10  Task 15 QA + 프로덕션 배포
Checkpoint 2
```

**엄격한 순서 제약**
- 0 → 1,2 → 3 → 4 (클라이언트 설정이 있어야 타입을 연결할 수 있음)
- 3 → 5 (Vercel 에 넣을 env 변수명이 Task 3 에서 확정됨)
- 4 → 6 (로그인 플로우가 `auth` 를 쓰므로 스키마가 살아있어야 함)
- 6 → 7 → (8,9,10) → 11 → 12
- 13, 14 는 Task 7 (레이아웃) 만 있으면 됨 → Checkpoint 1 / Phase 3 이후 아무 데나 끼워 넣을 수 있음

**병렬 가능 브랜치:** 8 / 9 / 10 (독립), 13 / 14 (독립). 나머지는 직렬.

---

## 사용자 차단 태스크

이 지점들에서는 반드시 멈추고 사용자 작업을 기다린다.

1. **Task 2 — Supabase 프로젝트** → 사용자가 프로젝트(Seoul 리전) 생성, `NEXT_PUBLIC_SUPABASE_URL` + `NEXT_PUBLIC_SUPABASE_ANON_KEY` 전달. 나는 `.env.local`(untracked) 과 `.env.example`(플레이스홀더) 작성.
2. **Task 4 — 마이그레이션 적용** → 내가 `supabase/migrations/0001_init.sql` 작성, 사용자가 Supabase SQL 편집기에 붙여넣거나 `supabase db push` 실행.
3. **Task 5 — Vercel import** → 사용자가 Vercel 에 리포 import, Prod/Preview/Dev 세 환경에 env 두 개 등록. 나는 배포 URL 을 fetch 해서 검증.
4. **Task 6 — 로그인 계정 생성** → v1 은 자체 회원가입이 없으므로, 사용자가 대시보드에서 단일 계정 수동 생성. 나는 로그인 UI 만 구현.

---

## PLAN.md Open Questions 기본값

PLAN.md 자체 권고를 그대로 채택:

| # | 질문 | 기본값 |
|---|---|---|
| 1 | `fixed_expenses` 가 참조 중인 통장/카드 삭제 | **삭제 금지**(RESTRICT). 사용자가 고정지출을 먼저 정리해야 함. Server Action 에서 친절한 에러 메시지로 노출. |
| 2 | 저축 중도 인출 개념 | v1 비포함. `calcAccumulated = 경과개월 × 월납입`, 하한 0. |
| 3 | 달력 URL 에 `?ym=YYYY-MM` 반영 | v1 비포함. 클라이언트 상태만 사용. |
| 4 | 회원가입 UI | v1 비포함. 로그인 폼만 구현. |
| 5 | `.env.example` 키 목록 | Supabase public key 두 개만. |

---

## 태스크별 실행 메모

(인수 조건 및 파일 목록은 `docs/PLAN.md` 참조. 아래는 PLAN.md 에 없는 실행 주의사항.)

**Task 1 (CLAUDE.md)** — 최상단 `@AGENTS.md` 라인 유지, 플레이스홀더 섹션만 교체. `pnpm` 스크립트는 Task 3/4 에서 `typecheck` + `supabase:types` 추가 후 실제 상태와 맞춘다.

**Task 3 (Supabase 클라이언트 + 미들웨어)**
- 코드 작성 전 `node_modules/next/dist/docs/` 에서 `middleware`, `cookies` 관련 페이지 확인 — Next 16 에서 API 가 바뀌었다.
- `lib/supabase/server.ts` 는 비동기 `cookies()` API 패턴 사용.
- 미들웨어 matcher 는 `_next/static`, `_next/image`, `favicon.ico`, `/login` 제외.

**Task 4 (스키마)** — `pnpm supabase:types` 스크립트 추가. Supabase CLI 가 로컬에 없으면 대시보드(Database → API docs → Types) 수동 fallback 을 `types/supabase.ts` 최상단 한 줄 주석으로 명시.

**Task 6 (로그인)** — 리다이렉트 로직은 미들웨어에 둔다. `/login` 페이지 자체는 Server Component 로 두고, `getUser()` 가 사용자 반환 시 `/` 로 redirect.

**Task 7 (사이드바)** — `pnpx shadcn@latest init` 으로 shadcn 초기화. Tailwind v4 는 `components.json` 형태가 다르므로 shadcn v4 문서 확인 후 진행.

**Task 8/9/10** — "리소스 페이지" 패턴(list + new + edit + actions.ts + _components/form.tsx) 공유. accounts 를 템플릿으로 두고 cards / categories 는 복붙+수정 — 섣부른 추상화 금지. Task 10 끝낸 후 자연스레 공통 헬퍼가 보이면 그때 추출.

**Task 11 (fixed_expenses)** — source FK 에 `on delete restrict` 걸면, 부모 삭제 시 Postgres 가 에러코드 `23503` 반환. accounts/cards 의 delete action 에서 이를 catch 해 폼 에러로 노출.

**Task 12 (달력)** — 월 상태(prev/next)만 클라이언트 컴포넌트. 데이터는 부모 페이지에서 서버사이드로 fetch, 클라이언트 그리드는 `day_of_month` 로 필터만. `useEffect` 로 fetch 금지.

**Task 13 (저축)** — `lib/calc/savings.ts` 는 순수 유지(DB import 금지). SPEC.md 에 나온 시그니처 그대로 사용.

**Task 15 (배포)** — Vercel production 전환 전, 두 번째 Supabase 사용자를 만들거나 SQL 로 가짜 `user_id` 로 row 삽입 후, 현재 로그인된 계정에서 안 보이는지 확인. RLS 회귀 검증으로 가장 강력함.

---

## 체크포인트

**Checkpoint 1 — Task 5 후**
- 로컬 `.env.local` 로드, `pnpm build` 통과.
- Vercel preview URL 200 응답, Supabase 스키마 적용, 비인증 `select *` 가 0 rows.
- Task 6 진입 전 사용자 사인오프.

**Checkpoint 2 — Task 15 후**
- SPEC.md 의 Success Criteria 10개 모두 충족.
- Vercel production URL 공유.
- `README.md` 로컬 실행 가이드 업데이트.

---

## 태스크별 검증 방식

모든 태스크는 커밋 전 아래 3개 실행:
```
pnpm lint && pnpm typecheck && pnpm build
```
`SPEC.md` Boundaries → Always 와 일치. 여기에 PLAN.md "Verification" 에 있는 태스크별 수동 플로우 추가.

UI 가 있는 태스크(6, 7, 8, 9, 10, 11, 12, 13, 14)는 커밋 전에 `pnpm dev` 로 브라우저에서 골든 패스 수동 확인.
