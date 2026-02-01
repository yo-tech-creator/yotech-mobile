import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";

const MAX_ITEMS = 1000;

type FormItemInput = {
  question: string;
  hasBinaryChoice: boolean;
  allowComment: boolean;
  score?: number;
};

type PublishBody = {
  tenantId?: string;
  title?: string;
  code?: string;
  description?: string;
  items?: FormItemInput[];
  visibleRoles?: string[];
};

const ROLE_HIERARCHY = ["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru", "personel"] as const;

function upperRoles(role: string) {
  const idx = ROLE_HIERARCHY.indexOf(role as (typeof ROLE_HIERARCHY)[number]);
  return idx >= 0 ? ROLE_HIERARCHY.slice(0, idx + 1) : [];
}

function lowerRoles(role: string) {
  const idx = ROLE_HIERARCHY.indexOf(role as (typeof ROLE_HIERARCHY)[number]);
  const below = idx >= 0 ? ROLE_HIERARCHY.slice(idx + 1) : ROLE_HIERARCHY;
  return Array.from(new Set([...below]));
}

function slugifyCode(input: string): string {
  const cleaned = input
    .normalize("NFKD")
    .replace(/[^a-zA-Z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .toUpperCase();
  return cleaned || `FORM_${Date.now()}`;
}

function normalizeBoolean(value: unknown, defaultValue: boolean): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (["1", "true", "evet", "yes", "y"].includes(normalized)) return true;
    if (["0", "false", "hayir", "no", "n"].includes(normalized)) return false;
  }
  if (typeof value === "number") return value !== 0;
  return defaultValue;
}

