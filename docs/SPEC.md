# Spec: my-tracker

## Objective

본인 전용 **개인 지출·자산 기록 웹앱**. "어떤 카드를 가지고 있고, 실적은 얼마이며, 어떤 고정지출이 어디서 나가고, 어떤 저축·투자에 얼마가 들어가 있는지"를 한곳에 수동 기록한다.

- **User:** 단일 사용자(본인). Supabase Auth로 로그인해 본인 데이터만 접근
- **Why:** 흩어진 카드·계좌·구독·저축·투자 정보를 한 화면에서 관리하고, 고정지출 달력 뷰로 현금 흐름을 파악하기 위함
- **Scope:** 수동 입력 전용 (오픈뱅킹·CODEF·증권사 API 연동 없음), KRW 단일 통화, 반응형 웹 (PWA 아님)

## Tech Stack

- **Framework:** Next.js 16 (App Router) + React 19 + TypeScript
- **Styling:** Tailwind CSS v4 + shadcn/ui
- **Backend:** Next.js Server Actions / Route Handlers (별도 Node 서버 없음)
- **DB & Auth:** Supabase (PostgreSQL + Auth)
- **Hosting:** Vercel
- **Package Manager:** pnpm
- **Lint/Format:** ESLint (next/core-web-vitals) + Prettier
- **Testing:** 테스트 프레임워크 미도입 (Vitest·Playwright 모두 v1 제외). 타입체크·린트·빌드로 회귀 방지

## Commands

```bash
pnpm dev              # 개발 서버 (localhost:3000)
pnpm build            # 프로덕션 빌드
pnpm start            # 빌드 결과 실행
pnpm lint             # ESLint
pnpm typecheck        # tsc --noEmit
pnpm supabase:types   # supabase 타입 생성 (선택, 도입 시 추가)
```

## Project Structure

```
my-tracker/
├── app/
│   ├── (auth)/
│   │   └── login/                로그인
│   ├── (app)/
│   │   ├── accounts/             통장 목록/상세
│   │   ├── cards/                카드 목록/상세 (실적·발급일·만료일·비고)
│   │   ├── fixed-expenses/       고정 지출 CRUD
│   │   ├── calendar/             고정 지출 달력 뷰
│   │   ├── savings/              저축 리스트 (월납입·시작일·만기일·누적액 자동계산)
│   │   └── investments/          투자 리스트 (초기 원금 기록)
│   ├── api/                      Route Handlers (필요 시)
│   └── layout.tsx
├── components/
│   ├── ui/                       shadcn/ui
│   └── [feature]/                피처별 컴포넌트
├── lib/
│   ├── supabase/                 클라이언트·서버 인스턴스
│   ├── utils.ts
│   └── calc/                     누적액·실적 계산 유틸
├── types/                        도메인 타입
├── supabase/
│   └── migrations/               SQL 마이그레이션
├── docs/
│   └── SPEC.md
└── CLAUDE.md
```

## Code Style

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

- 서버 로직은 Server Action 또는 Route Handler로. 컴포넌트에서 직접 Supabase 호출은 읽기(RLS 의존) 한정
- 입력 검증은 **Zod**로 시스템 경계(Action/Handler 진입점)에서 수행
- 파일명 `kebab-case`, 컴포넌트 `PascalCase`, 함수/변수 `camelCase`
- 금액은 정수(KRW, 원 단위)로 저장·연산 — float 금지

## Data Model (초안)

- `accounts` — 통장: name, bank, memo
- `cards` — 카드: name, issuer, annual_fee, spending_target, issued_at, expires_at, memo(실적 달성 혜택)
- `categories` — 사용자 정의 카테고리: name, color(optional) — 사용자가 자유롭게 추가/삭제
- `fixed_expenses` — 고정지출: name, amount, day_of_month, source_type('account'|'card'), source_id, category_id(nullable, FK→categories), memo
- `savings` — 저축: name, monthly_amount, start_date, maturity_date, memo — 누적액은 계산 필드
- `investments` — 투자: name, kind('stock'|'etf'|'isa'|'etc'), initial_principal, started_at, memo

모든 테이블에 `user_id` + **Supabase RLS**로 본인 행만 접근.

## Testing Strategy

- 단위 테스트 프레임워크는 도입하지 않는다 (사용자 결정: 소규모 프로젝트)
- 대신 다음으로 회귀를 방지한다:
  - `pnpm typecheck` — 타입 에러 0
  - `pnpm lint` — 경고 0
  - `pnpm build` — 빌드 성공
- 계산 유틸(`lib/calc/*`)은 순수 함수로 유지해 추후 테스트 도입 시 바로 붙일 수 있게 한다
- v1 이후 규모가 커지면 Playwright로 "로그인 → 카드 등록 → 고정지출 등록 → 달력 표시" 스모크 테스트 추가 검토

## Boundaries

**Always**
- 커밋 전 `pnpm lint && pnpm typecheck && pnpm build` 통과
- 모든 테이블에 RLS 정책 작성 (user_id = auth.uid())
- 금액은 정수(원)로 저장
- 입력은 Server Action/Route Handler 진입점에서 Zod 검증

**Ask First**
- DB 스키마 변경 (Supabase migration 추가/수정)
- 새 런타임 의존성 추가
- 인증 방식 변경
- v1 범위 확장 (대시보드·자동 역산·알림·시세 연동 등)

**Never**
- Supabase service_role 키를 클라이언트 번들에 노출
- `.env.local` 값을 코드나 커밋에 하드코딩
- RLS 우회 (service_role 키를 일반 읽기에 사용)

## Success Criteria (v1)

다음이 모두 충족되면 v1 완료:

1. Supabase Auth 로그인/로그아웃 동작
2. **통장 CRUD** — 통장 추가·수정·삭제·목록
3. **카드 CRUD** — 이름, 연회비, 실적 기준 금액, 발급일, 만료일, 비고(혜택 메모)
4. **카테고리 CRUD** — 사용자가 직접 카테고리를 추가·수정·삭제 (예: OTT, 보험, 통신)
5. **고정 지출 CRUD** — 이름, 금액, 매월 결제일(day_of_month), 출처(통장/카드), 카테고리(선택)
6. **고정 지출 달력 뷰** — 월 달력에 결제일마다 항목 표시
7. **저축 리스트** — 월 납입액·시작일·만기일 입력 시 누적액 자동 계산 표시
8. **투자 리스트** — 초기 원금 기록 및 항목 비교(리스트 뷰)
9. 모든 데이터가 **RLS로 본인 계정에만 보임**
10. `pnpm build` 성공, Vercel 배포 성공

## Out of Scope (v1)

- 대시보드/리포트/차트
- "총액 역산으로 변동지출 자동 계산" 로직
- 개별 변동지출 기록 기능
- 결제일 알림(이메일/푸시)
- 투자 시세 API 연동, 평가금액/수익률 계산
- 다중 사용자, 공유
- 다통화
- PWA, 네이티브 앱

## Open Questions

1. **프로젝트 초기화** — 현재 빈 디렉토리입니다. v1 구현 착수 시 `pnpm create next-app@latest` 부터 시작하면 되나요?
