# Implementation Plan: my-tracker v1

SPEC: `docs/SPEC.md`
범위: Supabase Auth + accounts / cards / categories / fixed_expenses(+달력) / savings / investments CRUD. 대시보드·변동지출·테스트 프레임워크 제외.

## Overview

v1은 "로그인 → 카드/통장/카테고리 등록 → 고정지출 등록·달력 확인 → 저축/투자 기록" 전 플로우가 동작하는 것이 목표다. 수직 슬라이스로 엔티티 하나씩 "스키마 + Server Action + UI" 를 완성해 나간다.

기술적 대전제:
- Next.js 16 **Server Actions + Route Handlers**를 백엔드로 사용 (별도 Node 서버 없음)
- Supabase **RLS** 를 보안 1차 방어선으로 삼고, Server Action 에서도 `auth.getUser()` 로 재확인
- 모든 금액은 정수(KRW, 원)로 저장 — `numeric`/`float` 금지
- 입력 검증은 **Zod** 로 Server Action 진입점에서 수행

## Architecture Decisions

| 결정 | 선택 | 이유 |
|---|---|---|
| 데이터 변이 | Server Actions | Next 16 App Router 기본 패턴, RSC와 자연스러움 |
| Supabase 클라이언트 | `@supabase/ssr` | RSC/Server Action/미들웨어에서 쿠키 기반 세션 공유 |
| 폼 | `react-hook-form` + Zod resolver | 가벼운 소규모 프로젝트에 적합 |
| 날짜 라이브러리 | `date-fns` | 작은 번들, tree-shakable |
| 달력 UI | 자체 구현 (date-fns 기반 단순 그리드) | v1은 월 그리드에 표식만 — 외부 라이브러리 불필요 |
| UI 프리미티브 | shadcn/ui | Tailwind v4 호환, copy-in 방식이라 종속성 낮음 |
| ID | uuid (Supabase `gen_random_uuid()`) | Postgres 기본 지원 |
| 마이그레이션 관리 | `supabase/migrations/*.sql` 직접 작성 | 개인 프로젝트 규모에 SQL 직접 관리가 간단 |

## Dependency Graph

```
Phase 1: Foundation (선행 작업)
  └─ CLAUDE.md 채움 → Supabase 프로젝트 → Supabase 클라이언트/미들웨어 → DB 스키마/RLS → Vercel 연결
Phase 2: Auth
  └─ 로그인/로그아웃 + 보호 라우트
Phase 3: Layout
  └─ 공통 네비 + /app 그룹 레이아웃
Phase 4~9: 엔티티별 수직 슬라이스 (accounts → cards → categories → fixed_expenses → calendar → savings → investments)
Phase 10: Ship
```

Phase 4~9 중 accounts/cards/categories 는 서로 **독립적** 이라 순서 바꿀 수 있음. fixed_expenses 는 accounts + cards + categories 에 의존.

---

## Task List

### Phase 1: Foundation (선행 작업 — 1순위)

#### Task 1: CLAUDE.md 프로젝트 개요 채우기

**Description:** 현재 `[프로젝트 이름]` 템플릿 상태인 CLAUDE.md 를 실제 my-tracker 정보로 채운다. SPEC.md 내용을 기반으로 프로젝트 개요, 기술 스택, 명령어, 프로젝트 구조, 코드 스타일, 경계를 업데이트한다.

**Acceptance criteria:**
- [ ] 프로젝트 개요 섹션에 "개인용 지출·자산 기록 웹앱" 설명이 들어 있다
- [ ] 기술 스택, 명령어(pnpm 기준)가 실제 설치된 버전과 일치한다
- [ ] `@AGENTS.md` 참조 라인이 유지된다
- [ ] 보호 규칙(Always/Ask First/Never)이 SPEC 의 Boundaries 와 일치한다

**Verification:**
- [ ] `pnpm lint`, `pnpm build` 기존대로 통과
- [ ] 수동 확인: CLAUDE.md 를 새 세션에서 읽었을 때 프로젝트 이해 가능

**Dependencies:** None
**Files:** `CLAUDE.md`
**Scope:** S

---

