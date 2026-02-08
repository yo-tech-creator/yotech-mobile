-- Migration: Request Assignment and Transfer System
-- Talep atama ve transfer mekanizması için tablo ve sütun güncellemeleri

-- 1. branch_requests tablosuna assigned_to ve assigned_at sütunları ekle
-- assigned_to: Talebi işleme alan (claim eden) kullanıcı
-- assigned_at: İşleme alınma zamanı
ALTER TABLE "public"."branch_requests" 
ADD COLUMN IF NOT EXISTS "assigned_to" uuid REFERENCES "public"."users"("id") ON DELETE SET NULL;

ALTER TABLE "public"."branch_requests" 
ADD COLUMN IF NOT EXISTS "assigned_at" timestamp with time zone;

-- Index oluştur
CREATE INDEX IF NOT EXISTS "idx_branch_requests_assigned_to" ON "public"."branch_requests" ("assigned_to");

-- 2. Request Transfers tablosu - Departman üyeleri arası transfer talepleri
CREATE TABLE IF NOT EXISTS "public"."request_transfers" (
    "id" uuid NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" uuid NOT NULL DEFAULT "public"."current_tenant_id"(),
    "request_id" uuid NOT NULL,
    "from_user_id" uuid NOT NULL,
    "to_user_id" uuid NOT NULL,
    "reason" text,
    "status" text NOT NULL DEFAULT 'pending', -- pending, approved, rejected
    "responded_at" timestamp with time zone,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT "request_transfers_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "request_transfers_request_id_fkey" FOREIGN KEY ("request_id") 
        REFERENCES "public"."branch_requests"("id") ON DELETE CASCADE,
    CONSTRAINT "request_transfers_from_user_id_fkey" FOREIGN KEY ("from_user_id") 
        REFERENCES "public"."users"("id") ON DELETE CASCADE,
    CONSTRAINT "request_transfers_to_user_id_fkey" FOREIGN KEY ("to_user_id") 
        REFERENCES "public"."users"("id") ON DELETE CASCADE,
    CONSTRAINT "request_transfers_tenant_id_fkey" FOREIGN KEY ("tenant_id") 
        REFERENCES "public"."tenants"("id") ON DELETE CASCADE,
    CONSTRAINT "request_transfers_status_check" CHECK (status IN ('pending', 'approved', 'rejected'))
);

-- Index'ler
CREATE INDEX IF NOT EXISTS "idx_request_transfers_tenant_id" ON "public"."request_transfers" ("tenant_id");
CREATE INDEX IF NOT EXISTS "idx_request_transfers_request_id" ON "public"."request_transfers" ("request_id");
CREATE INDEX IF NOT EXISTS "idx_request_transfers_from_user_id" ON "public"."request_transfers" ("from_user_id");
CREATE INDEX IF NOT EXISTS "idx_request_transfers_to_user_id" ON "public"."request_transfers" ("to_user_id");
CREATE INDEX IF NOT EXISTS "idx_request_transfers_status" ON "public"."request_transfers" ("status");

-- Updated_at trigger
CREATE OR REPLACE FUNCTION "public"."update_request_transfers_updated_at"()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS "request_transfers_updated_at_trigger" ON "public"."request_transfers";
CREATE TRIGGER "request_transfers_updated_at_trigger"
    BEFORE UPDATE ON "public"."request_transfers"
    FOR EACH ROW
    EXECUTE FUNCTION "public"."update_request_transfers_updated_at"();

-- 3. RLS Politikaları - request_transfers
ALTER TABLE "public"."request_transfers" ENABLE ROW LEVEL SECURITY;

-- Aynı tenant'taki kullanıcılar görebilir
CREATE POLICY "request_transfers_select_policy" ON "public"."request_transfers"
    FOR SELECT
    USING (
        tenant_id IN (
            SELECT u.tenant_id FROM "public"."users" u WHERE u.id = auth.uid()
        )
    );

-- Transfer talebi oluşturma - sadece talebin mevcut atanan kullanıcısı yapabilir
CREATE POLICY "request_transfers_insert_policy" ON "public"."request_transfers"
    FOR INSERT
    WITH CHECK (
        from_user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM "public"."branch_requests" br 
            WHERE br.id = request_id 
            AND br.assigned_to = auth.uid()
        )
    );