export async function POST(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Supabase yapılandırması eksik" }, { status: 500 });
  }

  const supabase = (await getSupabaseServerClient()) as SupabaseClient<any>;
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false } }) as SupabaseClient<any>;

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return NextResponse.json({ message: "Oturum doğrulanamadı" }, { status: 401 });
  }

  const userId = user.id;

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role, tenant_id")
    .eq("id", userId)
    .maybeSingle<{ role: string | null; tenant_id: string | null }>();

  if (profileError || !profile?.role) {
    return NextResponse.json({ message: "Profil bulunamadı" }, { status: 403 });
  }

  if (!["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"].includes(profile.role)) {
    return NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 });
  }

  const body = (await request.json().catch(() => null)) as PublishBody | null;

  if (!body || !Array.isArray(body.items) || body.items.length === 0) {
    return NextResponse.json({ message: "Geçerli bir Excel içeriği gönderilmedi" }, { status: 400 });
  }

  if (body.items.length > MAX_ITEMS) {
    return NextResponse.json({ message: `En fazla ${MAX_ITEMS} satır yükleyebilirsiniz` }, { status: 400 });
  }

  const title = (body.title ?? "Yeni Form").trim();
  const description = (body.description ?? "").trim();
  const code = slugifyCode(body.code ?? title);
  const selectable = lowerRoles(profile.role);
  const autoInclude = upperRoles(profile.role);
  const cleaned = Array.isArray(body.visibleRoles) && body.visibleRoles.length > 0
    ? body.visibleRoles.map((r) => (typeof r === "string" ? r.trim() : "")).filter((r) => (selectable as string[]).includes(r) || (autoInclude as string[]).includes(r))
    : [...selectable, ...autoInclude];
  const visibleRoles = Array.from(new Set([...autoInclude, ...cleaned]));

  const targetTenantId =
    profile.role === "grand_admin" ? body.tenantId?.trim() || null : profile.tenant_id?.toString() ?? null;

  if (!targetTenantId) {
    return NextResponse.json({ message: "Hedef firma seçilmedi" }, { status: 400 });
  }

  const targetTenantIds: string[] = [];

  if (profile.role === "grand_admin" && targetTenantId === "__ALL__") {
    const { data: allTenants, error: tenantsError } = await admin.from("tenants").select("id");
    if (tenantsError) {
      return NextResponse.json({ message: "Firmalar alınamadı" }, { status: 500 });
    }
    if (!allTenants || allTenants.length === 0) {
      return NextResponse.json({ message: "Kayıtlı firma bulunamadı" }, { status: 404 });
    }
    targetTenantIds.push(...allTenants.map((t: { id: string }) => t.id));
  } else {
    const { data: tenant, error: tenantError } = await admin
      .from("tenants")
      .select("id")
      .eq("id", targetTenantId)
      .maybeSingle<{ id: string }>();

    if (tenantError) {
      return NextResponse.json({ message: "Firma bilgisi alınamadı" }, { status: 500 });
    }
    if (!tenant) {
      return NextResponse.json({ message: "Firma bulunamadı" }, { status: 404 });
    }
    targetTenantIds.push(tenant.id);
  }

  const preparedItems = body.items
    .map((item, index) => {
      const question = (item.question ?? '').toString().trim();
      if (!question) return null;
      const rawScore = Number(item.score);
      const score = Number.isFinite(rawScore) && rawScore > 0 ? rawScore : 1;
      return {
        question,
        hasBinaryChoice: normalizeBoolean(item.hasBinaryChoice, true),
        allowComment: normalizeBoolean(item.allowComment, false),
        score,
        order: index,
      };
    })
    .filter(Boolean) as { question: string; hasBinaryChoice: boolean; allowComment: boolean; score: number; order: number }[];

  if (preparedItems.length === 0) {
    return NextResponse.json({ message: "Excel içinde soru bulunamadı" }, { status: 400 });
  }

  async function publishForTenant(tenantId: string) {
    const { data: existingForm, error: formLookupError } = await admin
      .from("store_scoring_forms")
      .select("id")
      .eq("tenant_id", tenantId)
      .eq("code", code)
      .maybeSingle<{ id: string }>();

    if (formLookupError) {
      throw new Error("Form sorgusunda hata oluştu");
    }

    let formId: string;
    if (existingForm) {
      formId = existingForm.id;
      const { error: updateError } = await admin
        .from("store_scoring_forms")
        .update({ title, description, visible_roles: visibleRoles, updated_at: new Date().toISOString() })
        .eq("id", formId);
      if (updateError) {
        throw new Error("Form güncellenemedi");
      }
    } else {
      const { data: created, error: insertError } = await admin
        .from("store_scoring_forms")
        .insert({ tenant_id: tenantId, code, title, description, visible_roles: visibleRoles, created_by: userId })
        .select("id")
        .maybeSingle<{ id: string }>();

      if (insertError || !created?.id) {
        throw new Error("Form oluşturulamadı");
      }
      formId = created.id;
    }

    const { data: latestVersionRow, error: versionQueryError } = await admin
      .from("store_scoring_form_versions")
      .select("version")
      .eq("form_id", formId)
      .order("version", { ascending: false })
      .limit(1)
      .maybeSingle<{ version: number }>();

    if (versionQueryError) {
      throw new Error("Form versiyonu hesaplanamadı");
    }

    const nextVersion = (latestVersionRow?.version ?? 0) + 1;

    const { data: versionRow, error: versionInsertError } = await admin
      .from("store_scoring_form_versions")
      .insert({
        form_id: formId,
        version: nextVersion,
        status: "published",
        published_at: new Date().toISOString(),
        created_by: userId,
      })
      .select("id")
      .maybeSingle<{ id: string }>();

    if (versionInsertError || !versionRow?.id) {
      throw new Error("Form versiyonu oluşturulamadı");
    }

    const formVersionId = versionRow.id;

    const { data: sectionRow, error: sectionError } = await admin
      .from("store_scoring_sections")
      .insert({ form_version_id: formVersionId, title: "GENEL", order_index: 0 })
      .select("id")
      .maybeSingle<{ id: string }>();

    if (sectionError || !sectionRow?.id) {
      throw new Error("Form bölümü oluşturulamadı");
    }

    const itemsPayload = preparedItems.map((item) => ({
      section_id: sectionRow.id,
      label: item.question,
      positive_points: item.score,
      negative_points: item.hasBinaryChoice ? item.score : 0,
      order_index: item.order,
      is_required: false,
      metadata: {
        hasBinaryChoice: item.hasBinaryChoice,
        allowComment: item.allowComment,
        score: item.score,
      },
    }));

    const { error: itemsError } = await admin.from("store_scoring_items").insert(itemsPayload);
    if (itemsError) {
      throw new Error("Form soruları kaydedilemedi");
    }

    return {
      formId,
      formVersionId,
      version: nextVersion,
      itemCount: itemsPayload.length,
    };
  }

  const results = [] as Array<{ formId: string; formVersionId: string; version: number; itemCount: number; tenantId: string }>;

  for (const tId of targetTenantIds) {
    const res = await publishForTenant(tId);
    results.push({ ...res, tenantId: tId });
  }

  return NextResponse.json({
    message: "Form yayınlandı",
    code,
    results,
  });
}