#### Task 2: Supabase 프로젝트 생성 + 환경변수 등록

**Description:** Supabase 대시보드에서 프로젝트를 생성하고 URL·anon key 를 받아 로컬 `.env.local` 에 저장한다. `.env.local` 은 이미 gitignore 되어 있음. 키는 `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` 두 개만 사용 (service_role 키는 v1 에서 사용하지 않음).

**Acceptance criteria:**
- [ ] Supabase 프로젝트가 생성됨 (region: Seoul 권장)
- [ ] 로컬 `.env.local` 에 두 키가 설정됨
- [ ] `.env.example` 파일이 생성되어 필요한 키를 문서화함 (값은 빈 문자열)

**Verification:**
- [ ] `node -e "console.log(process.env.NEXT_PUBLIC_SUPABASE_URL)"` 로 키 로드 확인
- [ ] `.env.local` 이 git 에 잡히지 않는 것 확인

**Dependencies:** None
**Files:** `.env.local`(untracked), `.env.example`
**Scope:** XS (사용자의 외부 작업 + 파일 추가)
**Note:** Supabase 프로젝트 생성은 사용자가 대시보드에서 직접 수행. 이후 키만 받아서 처리.

---

#### Task 3: Supabase 클라이언트 + 미들웨어 설정

**Description:** `@supabase/ssr`, `@supabase/supabase-js` 설치. 서버 컴포넌트 / Server Action / 미들웨어에서 세션을 공유하기 위한 클라이언트 팩토리 작성. 세션 refresh 를 위한 Next.js 미들웨어 추가.

**Acceptance criteria:**
- [ ] `lib/supabase/client.ts` (브라우저용)
- [ ] `lib/supabase/server.ts` (RSC/Action 용, 쿠키 기반)
- [ ] `middleware.ts` (세션 refresh + `/login` 을 제외한 경로 인증 가드)
- [ ] 환경변수 누락 시 런타임에 명확한 에러 throw

**Verification:**
- [ ] `pnpm typecheck` 통과
- [ ] `pnpm build` 통과
- [ ] 수동 확인: 임시 서버 컴포넌트에서 `supabase.auth.getUser()` 가 null 을 반환(아직 로그인 없음)

**Dependencies:** Task 2
**Files:** `lib/supabase/client.ts`, `lib/supabase/server.ts`, `middleware.ts`, `package.json`
**Scope:** M

---

#### Task 4: DB 스키마 + RLS 마이그레이션

**Description:** `supabase/migrations/0001_init.sql` 에 v1 모든 테이블 + RLS 정책 작성. 테이블: `accounts`, `cards`, `categories`, `fixed_expenses`, `savings`, `investments`. 모든 테이블에 `user_id uuid references auth.users(id) on delete cascade`, `created_at timestamptz default now()`. `fixed_expenses` 는 `category_id` FK 를 `categories` 에 연결 (nullable, on delete set null). 금액은 모두 `integer` (원 단위). 각 테이블에 "본인 행만 select/insert/update/delete 가능" RLS 정책 네 개씩.

**Acceptance criteria:**
- [ ] 6개 테이블 모두 생성되고 RLS 활성화
- [ ] 6개 테이블 각각 CRUD 4개 policy (총 24개)
- [ ] `fixed_expenses.source_type` 은 CHECK 제약 ('account'|'card')
- [ ] `investments.kind` 는 CHECK 제약 ('stock'|'etf'|'isa'|'etc')
- [ ] `fixed_expenses.day_of_month` 는 CHECK 제약 (1..31)
- [ ] 마이그레이션을 Supabase 에 적용 (대시보드 SQL 편집기 또는 CLI)
- [ ] `pnpm supabase:types` 로 `types/supabase.ts` 자동 생성 (스크립트는 package.json 에 추가)

**Verification:**
- [ ] Supabase 대시보드 Table Editor 에서 6개 테이블 보임
- [ ] `select * from accounts` 가 비인증 상태에서 0 rows (RLS 차단 증거)
- [ ] 생성된 `types/supabase.ts` 에 6개 테이블 타입이 존재

