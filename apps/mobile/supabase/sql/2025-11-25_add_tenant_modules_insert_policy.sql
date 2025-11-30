begin;

-- Allow grand admins or tenant-scoped admins to create tenant_modules rows from the client.
drop policy if exists tenant_modules_insert on public.tenant_modules;
create policy tenant_modules_insert
  on public.tenant_modules
  for insert
  with check (
    (auth.role() = 'service_role'::text)
    or exists (
      select 1
        from public.users u
       where u.id = auth.uid()
         and (
           u.role = 'grand_admin'::user_role
           or u.tenant_id = tenant_modules.tenant_id
         )
    )
  );

commit;
