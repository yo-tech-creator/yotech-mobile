-- ================================================================
-- LOGIN FIX: Employee Code ile Email Bulma Fonksiyonu (FIXED)
-- ================================================================
-- Gerçek kolon adlarıyla güncellendi: active, employee_code

CREATE OR REPLACE FUNCTION public.get_user_email_by_sicil(
  p_sicil_no TEXT
)
RETURNS TABLE (
  email TEXT,
  active BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.email::TEXT,
    u.active
  FROM public.users u
  WHERE u.employee_code = p_sicil_no
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_email_by_sicil(TEXT) TO authenticated, anon;

COMMENT ON FUNCTION public.get_user_email_by_sicil IS 
'Login için employee_code ile email ve active bilgisi döndürür. SECURITY DEFINER ile RLS bypass edilir.';
