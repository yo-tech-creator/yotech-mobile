-- Migration: store_scoring_sessions tablosuna evaluated_user_id sütunu ekle
-- Bu sütun formun hangi personel için doldurulduğunu tutar

-- evaluated_user_id sütunu ekle
ALTER TABLE public.store_scoring_sessions
ADD COLUMN IF NOT EXISTS evaluated_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL;

-- Index ekle (performans için)
CREATE INDEX IF NOT EXISTS idx_store_scoring_sessions_evaluated_user_id 
ON public.store_scoring_sessions(evaluated_user_id);

-- Yorum ekle
COMMENT ON COLUMN public.store_scoring_sessions.evaluated_user_id IS 'Değerlendirilen personelin ID''si';
