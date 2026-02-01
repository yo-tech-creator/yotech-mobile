-- Migration: Fix merch_people INSERT RLS policy
-- firma_admin, bolge_muduru and sube_muduru can add merch_people
-- Only personel should NOT be able to insert

-- Drop the existing INSERT policy
DROP POLICY IF EXISTS "merch_people_insert" ON "public"."merch_people";

-- Create new INSERT policy - personel excluded
CREATE POLICY "merch_people_insert" ON "public"."merch_people" 
FOR INSERT 
WITH CHECK (
  "public"."is_service_role"() 
  OR (
    EXISTS (
      SELECT 1
      FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
      WHERE (
        ("ctx"."role" = 'grand_admin'::"public"."user_role") 
        OR (
          ("ctx"."tenant_id" = "merch_people"."tenant_id") 
          AND ("ctx"."role" = ANY (ARRAY[
            'firma_admin'::"public"."user_role", 
            'bolge_muduru'::"public"."user_role",
            'sube_muduru'::"public"."user_role"
          ]))
        )
      )
    )
  )
);

-- Also fix UPDATE policy to be consistent (firma_admin, bolge_muduru and sube_muduru can update)
DROP POLICY IF EXISTS "merch_people_update" ON "public"."merch_people";

CREATE POLICY "merch_people_update" ON "public"."merch_people"
FOR UPDATE
USING (
  "public"."is_service_role"() 
  OR (
    EXISTS (
      SELECT 1
      FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
      WHERE (
        ("ctx"."role" = 'grand_admin'::"public"."user_role") 
        OR (
          ("ctx"."tenant_id" = "merch_people"."tenant_id") 
          AND ("ctx"."role" = ANY (ARRAY[
            'firma_admin'::"public"."user_role", 
            'bolge_muduru'::"public"."user_role",
            'sube_muduru'::"public"."user_role"
          ]))
        )
      )
    )
  )
);

-- DELETE policy - firma_admin, bolge_muduru and sube_muduru can delete
DROP POLICY IF EXISTS "merch_people_delete" ON "public"."merch_people";

CREATE POLICY "merch_people_delete" ON "public"."merch_people"
FOR DELETE
USING (
  "public"."is_service_role"() 
  OR (
    EXISTS (
      SELECT 1
      FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
      WHERE (
        ("ctx"."role" = 'grand_admin'::"public"."user_role") 
        OR (
          ("ctx"."tenant_id" = "merch_people"."tenant_id") 
          AND ("ctx"."role" = ANY (ARRAY[
            'firma_admin'::"public"."user_role", 
            'bolge_muduru'::"public"."user_role",
            'sube_muduru'::"public"."user_role"
          ]))
        )
      )
    )
  )
);

-- SELECT policy remains unchanged - all roles can view (including sube_muduru and personel)
-- No changes needed for SELECT policy
