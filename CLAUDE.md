@AGENTS.md

# my-tracker

> 이 파일은 Claude Code 의 행동 지침이다. 전체 스펙은 `docs/SPEC.md`, 실행 계획은 `docs/PLAN.md` 및 `docs/tasks/plan.md` 참조.

## 프로젝트 개요

**개인용 지출·자산 기록 웹앱** (단일 사용자). 흩어진 카드·통장·구독(고정지출)·저축·투자 정보를 한 화면에서 수동으로 기록하고, 고정지출 달력 뷰로 월별 현금 흐름을 파악한다.

- **User:** 본인 1인. Supabase Auth 로 로그인해 본인 데이터만 접근.
- **Scope:** 수동 입력 전용 (오픈뱅킹·CODEF·증권사 API 연동 없음), KRW 단일 통화, 반응형 웹.
- **v1 제외:** 대시보드/리포트, 변동지출 자동 계산, 결제일 알림, 시세 연동, 다중 사용자, PWA.

## 기술 스택

- **Language:** TypeScript 5 (strict)
- **Framework:** Next.js 16 (App Router, Server Actions) + React 19
- **Styling:** Tailwind CSS v4 + shadcn/ui
- **Validation:** Zod (Server Action/Route Handler 진입점에서)
- **Form:** react-hook-form + @hookform/resolvers/zod
- **Date:** date-fns
- **DB & Auth:** Supabase (PostgreSQL + Auth + RLS), `@supabase/ssr`
- **Hosting:** Vercel
- **Package Manager:** pnpm 10
- **Testing:** 프레임워크 미도입. `pnpm lint` + `pnpm typecheck` + `pnpm build` 로 회귀 방지. 계산 유틸은 순수 함수로 분리해 추후 테스트 도입 가능하게.

## 명령어

```bash
pnpm dev              # 개발 서버 (localhost:3000)
pnpm build            # 프로덕션 빌드
pnpm start            # 빌드 결과 실행
pnpm lint             # ESLint (next/core-web-vitals + TS)
pnpm typecheck        # tsc --noEmit
# pnpm supabase:types # Task 4 에서 추가 예정 (Supabase 타입 생성)
```

## 프로젝트 구조

```
my-tracker/
├── app/
│   ├── (auth)/
│   │   └── login/                 로그인 페이지
│   ├── (app)/                     로그인 후 영역 (미들웨어 가드)
│   │   ├── accounts/              통장 CRUD
│   │   ├── cards/                 카드 CRUD (실적·발급일·만료일)
│   │   ├── categories/            사용자 정의 카테고리 CRUD
│   │   ├── fixed-expenses/        고정지출 CRUD
│   │   ├── calendar/              고정지출 달력 뷰
│   │   ├── savings/               저축 (누적액 자동 계산)
│   │   └── investments/           투자 (초기 원금)
│   ├── api/                       Route Handlers (필요 시)
│   └── layout.tsx
├── components/
│   ├── ui/                        shadcn/ui 프리미티브
│   ├── nav/                       사이드바 등 공통 네비
│   └── [feature]/                 피처별 컴포넌트
├── lib/
│   ├── supabase/                  client.ts (브라우저) / server.ts (RSC·Action)
│   ├── validators/                Zod 스키마
│   ├── calc/                      누적액·달력 등 순수 계산
│   ├── format.ts                  KRW 포매팅 등
│   └── utils.ts                   shadcn `cn` 등
├── types/
│   └── supabase.ts                (generated)
├── supabase/
│   └── migrations/                SQL 마이그레이션
├── proxy.ts                       Next 16 proxy (구 middleware): 세션 refresh + 비로그인 가드
└── docs/
    ├── SPEC.md
    ├── PLAN.md
    └── tasks/                     실행 계획 + TODO
```

## 코드 스타일

네이밍: 파일 `kebab-case`, 컴포넌트 `PascalCase`, 함수/변수 `camelCase`. 금액은 정수(KRW, 원 단위)로 저장·연산 — float 금지.

**순수 계산 유틸 패턴** (DB import 금지, 테스트 도입 시 바로 붙이기 쉽게):

