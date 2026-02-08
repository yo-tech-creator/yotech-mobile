-- Migration: Departments System
-- Departman yönetimi için tablo ve ilişkiler

-- 1. Departmanlar tablosu
CREATE TABLE IF NOT EXISTS "public"."departments" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" uuid NOT NULL,
    "name" text NOT NULL,
    "description" text,
    "is_active" boolean NOT NULL DEFAULT true,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "departments_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "departments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE
);

-- Tenant ve isim için unique constraint
ALTER TABLE "public"."departments" 
ADD CONSTRAINT "departments_tenant_name_unique" UNIQUE ("tenant_id", "name");

-- 2. Users tablosuna department_id ekleme
ALTER TABLE "public"."users" 
ADD COLUMN IF NOT EXISTS "department_id" uuid REFERENCES "public"."departments"("id") ON DELETE SET NULL;

-- 3. branch_requests tablosuna target_department_id ekleme (mevcut target_department text alanı korunacak)
ALTER TABLE "public"."branch_requests" 
ADD COLUMN IF NOT EXISTS "target_department_id" uuid REFERENCES "public"."departments"("id") ON DELETE SET NULL;

-- 4. Index oluştur
CREATE INDEX IF NOT EXISTS "idx_departments_tenant_id" ON "public"."departments" ("tenant_id");
CREATE INDEX IF NOT EXISTS "idx_departments_is_active" ON "public"."departments" ("is_active");
CREATE INDEX IF NOT EXISTS "idx_users_department_id" ON "public"."users" ("department_id");
CREATE INDEX IF NOT EXISTS "idx_branch_requests_target_department_id" ON "public"."branch_requests" ("target_department_id");

-- 5. RLS Politikaları
ALTER TABLE "public"."departments" ENABLE ROW LEVEL SECURITY;

-- Aynı tenant'taki kullanıcılar görebilir
CREATE POLICY "departments_select_policy" ON "public"."departments"
    FOR SELECT
    USING (
        tenant_id IN (
            SELECT u.tenant_id FROM "public"."users" u WHERE u.id = auth.uid()
        )
    );

-- Sadece firma_admin insert/update/delete yapabilir
CREATE POLICY "departments_insert_policy" ON "public"."departments"
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM "public"."users" u 
            WHERE u.id = auth.uid() 
            AND u.tenant_id = tenant_id 
            AND u.role = 'firma_admin'
        )
    );

CREATE POLICY "departments_update_policy" ON "public"."departments"
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM "public"."users" u 
            WHERE u.id = auth.uid() 
            AND u.tenant_id = tenant_id 
            AND u.role = 'firma_admin'
        )
    );

CREATE POLICY "departments_delete_policy" ON "public"."departments"
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM "public"."users" u 
            WHERE u.id = auth.uid() 
            AND u.tenant_id = tenant_id 
            AND u.role = 'firma_admin'
        )
    );

-- 6. Updated_at trigger
CREATE OR REPLACE FUNCTION "public"."update_departments_updated_at"()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS "departments_updated_at_trigger" ON "public"."departments";
CREATE TRIGGER "departments_updated_at_trigger"
    BEFORE UPDATE ON "public"."departments"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."update_departments_updated_at"();

-- 7. Grant permissions
GRANT ALL ON TABLE "public"."departments" TO authenticated;
GRANT SELECT ON TABLE "public"."departments" TO anon;

-- 8. get_user_data_by_id fonksiyonunu department_id ile güncelle
-- Önce mevcut fonksiyonu drop et (return type değiştirilemez)
DROP FUNCTION IF EXISTS "public"."get_user_data_by_id"("text");

CREATE FUNCTION "public"."get_user_data_by_id"("p_user_id" "text") 
RETURNS TABLE(
    "id" "text", 
    "email" "text", 
    "first_name" "text", 
    "last_name" "text", 
    "role" "text", 
    "tenant_id" "text", 
    "branch_id" "text", 
    "employee_code" "text",
    "department_id" "text"
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT 
    id::TEXT, email::TEXT, first_name::TEXT, last_name::TEXT,
    role::TEXT, tenant_id::TEXT, branch_id::TEXT, employee_code::TEXT,
    department_id::TEXT
  FROM users WHERE id = p_user_id::UUID LIMIT 1;
$function$;

-- Grant tekrar ver
GRANT ALL ON FUNCTION "public"."get_user_data_by_id"("text") TO anon;
GRANT ALL ON FUNCTION "public"."get_user_data_by_id"("text") TO authenticated;
GRANT ALL ON FUNCTION "public"."get_user_data_by_id"("text") TO service_role;

-- 9. Örnek departmanlar ekleme fonksiyonu (tenant yöneticileri için)
CREATE OR REPLACE FUNCTION "public"."seed_default_departments"(p_tenant_id uuid)
RETURNS void AS $$
BEGIN
    INSERT INTO "public"."departments" (tenant_id, name, description)
    VALUES 
        (p_tenant_id, 'Teknik Servis', 'Teknik destek ve arıza talepleri'),
        (p_tenant_id, 'İnsan Kaynakları', 'Personel ve izin talepleri'),
        (p_tenant_id, 'Muhasebe', 'Mali işlemler ve ödemeler'),
        (p_tenant_id, 'Depo', 'Stok ve tedarik talepleri'),
        (p_tenant_id, 'Yönetim', 'Genel yönetim talepleri')
    ON CONFLICT (tenant_id, name) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION "public"."seed_default_departments"(uuid) TO authenticated;
