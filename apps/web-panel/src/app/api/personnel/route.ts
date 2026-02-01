import { NextRequest, NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";
import { checkRateLimit, rateLimitResponse, applyRateLimitHeaders } from "@/lib/security/rate-limiter";
import { z } from "zod";
import xss from "xss";

const ALLOWED_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"]);

// Input Validation Schemas
const createPersonnelSchema = z.object({
  first_name: z.string().max(100).optional().transform(v => v ? xss(v.trim()) : undefined),
  last_name: z.string().max(100).optional().transform(v => v ? xss(v.trim()) : undefined),
  email: z.string().email("Geçersiz e-posta").max(255).transform(v => v.toLowerCase().trim()),
  phone: z.string().max(20).optional().transform(v => v ? xss(v.trim()) : undefined),
  position: z.string().max(100).optional().transform(v => v ? xss(v.trim()) : undefined),
  branch_id: z.string().uuid("Geçersiz şube ID").optional(),
  role: z.enum(["firma_admin", "bolge_muduru", "sube_muduru", "personel"]).default("personel"),
});

const updatePersonnelSchema = z.object({
  id: z.string().uuid("Geçersiz kullanıcı ID"),
  branch_id: z.string().uuid("Geçersiz şube ID").nullable().optional(),
  role: z.enum(["firma_admin", "bolge_muduru", "sube_muduru", "personel"]).optional(),
  position: z.string().max(100).optional().transform(v => v ? xss(v.trim()) : undefined),
});

// Helper: Bölge müdürünün yetkili olduğu şube ID'lerini döndürür
async function getRegionManagerAllowedBranches(
  supabaseAdmin: SupabaseClient<Database>,
  userId: string,
  tenantId: string
): Promise<string[]> {
  // Kullanıcının yönettiği bölgeleri bul
  const { data: managedRegions } = await supabaseAdmin
    .from("regions")
    .select("id")
    .eq("manager_id", userId)
    .eq("tenant_id", tenantId);

  const regionIds = (managedRegions ?? []).map((r) => r.id);
  if (regionIds.length === 0) return [];

  // Bu bölgelerdeki şubeleri bul
  const { data: branches } = await supabaseAdmin
    .from("branches")
    .select("id")
    .eq("tenant_id", tenantId)
    .in("region_id", regionIds);

  return (branches ?? []).map((b) => b.id);
}

async function getProfile() {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const { data: userResp, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userResp?.user) {
    return { error: NextResponse.json({ message: "Yetkisiz" }, { status: 401 }) } as const;
  }
  const userId = userResp.user.id;
  const { data: profile, error: profileErr } = await supabase
    .from("users")
    .select("id, role, tenant_id, branch_id")
    .eq("id", userId)
    .maybeSingle();

  if (profileErr || !profile?.tenant_id || !ALLOWED_ROLES.has(profile.role ?? "")) {
    return { error: NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 }) } as const;
  }

  return { supabase, profile: profile as { id: string; role: string | null; tenant_id: string; branch_id: string | null }, userId } as const;
}

