-- Store scoring dynamic template schema
-- Allows firm admins to manage multiple checklists, versions, and evaluations.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE t.typname = 'store_scoring_item_result'
      AND n.nspname = 'public'
  ) THEN
    EXECUTE 'CREATE TYPE public.store_scoring_item_result AS ENUM (''positive'', ''negative'', ''not_applicable'')';
  ELSE
    -- Ensure enum contains the expected labels before proceeding.
    PERFORM 1
    FROM pg_enum
    WHERE enumtypid = 'public.store_scoring_item_result'::regtype
      AND enumlabel = 'positive';
    IF NOT FOUND THEN
      EXECUTE 'ALTER TYPE public.store_scoring_item_result ADD VALUE IF NOT EXISTS ''positive''';
    END IF;

    PERFORM 1
    FROM pg_enum
    WHERE enumtypid = 'public.store_scoring_item_result'::regtype
      AND enumlabel = 'negative';
    IF NOT FOUND THEN
      EXECUTE 'ALTER TYPE public.store_scoring_item_result ADD VALUE IF NOT EXISTS ''negative''';
    END IF;

    PERFORM 1
    FROM pg_enum
    WHERE enumtypid = 'public.store_scoring_item_result'::regtype
      AND enumlabel = 'not_applicable';
    IF NOT FOUND THEN
      EXECUTE 'ALTER TYPE public.store_scoring_item_result ADD VALUE IF NOT EXISTS ''not_applicable''';
    END IF;
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.store_scoring_forms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  code text NOT NULL,
  title text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid NOT NULL REFERENCES public.users (id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code)
);

CREATE TABLE IF NOT EXISTS public.store_scoring_form_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id uuid NOT NULL REFERENCES public.store_scoring_forms (id) ON DELETE CASCADE,
  version integer NOT NULL,
  status text NOT NULL DEFAULT 'draft', -- draft | published | archived
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL REFERENCES public.users (id) ON DELETE RESTRICT,
  UNIQUE (form_id, version)
);

CREATE TABLE IF NOT EXISTS public.store_scoring_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  form_version_id uuid NOT NULL REFERENCES public.store_scoring_form_versions (id) ON DELETE CASCADE,
  title text NOT NULL,
  order_index integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.store_scoring_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id uuid NOT NULL REFERENCES public.store_scoring_sections (id) ON DELETE CASCADE,
  label text NOT NULL,
  positive_points numeric(6,2) NOT NULL DEFAULT 0,
  negative_points numeric(6,2) NOT NULL DEFAULT 0,
  order_index integer NOT NULL DEFAULT 0,
  is_required boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.store_scoring_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  form_version_id uuid NOT NULL REFERENCES public.store_scoring_form_versions (id) ON DELETE RESTRICT,
  branch_id uuid NOT NULL REFERENCES public.branches (id) ON DELETE RESTRICT,
  evaluator_id uuid NOT NULL REFERENCES public.users (id) ON DELETE RESTRICT,
  total_positive numeric(8,2) NOT NULL DEFAULT 0,
  total_negative numeric(8,2) NOT NULL DEFAULT 0,
  total_possible numeric(8,2) NOT NULL DEFAULT 0,
  notes text,
  scored_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.store_scoring_session_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.store_scoring_sessions (id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES public.store_scoring_items (id) ON DELETE RESTRICT,
  result public.store_scoring_item_result NOT NULL,
  points_awarded numeric(6,2) NOT NULL DEFAULT 0,
  comment text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, item_id)
);

CREATE INDEX IF NOT EXISTS store_scoring_forms_tenant_idx ON public.store_scoring_forms (tenant_id);
CREATE INDEX IF NOT EXISTS store_scoring_form_versions_form_idx ON public.store_scoring_form_versions (form_id);
CREATE INDEX IF NOT EXISTS store_scoring_sections_version_idx ON public.store_scoring_sections (form_version_id);
CREATE INDEX IF NOT EXISTS store_scoring_items_section_idx ON public.store_scoring_items (section_id);
CREATE INDEX IF NOT EXISTS store_scoring_sessions_branch_idx ON public.store_scoring_sessions (branch_id);
CREATE INDEX IF NOT EXISTS store_scoring_sessions_evaluator_idx ON public.store_scoring_sessions (evaluator_id);
CREATE INDEX IF NOT EXISTS store_scoring_session_items_session_idx ON public.store_scoring_session_items (session_id);

