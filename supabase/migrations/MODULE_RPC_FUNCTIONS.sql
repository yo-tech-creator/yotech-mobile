-- ================================================================
-- MODÜL YÖNETİMİ RPC FONKSİYONLARI
-- ================================================================

-- ============================================================
-- 1. GET_ALL_TENANTS - Grand Admin için tüm firmaları listele
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_all_tenants()
RETURNS TABLE (
  id UUID,
  code TEXT,
  name TEXT,
  active BOOLEAN,
  total_users BIGINT,
  active_modules BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Sadece grand admin çağırabilir
  IF current_user_role() != 'grand_admin' THEN
    RAISE EXCEPTION 'Bu fonksiyonu sadece Grand Admin çağırabilir';
  END IF;
  
  RETURN QUERY
  SELECT 
    t.id,
    t.code,
    t.name,
    t.active,
    COUNT(DISTINCT u.id) as total_users,
    COUNT(DISTINCT tm.module_code) FILTER (WHERE tm.is_enabled = true) as active_modules
  FROM tenants t
  LEFT JOIN users u ON u.tenant_id = t.id AND u.active = true
  LEFT JOIN tenant_modules tm ON tm.tenant_id = t.id
  WHERE t.code != 'SYSTEM' -- Sistem tenant'ını gösterme
  GROUP BY t.id, t.code, t.name, t.active
  ORDER BY t.name;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_tenants() TO authenticated;

-- ============================================================
-- 2. GET_TENANT_MODULES - Firma modüllerini getir
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_tenant_modules(p_tenant_id UUID)
RETURNS TABLE (
  module_code TEXT,
  module_name TEXT,
  module_icon TEXT,
  module_description TEXT,
  is_core BOOLEAN,
  is_enabled BOOLEAN,
  enabled_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Grand admin veya aynı tenant'taki kullanıcı çağırabilir
  IF current_user_role() != 'grand_admin' AND current_tenant_id() != p_tenant_id THEN
    RAISE EXCEPTION 'Bu firmaya erişim yetkiniz yok';
  END IF;
  
  RETURN QUERY
  SELECT 
    m.code,
    m.name,
    m.icon,
    m.description,
    m.is_core,
    COALESCE(tm.is_enabled, false) as is_enabled,
    tm.enabled_at
  FROM modules m
  LEFT JOIN tenant_modules tm ON tm.module_code = m.code AND tm.tenant_id = p_tenant_id
  WHERE m.active = true
  ORDER BY m.display_order;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_tenant_modules(UUID) TO authenticated;

-- ============================================================
-- 3. TOGGLE_TENANT_MODULE - Modül aç/kapa
-- ============================================================
CREATE OR REPLACE FUNCTION public.toggle_tenant_module(
  p_tenant_id UUID,
  p_module_code TEXT,
  p_is_enabled BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_core BOOLEAN;
BEGIN
  -- Sadece grand admin çağırabilir
  IF current_user_role() != 'grand_admin' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bu işlem için Grand Admin yetkisi gerekli'
    );
  END IF;
  
  -- Core modül mü kontrol et
  SELECT is_core INTO v_is_core FROM modules WHERE code = p_module_code;
  
  IF v_is_core AND NOT p_is_enabled THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Temel modüller kapatılamaz'
    );
  END IF;
  
  -- Modül kaydını ekle veya güncelle
  INSERT INTO tenant_modules (tenant_id, module_code, is_enabled, enabled_by)
  VALUES (p_tenant_id, p_module_code, p_is_enabled, current_user_id())
  ON CONFLICT (tenant_id, module_code)
  DO UPDATE SET 
    is_enabled = p_is_enabled,
    enabled_at = NOW(),
    enabled_by = current_user_id();
  
  RETURN jsonb_build_object(
    'success', true,
    'tenant_id', p_tenant_id,
    'module_code', p_module_code,
    'is_enabled', p_is_enabled
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_tenant_module(UUID, TEXT, BOOLEAN) TO authenticated;

-- ============================================================
-- 4. GET_USER_MODULES - Kullanıcının modüllerini getir
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_modules()
RETURNS TABLE (
  module_code TEXT,
  module_name TEXT,
  module_icon TEXT,
  is_core BOOLEAN,
  display_order INT,
  is_visible BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id UUID;
BEGIN
  v_tenant_id := current_tenant_id();
  
  RETURN QUERY
  SELECT 
    COALESCE(m.code, '') as module_code,
    COALESCE(m.name, 'Bilinmeyen Modül') as module_name,
    COALESCE(m.icon, 'apps') as module_icon,
    COALESCE(m.is_core, false) as is_core,
    COALESCE(ump.display_order, m.display_order, 999) as display_order,
    COALESCE(ump.is_visible, true) as is_visible
  FROM modules m
  INNER JOIN tenant_modules tm ON tm.module_code = m.code AND tm.tenant_id = v_tenant_id
  LEFT JOIN user_module_preferences ump ON ump.module_code = m.code AND ump.user_id = current_user_id()
  WHERE m.active = true 
    AND tm.is_enabled = true
    AND m.code IS NOT NULL
    AND m.name IS NOT NULL
    AND m.icon IS NOT NULL
  ORDER BY COALESCE(ump.display_order, m.display_order, 999);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_modules() TO authenticated;

-- ============================================================
-- 5. UPDATE_USER_MODULE_ORDER - Modül sırasını güncelle
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_user_module_order(
  p_module_code TEXT,
  p_display_order INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO user_module_preferences (user_id, module_code, display_order)
  VALUES (current_user_id(), p_module_code, p_display_order)
  ON CONFLICT (user_id, module_code)
  DO UPDATE SET 
    display_order = p_display_order,
    updated_at = NOW();
  
  RETURN jsonb_build_object(
    'success', true,
    'module_code', p_module_code,
    'display_order', p_display_order
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_user_module_order(TEXT, INT) TO authenticated;

-- ============================================================
-- 6. BATCH_UPDATE_MODULE_ORDER - Toplu sıra güncelleme
-- ============================================================
CREATE OR REPLACE FUNCTION public.batch_update_module_order(
  p_module_orders JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_module JSONB;
  v_count INT := 0;
BEGIN
  FOR v_module IN SELECT * FROM jsonb_array_elements(p_module_orders)
  LOOP
    INSERT INTO user_module_preferences (user_id, module_code, display_order)
    VALUES (
      current_user_id(),
      v_module->>'module_code',
      (v_module->>'display_order')::INT
    )
    ON CONFLICT (user_id, module_code)
    DO UPDATE SET 
      display_order = (v_module->>'display_order')::INT,
      updated_at = NOW();
    
    v_count := v_count + 1;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'updated_count', v_count
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.batch_update_module_order(JSONB) TO authenticated;

-- ============================================================
-- BAŞARI MESAJI
-- ============================================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🎉 Modül RPC fonksiyonları oluşturuldu!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Fonksiyonlar:';
  RAISE NOTICE '  ✅ get_all_tenants() - Tüm firmaları listele';
  RAISE NOTICE '  ✅ get_tenant_modules(tenant_id) - Firma modüllerini getir';
  RAISE NOTICE '  ✅ toggle_tenant_module(tenant_id, module_code, is_enabled) - Modül aç/kapa';
  RAISE NOTICE '  ✅ get_user_modules() - Kullanıcı modüllerini getir';
  RAISE NOTICE '  ✅ update_user_module_order(module_code, display_order) - Sıra güncelle';
  RAISE NOTICE '  ✅ batch_update_module_order(module_orders) - Toplu sıra güncelle';
END $$;
