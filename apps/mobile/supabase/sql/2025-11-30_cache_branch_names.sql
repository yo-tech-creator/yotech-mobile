-- Cache branch names on depot tables to avoid RLS issues when joining branches
-- Date: 2025-11-30

set statement_timeout = 0;

-- 1) Add branch_name columns if they don't exist
do $$
begin
    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'depot_notices'
          and column_name = 'branch_name'
    ) then
        alter table public.depot_notices
            add column branch_name text;
    end if;

    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'depot_notice_offers'
          and column_name = 'branch_name'
    ) then
        alter table public.depot_notice_offers
            add column branch_name text;
    end if;
end $$;

-- 2) Backfill existing rows
update public.depot_notices n
set branch_name = b.name
from public.branches b
where n.branch_id = b.id
  and coalesce(n.branch_name, '') <> b.name;

update public.depot_notice_offers o
set branch_name = b.name
from public.branches b
where o.branch_id = b.id
  and coalesce(o.branch_name, '') <> b.name;

-- 3) Helper function + triggers to keep columns in sync
create or replace function public.depot_set_branch_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_branch_name text;
begin
    select name into v_branch_name
    from public.branches
    where id = new.branch_id;

    new.branch_name = v_branch_name;
    return new;
end;
$$;

drop trigger if exists depot_notices_branch_name on public.depot_notices;
create trigger depot_notices_branch_name
before insert or update on public.depot_notices
for each row
execute function public.depot_set_branch_name();

drop trigger if exists depot_notice_offers_branch_name on public.depot_notice_offers;
create trigger depot_notice_offers_branch_name
before insert or update on public.depot_notice_offers
for each row
execute function public.depot_set_branch_name();