-- Seed helper view to fetch published form definitions with sections and items.
DROP VIEW IF EXISTS public.v_store_scoring_published_forms;
CREATE OR REPLACE VIEW public.v_store_scoring_published_forms AS
SELECT
  fv.id AS form_version_id,
  f.id AS form_id,
  f.tenant_id,
  f.code,
  f.title,
  f.description,
  fv.version,
  fv.published_at,
  jsonb_agg(
    jsonb_build_object(
      'sectionId', s.id,
      'title', s.title,
      'order', s.order_index,
      'items', (
        SELECT jsonb_agg(
                 jsonb_build_object(
                   'itemId', i.id,
                   'label', i.label,
                   'positivePoints', i.positive_points,
                   'negativePoints', i.negative_points,
                   'order', i.order_index,
                   'isRequired', i.is_required
                 )
                 ORDER BY i.order_index
               )
        FROM public.store_scoring_items i
        WHERE i.section_id = s.id
      )
    )
    ORDER BY s.order_index
  ) AS sections
FROM public.store_scoring_form_versions fv
JOIN public.store_scoring_forms f ON f.id = fv.form_id
JOIN public.store_scoring_sections s ON s.form_version_id = fv.id
WHERE fv.status = 'published'
GROUP BY fv.id, f.id, f.tenant_id, f.code, f.title, f.description, fv.version, fv.published_at;

