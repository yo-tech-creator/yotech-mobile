import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

const ALLOWED_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"]);

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

export async function GET() {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { profile } = gate;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

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

export async function POST(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { profile } = gate;

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const body = await request.json().catch(() => null);
  const firstName = typeof body?.first_name === "string" ? body.first_name.trim() : "";
  const lastName = typeof body?.last_name === "string" ? body.last_name.trim() : "";
  const email = typeof body?.email === "string" ? body.email.trim() : "";
  const phone = typeof body?.phone === "string" ? body.phone.trim() : null;
  const position = typeof body?.position === "string" ? body.position.trim() : null;
  const branchId = typeof body?.branch_id === "string" ? body.branch_id.trim() : profile.branch_id;
  const role = typeof body?.role === "string" ? body.role : "sube_muduru";

  if (!email || !branchId) {
    return NextResponse.json({ message: "Email ve şube zorunlu" }, { status: 400 });
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
    first_name: firstName || null,
    last_name: lastName || null,
    email,
    phone,
    position,
    active: true,
  };

  const { error: insertErr } = await supabaseAdmin.from("users").insert(insertPayload);
  if (insertErr) {
    await supabaseAdmin.auth.admin.deleteUser(authUser.user.id);
    return NextResponse.json({ message: "Personel kaydedilemedi", detail: insertErr.message }, { status: 500 });
  }

  return NextResponse.json({ id: authUser.user.id });
}

export async function PATCH(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile } = gate;

  const body = await request.json().catch(() => null);
  const id = typeof body?.id === "string" ? body.id : null;
  if (!id) {
    return NextResponse.json({ message: "id gerekli" }, { status: 400 });
  }

  const branchId = body?.branch_id === null ? null : typeof body?.branch_id === "string" ? body.branch_id : undefined;
  const role = typeof body?.role === "string" ? body.role : undefined;
  const position = typeof body?.position === "string" ? body.position : undefined;

  const { data: existing, error: readErr } = await supabase
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

  const updatePayload: Database["public"]["Tables"]["users"]["Update"] = {
    branch_id: branchId,
    role,
    position,
  };

  const { error } = await supabase.from("users").update(updatePayload).eq("id", id).eq("tenant_id", profile.tenant_id);
  if (error) {
    return NextResponse.json({ message: "Güncelleme başarısız", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}

export async function DELETE(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { profile } = gate;

  const url = new URL(request.url);
  const id = url.searchParams.get("id");
  if (!id) {
    return NextResponse.json({ message: "id gerekli" }, { status: 400 });
  }

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: existing, error: readErr } = await supabaseAdmin
    .from("users")
    .select("id, tenant_id")
    .eq("id", id)
    .maybeSingle();

  if (readErr) {
    return NextResponse.json({ message: "Kayıt okunamadı", detail: readErr.message }, { status: 500 });
  }
  if (!existing || existing.tenant_id !== profile.tenant_id) {
    return NextResponse.json({ message: "Kayıt bulunamadı" }, { status: 404 });
  }

  await supabaseAdmin.auth.admin.deleteUser(id);
  await supabaseAdmin.from("users").delete().eq("id", id);

  return NextResponse.json({ id });
}
