-- =====================================================
-- FIX: Multiple RLS policies and task improvements
-- 1. merch_people - sube_muduru insert izni
-- 2. depot_notices - personel insert izni
-- =====================================================

-- 1. merch_people INSERT politikasını güncelle - sube_muduru ekle
DROP POLICY IF EXISTS "merch_people_insert" ON "public"."merch_people";

CREATE POLICY "merch_people_insert" ON "public"."merch_people" 
FOR INSERT 
WITH CHECK (
  public.is_service_role() 
  OR (
    EXISTS (
      SELECT 1
      FROM public.current_user_ctx() ctx(id, tenant_id, role, branch_id)
      WHERE ctx.role = 'grand_admin'::public.user_role
        OR (
          ctx.tenant_id = merch_people.tenant_id 
          AND ctx.role = ANY (ARRAY[
            'firma_admin'::public.user_role, 
            'bolge_muduru'::public.user_role,
            'sube_muduru'::public.user_role  -- Şube müdürü eklendi
          ])
        )
    )
  )
);

-- 2. merch_people UPDATE politikasını güncelle - sube_muduru ekle
DROP POLICY IF EXISTS "merch_people_update" ON "public"."merch_people";

CREATE POLICY "merch_people_update" ON "public"."merch_people" 
FOR UPDATE 
USING (
  public.is_service_role() 
  OR (
    EXISTS (
      SELECT 1
      FROM public.current_user_ctx() ctx(id, tenant_id, role, branch_id)
      WHERE ctx.role = 'grand_admin'::public.user_role
        OR (
          ctx.tenant_id = merch_people.tenant_id 
          AND ctx.role = ANY (ARRAY[
            'firma_admin'::public.user_role, 
            'bolge_muduru'::public.user_role,
            'sube_muduru'::public.user_role  -- Şube müdürü eklendi
          ])
        )
    )
  )
);

-- 3. merch_people DELETE politikasını güncelle - sube_muduru ekle
DROP POLICY IF EXISTS "merch_people_delete" ON "public"."merch_people";

CREATE POLICY "merch_people_delete" ON "public"."merch_people" 
FOR DELETE 
USING (
  public.is_service_role() 
  OR (
    EXISTS (
      SELECT 1
      FROM public.current_user_ctx() ctx(id, tenant_id, role, branch_id)
      WHERE ctx.role = 'grand_admin'::public.user_role
        OR (
          ctx.tenant_id = merch_people.tenant_id 
          AND ctx.role = ANY (ARRAY[
            'firma_admin'::public.user_role, 
            'bolge_muduru'::public.user_role,
            'sube_muduru'::public.user_role  -- Şube müdürü eklendi
          ])
        )
    )
  )
);

-- 4. depot_notices INSERT politikasını güncelle - personel hariç
-- Sadece sube_muduru ve üstü sevk ilanı oluşturabilir
DROP POLICY IF EXISTS "depot_notices_insert" ON "public"."depot_notices";

CREATE POLICY "depot_notices_insert" ON "public"."depot_notices" 
FOR INSERT 
WITH CHECK (
  tenant_id = public.current_tenant_id()
  AND branch_id = (SELECT users.branch_id FROM public.users WHERE users.id = public.current_user_id())
  AND EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id = public.current_user_id()
      AND u.role = ANY (ARRAY[
        'grand_admin'::public.user_role,
        'firma_admin'::public.user_role,
        'bolge_muduru'::public.user_role,
        'sube_muduru'::public.user_role
      ])
  )
);

COMMENT ON POLICY "merch_people_insert" ON "public"."merch_people" IS 
'grand_admin, firma_admin, bolge_muduru ve sube_muduru rolleri mörş kişi ekleyebilir';

COMMENT ON POLICY "depot_notices_insert" ON "public"."depot_notices" IS 
'Sadece grand_admin, firma_admin, bolge_muduru ve sube_muduru sevk ilanı oluşturabilir. Personel ilan oluşturamaz.';

-- =====================================================
-- 5. tasks INSERT politikasını güncelle - personel hariç
-- Sadece sube_muduru ve bolge_muduru görev oluşturabilir
-- =====================================================

