-- Migration: Enhanced Announcements and Surveys System
-- Purpose: Complete announcement and survey/poll system with role-based targeting

-- ============================================================
-- PART 1: ENUM TYPES
-- ============================================================

-- Announcement/Survey type
DO $$ BEGIN
  CREATE TYPE announcement_type AS ENUM ('announcement', 'survey');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Survey question types
DO $$ BEGIN
  CREATE TYPE survey_question_type AS ENUM (
    'single_choice',     -- Radio buttons (tek seçim)
    'multiple_choice',   -- Checkboxes (çoklu seçim)
    'text',              -- Açık uçlu metin
    'rating',            -- 1-5 yıldız
    'yes_no'             -- Evet/Hayır
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Target audience scope
DO $$ BEGIN
  CREATE TYPE target_scope AS ENUM (
    'all_branches',           -- Tüm şubeler
    'selected_branches',      -- Seçili şubeler
    'my_branches',            -- Sadece kendi şubelerim (bölge müdürü için)
    'my_branch',              -- Sadece kendi şubem (şube müdürü için)
    'region_managers_only'    -- Sadece bölge müdürleri
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- PART 2: ENHANCED ANNOUNCEMENTS TABLE
-- ============================================================

-- Add new columns to existing announcements table
ALTER TABLE public.announcements 
  ADD COLUMN IF NOT EXISTS type announcement_type DEFAULT 'announcement',
  ADD COLUMN IF NOT EXISTS target_scope target_scope DEFAULT 'all_branches',
  ADD COLUMN IF NOT EXISTS include_region_managers boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS managers_only boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS priority integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pinned boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_by_role user_role,
  ADD COLUMN IF NOT EXISTS cover_image_url text,
  ADD COLUMN IF NOT EXISTS summary text,
  ADD COLUMN IF NOT EXISTS target_regions uuid[] DEFAULT NULL;

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_announcements_type ON public.announcements(type);
CREATE INDEX IF NOT EXISTS idx_announcements_target_scope ON public.announcements(target_scope);
CREATE INDEX IF NOT EXISTS idx_announcements_priority ON public.announcements(priority DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_pinned ON public.announcements(pinned) WHERE pinned = true;

-- ============================================================
-- PART 3: SURVEYS TABLES
-- ============================================================

-- Survey questions table
CREATE TABLE IF NOT EXISTS public.survey_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id uuid NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
  question_text text NOT NULL,
  question_type survey_question_type NOT NULL DEFAULT 'single_choice',
  options jsonb DEFAULT '[]'::jsonb,  -- Array of option strings for choice questions
  required boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_survey_questions_announcement ON public.survey_questions(announcement_id);
CREATE INDEX IF NOT EXISTS idx_survey_questions_sort ON public.survey_questions(announcement_id, sort_order);

-- Survey responses table (one per user per survey)
CREATE TABLE IF NOT EXISTS public.survey_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id uuid NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  submitted_at timestamptz DEFAULT now(),
  UNIQUE(announcement_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_survey_responses_announcement ON public.survey_responses(announcement_id);
CREATE INDEX IF NOT EXISTS idx_survey_responses_user ON public.survey_responses(user_id);

-- Survey answers table (one per question per response)
CREATE TABLE IF NOT EXISTS public.survey_answers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  response_id uuid NOT NULL REFERENCES public.survey_responses(id) ON DELETE CASCADE,
  question_id uuid NOT NULL REFERENCES public.survey_questions(id) ON DELETE CASCADE,
  answer_text text,                    -- For text questions
  answer_options jsonb DEFAULT '[]'::jsonb,  -- For choice questions (array of selected options)
  answer_rating integer,               -- For rating questions (1-5)
  answer_boolean boolean,              -- For yes/no questions
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_survey_answers_response ON public.survey_answers(response_id);
CREATE INDEX IF NOT EXISTS idx_survey_answers_question ON public.survey_answers(question_id);

-- ============================================================
-- PART 4: HELPER VIEWS
-- ============================================================

-- View to get survey statistics
CREATE OR REPLACE VIEW public.v_survey_statistics AS
SELECT 
  a.id as announcement_id,
  a.title,
  a.tenant_id,
  a.published_at,
  COUNT(DISTINCT sr.user_id) as total_responses,
  (
    SELECT COUNT(DISTINCT u.id) 
    FROM public.users u 
    WHERE u.tenant_id = a.tenant_id
      AND u.active = true
      AND (
        -- Check target scope
        a.target_scope = 'all_branches'
        OR (a.target_scope = 'selected_branches' AND u.branch_id = ANY(a.target_branches))
        OR (a.target_scope = 'region_managers_only' AND u.role = 'bolge_muduru')
      )
      AND (
        -- Check managers only
        NOT a.managers_only 
        OR u.role IN ('sube_muduru', 'bolge_muduru', 'firma_admin')
      )
  ) as target_audience_count
FROM public.announcements a
LEFT JOIN public.survey_responses sr ON sr.announcement_id = a.id
WHERE a.type = 'survey'
GROUP BY a.id;

-- ============================================================
-- PART 5: RLS POLICIES
-- ============================================================

-- Enable RLS
ALTER TABLE public.survey_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.survey_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.survey_answers ENABLE ROW LEVEL SECURITY;

-- Survey Questions policies
CREATE POLICY "survey_questions_select" ON public.survey_questions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.announcements a 
      WHERE a.id = announcement_id 
        AND a.tenant_id = (SELECT current_tenant_id())
    )
  );

CREATE POLICY "survey_questions_insert" ON public.survey_questions
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.announcements a 
      WHERE a.id = announcement_id 
        AND a.tenant_id = (SELECT current_tenant_id())
        AND a.published_by = (SELECT auth.uid())
    )
  );

