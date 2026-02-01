-- ============================================================================
-- BUG REPORT NOTIFICATIONS SYSTEM
-- Hata bildirimleri için kullanıcıya bildirim gönderme altyapısı
-- ============================================================================

-- Bug report notifications tablosu (uygulama içi bildirimler için)
CREATE TABLE IF NOT EXISTS public.bug_report_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bug_report_id UUID NOT NULL REFERENCES public.bug_reports(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Bildirim içeriği
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL CHECK (notification_type IN ('status_change', 'admin_message', 'resolved')),
    
    -- Durum
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    
    -- Zaman damgaları
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- İndeksler
CREATE INDEX IF NOT EXISTS idx_bug_report_notifications_user_id ON public.bug_report_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_bug_report_notifications_bug_report_id ON public.bug_report_notifications(bug_report_id);
CREATE INDEX IF NOT EXISTS idx_bug_report_notifications_is_read ON public.bug_report_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_bug_report_notifications_created_at ON public.bug_report_notifications(created_at DESC);

-- RLS Politikaları
ALTER TABLE public.bug_report_notifications ENABLE ROW LEVEL SECURITY;

-- Kullanıcı kendi bildirimlerini görebilir
CREATE POLICY "users_view_own_notifications"
    ON public.bug_report_notifications FOR SELECT
    USING (auth.uid() = user_id);

-- Kullanıcı kendi bildirimlerini okundu olarak işaretleyebilir
CREATE POLICY "users_update_own_notifications"
    ON public.bug_report_notifications FOR UPDATE
    USING (auth.uid() = user_id);

-- Grand admin bildirim oluşturabilir
CREATE POLICY "grand_admin_insert_notifications"
    ON public.bug_report_notifications FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
            AND u.role = 'grand_admin'
        )
    );

