-- Fix request-files storage policies to support all request categories
-- (malfunctions, equipment, other)

-- 1. Drop existing restrictive policies
DROP POLICY IF EXISTS "request-files insert" ON storage.objects;
DROP POLICY IF EXISTS "request-files select" ON storage.objects;

-- 2. Create new insert policy that supports all request types
CREATE POLICY "request-files insert all types"
ON storage.objects
AS PERMISSIVE
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'request-files'
    AND (
        -- Check folder structure: category/tenant_id/branch_id/type/filename
        (storage.foldername(name))[1] IN ('malfunctions', 'equipment', 'other')
    )
    AND cardinality(storage.foldername(name)) >= 3
    AND storage.filename(name) ~~ (auth.uid()::text || '_%')
    AND EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = auth.uid()
        AND u.tenant_id::text = (storage.foldername(objects.name))[2]
        AND u.branch_id::text = (storage.foldername(objects.name))[3]
    )
);

-- 3. Create new select policy that supports all request types
CREATE POLICY "request-files select all types"
ON storage.objects
AS PERMISSIVE
FOR SELECT
TO authenticated
USING (
    bucket_id = 'request-files'
    AND (storage.foldername(name))[1] IN ('malfunctions', 'equipment', 'other')
    AND EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = auth.uid()
        AND u.tenant_id::text = (storage.foldername(objects.name))[2]
        AND (
            -- Same branch or manager role
            u.branch_id::text = (storage.foldername(objects.name))[3]
            OR u.role IN ('grand_admin', 'firma_admin', 'bolge_muduru', 'sube_muduru')
        )
    )
);

-- 4. Ensure bucket is public for signed URLs
UPDATE storage.buckets
SET public = true
WHERE id = 'request-files';