CREATE POLICY "survey_questions_update" ON public.survey_questions
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.announcements a 
      WHERE a.id = announcement_id 
        AND a.tenant_id = (SELECT current_tenant_id())
        AND a.published_by = (SELECT auth.uid())
    )
  );

CREATE POLICY "survey_questions_delete" ON public.survey_questions
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.announcements a 
      WHERE a.id = announcement_id 
        AND a.tenant_id = (SELECT current_tenant_id())
        AND a.published_by = (SELECT auth.uid())
    )
  );

-- Survey Responses policies
CREATE POLICY "survey_responses_select" ON public.survey_responses
  FOR SELECT USING (
    user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.announcements a 
      WHERE a.id = announcement_id 
        AND a.published_by = (SELECT auth.uid())
    )
    OR (SELECT current_user_role()) IN ('firma_admin', 'grand_admin')
  );

CREATE POLICY "survey_responses_insert" ON public.survey_responses
  FOR INSERT WITH CHECK (
    user_id = (SELECT auth.uid())
  );

-- Survey Answers policies
CREATE POLICY "survey_answers_select" ON public.survey_answers
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.survey_responses sr 
      WHERE sr.id = response_id 
        AND (
          sr.user_id = (SELECT auth.uid())
          OR EXISTS (
            SELECT 1 FROM public.announcements a 
            WHERE a.id = sr.announcement_id 
              AND a.published_by = (SELECT auth.uid())
          )
          OR (SELECT current_user_role()) IN ('firma_admin', 'grand_admin')
        )
    )
  );

CREATE POLICY "survey_answers_insert" ON public.survey_answers
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.survey_responses sr 
      WHERE sr.id = response_id 
        AND sr.user_id = (SELECT auth.uid())
    )
  );

-- ============================================================
-- PART 6: RPC FUNCTIONS
-- ============================================================

