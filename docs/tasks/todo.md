# TODO — my-tracker v1

> `docs/tasks/plan.md` (`docs/PLAN.md` 순차 실행) 을 위한 진행 트래커.
> `[사용자]` = 이 지점에서 멈추고 사용자 작업을 기다린다.

## 사전 작업
- [x] Task 0 — `pnpm install` (lint / typecheck / build 통과)

## Phase 1 — Foundation
- [x] Task 1 — `CLAUDE.md` 에 프로젝트 실제 정보 채우기 (`package.json` 에 `typecheck` 스크립트 추가)
- [x] Task 2 — **[사용자]** Supabase 프로젝트 생성 + publishable key 전달 (`.env.local`, `.env.example` 작성; `.gitignore` 에 `!.env.example` 예외)
- [x] Task 3 — Supabase client/server 팩토리 + `proxy.ts` (Next 16 에서 `middleware.ts` → `proxy.ts` 로 rename)
- [x] Task 4 — `supabase/migrations/0001_init.sql` + `types/supabase.ts` + `supabase:types` 스크립트
  - [x] **[사용자]** Supabase SQL 편집기에서 마이그레이션 적용
- [ ] Task 5 — **[사용자]** Vercel import + env 변수 등록 + 첫 preview 빌드

### Checkpoint 1
- [ ] 로컬 `pnpm build` 통과, `.env.local` 로드 확인
- [ ] Vercel preview URL 200 응답
- [ ] Supabase 스키마 적용, RLS 로 비인증 `select` 차단

## Phase 2 — Auth
- [ ] Task 6 — `/login` 페이지 + 로그아웃 action + 미들웨어 가드
  - [ ] **[사용자]** Supabase 대시보드에서 단일 사용자 수동 생성

## Phase 3 — Layout
- [ ] Task 7 — `app/(app)/layout.tsx` 사이드바 + shadcn 초기화

## Phase 4–6 — 독립 CRUD (나열 순서대로)
- [ ] Task 8 — Accounts CRUD
- [ ] Task 9 — Cards CRUD
- [ ] Task 10 — Categories CRUD

## Phase 7 — 고정지출 + 달력
- [ ] Task 11 — Fixed expenses CRUD (source FK 는 RESTRICT delete)
- [ ] Task 12 — `/calendar` 월 그리드

## Phase 8–9 — 독립 CRUD
- [ ] Task 13 — Savings CRUD + 순수 함수 `calcAccumulated`
- [ ] Task 14 — Investments CRUD + 총합 표시

## Phase 10 — Ship
- [ ] Task 15 — QA + 프로덕션 배포
  - [ ] SPEC.md Success Criteria 전 항목 체크
  - [ ] `README.md` 로컬 실행 가이드 업데이트

### Checkpoint 2
- [ ] Vercel production URL 공유

---

## 채택된 기본값 (PLAN.md Open Questions)

1. `fixed_expenses` 가 참조 중인 통장/카드 삭제 → **삭제 금지** (RESTRICT).
2. 저축 중도 인출 → **v1 비포함**.
3. 달력 `?ym=` URL 파라미터 → **v1 비포함** (클라이언트 상태만).
4. 회원가입 UI → **v1 비포함** (대시보드에서 단일 사용자 관리).
5. `.env.example` → Supabase public key 2개만.