-- Transfer talebini güncelleme - hedef kullanıcı veya firma_admin yapabilir
CREATE POLICY "request_transfers_update_policy" ON "public"."request_transfers"
    FOR UPDATE
    USING (
        to_user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM "public"."users" u 
            WHERE u.id = auth.uid() 
            AND u.tenant_id = tenant_id 
            AND u.role = 'firma_admin'
        )
    );

-- 4. Yardımcı fonksiyonlar

-- Talep atama fonksiyonu (claim)
CREATE OR REPLACE FUNCTION "public"."claim_request"(
    p_request_id uuid
)
RETURNS "public"."branch_requests" AS $$
DECLARE
    v_request "public"."branch_requests";
    v_user_id uuid := auth.uid();
BEGIN
    -- Talebi kontrol et ve ata
    UPDATE "public"."branch_requests"
    SET 
        assigned_to = v_user_id,
        assigned_at = now(),
        status = CASE 
            WHEN status = 'pending' THEN 'in_progress'::public.request_status
            ELSE status
        END,
        updated_at = now()
    WHERE id = p_request_id
    AND assigned_to IS NULL
    AND created_by != v_user_id -- Kendi talebini alamaz
    RETURNING * INTO v_request;
    
    IF v_request IS NULL THEN
        RAISE EXCEPTION 'Talep atanamadı. Talep zaten atanmış veya mevcut değil.';
    END IF;
    
    RETURN v_request;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Transfer talebi oluşturma
CREATE OR REPLACE FUNCTION "public"."create_transfer_request"(
    p_request_id uuid,
    p_to_user_id uuid,
    p_reason text DEFAULT NULL
)
RETURNS "public"."request_transfers" AS $$
DECLARE
    v_transfer "public"."request_transfers";
    v_user_id uuid := auth.uid();
    v_tenant_id uuid;
BEGIN
    -- Tenant ID'yi al
    SELECT tenant_id INTO v_tenant_id 
    FROM "public"."users" 
    WHERE id = v_user_id;
    
    -- Mevcut atanmış kullanıcı olduğunu kontrol et
    IF NOT EXISTS (
        SELECT 1 FROM "public"."branch_requests" 
        WHERE id = p_request_id 
        AND assigned_to = v_user_id
    ) THEN
        RAISE EXCEPTION 'Bu talebi transfer etme yetkiniz yok.';
    END IF;
    
    -- Bekleyen transfer talebi var mı kontrol et
    IF EXISTS (
        SELECT 1 FROM "public"."request_transfers"
        WHERE request_id = p_request_id
        AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'Bu talep için bekleyen bir transfer talebi zaten mevcut.';
    END IF;
    
    -- Transfer talebi oluştur
    INSERT INTO "public"."request_transfers" (
        tenant_id, request_id, from_user_id, to_user_id, reason
    ) VALUES (
        v_tenant_id, p_request_id, v_user_id, p_to_user_id, p_reason
    ) RETURNING * INTO v_transfer;
    
    RETURN v_transfer;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Transfer talebini yanıtla (onayla/reddet)
CREATE OR REPLACE FUNCTION "public"."respond_transfer_request"(
    p_transfer_id uuid,
    p_approve boolean
)
RETURNS "public"."request_transfers" AS $$
DECLARE
    v_transfer "public"."request_transfers";
    v_user_id uuid := auth.uid();
BEGIN
    -- Transfer talebini güncelle
    UPDATE "public"."request_transfers"
    SET 
        status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
        responded_at = now(),
        updated_at = now()
    WHERE id = p_transfer_id
    AND to_user_id = v_user_id
    AND status = 'pending'
    RETURNING * INTO v_transfer;
    
    IF v_transfer IS NULL THEN
        RAISE EXCEPTION 'Transfer talebi bulunamadı veya zaten yanıtlanmış.';
    END IF;
    
    -- Onaylandıysa talebin atanmasını güncelle
    IF p_approve THEN
        UPDATE "public"."branch_requests"
        SET 
            assigned_to = v_transfer.to_user_id,
            assigned_at = now(),
            updated_at = now()
        WHERE id = v_transfer.request_id;
    END IF;
    
    RETURN v_transfer;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Grant permissions
GRANT ALL ON TABLE "public"."request_transfers" TO authenticated;
GRANT SELECT ON TABLE "public"."request_transfers" TO anon;
GRANT EXECUTE ON FUNCTION "public"."claim_request"(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION "public"."create_transfer_request"(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION "public"."respond_transfer_request"(uuid, boolean) TO authenticated;