-- Function to create a survey with questions in one transaction
CREATE OR REPLACE FUNCTION public.create_survey(
  p_title text,
  p_content text,
  p_summary text DEFAULT NULL,
  p_target_scope target_scope DEFAULT 'all_branches',
  p_target_branches uuid[] DEFAULT NULL,
  p_target_regions uuid[] DEFAULT NULL,
  p_managers_only boolean DEFAULT false,
  p_include_region_managers boolean DEFAULT false,
  p_expires_at timestamptz DEFAULT NULL,
  p_questions jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_tenant_id uuid;
  v_user_role user_role;
  v_announcement_id uuid;
  v_question jsonb;
  v_question_id uuid;
  v_sort_order int := 0;
BEGIN
  -- Get user info
  SELECT tenant_id, role INTO v_tenant_id, v_user_role
  FROM public.users
  WHERE id = v_user_id;
  
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;
  
  -- Validate role permissions
  IF v_user_role NOT IN ('firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Anket oluşturma yetkiniz yok');
  END IF;
  
  -- Validate scope based on role
  IF v_user_role = 'sube_muduru' AND p_target_scope NOT IN ('my_branch') THEN
    p_target_scope := 'my_branch';
  END IF;
  
  IF v_user_role = 'bolge_muduru' AND p_target_scope = 'region_managers_only' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu hedef kitleyi seçme yetkiniz yok');
  END IF;
  
  -- Create announcement
  INSERT INTO public.announcements (
    tenant_id,
    title,
    content,
    summary,
    type,
    target_scope,
    target_branches,
    target_regions,
    managers_only,
    include_region_managers,
    published_by,
    created_by_role,
    expires_at,
    active
  ) VALUES (
    v_tenant_id,
    p_title,
    p_content,
    p_summary,
    'survey',
    p_target_scope,
    p_target_branches,
    p_target_regions,
    p_managers_only,
    p_include_region_managers,
    v_user_id,
    v_user_role,
    p_expires_at,
    true
  )
  RETURNING id INTO v_announcement_id;
  
  -- Create questions
  FOR v_question IN SELECT * FROM jsonb_array_elements(p_questions)
  LOOP
    INSERT INTO public.survey_questions (
      announcement_id,
      question_text,
      question_type,
      options,
      required,
      sort_order
    ) VALUES (
      v_announcement_id,
      v_question->>'question_text',
      (v_question->>'question_type')::survey_question_type,
      COALESCE(v_question->'options', '[]'::jsonb),
      COALESCE((v_question->>'required')::boolean, true),
      v_sort_order
    );
    v_sort_order := v_sort_order + 1;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true, 
    'announcement_id', v_announcement_id,
    'question_count', v_sort_order
  );
END;
$$;

