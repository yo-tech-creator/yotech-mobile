-- ============================================
-- VISUAL AUDIT STORAGE - PUBLIC READ ACCESS
-- ============================================
-- NOTE: This migration is for production only, commented for shadow database compatibility
-- These operations work on the remote Supabase but not on local shadow database

/*
-- 1. Bucket'ı public yap (eğer değilse)
UPDATE storage.buckets 
SET public = true 
WHERE id = 'visual-audits';
*/

-- 2. Herkese okuma izni ver (public URL'ler için)
DROP POLICY IF EXISTS "Visual audit photos are publicly accessible" ON storage.objects;
CREATE POLICY "Visual audit photos are publicly accessible"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'visual-audits');

-- 3. Authenticated kullanıcılar upload edebilir
DROP POLICY IF EXISTS "Authenticated users can upload visual audit photos" ON storage.objects;
CREATE POLICY "Authenticated users can upload visual audit photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'visual-audits');

-- 4. Authenticated kullanıcılar silebilir
DROP POLICY IF EXISTS "Authenticated users can delete visual audit photos" ON storage.objects;
CREATE POLICY "Authenticated users can delete visual audit photos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'visual-audits');
