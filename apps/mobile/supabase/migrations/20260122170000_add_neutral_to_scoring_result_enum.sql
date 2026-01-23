-- Add 'neutral' (partial) value to store_scoring_item_result enum
-- This allows for "Kısmen" (partial) answers in form scoring

ALTER TYPE public.store_scoring_item_result ADD VALUE IF NOT EXISTS 'neutral';

COMMENT ON TYPE public.store_scoring_item_result IS 
'Form scoring item results: positive (Evet), negative (Hayır), neutral (Kısmen), not_applicable (N/A)';
