-- Depo transfer modülü temel şeması
-- Tarih: 2025-11-26
-- Amaç: depot_notices + depot_notice_offers tablolarını, enum tiplerini ve RLS politikalarını kurmak

set statement_timeout = 0;

-- 1) Enum tipleri
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'depot_notice_type') THEN
        CREATE TYPE public.depot_notice_type AS ENUM ('shortage', 'surplus');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'depot_notice_status') THEN
        CREATE TYPE public.depot_notice_status AS ENUM ('open', 'in_transfer', 'fulfilled', 'cancelled');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'depot_offer_status') THEN
        CREATE TYPE public.depot_offer_status AS ENUM ('pending', 'accepted', 'rejected', 'expired');
    END IF;
END $$;

-- 2) depot_notices tablosu
CREATE TABLE IF NOT EXISTS public.depot_notices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
    branch_id uuid NOT NULL REFERENCES public.branches (id) ON DELETE CASCADE,
    created_by uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    product_name text NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    unit text NOT NULL DEFAULT 'adet',
    type public.depot_notice_type NOT NULL,
    status public.depot_notice_status NOT NULL DEFAULT 'open',
    note text,
    expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS depot_notices_tenant_branch_idx
    ON public.depot_notices (tenant_id, branch_id, status);

-- 3) depot_notice_offers tablosu
CREATE TABLE IF NOT EXISTS public.depot_notice_offers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
    notice_id uuid NOT NULL REFERENCES public.depot_notices (id) ON DELETE CASCADE,
    branch_id uuid NOT NULL REFERENCES public.branches (id) ON DELETE CASCADE,
    offered_by uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    quantity integer NOT NULL CHECK (quantity > 0),
    status public.depot_offer_status NOT NULL DEFAULT 'pending',
    decision_by uuid REFERENCES public.users (id) ON DELETE SET NULL,
    decision_at timestamptz,
    message text,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS depot_notice_offers_notice_idx
    ON public.depot_notice_offers (notice_id, status);

CREATE UNIQUE INDEX IF NOT EXISTS depot_notice_offers_unique_pending
    ON public.depot_notice_offers (notice_id, branch_id)
    WHERE status = 'pending';

-- 4) updated_at trigger helper (sadece bu tablolar için)
CREATE OR REPLACE FUNCTION public.depot_touch_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = timezone('utc', now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER depot_notices_set_updated_at
BEFORE UPDATE ON public.depot_notices
FOR EACH ROW EXECUTE FUNCTION public.depot_touch_updated_at();

CREATE TRIGGER depot_notice_offers_set_updated_at
BEFORE UPDATE ON public.depot_notice_offers
FOR EACH ROW EXECUTE FUNCTION public.depot_touch_updated_at();

-- 5) RLS
ALTER TABLE public.depot_notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.depot_notice_offers ENABLE ROW LEVEL SECURITY;

-- depot_notices policies
DROP POLICY IF EXISTS "depot_notices_select" ON public.depot_notices;
CREATE POLICY "depot_notices_select"
    ON public.depot_notices
    FOR SELECT
    USING (tenant_id = current_tenant_id());

DROP POLICY IF EXISTS "depot_notices_insert" ON public.depot_notices;
CREATE POLICY "depot_notices_insert"
    ON public.depot_notices
    FOR INSERT
    WITH CHECK (
        tenant_id = current_tenant_id()
        AND branch_id = (SELECT branch_id FROM public.users WHERE id = current_user_id())
    );

DROP POLICY IF EXISTS "depot_notices_update" ON public.depot_notices;
CREATE POLICY "depot_notices_update"
    ON public.depot_notices
    FOR UPDATE
    USING (
        tenant_id = current_tenant_id()
        AND (
            created_by = current_user_id()
            OR current_user_role() IN ('sube_muduru', 'firma_admin', 'grand_admin')
        )
    )
    WITH CHECK (
        tenant_id = current_tenant_id()
    );

-- depot_notice_offers policies
DROP POLICY IF EXISTS "depot_notice_offers_select" ON public.depot_notice_offers;
CREATE POLICY "depot_notice_offers_select"
    ON public.depot_notice_offers
    FOR SELECT
    USING (
        tenant_id = current_tenant_id()
        AND (
            branch_id = (SELECT branch_id FROM public.users WHERE id = current_user_id())
            OR notice_id IN (
                SELECT id FROM public.depot_notices WHERE created_by = current_user_id()
            )
        )
    );

DROP POLICY IF EXISTS "depot_notice_offers_insert" ON public.depot_notice_offers;
CREATE POLICY "depot_notice_offers_insert"
    ON public.depot_notice_offers
    FOR INSERT
    WITH CHECK (
        tenant_id = current_tenant_id()
        AND branch_id = (SELECT branch_id FROM public.users WHERE id = current_user_id())
        AND notice_id IN (
            SELECT id FROM public.depot_notices WHERE tenant_id = current_tenant_id()
        )
    );

DROP POLICY IF EXISTS "depot_notice_offers_update" ON public.depot_notice_offers;
CREATE POLICY "depot_notice_offers_update"
    ON public.depot_notice_offers
    FOR UPDATE
    USING (
        tenant_id = current_tenant_id()
        AND notice_id IN (
            SELECT id FROM public.depot_notices WHERE created_by = current_user_id()
        )
    )
    WITH CHECK (
        tenant_id = current_tenant_id()
    );

-- 6) Özete dönük view (pending sayacı)
DROP VIEW IF EXISTS public.depot_notice_offer_counts;

CREATE OR REPLACE FUNCTION public.get_depot_notice_offer_counts()
RETURNS TABLE (
    notice_id uuid,
    pending_count bigint,
    accepted_count bigint,
    rejected_count bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        n.id AS notice_id,
        COUNT(*) FILTER (WHERE o.status = 'pending') AS pending_count,
        COUNT(*) FILTER (WHERE o.status = 'accepted') AS accepted_count,
        COUNT(*) FILTER (WHERE o.status = 'rejected') AS rejected_count
    FROM public.depot_notices n
    LEFT JOIN public.depot_notice_offers o ON o.notice_id = n.id
    WHERE n.tenant_id = current_tenant_id()
    GROUP BY n.id;
$$;

GRANT EXECUTE ON FUNCTION public.get_depot_notice_offer_counts TO authenticated;
