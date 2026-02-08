-- Fix RLS policy for store_scoring_forms to allow grand_admin to view all tenants

-- Drop existing policy
DROP POLICY IF EXISTS "store_forms_access_v2" ON public.store_scoring_forms;

-- Create new policy that allows:
-- 1. grand_admin to see all forms (all tenants)
-- 2. firma_admin, bolge_muduru, sube_muduru, personel to see their tenant's forms
CREATE POLICY "store_forms_select" ON public.store_scoring_forms
FOR SELECT TO authenticated
USING (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR tenant_id = current_tenant_id()
);

-- Also need policies for INSERT, UPDATE, DELETE for form management
-- Currently only SELECT policy exists, let's add the others for completeness

-- INSERT policy: Only firma_admin and grand_admin can create forms
DROP POLICY IF EXISTS "store_forms_insert" ON public.store_scoring_forms;
CREATE POLICY "store_forms_insert" ON public.store_scoring_forms
FOR INSERT TO authenticated
WITH CHECK (
  current_user_role() IN ('grand_admin', 'firma_admin')
  OR is_service_role()
);

-- UPDATE policy: grand_admin can update any, firma_admin can update their tenant's forms
DROP POLICY IF EXISTS "store_forms_update" ON public.store_scoring_forms;
CREATE POLICY "store_forms_update" ON public.store_scoring_forms
FOR UPDATE TO authenticated
USING (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR (current_user_role() = 'firma_admin' AND tenant_id = current_tenant_id())
)
WITH CHECK (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR (current_user_role() = 'firma_admin' AND tenant_id = current_tenant_id())
);

-- DELETE policy: grand_admin can delete any, firma_admin can delete their tenant's forms
DROP POLICY IF EXISTS "store_forms_delete" ON public.store_scoring_forms;
CREATE POLICY "store_forms_delete" ON public.store_scoring_forms
FOR DELETE TO authenticated
USING (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR (current_user_role() = 'firma_admin' AND tenant_id = current_tenant_id())
);

-- Also fix RLS for related tables that the view joins

-- store_scoring_form_versions
DROP POLICY IF EXISTS "store_form_versions_select" ON public.store_scoring_form_versions;
CREATE POLICY "store_form_versions_select" ON public.store_scoring_form_versions
FOR SELECT TO authenticated
USING (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR form_id IN (SELECT id FROM store_scoring_forms WHERE tenant_id = current_tenant_id())
);

DROP POLICY IF EXISTS "store_form_versions_insert" ON public.store_scoring_form_versions;
CREATE POLICY "store_form_versions_insert" ON public.store_scoring_form_versions
FOR INSERT TO authenticated
WITH CHECK (
  current_user_role() IN ('grand_admin', 'firma_admin')
  OR is_service_role()
);

DROP POLICY IF EXISTS "store_form_versions_update" ON public.store_scoring_form_versions;
CREATE POLICY "store_form_versions_update" ON public.store_scoring_form_versions
FOR UPDATE TO authenticated
USING (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR (current_user_role() = 'firma_admin' AND form_id IN (SELECT id FROM store_scoring_forms WHERE tenant_id = current_tenant_id()))
)
WITH CHECK (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR (current_user_role() = 'firma_admin' AND form_id IN (SELECT id FROM store_scoring_forms WHERE tenant_id = current_tenant_id()))
);

-- store_scoring_sections
DROP POLICY IF EXISTS "store_sections_select" ON public.store_scoring_sections;
CREATE POLICY "store_sections_select" ON public.store_scoring_sections
FOR SELECT TO authenticated
USING (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR form_version_id IN (
    SELECT fv.id FROM store_scoring_form_versions fv
    JOIN store_scoring_forms f ON f.id = fv.form_id
    WHERE f.tenant_id = current_tenant_id()
  )
);

DROP POLICY IF EXISTS "store_sections_insert" ON public.store_scoring_sections;
CREATE POLICY "store_sections_insert" ON public.store_scoring_sections
FOR INSERT TO authenticated
WITH CHECK (
  current_user_role() IN ('grand_admin', 'firma_admin')
  OR is_service_role()
);

DROP POLICY IF EXISTS "store_sections_update" ON public.store_scoring_sections;
CREATE POLICY "store_sections_update" ON public.store_scoring_sections
FOR UPDATE TO authenticated
USING (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR (current_user_role() = 'firma_admin' AND form_version_id IN (
    SELECT fv.id FROM store_scoring_form_versions fv
    JOIN store_scoring_forms f ON f.id = fv.form_id
    WHERE f.tenant_id = current_tenant_id()
  ))
)
WITH CHECK (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR (current_user_role() = 'firma_admin' AND form_version_id IN (
    SELECT fv.id FROM store_scoring_form_versions fv
    JOIN store_scoring_forms f ON f.id = fv.form_id
    WHERE f.tenant_id = current_tenant_id()
  ))
);

-- store_scoring_items
DROP POLICY IF EXISTS "store_items_select" ON public.store_scoring_items;
CREATE POLICY "store_items_select" ON public.store_scoring_items
FOR SELECT TO authenticated
USING (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR section_id IN (
    SELECT s.id FROM store_scoring_sections s
    JOIN store_scoring_form_versions fv ON fv.id = s.form_version_id
    JOIN store_scoring_forms f ON f.id = fv.form_id
    WHERE f.tenant_id = current_tenant_id()
  )
);

DROP POLICY IF EXISTS "store_items_insert" ON public.store_scoring_items;
CREATE POLICY "store_items_insert" ON public.store_scoring_items
FOR INSERT TO authenticated
WITH CHECK (
  current_user_role() IN ('grand_admin', 'firma_admin')
  OR is_service_role()
);

DROP POLICY IF EXISTS "store_items_update" ON public.store_scoring_items;
CREATE POLICY "store_items_update" ON public.store_scoring_items
FOR UPDATE TO authenticated
USING (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR (current_user_role() = 'firma_admin' AND section_id IN (
    SELECT s.id FROM store_scoring_sections s
    JOIN store_scoring_form_versions fv ON fv.id = s.form_version_id
    JOIN store_scoring_forms f ON f.id = fv.form_id
    WHERE f.tenant_id = current_tenant_id()
  ))
)
WITH CHECK (
  current_user_role() = 'grand_admin'
  OR is_service_role()
  OR (current_user_role() = 'firma_admin' AND section_id IN (
    SELECT s.id FROM store_scoring_sections s
    JOIN store_scoring_form_versions fv ON fv.id = s.form_version_id
    JOIN store_scoring_forms f ON f.id = fv.form_id
    WHERE f.tenant_id = current_tenant_id()
  ))
);
