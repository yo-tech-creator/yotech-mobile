drop policy "merch_people_delete" on "public"."merch_people";

drop policy "merch_people_insert" on "public"."merch_people";

drop policy "merch_people_update" on "public"."merch_people";


  create policy "merch_people_delete"
  on "public"."merch_people"
  as permissive
  for delete
  to public
using ((public.is_service_role() OR (EXISTS ( SELECT 1
   FROM public.current_user_ctx() ctx(id, tenant_id, role, branch_id)
  WHERE ((ctx.role = 'grand_admin'::public.user_role) OR ((ctx.tenant_id = merch_people.tenant_id) AND (ctx.role = ANY (ARRAY['firma_admin'::public.user_role, 'bolge_muduru'::public.user_role]))))))));



  create policy "merch_people_insert"
  on "public"."merch_people"
  as permissive
  for insert
  to public
with check ((public.is_service_role() OR (EXISTS ( SELECT 1
   FROM public.current_user_ctx() ctx(id, tenant_id, role, branch_id)
  WHERE ((ctx.role = 'grand_admin'::public.user_role) OR ((ctx.tenant_id = merch_people.tenant_id) AND (ctx.role = ANY (ARRAY['firma_admin'::public.user_role, 'bolge_muduru'::public.user_role]))))))));



  create policy "merch_people_update"
  on "public"."merch_people"
  as permissive
  for update
  to public
using ((public.is_service_role() OR (EXISTS ( SELECT 1
   FROM public.current_user_ctx() ctx(id, tenant_id, role, branch_id)
  WHERE ((ctx.role = 'grand_admin'::public.user_role) OR ((ctx.tenant_id = merch_people.tenant_id) AND (ctx.role = ANY (ARRAY['firma_admin'::public.user_role, 'bolge_muduru'::public.user_role]))))))));