-- Function to submit survey response
CREATE OR REPLACE FUNCTION public.submit_survey_response(
  p_announcement_id uuid,
  p_answers jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_response_id uuid;
  v_answer jsonb;
  v_question_id uuid;
BEGIN
  -- Check if already responded
  IF EXISTS (
    SELECT 1 FROM public.survey_responses 
    WHERE announcement_id = p_announcement_id AND user_id = v_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu ankete zaten katıldınız');
  END IF;
  
  -- Create response
  INSERT INTO public.survey_responses (announcement_id, user_id)
  VALUES (p_announcement_id, v_user_id)
  RETURNING id INTO v_response_id;
  
  -- Insert answers
  FOR v_answer IN SELECT * FROM jsonb_array_elements(p_answers)
  LOOP
    v_question_id := (v_answer->>'question_id')::uuid;
    
    INSERT INTO public.survey_answers (
      response_id,
      question_id,
      answer_text,
      answer_options,
      answer_rating,
      answer_boolean
    ) VALUES (
      v_response_id,
      v_question_id,
      v_answer->>'answer_text',
      COALESCE(v_answer->'answer_options', '[]'::jsonb),
      (v_answer->>'answer_rating')::integer,
      (v_answer->>'answer_boolean')::boolean
    );
  END LOOP;
  
  -- Also mark as read
  INSERT INTO public.announcement_reads (announcement_id, user_id)
  VALUES (p_announcement_id, v_user_id)
  ON CONFLICT (announcement_id, user_id) DO NOTHING;
  
  RETURN jsonb_build_object('success', true, 'response_id', v_response_id);
END;
$$;

-- Function to get survey results (for survey owner)
CREATE OR REPLACE FUNCTION public.get_survey_results(p_announcement_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_user_role user_role;
  v_result jsonb;
BEGIN
  -- Get user role
  SELECT role INTO v_user_role FROM public.users WHERE id = v_user_id;
  
  -- Check access
  IF NOT EXISTS (
    SELECT 1 FROM public.announcements 
    WHERE id = p_announcement_id 
      AND (published_by = v_user_id OR v_user_role IN ('firma_admin', 'grand_admin'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Erişim yetkiniz yok');
  END IF;
  
  -- Build results
  SELECT jsonb_build_object(
    'success', true,
    'announcement_id', p_announcement_id,
    'total_responses', (
      SELECT COUNT(*) FROM public.survey_responses WHERE announcement_id = p_announcement_id
    ),
    'questions', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'question_id', sq.id,
          'question_text', sq.question_text,
          'question_type', sq.question_type,
          'options', sq.options,
          'answers', (
            SELECT jsonb_agg(
              jsonb_build_object(
                'user_id', sr.user_id,
                'user_name', u.first_name || ' ' || u.last_name,
                'branch_name', b.name,
                'answer_text', sa.answer_text,
                'answer_options', sa.answer_options,
                'answer_rating', sa.answer_rating,
                'answer_boolean', sa.answer_boolean,
                'submitted_at', sr.submitted_at
              )
            )
            FROM public.survey_answers sa
            JOIN public.survey_responses sr ON sr.id = sa.response_id
            JOIN public.users u ON u.id = sr.user_id
            LEFT JOIN public.branches b ON b.id = u.branch_id
            WHERE sa.question_id = sq.id
          ),
          'summary', CASE 
            WHEN sq.question_type IN ('single_choice', 'multiple_choice') THEN (
              SELECT jsonb_object_agg(
                opt.value,
                (
                  SELECT COUNT(*) 
                  FROM public.survey_answers sa2 
                  WHERE sa2.question_id = sq.id 
                    AND sa2.answer_options ? opt.value
                )
              )
              FROM jsonb_array_elements_text(sq.options) opt(value)
            )
            WHEN sq.question_type = 'rating' THEN (
              SELECT jsonb_build_object(
                'average', ROUND(AVG(sa.answer_rating)::numeric, 2),
                'count_1', COUNT(*) FILTER (WHERE sa.answer_rating = 1),
                'count_2', COUNT(*) FILTER (WHERE sa.answer_rating = 2),
                'count_3', COUNT(*) FILTER (WHERE sa.answer_rating = 3),
                'count_4', COUNT(*) FILTER (WHERE sa.answer_rating = 4),
                'count_5', COUNT(*) FILTER (WHERE sa.answer_rating = 5)
              )
              FROM public.survey_answers sa
              WHERE sa.question_id = sq.id
            )
            WHEN sq.question_type = 'yes_no' THEN (
              SELECT jsonb_build_object(
                'yes', COUNT(*) FILTER (WHERE sa.answer_boolean = true),
                'no', COUNT(*) FILTER (WHERE sa.answer_boolean = false)
              )
              FROM public.survey_answers sa
              WHERE sa.question_id = sq.id
            )
            ELSE NULL
          END
        )
        ORDER BY sq.sort_order
      )
      FROM public.survey_questions sq
      WHERE sq.announcement_id = p_announcement_id
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;

-- Function to create announcement
CREATE OR REPLACE FUNCTION public.create_announcement(
  p_title text,
  p_content text,
  p_summary text DEFAULT NULL,
  p_cover_image_url text DEFAULT NULL,
  p_target_scope target_scope DEFAULT 'all_branches',
  p_target_branches uuid[] DEFAULT NULL,
  p_target_regions uuid[] DEFAULT NULL,
  p_managers_only boolean DEFAULT false,
  p_include_region_managers boolean DEFAULT false,
  p_expires_at timestamptz DEFAULT NULL,
  p_pinned boolean DEFAULT false,
  p_priority integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_tenant_id uuid;
  v_user_role user_role;
  v_announcement_id uuid;
BEGIN
  -- Get user info
  SELECT tenant_id, role INTO v_tenant_id, v_user_role
  FROM public.users
  WHERE id = v_user_id;
  
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;
  
  -- Validate role permissions
  IF v_user_role NOT IN ('firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duyuru oluşturma yetkiniz yok');
  END IF;
  
  -- Validate scope based on role
  IF v_user_role = 'sube_muduru' AND p_target_scope NOT IN ('my_branch') THEN
    p_target_scope := 'my_branch';
  END IF;
  
  IF v_user_role = 'bolge_muduru' AND p_target_scope = 'region_managers_only' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu hedef kitleyi seçme yetkiniz yok');
  END IF;
  
  -- Create announcement
  INSERT INTO public.announcements (
    tenant_id,
    title,
    content,
    summary,
    cover_image_url,
    type,
    target_scope,
    target_branches,
    target_regions,
    managers_only,
    include_region_managers,
    published_by,
    created_by_role,
    expires_at,
    pinned,
    priority,
    active
  ) VALUES (
    v_tenant_id,
    p_title,
    p_content,
    p_summary,
    p_cover_image_url,
    'announcement',
    p_target_scope,
    p_target_branches,
    p_target_regions,
    p_managers_only,
    p_include_region_managers,
    v_user_id,
    v_user_role,
    p_expires_at,
    p_pinned,
    p_priority,
    true
  )
  RETURNING id INTO v_announcement_id;
  
  RETURN jsonb_build_object('success', true, 'announcement_id', v_announcement_id);
END;
$$;

-- Function to get announcements for current user
CREATE OR REPLACE FUNCTION public.get_my_announcements(
  p_type text DEFAULT NULL,  -- 'announcement', 'survey', or NULL for all
  p_include_expired boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_tenant_id uuid;
  v_user_role user_role;
  v_branch_id uuid;
  v_region_id uuid;
BEGIN
  -- Get user info
  SELECT tenant_id, role, branch_id 
  INTO v_tenant_id, v_user_role, v_branch_id
  FROM public.users
  WHERE id = v_user_id;
  
  -- Get region_id if exists
  SELECT region_id INTO v_region_id FROM public.branches WHERE id = v_branch_id;
  
  RETURN (
    SELECT jsonb_build_object(
      'success', true,
      'announcements', COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'title', a.title,
          'content', a.content,
          'summary', a.summary,
          'cover_image_url', a.cover_image_url,
          'type', a.type,
          'published_at', a.published_at,
          'expires_at', a.expires_at,
          'pinned', a.pinned,
          'priority', a.priority,
          'is_read', EXISTS (
            SELECT 1 FROM public.announcement_reads ar 
            WHERE ar.announcement_id = a.id AND ar.user_id = v_user_id
          ),
          'is_responded', CASE WHEN a.type = 'survey' THEN EXISTS (
            SELECT 1 FROM public.survey_responses sr 
            WHERE sr.announcement_id = a.id AND sr.user_id = v_user_id
          ) ELSE NULL END,
          'question_count', CASE WHEN a.type = 'survey' THEN (
            SELECT COUNT(*) FROM public.survey_questions sq WHERE sq.announcement_id = a.id
          ) ELSE NULL END,
          'publisher', (
            SELECT jsonb_build_object(
              'id', u.id,
              'name', u.first_name || ' ' || u.last_name,
              'role', u.role
            )
            FROM public.users u WHERE u.id = a.published_by
          )
        )
        ORDER BY a.pinned DESC, a.priority DESC, a.published_at DESC
      ), '[]'::jsonb)
    )
    FROM public.announcements a
    WHERE a.tenant_id = v_tenant_id
      AND a.active = true
      AND (p_type IS NULL OR a.type::text = p_type)
      AND (p_include_expired OR a.expires_at IS NULL OR a.expires_at > now())
      -- Check visibility based on target scope
      AND (
        -- All branches
        a.target_scope = 'all_branches'
        -- Selected branches
        OR (a.target_scope = 'selected_branches' AND v_branch_id = ANY(a.target_branches))
        -- My branches (for region manager announcements - user in that region)
        OR (a.target_scope = 'my_branches' AND v_region_id = ANY(a.target_regions))
        -- My branch (for branch manager announcements)
        OR (a.target_scope = 'my_branch' AND (
          v_branch_id = ANY(a.target_branches)
          OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = a.published_by AND u.branch_id = v_branch_id)
        ))
        -- Region managers only
        OR (a.target_scope = 'region_managers_only' AND v_user_role = 'bolge_muduru')
        -- User is the publisher (can see their own)
        OR a.published_by = v_user_id
        -- Include region managers
        OR (a.include_region_managers AND v_user_role = 'bolge_muduru')
      )
      -- Check managers_only flag
      AND (
        NOT a.managers_only 
        OR v_user_role IN ('sube_muduru', 'bolge_muduru', 'firma_admin', 'grand_admin')
      )
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.create_survey TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_survey_response TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_survey_results TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_announcement TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_announcements TO authenticated;

-- ============================================================
-- PART 7: UPDATE ANNOUNCEMENT READS TABLE
-- ============================================================

-- Add unique constraint if not exists
DO $$ BEGIN
  ALTER TABLE public.announcement_reads 
    ADD CONSTRAINT announcement_reads_unique UNIQUE (announcement_id, user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
