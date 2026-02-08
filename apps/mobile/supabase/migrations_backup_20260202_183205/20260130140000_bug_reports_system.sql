-- ============================================================================
-- BUG REPORTS SYSTEM
-- Kullanıcılardan gelen hata bildirimlerini yönetmek için
-- ============================================================================

-- Bug Reports Tablosu
CREATE TABLE IF NOT EXISTS public.bug_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Rapor detayları
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    
    -- Cihaz bilgileri
    device_info JSONB DEFAULT '{}',
    app_version VARCHAR(50),
    
    -- Durum
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'critical')),
    
    -- Admin yanıtı
    admin_notes TEXT,
    resolved_by UUID REFERENCES auth.users(id),
    resolved_at TIMESTAMPTZ,
    
    -- Zaman damgaları
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- İndeksler
CREATE INDEX IF NOT EXISTS idx_bug_reports_tenant_id ON public.bug_reports(tenant_id);
CREATE INDEX IF NOT EXISTS idx_bug_reports_user_id ON public.bug_reports(user_id);
CREATE INDEX IF NOT EXISTS idx_bug_reports_status ON public.bug_reports(status);
CREATE INDEX IF NOT EXISTS idx_bug_reports_created_at ON public.bug_reports(created_at DESC);

-- Updated_at trigger fonksiyonu (eğer yoksa)
CREATE OR REPLACE FUNCTION public.trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Updated_at trigger
CREATE TRIGGER set_bug_reports_updated_at
    BEFORE UPDATE ON public.bug_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_set_updated_at();

-- RLS Politikaları
ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;

-- Kullanıcı kendi raporlarını görebilir
CREATE POLICY "users_view_own_bug_reports"
    ON public.bug_reports FOR SELECT
    USING (auth.uid() = user_id);

-- Kullanıcı rapor oluşturabilir
CREATE POLICY "users_insert_bug_reports"
    ON public.bug_reports FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Grand admin tüm raporları görebilir
CREATE POLICY "grand_admin_view_all_bug_reports"
    ON public.bug_reports FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
            AND u.role = 'grand_admin'
        )
    );

-- Grand admin raporları güncelleyebilir
CREATE POLICY "grand_admin_update_bug_reports"
    ON public.bug_reports FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
            AND u.role = 'grand_admin'
        )
    );

-- Firma admin kendi tenant'ındaki raporları görebilir
CREATE POLICY "firma_admin_view_tenant_bug_reports"
    ON public.bug_reports FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
            AND u.role = 'firma_admin'
            AND u.tenant_id = bug_reports.tenant_id
        )
    );

-- ============================================================================
-- RPC: Hata raporu oluştur
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_bug_report(
    p_title TEXT,
    p_description TEXT,
    p_device_info JSONB DEFAULT '{}',
    p_app_version TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_tenant_id UUID;
    v_report_id UUID;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Oturum açılmamış';
    END IF;
    
    -- Kullanıcının tenant_id'sini al
    SELECT tenant_id INTO v_tenant_id
    FROM public.users
    WHERE id = v_user_id;
    
    -- Rapor oluştur
    INSERT INTO public.bug_reports (
        tenant_id,
        user_id,
        title,
        description,
        device_info,
        app_version
    ) VALUES (
        v_tenant_id,
        v_user_id,
        p_title,
        p_description,
        p_device_info,
        p_app_version
    )
    RETURNING id INTO v_report_id;
    
    RETURN v_report_id;
END;
$$;

-- ============================================================================
-- RPC: Hata raporlarını listele (Grand Admin için)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_bug_reports(
    p_status TEXT DEFAULT NULL,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    tenant_id UUID,
    tenant_name TEXT,
    user_id UUID,
    user_name TEXT,
    user_email TEXT,
    title TEXT,
    description TEXT,
    device_info JSONB,
    app_version TEXT,
    status TEXT,
    priority TEXT,
    admin_notes TEXT,
    resolved_by UUID,
    resolved_by_name TEXT,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_role TEXT;
BEGIN
    v_user_id := auth.uid();
    
    SELECT role INTO v_role
    FROM public.users
    WHERE id = v_user_id;
    
    IF v_role != 'grand_admin' THEN
        RAISE EXCEPTION 'Bu işlem için yetkiniz yok';
    END IF;
    
    RETURN QUERY
    SELECT 
        br.id,
        br.tenant_id,
        t.name::TEXT AS tenant_name,
        br.user_id,
        (u.first_name || ' ' || u.last_name)::TEXT AS user_name,
        au.email::TEXT AS user_email,
        br.title::TEXT,
        br.description::TEXT,
        br.device_info,
        br.app_version::TEXT,
        br.status::TEXT,
        br.priority::TEXT,
        br.admin_notes::TEXT,
        br.resolved_by,
        (ru.first_name || ' ' || ru.last_name)::TEXT AS resolved_by_name,
        br.resolved_at,
        br.created_at
    FROM public.bug_reports br
    LEFT JOIN public.tenants t ON t.id = br.tenant_id
    LEFT JOIN public.users u ON u.id = br.user_id
    LEFT JOIN auth.users au ON au.id = br.user_id
    LEFT JOIN public.users ru ON ru.id = br.resolved_by
    WHERE (p_status IS NULL OR br.status = p_status)
    ORDER BY 
        CASE br.priority 
            WHEN 'critical' THEN 1 
            WHEN 'high' THEN 2 
            WHEN 'normal' THEN 3 
            ELSE 4 
        END,
        br.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

-- ============================================================================
-- RPC: Hata raporu güncelle (Grand Admin için)
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
BEGIN
    v_user_id := auth.uid();
    
    SELECT role INTO v_role
    FROM public.users
    WHERE id = v_user_id;
    
    IF v_role != 'grand_admin' THEN
        RAISE EXCEPTION 'Bu işlem için yetkiniz yok';
    END IF;
    
    UPDATE public.bug_reports
    SET 
        status = COALESCE(p_status, status),
        priority = COALESCE(p_priority, priority),
        admin_notes = COALESCE(p_admin_notes, admin_notes),
        resolved_by = CASE WHEN p_status IN ('resolved', 'closed') THEN v_user_id ELSE resolved_by END,
        resolved_at = CASE WHEN p_status IN ('resolved', 'closed') AND resolved_at IS NULL THEN NOW() ELSE resolved_at END,
        updated_at = NOW()
    WHERE id = p_report_id;
    
    RETURN FOUND;
END;
$$;

COMMENT ON TABLE public.bug_reports IS 'Kullanıcılardan gelen hata bildirimleri';