**Dependencies:** Task 2
**Files:** `supabase/migrations/0001_init.sql`, `types/supabase.ts`(generated), `package.json`
**Scope:** M

---

#### Task 5: Vercel 프로젝트 연결 + preview 배포

**Description:** Vercel 에 `github.com/jseop905/my-tracker` 를 import 하고 환경변수 두 개(`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`)를 Production/Preview/Development 모두에 등록. main 브랜치 push 시 자동 배포가 트리거되는지 확인.

**Acceptance criteria:**
- [ ] Vercel 프로젝트가 생성되고 main 브랜치와 연결됨
- [ ] 환경변수 두 개가 세 환경(Prod/Preview/Dev)에 등록
- [ ] main 에 이미 있는 커밋으로 첫 production 배포 성공
- [ ] 배포된 URL 에 접속해 기본 Next.js 스타터 페이지가 뜨는 것 확인

**Verification:**
- [ ] 배포 URL 수동 접속 & 200 응답
- [ ] Vercel 빌드 로그에 환경변수 누락 경고 없음

**Dependencies:** Task 2 (환경변수)
**Files:** 없음 (외부 작업)
**Scope:** XS
**Note:** 사용자가 Vercel 대시보드에서 직접 수행. 연결 후 preview URL 공유.

---

### Checkpoint 1: Foundation 완료

- [ ] Task 1~5 모두 완료
- [ ] `.env.local` 로컬 구동 가능, Vercel preview 동작
- [ ] Supabase 에 스키마 적용, RLS 활성 상태
- [ ] `pnpm build` 성공, Vercel production 배포 1회 성공

---

### Phase 2: Auth

#### Task 6: 로그인 / 로그아웃 페이지 + 보호 라우트

**Description:** `/login` 페이지에 이메일·비밀번호 로그인 폼 (Supabase Auth). 회원가입은 한 사람만 쓰므로 Supabase 대시보드에서 수동 생성하고 로그인만 구현. 로그아웃 Server Action. 미들웨어에서 `/login` 외 모든 경로는 세션 없을 시 `/login` 으로 redirect. 로그인 성공 시 `/` 로 redirect.

**Acceptance criteria:**
- [ ] `/login` 폼 렌더 및 실패/성공 메시지 표시
- [ ] 로그아웃 버튼 (공통 네비에서 사용 예정이지만 우선 임시 레이아웃에 배치)
- [ ] 비로그인 상태에서 `/` 접근 시 `/login` 으로 redirect
- [ ] 로그인된 상태에서 `/login` 접근 시 `/` 로 redirect

**Verification:**
- [ ] Supabase 대시보드에서 생성한 계정으로 수동 로그인/로그아웃 성공
- [ ] `pnpm typecheck && pnpm lint && pnpm build` 통과

**Dependencies:** Task 3
**Files:** `app/(auth)/login/page.tsx`, `app/(auth)/login/actions.ts`, `app/(auth)/layout.tsx`, `middleware.ts` 업데이트
**Scope:** M

---

### Phase 3: 공통 레이아웃

#### Task 7: `/app` 그룹 레이아웃 + 네비게이션

**Description:** 로그인 후 영역(`app/(app)/layout.tsx`) 에 사이드바 네비 추가. 메뉴: 통장, 카드, 카테고리, 고정지출, 달력, 저축, 투자. 로그아웃 버튼 포함. shadcn/ui 의 `button`, `separator` 정도만 초기 설치.

**Acceptance criteria:**
- [ ] shadcn/ui 초기화 (`components.json`, `lib/utils.ts` 의 `cn` 헬퍼 등)
- [ ] 사이드바가 모든 보호 라우트에서 표시
- [ ] 활성 메뉴 시각 표시
- [ ] 모바일(< 768px) 에서 햄버거 토글 (shadcn Sheet 로 간단히 처리 가능)

**Verification:**
- [ ] 메뉴 클릭 시 각 페이지(빈 플레이스홀더) 로 이동
- [ ] 모바일 뷰에서 네비가 가려지지 않음
- [ ] `pnpm build` 통과

**Dependencies:** Task 6
**Files:** `app/(app)/layout.tsx`, `components/nav/sidebar.tsx`, `components/ui/*` (shadcn), `components.json`, `lib/utils.ts`
**Scope:** M

