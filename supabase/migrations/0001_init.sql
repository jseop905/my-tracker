-- 0001_init.sql — my-tracker v1 schema + RLS
-- 6 tables: accounts, cards, categories, fixed_expenses, savings, investments
-- All amounts are integers (KRW, 원 단위). All tables RLS-protected (user_id = auth.uid()).

create extension if not exists "pgcrypto";

-- ============================================================
-- Tables
-- ============================================================

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  bank text not null,
  memo text,
  created_at timestamptz not null default now()
);
create index accounts_user_id_idx on public.accounts(user_id);

create table public.cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  issuer text not null,
  annual_fee integer not null default 0 check (annual_fee >= 0),
  spending_target integer not null default 0 check (spending_target >= 0),
  issued_at date not null,
  expires_at date,
  memo text,
  created_at timestamptz not null default now()
);
create index cards_user_id_idx on public.cards(user_id);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color text,
  created_at timestamptz not null default now(),
  unique (user_id, name)
);
create index categories_user_id_idx on public.categories(user_id);

-- fixed_expenses.source_id is polymorphic (points to accounts.id or cards.id
-- depending on source_type). Referential integrity is enforced in Server Actions:
-- deleting an accounts/cards row referenced by a fixed_expenses row is blocked.
create table public.fixed_expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  amount integer not null check (amount >= 0),
  day_of_month smallint not null check (day_of_month between 1 and 31),
  source_type text not null check (source_type in ('account', 'card')),
  source_id uuid not null,
  category_id uuid references public.categories(id) on delete set null,
  memo text,
  created_at timestamptz not null default now()
);
create index fixed_expenses_user_id_idx on public.fixed_expenses(user_id);
create index fixed_expenses_source_idx on public.fixed_expenses(source_type, source_id);
create index fixed_expenses_category_id_idx on public.fixed_expenses(category_id);

create table public.savings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  monthly_amount integer not null check (monthly_amount >= 0),
  start_date date not null,
  maturity_date date,
  memo text,
  created_at timestamptz not null default now()
);
create index savings_user_id_idx on public.savings(user_id);

create table public.investments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  kind text not null check (kind in ('stock', 'etf', 'isa', 'etc')),
  initial_principal integer not null check (initial_principal >= 0),
  started_at date not null,
  memo text,
  created_at timestamptz not null default now()
);
create index investments_user_id_idx on public.investments(user_id);

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.accounts        enable row level security;
alter table public.cards           enable row level security;
alter table public.categories      enable row level security;
alter table public.fixed_expenses  enable row level security;
alter table public.savings         enable row level security;
alter table public.investments     enable row level security;

-- accounts
create policy "accounts_select_own" on public.accounts for select using (user_id = auth.uid());
create policy "accounts_insert_own" on public.accounts for insert with check (user_id = auth.uid());
create policy "accounts_update_own" on public.accounts for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "accounts_delete_own" on public.accounts for delete using (user_id = auth.uid());

-- cards
create policy "cards_select_own" on public.cards for select using (user_id = auth.uid());
create policy "cards_insert_own" on public.cards for insert with check (user_id = auth.uid());
create policy "cards_update_own" on public.cards for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "cards_delete_own" on public.cards for delete using (user_id = auth.uid());

-- categories
create policy "categories_select_own" on public.categories for select using (user_id = auth.uid());
create policy "categories_insert_own" on public.categories for insert with check (user_id = auth.uid());
create policy "categories_update_own" on public.categories for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "categories_delete_own" on public.categories for delete using (user_id = auth.uid());

-- fixed_expenses
create policy "fixed_expenses_select_own" on public.fixed_expenses for select using (user_id = auth.uid());
create policy "fixed_expenses_insert_own" on public.fixed_expenses for insert with check (user_id = auth.uid());
create policy "fixed_expenses_update_own" on public.fixed_expenses for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "fixed_expenses_delete_own" on public.fixed_expenses for delete using (user_id = auth.uid());

-- savings
create policy "savings_select_own" on public.savings for select using (user_id = auth.uid());
create policy "savings_insert_own" on public.savings for insert with check (user_id = auth.uid());
create policy "savings_update_own" on public.savings for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "savings_delete_own" on public.savings for delete using (user_id = auth.uid());

-- investments
create policy "investments_select_own" on public.investments for select using (user_id = auth.uid());
create policy "investments_insert_own" on public.investments for insert with check (user_id = auth.uid());
create policy "investments_update_own" on public.investments for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "investments_delete_own" on public.investments for delete using (user_id = auth.uid());