-- Seeder function for the default checklist used in the mobile app today.
CREATE OR REPLACE FUNCTION public.seed_default_store_scoring_form(
  p_tenant_id uuid,
  p_admin_id uuid,
  p_form_code text DEFAULT 'STORE_STANDARD'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_existing uuid;
  v_form_id uuid;
  v_version_id uuid;
  v_section_id uuid;
  v_section_index integer := 0;
  v_item_index integer;
  rec_section record;
  item_text text;
  v_sections jsonb := jsonb_build_array(
    jsonb_build_object(
      'title', 'GENEL',
      'items', jsonb_build_array(
        'Mağaza dış alanı; otopark temizliği ve düzeni, cam, sticker ve doğrama temizliği',
        'Mağazadan dış alana açılan kapı ve pencerelerde haşere–kemirgen girişini engelleyecek önlemlerin kontrolü',
        'Mağaza sıfır ürün sayısı (mağaza kaynaklı sıfır sayısı 10 adet üzeri ise puan verilmez)',
        'Müşteri arabası ve müşteri sepeti temizlik ve konumlandırma',
        'Kasa bölgesi standartları (etiket, poşet, optik okuyucular, kasa üstü teşhir)',
        'Macao dolap kırmızı çizgi, doluluk, etiket ve temizlik'
      )
    ),
    jsonb_build_object(
      'title', 'MANAV',
      'items', jsonb_build_array(
        'Manav bölümü doluluk ve RYS',
        'Manav bölümü tazelik ve bileşeleme (kalite standart temellendirilmeli)',
        'Manav bölümü eksik etiket ve künye',
        'Manav bölümü AHT etiket, doluluk, kırmızı çizgi ve temizlik',
        'Manav bölümü soğuk dolap (+4) temizlik, doluluk ve etiket',
        'Manav hazırlık odası ve soğuk oda temizlik, düzen ve kalite temelli kontrol (sıcaklık ve temizlik formu, tanımlı kimyasallar)'
      )
    ),
    jsonb_build_object(
      'title', 'UNLU',
      'items', jsonb_build_array(
        'Unlu servis/distriyel ekmek doluluk & RYS & SKT/RKS',
        'Unlu servis bölümü ekipman, doluluk ve RYS',
        'Unlu servis bölümü izlenebilirlik',
        'Unlu servis bölümü çözündürme, pişirme adetler ve üretim standardı kontrolü (fazla pişme, çiğ kalma, hamurlaşma)',
        'Unlu bölüm AHT etiket, doluluk, kırmızı çizgi ve temizlik',
        'Unlu hazırlık odası ve soğuk oda temizlik, düzen ve kalite temelli kontrol (sıcaklık ve temizlik formu, tanımlı kimyasallar)'
      )
    ),
    jsonb_build_object(
      'title', 'KASAP / ŞARKÜTERİ',
      'items', jsonb_build_array(
        'Kasap şarküteri bölümü tazelik, doluluk ve RYS',
        'Kasap şarküteri bölümü izlenebilirlik',
        'Kasap şarküteri bölümü kıyma mak. standart kullanım',
        'Kasap şarküteri bölümü SKT/RKS (elleçleme / 10 adet ürün)',
        'Kasap şarküteri bölümü AHT etiket, doluluk, kırmızı çizgi ve temizlik',
        'Kasap ve şarküteri hazırlık odası ve soğuk oda temizlik, düzen ve kalite temelli kontrol (sıcaklık ve temizlik formu, tanımlı kimyasallar)'
      )
    ),
    jsonb_build_object(
      'title', 'GENEL (DEVAM)',
      'items', jsonb_build_array(
        'İptal kartın muhafaza ve yönetiliş şekli & gider pusulası muhafaza ve yönetiliş şekli',
        'Personel dış görünüş, iş kıyafeti, yaka kartı ve kişisel hijyen',
        'Bölümlerde personel bulunurluğu',
        'Teşhir sepet sayısı, doluluğu, etiketleri ve konumlandırılması',
        'İçecek dolap FIFO, doluluk ve etiket',
        'Mağaza genel koli açılışları (perfora), ön yüz ve doluluk',
        'Genel depo düzen / mal kabul / karton kafes / sigara içme alanı yönetimi',
        'Atık, iade ve karantina alan standartları',
        'Sosyal alan standartları (mutfak, soyunma dolap, WC ve mescit)',
        'Mağaza genel SKT/RKS (elleçleme 10 ürün)',
        'Mağaza palet altı, raf ve reyon temizlik',
        'Bir önceki mağaza ziyareti tespit / aksiyon',
        'Haftalık ve aylık bülten uygulamaları',
        'Müşteri gözüyle mağaza kontrol formu'
      )
    )
  );
BEGIN
  IF p_tenant_id IS NULL OR p_admin_id IS NULL THEN
    RAISE EXCEPTION 'tenant ve admin kullanıcı kimliği zorunludur';
  END IF;

  SELECT id INTO v_existing
  FROM public.store_scoring_forms
  WHERE tenant_id = p_tenant_id
    AND code = p_form_code;

  IF v_existing IS NOT NULL THEN
    SELECT id
      INTO v_version_id
    FROM public.store_scoring_form_versions
    WHERE form_id = v_existing
      AND status = 'published'
    ORDER BY version DESC
    LIMIT 1;

    IF v_version_id IS NULL THEN
      RETURN v_existing;
    END IF;

    RETURN v_version_id;
  END IF;

  INSERT INTO public.store_scoring_forms (
    tenant_id, code, title, description, created_by
  )
  VALUES (
    p_tenant_id,
    p_form_code,
    'Mağaza Genel Denetim Formu',
    'Varsayılan mağaza kalite ve operasyon kontrol listesi',
    p_admin_id
  )
  RETURNING id INTO v_form_id;

  INSERT INTO public.store_scoring_form_versions (
    form_id, version, status, published_at, created_by
  )
  VALUES (
    v_form_id,
    1,
    'published',
    now(),
    p_admin_id
  )
  RETURNING id INTO v_version_id;

  FOR rec_section IN
    SELECT value
    FROM jsonb_array_elements(v_sections) AS t(value)
  LOOP
    INSERT INTO public.store_scoring_sections (
      form_version_id, title, order_index
    )
    VALUES (
      v_version_id,
      rec_section.value->>'title',
      v_section_index
    )
    RETURNING id INTO v_section_id;

    v_item_index := 0;
    FOR item_text IN SELECT jsonb_array_elements_text(rec_section.value->'items') LOOP
      INSERT INTO public.store_scoring_items (
        section_id,
        label,
        positive_points,
        negative_points,
        order_index,
        is_required
      )
      VALUES (
        v_section_id,
        item_text,
        2,
        0,
        v_item_index,
        false
      );
      v_item_index := v_item_index + 1;
    END LOOP;

    v_section_index := v_section_index + 1;
  END LOOP;

  RETURN v_version_id;
END;
$$;

-- Enable row level security; policies to be defined per tenant requirements.
ALTER TABLE public.store_scoring_forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_scoring_form_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_scoring_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_scoring_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_scoring_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_scoring_session_items ENABLE ROW LEVEL SECURITY;

-- Example policy placeholders (adjust before enabling):
-- CREATE POLICY "tenant admins manage store scoring" ON public.store_scoring_forms
--   USING (tenant_id = current_tenant_id())
--   WITH CHECK (tenant_id = current_tenant_id());