export async function GET(request: NextRequest) {
  // Rate limiting check
  const rateLimit = await checkRateLimit(request, 'api');
  if (!rateLimit.success) {
    return rateLimitResponse(rateLimit);
  }

  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { profile } = gate;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Bölge müdürü için: kendi bölgesindeki şubelerin personellerini getir
  if (profile.role === "bolge_muduru") {
    // Önce bu kullanıcının yönettiği bölgeleri bul
    const { data: managedRegions, error: regErr } = await supabaseAdmin
      .from("regions")
      .select("id")
      .eq("manager_id", profile.id)
      .eq("tenant_id", profile.tenant_id);

    if (regErr) {
      return NextResponse.json({ message: "Bölgeler alınamadı", detail: regErr.message }, { status: 500 });
    }

    const regionIds = (managedRegions ?? []).map((r) => r.id);

    if (regionIds.length === 0) {
      // Bölge müdürünün yönettiği bölge yok, sadece kendi şubesindeki personeli göster
      let query = supabaseAdmin
        .from("users")
        .select("id, first_name, last_name, email, phone, role, branch_id, tenant_id, position, employee_code, branches(name)")
        .eq("tenant_id", profile.tenant_id)
        .order("first_name", { ascending: true });

      if (profile.branch_id) {
        query = query.eq("branch_id", profile.branch_id);
      }

      const { data, error } = await query;
      if (error) {
        return NextResponse.json({ message: "Personel alınamadı", detail: error.message }, { status: 500 });
      }

      return NextResponse.json({ users: data ?? [], branchId: profile.branch_id, tenantId: profile.tenant_id });
    }

    // Bölgelerdeki şubeleri bul
    const { data: branchesInRegions, error: brErr } = await supabaseAdmin
      .from("branches")
      .select("id")
      .eq("tenant_id", profile.tenant_id)
      .in("region_id", regionIds);

    if (brErr) {
      return NextResponse.json({ message: "Şubeler alınamadı", detail: brErr.message }, { status: 500 });
    }

    const branchIds = (branchesInRegions ?? []).map((b) => b.id);

    if (branchIds.length === 0) {
      return NextResponse.json({ users: [], branchId: profile.branch_id, tenantId: profile.tenant_id });
    }

    // Sadece bu şubelerdeki personelleri getir
    const { data, error } = await supabaseAdmin
      .from("users")
      .select("id, first_name, last_name, email, phone, role, branch_id, tenant_id, position, employee_code, branches(name)")
      .eq("tenant_id", profile.tenant_id)
      .in("branch_id", branchIds)
      .order("first_name", { ascending: true });

    if (error) {
      return NextResponse.json({ message: "Personel alınamadı", detail: error.message }, { status: 500 });
    }

    return NextResponse.json({ users: data ?? [], branchId: profile.branch_id, tenantId: profile.tenant_id });
  }

  // Şube müdürü için: sadece kendi şubesindeki personeller
  if (profile.role === "sube_muduru" && profile.branch_id) {
    const { data, error } = await supabaseAdmin
      .from("users")
      .select("id, first_name, last_name, email, phone, role, branch_id, tenant_id, position, employee_code, branches(name)")
      .eq("tenant_id", profile.tenant_id)
      .eq("branch_id", profile.branch_id)
      .order("first_name", { ascending: true });

    if (error) {
      return NextResponse.json({ message: "Personel alınamadı", detail: error.message }, { status: 500 });
    }

    return NextResponse.json({ users: data ?? [], branchId: profile.branch_id, tenantId: profile.tenant_id });
  }

  // grand_admin ve firma_admin için: tüm tenant personelleri
  const { data, error } = await supabaseAdmin
    .from("users")
    .select("id, first_name, last_name, email, phone, role, branch_id, tenant_id, position, employee_code, branches(name)")
    .eq("tenant_id", profile.tenant_id)
    .order("first_name", { ascending: true });

  if (error) {
    return NextResponse.json({ message: "Personel alınamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ users: data ?? [], branchId: profile.branch_id, tenantId: profile.tenant_id });
}

export async function POST(request: NextRequest) {
  // Rate limiting check
  const rateLimit = await checkRateLimit(request, 'api');
  if (!rateLimit.success) {
    return rateLimitResponse(rateLimit);
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { profile } = gate;

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  
  // Input validation with Zod
  let body;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ message: "Geçersiz JSON formatı" }, { status: 400 });
  }

  const validation = createPersonnelSchema.safeParse(body);
  if (!validation.success) {
    return NextResponse.json({ 
      message: "Doğrulama hatası", 
      errors: validation.error.errors.map(e => ({ field: e.path.join('.'), message: e.message }))
    }, { status: 400 });
  }

  const { first_name, last_name, email, phone, position, role } = validation.data;
  const branchId = validation.data.branch_id ?? profile.branch_id;

  if (!email || !branchId) {
    return NextResponse.json({ message: "Email ve şube zorunlu" }, { status: 400 });
  }

  // Bölge müdürü için şube yetki kontrolü
  if (profile.role === "bolge_muduru") {
    const allowedBranches = await getRegionManagerAllowedBranches(supabaseAdmin, profile.id, profile.tenant_id);
    if (!allowedBranches.includes(branchId)) {
      return NextResponse.json({ message: "Bu şubeye personel ekleme yetkiniz yok" }, { status: 403 });
    }
  }

  // Şube müdürü sadece kendi şubesine ekleyebilir
  if (profile.role === "sube_muduru" && branchId !== profile.branch_id) {
    return NextResponse.json({ message: "Sadece kendi şubenize personel ekleyebilirsiniz" }, { status: 403 });
  }

  const password = crypto.randomUUID();

  const { data: authUser, error: authErr } = await supabaseAdmin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (authErr || !authUser?.user?.id) {
    return NextResponse.json({ message: "Kullanıcı oluşturulamadı", detail: authErr?.message }, { status: 500 });
  }

  const insertPayload: Database["public"]["Tables"]["users"]["Insert"] = {
    id: authUser.user.id,
    tenant_id: profile.tenant_id,
    branch_id: branchId,
    role,
    first_name: first_name || null,
    last_name: last_name || null,
    email,
    phone: phone || null,
    position: position || null,
    active: true,
  };

  const { error: insertErr } = await supabaseAdmin.from("users").insert(insertPayload);
  if (insertErr) {
    await supabaseAdmin.auth.admin.deleteUser(authUser.user.id);
    return NextResponse.json({ message: "Personel kaydedilemedi", detail: insertErr.message }, { status: 500 });
  }

  return NextResponse.json({ id: authUser.user.id });
}

export async function PATCH(request: NextRequest) {
  // Rate limiting check
  const rateLimit = await checkRateLimit(request, 'api');
  if (!rateLimit.success) {
    return rateLimitResponse(rateLimit);
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { profile } = gate;

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Input validation with Zod
  let body;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ message: "Geçersiz JSON formatı" }, { status: 400 });
  }

  const validation = updatePersonnelSchema.safeParse(body);
  if (!validation.success) {
    return NextResponse.json({ 
      message: "Doğrulama hatası", 
      errors: validation.error.errors.map(e => ({ field: e.path.join('.'), message: e.message }))
    }, { status: 400 });
  }

  const { id, branch_id: branchId, role, position } = validation.data;

  const { data: existing, error: readErr } = await supabaseAdmin
    .from("users")
    .select("id, tenant_id, branch_id")
    .eq("id", id)
    .maybeSingle();

  if (readErr) {
    return NextResponse.json({ message: "Kayıt okunamadı", detail: readErr.message }, { status: 500 });
  }
  if (!existing || existing.tenant_id !== profile.tenant_id) {
    return NextResponse.json({ message: "Kayıt bulunamadı" }, { status: 404 });
  }

  // Bölge müdürü için yetki kontrolü
  if (profile.role === "bolge_muduru") {
    const allowedBranches = await getRegionManagerAllowedBranches(supabaseAdmin, profile.id, profile.tenant_id);
    // Mevcut şube yetkili mi?
    if (existing.branch_id && !allowedBranches.includes(existing.branch_id)) {
      return NextResponse.json({ message: "Bu personeli düzenleme yetkiniz yok" }, { status: 403 });
    }
    // Yeni şube yetkili mi?
    if (branchId && !allowedBranches.includes(branchId)) {
      return NextResponse.json({ message: "Bu şubeye personel atama yetkiniz yok" }, { status: 403 });
    }
  }

  // Şube müdürü sadece kendi şubesindeki personeli düzenleyebilir
  if (profile.role === "sube_muduru") {
    if (existing.branch_id !== profile.branch_id) {
      return NextResponse.json({ message: "Bu personeli düzenleme yetkiniz yok" }, { status: 403 });
    }
    if (branchId && branchId !== profile.branch_id) {
      return NextResponse.json({ message: "Personeli sadece kendi şubenize atayabilirsiniz" }, { status: 403 });
    }
  }

  const updatePayload: Database["public"]["Tables"]["users"]["Update"] = {
    branch_id: branchId,
    role,
    position,
  };

  const { error } = await supabaseAdmin.from("users").update(updatePayload).eq("id", id).eq("tenant_id", profile.tenant_id);
  if (error) {
    return NextResponse.json({ message: "Güncelleme başarısız", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}

export async function DELETE(request: NextRequest) {
  // Rate limiting check
  const rateLimit = await checkRateLimit(request, 'api');
  if (!rateLimit.success) {
    return rateLimitResponse(rateLimit);
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { profile } = gate;

  const url = new URL(request.url);
  const id = url.searchParams.get("id");
  
  // ID validation
  const idValidation = z.string().uuid("Geçersiz kullanıcı ID").safeParse(id);
  if (!idValidation.success) {
    return NextResponse.json({ message: "Geçersiz kullanıcı ID" }, { status: 400 });
  }

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: existing, error: readErr } = await supabaseAdmin
    .from("users")
    .select("id, tenant_id, branch_id")
    .eq("id", id)
    .maybeSingle();

  if (readErr) {
    return NextResponse.json({ message: "Kayıt okunamadı", detail: readErr.message }, { status: 500 });
  }
  if (!existing || existing.tenant_id !== profile.tenant_id) {
    return NextResponse.json({ message: "Kayıt bulunamadı" }, { status: 404 });
  }

  // Bölge müdürü için yetki kontrolü
  if (profile.role === "bolge_muduru") {
    const allowedBranches = await getRegionManagerAllowedBranches(supabaseAdmin, profile.id, profile.tenant_id);
    if (existing.branch_id && !allowedBranches.includes(existing.branch_id)) {
      return NextResponse.json({ message: "Bu personeli silme yetkiniz yok" }, { status: 403 });
    }
  }

  // Şube müdürü sadece kendi şubesindeki personeli silebilir
  if (profile.role === "sube_muduru" && existing.branch_id !== profile.branch_id) {
    return NextResponse.json({ message: "Bu personeli silme yetkiniz yok" }, { status: 403 });
  }

  await supabaseAdmin.auth.admin.deleteUser(id);
  await supabaseAdmin.from("users").delete().eq("id", id);

  return NextResponse.json({ id });
}
