-- İlan silme yetkisi için RLS politikası
-- Tarih: 2025-12-01

set statement_timeout = 0;

alter table public.depot_notices enable row level security;

drop policy if exists "depot_notices_delete" on public.depot_notices;
create policy "depot_notices_delete"
    on public.depot_notices
    for delete
    using (
        tenant_id = current_tenant_id()
        and (
            created_by = current_user_id()
            or current_user_role() in ('sube_muduru', 'firma_admin', 'grand_admin')
        )
    );
