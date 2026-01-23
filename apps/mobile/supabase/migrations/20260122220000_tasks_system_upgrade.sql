-- Migration: Görev sistemi güncellemesi
-- 1. tasks tablosuna yeni sütunlar
-- 2. task_attachments tablosu (görev ekleri için)

-- ============================================
-- 1. TASKS TABLOSU GÜNCELLEMELERİ
-- ============================================

-- is_archived: Arşivlenmiş görevler için
ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS is_archived boolean DEFAULT false;

-- source_task_id: Görev iletme için (forked from)
-- Şube müdürü bir yan görevi personele ilettiğinde, orijinal görevin ID'si
ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS source_task_id uuid REFERENCES public.tasks(id) ON DELETE SET NULL;

-- approved_at: Görev onaylandığında timestamp
ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS approved_at timestamp with time zone;

-- approved_by: Görevi onaylayan kullanıcı
ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS approved_by uuid REFERENCES public.users(id) ON DELETE SET NULL;

-- Index'ler
CREATE INDEX IF NOT EXISTS idx_tasks_is_archived ON public.tasks(is_archived);
CREATE INDEX IF NOT EXISTS idx_tasks_source_task_id ON public.tasks(source_task_id);
CREATE INDEX IF NOT EXISTS idx_tasks_approved_by ON public.tasks(approved_by);

-- Yorumlar
COMMENT ON COLUMN public.tasks.is_archived IS 'Görev arşivlendi mi';
COMMENT ON COLUMN public.tasks.source_task_id IS 'İletilen görevin orijinal kaynak görevi';
COMMENT ON COLUMN public.tasks.approved_at IS 'Görevin onaylandığı tarih';
COMMENT ON COLUMN public.tasks.approved_by IS 'Görevi onaylayan kullanıcı';

-- ============================================
-- 2. TASK_ATTACHMENTS TABLOSU (YENİ)
-- ============================================

CREATE TABLE IF NOT EXISTS public.task_attachments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    file_url text NOT NULL,
    file_name text NOT NULL,
    file_type text, -- image/jpeg, application/pdf, etc.
    file_size integer, -- bytes
    uploaded_by uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now()
);

-- Index'ler
CREATE INDEX IF NOT EXISTS idx_task_attachments_task_id ON public.task_attachments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_attachments_uploaded_by ON public.task_attachments(uploaded_by);

-- RLS
ALTER TABLE public.task_attachments ENABLE ROW LEVEL SECURITY;

-- RLS Politikaları
DROP POLICY IF EXISTS "task_attachments_select_policy" ON public.task_attachments;
CREATE POLICY "task_attachments_select_policy" ON public.task_attachments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.tasks t
            WHERE t.id = task_attachments.task_id
            AND (
                t.created_by = auth.uid()
                OR t.branch_id IN (
                    SELECT branch_id FROM public.users WHERE id = auth.uid()
                )
                OR EXISTS (
                    SELECT 1 FROM public.task_assignees ta
                    WHERE ta.task_id = t.id AND ta.user_id = auth.uid()
                )
            )
        )
    );

DROP POLICY IF EXISTS "task_attachments_insert_policy" ON public.task_attachments;
CREATE POLICY "task_attachments_insert_policy" ON public.task_attachments
    FOR INSERT WITH CHECK (
        uploaded_by = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.tasks t
            WHERE t.id = task_attachments.task_id
            AND (
                t.created_by = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM public.task_assignees ta
                    WHERE ta.task_id = t.id AND ta.user_id = auth.uid()
                )
            )
        )
    );

DROP POLICY IF EXISTS "task_attachments_delete_policy" ON public.task_attachments;
CREATE POLICY "task_attachments_delete_policy" ON public.task_attachments
    FOR DELETE USING (
        uploaded_by = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.tasks t
            WHERE t.id = task_attachments.task_id AND t.created_by = auth.uid()
        )
    );

-- Yorumlar
COMMENT ON TABLE public.task_attachments IS 'Görev ekleri (fotoğraf, dosya)';
COMMENT ON COLUMN public.task_attachments.file_url IS 'Dosyanın storage URL''i';
COMMENT ON COLUMN public.task_attachments.file_type IS 'MIME tipi';
COMMENT ON COLUMN public.task_attachments.file_size IS 'Dosya boyutu (bytes)';

-- ============================================
-- 3. STORAGE BUCKET (GÖREV EKLERİ)
-- ============================================

-- Not: Bu kısım Supabase Dashboard'dan yapılmalı veya
-- storage.buckets tablosuna insert yapılmalı
-- INSERT INTO storage.buckets (id, name, public) 
-- VALUES ('task-attachments', 'task-attachments', false)
-- ON CONFLICT (id) DO NOTHING;