---

### Phase 4: Accounts (통장)

#### Task 8: Accounts CRUD

**Description:** 통장 목록/추가/수정/삭제. 필드: name, bank, memo. Server Action + 목록 페이지 + 폼 페이지. 삭제는 확인 다이얼로그.

**Acceptance criteria:**
- [ ] `/accounts` 목록 테이블
- [ ] `/accounts/new` 생성 폼
- [ ] `/accounts/[id]/edit` 수정 폼
- [ ] 삭제 Server Action + 확인 다이얼로그
- [ ] Zod 스키마로 입력 검증 (name 필수, bank 필수, memo 선택)

**Verification:**
- [ ] 생성 → 목록 표시 → 수정 → 삭제 플로우 수동 확인
- [ ] 브라우저 다른 사용자(또는 시크릿 창에서 비로그인) 로 목록 조회 시 0 rows
- [ ] `pnpm build` 통과

**Dependencies:** Task 7
**Files:** `app/(app)/accounts/page.tsx`, `app/(app)/accounts/actions.ts`, `app/(app)/accounts/new/page.tsx`, `app/(app)/accounts/[id]/edit/page.tsx`, `app/(app)/accounts/_components/form.tsx`, `lib/validators/account.ts`
**Scope:** M

---

### Phase 5: Cards (카드)

#### Task 9: Cards CRUD

**Description:** 카드 목록/추가/수정/삭제. 필드: name, issuer, annual_fee(int), spending_target(int), issued_at(date), expires_at(date, nullable), memo(혜택 설명). 목록에서 실적 기준 금액과 만료까지 남은 일수 표시.

**Acceptance criteria:**
- [ ] CRUD 4 기능 (Task 8 과 동일 패턴)
- [ ] 목록 카드 뷰에 실적 기준 / 발급일 / 만료일 표시
- [ ] 만료 30일 이내 카드는 시각 강조
- [ ] 금액 입력은 1000단위 콤마 표시 유틸 사용

**Verification:**
- [ ] CRUD 수동 확인
- [ ] 만료일 빈값도 정상 저장/표시

**Dependencies:** Task 7
**Files:** `app/(app)/cards/*` (Task 8 과 유사 구조), `lib/validators/card.ts`, `lib/format.ts`(krw format 등)
**Scope:** M

---

### Phase 6: Categories (사용자 정의 카테고리)

#### Task 10: Categories CRUD

**Description:** 카테고리 목록/추가/삭제. 수정은 이름만 변경. 삭제 시 연결된 `fixed_expenses.category_id` 는 NULL 로 자동 설정(on delete set null).

**Acceptance criteria:**
- [ ] `/categories` 목록 (이름 + 색상 뱃지)
- [ ] 인라인 추가 폼 (name 필수, color 선택, 기본 회색)
- [ ] 삭제 확인 다이얼로그
- [ ] 빈 상태: "카테고리를 추가해 고정지출을 분류하세요"

**Verification:**
- [ ] 추가 / 수정 / 삭제 후 목록 갱신
- [ ] 카테고리 삭제 후 해당 카테고리를 가졌던 고정지출이 "미분류" 로 바뀌는 것 확인 (Phase 7 이후 재확인)

**Dependencies:** Task 7
**Files:** `app/(app)/categories/*`, `lib/validators/category.ts`
**Scope:** S

---

### Phase 7: Fixed Expenses + 달력

#### Task 11: Fixed Expenses CRUD

**Description:** 고정지출 목록/추가/수정/삭제. 필드: name, amount(int, 원), day_of_month(1..31), source_type('account'|'card'), source_id(해당 테이블 FK), category_id(nullable), memo. 출처 선택 시 선택한 타입에 맞는 목록만 드롭다운에 표시.

**Acceptance criteria:**
- [ ] CRUD 4 기능
- [ ] 출처 타입 전환 시 ID 드롭다운이 해당 엔티티 목록으로 바뀜
- [ ] 카테고리 드롭다운(사용자의 categories 전체 + "미분류")
- [ ] 목록에서 카테고리 색상 뱃지 + 출처 이름 + 결제일 표시
- [ ] day_of_month 는 1..31 검증, 28 초과는 "28일 이후 월은 말일에 청구"라는 주의 안내 (기록만)

