-- Sales Manager / PostgreSQL foundation
-- Run this in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  address text,
  currency_code text not null default 'EGP',
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.business_members (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'cashier'
    check (role in ('owner','manager','cashier','accountant')),
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);

create index if not exists business_members_user_idx
  on public.business_members(user_id);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (business_id, name)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  barcode text,
  sku text,
  purchase_price numeric(14,2) not null default 0 check (purchase_price >= 0),
  sale_price numeric(14,2) not null default 0 check (sale_price >= 0),
  wholesale_price numeric(14,2) not null default 0 check (wholesale_price >= 0),
  stock numeric(14,3) not null default 0,
  minimum_stock numeric(14,3) not null default 0,
  unit text not null default 'قطعة',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists products_business_idx on public.products(business_id);
create index if not exists products_barcode_idx on public.products(business_id, barcode);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  phone text,
  address text,
  credit_limit numeric(14,2) not null default 0,
  balance numeric(14,2) not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists customers_business_idx on public.customers(business_id);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  phone text,
  address text,
  balance numeric(14,2) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  invoice_number bigint generated always as identity,
  customer_id uuid references public.customers(id) on delete set null,
  cashier_id uuid references auth.users(id) on delete set null,
  subtotal numeric(14,2) not null default 0,
  discount numeric(14,2) not null default 0,
  tax numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  paid numeric(14,2) not null default 0,
  payment_method text not null default 'cash'
    check (payment_method in ('cash','card','credit','transfer')),
  status text not null default 'completed'
    check (status in ('draft','completed','cancelled','returned')),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists sales_business_date_idx
  on public.sales(business_id, created_at desc);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  discount numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0
);

create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  supplier_id uuid references public.suppliers(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  total numeric(14,2) not null default 0,
  paid numeric(14,2) not null default 0,
  status text not null default 'completed',
  created_at timestamptz not null default now()
);

create table if not exists public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  total numeric(14,2) not null default 0
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  category text not null,
  amount numeric(14,2) not null check (amount >= 0),
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  movement_type text not null
    check (movement_type in ('purchase','sale','return','adjustment','damage')),
  quantity numeric(14,3) not null,
  reference_id uuid,
  note text,
  created_at timestamptz not null default now()
);

-- Membership helper. SECURITY DEFINER avoids recursive RLS checks.
create or replace function public.is_business_member(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.business_members bm
    where bm.business_id = p_business_id
      and bm.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_business_member(uuid) from public;
grant execute on function public.is_business_member(uuid) to authenticated;

-- Create a business and make the caller its owner.
create or replace function public.create_business(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_business_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.businesses(name)
  values (trim(p_name))
  returning id into new_business_id;

  insert into public.business_members(business_id, user_id, role)
  values (new_business_id, auth.uid(), 'owner');

  insert into public.profiles(id)
  values (auth.uid())
  on conflict (id) do nothing;

  return new_business_id;
end;
$$;

revoke all on function public.create_business(text) from public;
grant execute on function public.create_business(text) to authenticated;

-- RLS
do $$
declare
  t text;
begin
  foreach t in array array[
    'businesses','business_members','categories','products','customers',
    'suppliers','sales','sale_items','purchases','purchase_items',
    'expenses','stock_movements'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
  alter table public.profiles enable row level security;
end $$;

-- Profiles: each user sees/updates own profile.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
for select to authenticated
using (id = (select auth.uid()));

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
for insert to authenticated
with check (id = (select auth.uid()));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Business membership policies.
drop policy if exists members_select on public.business_members;
create policy members_select on public.business_members
for select to authenticated
using (user_id = (select auth.uid()));

-- Shared helper for business-scoped tables.
-- Each policy explicitly names authenticated and checks membership.

drop policy if exists businesses_select on public.businesses;
create policy businesses_select on public.businesses
for select to authenticated
using (public.is_business_member(id));

drop policy if exists businesses_update on public.businesses;
create policy businesses_update on public.businesses
for update to authenticated
using (public.is_business_member(id))
with check (public.is_business_member(id));

drop policy if exists categories_all on public.categories;
create policy categories_all on public.categories
for all to authenticated
using (public.is_business_member(business_id))
with check (public.is_business_member(business_id));

drop policy if exists products_all on public.products;
create policy products_all on public.products
for all to authenticated
using (public.is_business_member(business_id))
with check (public.is_business_member(business_id));

drop policy if exists customers_all on public.customers;
create policy customers_all on public.customers
for all to authenticated
using (public.is_business_member(business_id))
with check (public.is_business_member(business_id));

drop policy if exists suppliers_all on public.suppliers;
create policy suppliers_all on public.suppliers
for all to authenticated
using (public.is_business_member(business_id))
with check (public.is_business_member(business_id));

drop policy if exists sales_all on public.sales;
create policy sales_all on public.sales
for all to authenticated
using (public.is_business_member(business_id))
with check (public.is_business_member(business_id));

drop policy if exists purchases_all on public.purchases;
create policy purchases_all on public.purchases
for all to authenticated
using (public.is_business_member(business_id))
with check (public.is_business_member(business_id));

drop policy if exists expenses_all on public.expenses;
create policy expenses_all on public.expenses
for all to authenticated
using (public.is_business_member(business_id))
with check (public.is_business_member(business_id));

drop policy if exists stock_movements_all on public.stock_movements;
create policy stock_movements_all on public.stock_movements
for all to authenticated
using (public.is_business_member(business_id))
with check (public.is_business_member(business_id));

-- Child tables derive access through their parent business.
drop policy if exists sale_items_all on public.sale_items;
create policy sale_items_all on public.sale_items
for all to authenticated
using (exists (
  select 1 from public.sales s
  where s.id = sale_id and public.is_business_member(s.business_id)
))
with check (exists (
  select 1 from public.sales s
  where s.id = sale_id and public.is_business_member(s.business_id)
));

drop policy if exists purchase_items_all on public.purchase_items;
create policy purchase_items_all on public.purchase_items
for all to authenticated
using (exists (
  select 1 from public.purchases p
  where p.id = purchase_id and public.is_business_member(p.business_id)
))
with check (exists (
  select 1 from public.purchases p
  where p.id = purchase_id and public.is_business_member(p.business_id)
));

-- Realtime for the main synchronized entities.
do $$
begin
  alter publication supabase_realtime add table public.products;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.customers;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.sales;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.stock_movements;
exception when duplicate_object then null;
end $$;

-- Useful dashboard view.
create or replace view public.sales_daily
with (security_invoker = true)
as
select
  business_id,
  date_trunc('day', created_at)::date as day,
  count(*) as orders,
  coalesce(sum(total), 0) as total_sales,
  coalesce(sum(paid), 0) as total_paid
from public.sales
where status = 'completed'
group by business_id, date_trunc('day', created_at)::date;

grant select on public.sales_daily to authenticated;