```typescript
// lib/calc/savings.ts
import { differenceInMonths } from 'date-fns';

export type SavingInput = {
  startDate: Date;
  monthlyAmount: number;
  today?: Date;
};

export function calcAccumulated({ startDate, monthlyAmount, today = new Date() }: SavingInput): number {
  const months = Math.max(0, differenceInMonths(today, startDate) + 1);
  return months * monthlyAmount;
}
```

**Server Action 패턴** (Zod 검증 → RLS 의존 쿼리 → redirect/revalidate):

```typescript
// app/(app)/accounts/actions.ts
'use server';
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { accountSchema } from '@/lib/validators/account';

export async function createAccount(formData: FormData) {
  const parsed = accountSchema.parse(Object.fromEntries(formData));
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('unauthenticated');
  const { error } = await supabase.from('accounts').insert({ ...parsed, user_id: user.id });
  if (error) throw error;
  revalidatePath('/accounts');
}
```

클라이언트에서 Supabase 호출은 읽기(RLS 의존) 에만 제한적으로 사용. 쓰기는 전부 Server Action 을 거친다.

## 프로젝트 문서

- `docs/SPEC.md` — v1 요구사항·데이터 모델·Success Criteria
- `docs/PLAN.md` — 15개 설계 태스크 + 인수 조건
- `docs/tasks/plan.md` — 실행 순서·차단 지점·기본값
- `docs/tasks/todo.md` — 진행 트래커
- `docs/wiki/` — 없음 (필요해지면 `/project` 로 생성)

wiki 가 생기면 보조 자료로 참고하되, 코드와 wiki 가 다르면 코드를 따른다.

## 워크플로우

이 프로젝트는 `.claude/` 디렉토리의 commands, skills, hooks 를 활용한다.

### v1 구현 중 (현재)

`docs/tasks/todo.md` 를 따라 Task 1 → 15 순차 진행. 각 태스크는:

1. PLAN.md 의 해당 태스크 인수 조건 확인.
2. 관련 Next 16 문서 (`node_modules/next/dist/docs/`) 사전 참조. Next 16 은 학습 데이터와 API 차이가 있을 수 있다.
3. 구현.
4. `pnpm lint && pnpm typecheck && pnpm build` 통과.
5. UI 태스크는 `pnpm dev` 로 골든 패스 수동 확인.
6. 커밋.

`[사용자]` 표시된 태스크(Supabase 프로젝트 생성·마이그레이션 적용·Vercel 연결·로그인 계정 생성)에서는 사용자 작업을 기다린다.

### 버그 수정

`/test` → `/code-review`. Prove-It 패턴: 재현 테스트 → 근본 원인 수정 → 회귀 확인.

### 코드 정리

`/code-simplify` → `/code-review`. 동작 변경 없이 구조만 개선, 기능 추가와 섞지 않음.

### 배포 전 점검

`/ship` — 코드 품질·보안·성능·접근성·인프라·문서 전체 점검.

### 프로젝트 문서화

`/project` (최초) → `/wiki` (갱신). `docs/wiki/` 에 문서 생성·갱신.

## 경계

### Always
- 커밋 전 `pnpm lint && pnpm typecheck && pnpm build` 통과
- 모든 테이블에 RLS 정책 작성 (`user_id = auth.uid()`)
- 금액은 정수(원)로 저장·연산
- 입력은 Server Action/Route Handler 진입점에서 Zod 검증
- 기존 코드 패턴·컨벤션 따르기

### Ask First
- DB 스키마 변경 (Supabase migration 추가/수정)
- 새 런타임 의존성 추가
- 인증 방식 변경
- v1 범위 확장 (대시보드·자동 역산·알림·시세 연동 등)

### Never
- Supabase `service_role` 키를 클라이언트 번들에 노출
- `.env.local` 값을 코드나 커밋에 하드코딩
- RLS 우회 (`service_role` 키를 일반 읽기에 사용)
- 실패하는 테스트나 린트 규칙을 무력화해 통과시키기