**Verification:**
- [ ] 전체 CRUD 수동 확인
- [ ] 통장/카드 삭제 시 해당 출처 참조하는 고정지출이 어떻게 처리되는지 확인 → **Open Question 참조**
- [ ] `pnpm build` 통과

**Dependencies:** Task 8, 9, 10
**Files:** `app/(app)/fixed-expenses/*`, `lib/validators/fixed-expense.ts`
**Scope:** L — 구현 전 Open Question 확정 후 시작

---

#### Task 12: 고정지출 달력 뷰

**Description:** `/calendar` 에 현재 월의 달력 그리드 렌더. 각 날짜 칸에 해당 `day_of_month` 에 해당하는 고정지출 모두 표시(이름 + 금액, 카테고리 색상). 이전/다음 월 이동. 특정 날짜 클릭 시 해당 날의 지출 리스트 팝오버.

**Acceptance criteria:**
- [ ] 월 그리드 렌더 (date-fns 기반)
- [ ] 오늘 날짜 시각 강조
- [ ] 월 이동 버튼 (prev/next)
- [ ] 날짜당 지출 2개 이하면 전부 표시, 3개 이상이면 "+N more"
- [ ] 모바일에서는 리스트 뷰로 자동 전환 (< 640px)
- [ ] 데이터 없는 달도 정상 렌더 ("이 달에 예정된 고정지출 없음" 풋노트)

**Verification:**
- [ ] 현재 월에 day_of_month=오늘 인 고정지출 만들었을 때 오늘 칸에 표시
- [ ] 이전 월로 넘겨도 동일하게 표시 (고정지출은 월 독립적)
- [ ] `pnpm build` 통과

**Dependencies:** Task 11
**Files:** `app/(app)/calendar/page.tsx`, `components/calendar/month-grid.tsx`, `lib/calc/calendar.ts`
**Scope:** M

---

### Phase 8: Savings (저축)

#### Task 13: Savings CRUD + 누적액 자동 계산

**Description:** 저축 목록/추가/수정/삭제. 필드: name, monthly_amount(int), start_date, maturity_date(nullable), memo. 목록에 경과 개월 × 월납입 = 누적액 자동 계산해 표시. 계산 로직은 `lib/calc/savings.ts` 순수 함수로 분리.

**Acceptance criteria:**
- [ ] CRUD 4 기능
- [ ] `lib/calc/savings.ts::calcAccumulated({ startDate, monthlyAmount, today })` 순수 함수
- [ ] 목록에 시작일 / 월납입 / 누적액(자동) / 만기일 표시
- [ ] 만기일 지난 저축은 "만기" 뱃지
- [ ] 시작일 미래면 누적액 = 0

**Verification:**
- [ ] 시작일 1년 전, 월 10만원 저축 → 누적액 120만원 수동 확인
- [ ] 시작일 미래면 0 표시
- [ ] `pnpm build` 통과

**Dependencies:** Task 7
**Files:** `app/(app)/savings/*`, `lib/calc/savings.ts`, `lib/validators/saving.ts`
**Scope:** M

---

### Phase 9: Investments (투자)

#### Task 14: Investments CRUD + 비교 뷰

**Description:** 투자 목록/추가/수정/삭제. 필드: name, kind('stock'|'etf'|'isa'|'etc'), initial_principal(int), started_at, memo. 목록은 "종류별 그룹" 또는 "원금 내림차순" 토글. 총 투자 원금 합계 상단 표시.

**Acceptance criteria:**
- [ ] CRUD 4 기능
- [ ] 종류 선택 드롭다운 (stock/etf/isa/etc)
- [ ] 목록 정렬: 종류별 / 원금 내림차순 두 모드
- [ ] 상단에 "총 원금 합계" 표시

**Verification:**
- [ ] 항목 3개 추가 후 합계 = 개별 합과 일치
- [ ] 정렬 모드 전환 정상 동작
- [ ] `pnpm build` 통과

