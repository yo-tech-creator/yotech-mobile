-- Güncelleme: Taleplerin iptal/teslim akışı
-- Tarih: 2025-12-02
-- İçerik: Yeni teklif statüleri, genişletilmiş RLS ve iptal sonrası ilan miktar restorasyonu

set statement_timeout = 0;

-- 1) Enum'a yeni statüler ekle
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumtypid = 'depot_offer_status'::regtype
          AND enumlabel = 'cancelled'
    ) THEN
        ALTER TYPE public.depot_offer_status ADD VALUE IF NOT EXISTS 'cancelled';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_enum
        WHERE enumtypid = 'depot_offer_status'::regtype
          AND enumlabel = 'delivered'
    ) THEN
        ALTER TYPE public.depot_offer_status ADD VALUE IF NOT EXISTS 'delivered';
    END IF;
END $$;

-- 2) Teklif güncelleme politikasını genişlet (talep sahibi de güncelleyebilsin)
DROP POLICY IF EXISTS "depot_notice_offers_update" ON public.depot_notice_offers;
CREATE POLICY "depot_notice_offers_update"
    ON public.depot_notice_offers
    FOR UPDATE
    USING (
        tenant_id = current_tenant_id()
        AND (
            notice_id IN (
                SELECT id FROM public.depot_notices WHERE created_by = current_user_id()
            )
            OR offered_by = current_user_id()
        )
    )
    WITH CHECK (
        tenant_id = current_tenant_id()
        AND (
            notice_id IN (
                SELECT id FROM public.depot_notices WHERE created_by = current_user_id()
            )
            OR offered_by = current_user_id()
        )
    );

-- 3) İptal edilen kabul edilmiş talepler için ilan miktarını geri yükleyen trigger
CREATE OR REPLACE FUNCTION public.handle_offer_cancellation()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF OLD.status = 'accepted' AND NEW.status = 'cancelled' THEN
            UPDATE public.depot_notices n
            SET quantity = n.quantity + OLD.quantity,
                status = CASE
                    WHEN EXISTS (
                        SELECT 1 FROM public.depot_notice_offers o
                        WHERE o.notice_id = n.id
                          AND o.status = 'accepted'
                          AND o.id <> NEW.id
                    ) THEN 'in_transfer'::public.depot_notice_status
                    ELSE 'open'::public.depot_notice_status
                END
            WHERE n.id = NEW.notice_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS depot_notice_offers_after_update ON public.depot_notice_offers;
CREATE TRIGGER depot_notice_offers_after_update
AFTER UPDATE ON public.depot_notice_offers
FOR EACH ROW EXECUTE FUNCTION public.handle_offer_cancellation();
