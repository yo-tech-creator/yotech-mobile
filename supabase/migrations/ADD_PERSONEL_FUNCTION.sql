-- ================================================================
-- PERSONEL EKLEME RPC FONKSİYONU
-- ================================================================
-- Firma admin'lerin yeni personel eklemesi için güvenli fonksiyon

CREATE OR REPLACE FUNCTION public.add_personel(
  p_employee_code TEXT,
  p_password TEXT,
  p_tenant_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_email TEXT;
  v_first_name TEXT := 'Personel';
  v_last_name TEXT;
  v_phone TEXT;
  v_random_num INT;
BEGIN
  -- Random değerler oluştur
  v_random_num := (EXTRACT(EPOCH FROM NOW()) * 1000)::INT % 10000;
  v_last_name := 'User' || v_random_num::TEXT;
  v_email := LOWER(p_employee_code) || '@filemarket.com';
  v_phone := '555' || LPAD(v_random_num::TEXT, 7, '0');
  v_user_id := gen_random_uuid();
  
  -- 1. Auth kullanıcısı oluştur
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    crypt(p_password, gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    '', '', '', ''
  );
  
  -- 2. Public users tablosuna ekle
  INSERT INTO public.users (
    id, tenant_id, first_name, last_name, email, phone,
    employee_code, role, position, hire_date, active
  ) VALUES (
    v_user_id,
    p_tenant_id,
    v_first_name,
    v_last_name,
    v_email,
    v_phone,
    p_employee_code,
    'personel'::user_role,
    'Personel',
    CURRENT_DATE,
    true
  );
  
  -- Başarılı sonuç döndür
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', v_email,
    'employee_code', p_employee_code,
    'full_name', v_first_name || ' ' || v_last_name
  );
  
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bu employee code veya email zaten kullanılıyor'
    );
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;

-- Sadece authenticated kullanıcılar çalıştırabilir
GRANT EXECUTE ON FUNCTION public.add_personel(TEXT, TEXT, UUID) TO authenticated;

COMMENT ON FUNCTION public.add_personel IS 
'Firma admin''lerin yeni personel eklemesi için güvenli RPC fonksiyonu';
