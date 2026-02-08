-- Visual Audits Storage Bucket RLS Politikaları

-- SELECT: Authenticated kullanıcılar kendi tenant'larının dosyalarını okuyabilir
CREATE POLICY "visual_audits_select_policy"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'visual-audits'
);

-- INSERT: Authenticated kullanıcılar yükleyebilir
CREATE POLICY "visual_audits_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'visual-audits'
);

-- UPDATE: Authenticated kullanıcılar güncelleyebilir
CREATE POLICY "visual_audits_update_policy"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'visual-audits'
);

-- DELETE: Authenticated kullanıcılar silebilir (kendi yüklediklerini)
CREATE POLICY "visual_audits_delete_policy"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'visual-audits'
);