-- ============================================================================
-- RPC: Hata raporu durumu güncellenince bildirim oluştur
-- ============================================================================
CREATE OR REPLACE FUNCTION public.notify_bug_report_status_change(
    p_report_id UUID,
    p_new_status TEXT,
    p_admin_message TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_report_title TEXT;
    v_notification_title TEXT;
    v_notification_message TEXT;
    v_notification_type TEXT;
BEGIN
    -- Rapor bilgilerini al
    SELECT user_id, title INTO v_user_id, v_report_title
    FROM public.bug_reports
    WHERE id = p_report_id;
    
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Duruma göre bildirim içeriğini belirle
    CASE p_new_status
        WHEN 'in_progress' THEN
            v_notification_title := 'Bildiriminiz İşleme Alındı';
            v_notification_message := 'Bildirdiğiniz "' || v_report_title || '" hatası incelemeye alındı.';
            v_notification_type := 'status_change';
        WHEN 'closed' THEN
            v_notification_title := 'Bildiriminiz Çözüldü';
            v_notification_message := 'Bildirdiğiniz "' || v_report_title || '" hatası çözüldü. Teşekkür ederiz!';
            v_notification_type := 'resolved';
        ELSE
            RETURN FALSE;
    END CASE;
    
    -- Admin mesajı varsa ekle
    IF p_admin_message IS NOT NULL AND p_admin_message != '' THEN
        v_notification_message := v_notification_message || E'\n\nYönetici notu: ' || p_admin_message;
    END IF;
    
    -- Bildirim oluştur
    INSERT INTO public.bug_report_notifications (
        bug_report_id,
        user_id,
        title,
        message,
        notification_type
    ) VALUES (
        p_report_id,
        v_user_id,
        v_notification_title,
        v_notification_message,
        v_notification_type
    );
    
    RETURN TRUE;
END;
$$;

-- ============================================================================
-- RPC: Admin mesajı gönder (kullanıcıya bildirim)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.send_bug_report_message(
    p_report_id UUID,
    p_message TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID;
    v_admin_role TEXT;
    v_user_id UUID;
    v_report_title TEXT;
BEGIN
    v_admin_id := auth.uid();
    
    -- Admin kontrolü
    SELECT role INTO v_admin_role
    FROM public.users
    WHERE id = v_admin_id;
    
    IF v_admin_role != 'grand_admin' THEN
        RAISE EXCEPTION 'Bu işlem için yetkiniz yok';
    END IF;
    
    -- Rapor bilgilerini al
    SELECT user_id, title INTO v_user_id, v_report_title
    FROM public.bug_reports
    WHERE id = p_report_id;
    
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Mesajı admin_notes'a kaydet
    UPDATE public.bug_reports
    SET admin_notes = COALESCE(admin_notes || E'\n\n', '') || '[' || NOW()::TEXT || '] ' || p_message
    WHERE id = p_report_id;
    
    -- Bildirim oluştur
    INSERT INTO public.bug_report_notifications (
        bug_report_id,
        user_id,
        title,
        message,
        notification_type
    ) VALUES (
        p_report_id,
        v_user_id,
        'Yöneticiden Mesaj',
        'Bildirdiğiniz "' || v_report_title || '" hakkında yönetici size mesaj gönderdi: ' || p_message,
        'admin_message'
    );
    
    RETURN TRUE;
END;
$$;

-- ============================================================================
-- RPC: Kullanıcının okunmamış bildirimlerini getir
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_user_bug_notifications(
    p_unread_only BOOLEAN DEFAULT FALSE,
    p_limit INT DEFAULT 20
)
RETURNS TABLE (
    notification_id UUID,
    bug_report_id UUID,
    notification_title TEXT,
    notification_message TEXT,
    notification_type TEXT,
    is_read BOOLEAN,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.id,
        n.bug_report_id,
        n.title::TEXT,
        n.message::TEXT,
        n.notification_type::TEXT,
        n.is_read,
        n.created_at
    FROM public.bug_report_notifications n
    WHERE n.user_id = auth.uid()
    AND (NOT p_unread_only OR n.is_read = FALSE)
    ORDER BY n.created_at DESC
    LIMIT p_limit;
END;
$$;

-- ============================================================================
-- RPC: Bildirimi okundu olarak işaretle
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_bug_notification_read(
    p_notification_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.bug_report_notifications
    SET is_read = TRUE, read_at = NOW()
    WHERE id = p_notification_id AND user_id = auth.uid();
    
    RETURN FOUND;
END;
$$;

-- ============================================================================
-- RPC: Tüm bildirimleri okundu olarak işaretle
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_all_bug_notifications_read()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INT;
BEGIN
    UPDATE public.bug_report_notifications
    SET is_read = TRUE, read_at = NOW()
    WHERE user_id = auth.uid() AND is_read = FALSE;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

-- ============================================================================
-- Update bug_report RPC to trigger notifications
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_bug_report(
    p_report_id UUID,
    p_status TEXT DEFAULT NULL,
    p_priority TEXT DEFAULT NULL,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_role TEXT;
    v_old_status TEXT;
BEGIN
    v_user_id := auth.uid();
    
    SELECT role INTO v_role
    FROM public.users
    WHERE id = v_user_id;
    
    IF v_role != 'grand_admin' THEN
        RAISE EXCEPTION 'Bu işlem için yetkiniz yok';
    END IF;
    
    -- Mevcut durumu al (bildirim için)
    SELECT status INTO v_old_status
    FROM public.bug_reports
    WHERE id = p_report_id;
    
    -- Güncelleme yap
    UPDATE public.bug_reports
    SET 
        status = COALESCE(p_status, status),
        priority = COALESCE(p_priority, priority),
        admin_notes = COALESCE(p_admin_notes, admin_notes),
        resolved_by = CASE WHEN p_status = 'closed' THEN v_user_id ELSE resolved_by END,
        resolved_at = CASE WHEN p_status = 'closed' AND resolved_at IS NULL THEN NOW() ELSE resolved_at END,
        updated_at = NOW()
    WHERE id = p_report_id;
    
    -- Durum değiştiyse bildirim gönder
    IF p_status IS NOT NULL AND p_status != v_old_status AND p_status IN ('in_progress', 'closed') THEN
        PERFORM public.notify_bug_report_status_change(p_report_id, p_status, NULL);
    END IF;
    
    RETURN FOUND;
END;
$$;