DROP POLICY IF EXISTS "tasks_insert" ON "public"."tasks";

CREATE POLICY "tasks_insert" ON "public"."tasks" 
FOR INSERT 
WITH CHECK (
  is_service_role() 
  OR (
    created_by = current_user_id() 
    AND tenant_id = COALESCE(current_tenant_id(), (SELECT u.tenant_id FROM users u WHERE u.id = current_user_id()))
    AND EXISTS (
      SELECT 1
      FROM users u
      WHERE u.id = current_user_id()
        AND u.role = ANY (ARRAY[
          'grand_admin'::user_role,
          'firma_admin'::user_role,
          'bolge_muduru'::user_role,
          'sube_muduru'::user_role
        ])
    )
  )
);

COMMENT ON POLICY "tasks_insert" ON "public"."tasks" IS 
'Sadece grand_admin, firma_admin, bolge_muduru ve sube_muduru görev oluşturabilir. Personel görev oluşturamaz.';

-- =====================================================
-- 6. store_scoring_sessions UPDATE politikasını güncelle
-- Şube müdürü ve personel kendi oluşturdukları formları güncelleyebilmeli
-- =====================================================

DROP POLICY IF EXISTS "store_scoring_sessions_update_v2" ON "public"."store_scoring_sessions";

CREATE POLICY "store_scoring_sessions_update_v2" ON "public"."store_scoring_sessions" 
FOR UPDATE 
USING (
  (current_user_role() = 'grand_admin'::text) 
  OR (
    (current_user_role() = 'firma_admin'::text) 
    AND EXISTS (
      SELECT 1
      FROM store_scoring_form_versions v
      JOIN store_scoring_forms f ON f.id = v.form_id
      WHERE v.id = store_scoring_sessions.form_version_id 
        AND f.tenant_id = current_tenant_id()
    )
  ) 
  OR (
    (current_user_role() = 'bolge_muduru'::text) 
    AND EXISTS (
      SELECT 1
      FROM branches b
      JOIN regions r ON r.id = b.region_id
      WHERE b.id = store_scoring_sessions.branch_id 
        AND r.manager_id = current_user_id() 
        AND r.tenant_id = current_tenant_id()
    )
  ) 
  -- Şube müdürü kendi oluşturduğu formu güncelleyebilir
  OR (
    (current_user_role() = 'sube_muduru'::text) 
    AND evaluator_id = current_user_id()
  )
  -- Personel kendi oluşturduğu formu güncelleyebilir
  OR (
    (current_user_role() = 'personel'::text) 
    AND evaluator_id = current_user_id()
  )
  OR is_service_role()
)
WITH CHECK (
  (current_user_role() = 'grand_admin'::text) 
  OR (
    (current_user_role() = 'firma_admin'::text) 
    AND EXISTS (
      SELECT 1
      FROM store_scoring_form_versions v
      JOIN store_scoring_forms f ON f.id = v.form_id
      WHERE v.id = store_scoring_sessions.form_version_id 
        AND f.tenant_id = current_tenant_id()
    )
  ) 
  OR (
    (current_user_role() = 'bolge_muduru'::text) 
    AND EXISTS (
      SELECT 1
      FROM branches b
      JOIN regions r ON r.id = b.region_id
      WHERE b.id = store_scoring_sessions.branch_id 
        AND r.manager_id = current_user_id() 
        AND r.tenant_id = current_tenant_id()
    )
  )
  -- Şube müdürü kendi oluşturduğu formu güncelleyebilir
  OR (
    (current_user_role() = 'sube_muduru'::text) 
    AND evaluator_id = current_user_id()
  )
  -- Personel kendi oluşturduğu formu güncelleyebilir
  OR (
    (current_user_role() = 'personel'::text) 
    AND evaluator_id = current_user_id()
  )
  OR is_service_role()
);

COMMENT ON POLICY "store_scoring_sessions_update_v2" ON "public"."store_scoring_sessions" IS 
'grand_admin, firma_admin, bolge_muduru herşeyi; sube_muduru ve personel kendi oluşturdukları formları güncelleyebilir';