**Dependencies:** Task 7
**Files:** `app/(app)/investments/*`, `lib/validators/investment.ts`
**Scope:** M

---

### Phase 10: Ship

#### Task 15: v1 QA + Production 배포

**Description:** 전 기능 수동 QA 체크리스트 실행. 주요 엣지 케이스 확인. Vercel production 배포.

**Acceptance criteria:**
- [ ] 비로그인 상태에서 보호 라우트 접근 → `/login` redirect
- [ ] 두 번째 계정(또는 임시) 을 만들어 RLS 가 격리를 보장하는지 확인
- [ ] 모든 페이지 `pnpm lint` 경고 0
- [ ] `pnpm typecheck` 에러 0
- [ ] `pnpm build` 성공
- [ ] Vercel production URL 에서 전 플로우 동작

**Verification:**
- [ ] SPEC "Success Criteria (v1)" 10개 항목 모두 체크
- [ ] README.md 를 프로젝트 설명 + 로컬 실행 가이드로 업데이트

**Dependencies:** Task 1~14
**Files:** `README.md`, 그 외 자잘한 버그 수정
**Scope:** M

---

### Checkpoint 2: v1 완료

- [ ] SPEC.md "Success Criteria (v1)" 전 항목 충족
- [ ] Production 배포 URL 공유 가능

---

## Parallelization

- Task 8 (accounts) / Task 9 (cards) / Task 10 (categories) 는 서로 독립 → 원한다면 순서 교환 또는 병행 가능
- Task 13 (savings) / Task 14 (investments) 도 독립 — 작업 피로도에 따라 끼워 넣기 가능
- **반드시 순차인 것:** Task 1~7 기반 작업, Task 11 (fixed_expenses) 는 8·9·10 완료 후, Task 12 (calendar) 는 11 후

## Risks and Mitigations

| 리스크 | 영향 | 대응 |
|---|---|---|
| Supabase RLS 정책 누락/오류 | 다른 사용자 데이터 노출 가능 | Task 4 후 두 계정으로 수동 검증 (Task 15 에서도 재검증) |
| Next 16 API 변경점 | 훈련 데이터와 불일치 | `@AGENTS.md` 지시대로 `node_modules/next/dist/docs/` 참조 |
| Server Action 에서 error boundary 누락 | 사용자가 빈 화면 봄 | 각 Action에 try/catch + form state 에러 메시지 반환 |
| Tailwind v4 설정 학습 곡선 | 구현 지연 | create-next-app 기본 설정 그대로 사용, 커스텀 최소화 |
| 금액 정수 오버플로우 | `integer` (max ~21억) 초과 위험 | 실사용 금액은 수십만~수백만 원이라 안전. 필요 시 `bigint` 로 전환 (스키마 변경) |
| 달력 뷰에 항목 많을 때 레이아웃 깨짐 | UX 저하 | Task 12 AC 에 "+N more" 규칙 포함 |

## Open Questions (구현 시점에 확정 필요)

1. **통장/카드 삭제 시 연결된 `fixed_expenses` 처리** — cascade delete? set null? 아니면 참조 있으면 삭제 금지?
   - 추천: 참조 있으면 **삭제 금지** (사용자가 명시적으로 고정지출부터 정리하도록)
   - Task 8·9 구현 시 정책 확정
2. **저축 누적액에 "중도 인출" 개념을 둘 것인가?** — v1 은 단순 계산(경과 개월 × 월납입)으로 충분하다는 전제. 불충분하면 Task 13 재설계.
3. **달력 다른 월 이동 시 URL 에 반영할 것인가?** (`/calendar?ym=2026-05`) — 북마크/공유를 원치 않으면 클라이언트 상태로 충분.
4. **회원가입 UI 필요 여부** — 단일 사용자 전제라 Supabase 대시보드에서 수동 계정 생성 → 로그인 UI 만 구현(Task 6)으로 가정. 가족 추가 계정 등 수요가 생기면 회원가입 UI 를 별도 태스크로.
5. **`.env.example`** 에 포함할 키 목록 — 현재는 두 개만. 나중에 Supabase Storage 등 확장 시 추가.
