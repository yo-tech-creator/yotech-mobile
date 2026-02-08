import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

async function requireAllowed() {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const { data: userResp, error: userError } = await supabase.auth.getUser();

  if (userError || !userResp?.user) {
    return { error: NextResponse.json({ message: "Yetkisiz" }, { status: 401 }) } as const;
  }

  const { data: profile } = await supabase
    .from("users")
    .select("role, tenant_id")
    .eq("id", userResp.user.id)
    .maybeSingle<{ role: string | null; tenant_id: string | null }>();

  const isGrand = profile?.role === "grand_admin";
  const isFirma = profile?.role === "firma_admin" && profile.tenant_id;

  if (!isGrand && !isFirma) {
    return { error: NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 }) } as const;
  }

  return { supabase, profile } as const;
}

export async function GET(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const gate = await requireAllowed();
  if ("error" in gate) return gate.error;
  const requesterTenant = gate.profile?.tenant_id ?? null;

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const url = new URL(request.url);
  const tenantId = url.searchParams.get("tenantId");
  const branchId = url.searchParams.get("branchId");
  const search = url.searchParams.get("search")?.trim();
  const sort = url.searchParams.get("sort") ?? "name_asc";
  const pageParam = Number(url.searchParams.get("page") ?? "1");
  const pageSizeParam = Number(url.searchParams.get("pageSize") ?? "100");

  const pageSize = Math.min(Math.max(Number.isFinite(pageSizeParam) ? pageSizeParam : 100, 1), 500);
  const page = Math.max(Number.isFinite(pageParam) ? pageParam : 1, 1);
  const from = (page - 1) * pageSize;
  const to = from + pageSize - 1;

  if (!tenantId) {
    return NextResponse.json({ message: "tenantId zorunlu" }, { status: 400 });
  }

  // Firma admin kendi tenant'ı dışında sorgu yapamasın
  if (gate.profile?.role === "firma_admin" && requesterTenant && tenantId !== requesterTenant) {
    return NextResponse.json({ message: "Bu firmayı görüntüleme yetkiniz yok" }, { status: 403 });
  }

  let query = supabaseAdmin
    .from("users")
    .select("id, first_name, last_name, email, phone, role, tenant_id, branch_id, employee_code, position, is_active, branches(name, code)", {
      count: "exact",
    })
    .eq("tenant_id", tenantId);

  if (branchId) {
    query = query.eq("branch_id", branchId);
  }

  if (search) {
    const term = `%${search}%`;
    query = query.or(`first_name.ilike.${term},last_name.ilike.${term},email.ilike.${term}`);
  }

  switch (sort) {
    case "name_desc":
      query = query.order("first_name", { ascending: false }).order("last_name", { ascending: false });
      break;
    case "branch_asc":
      query = query.order("name", { ascending: true, foreignTable: "branches" }).order("first_name", { ascending: true });
      break;
    case "branch_desc":
      query = query.order("name", { ascending: false, foreignTable: "branches" }).order("first_name", { ascending: true });
      break;
    case "name_asc":
    default:
      query = query.order("first_name", { ascending: true }).order("last_name", { ascending: true });
      break;
  }

  query = query.range(from, to);

  const { data, error, count } = await query;

  if (error) {
    return NextResponse.json({ message: "Kullanıcılar alınamadı" }, { status: 500 });
  }

  const total = count ?? 0;
  const pageCount = Math.max(1, Math.ceil(total / pageSize));
  const safePage = Math.min(page, pageCount);

  return NextResponse.json({
    users: data ?? [],
    total,
    page: safePage,
    pageSize,
    pageCount,
  });
}

export async function POST(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const gate = await requireAllowed();
  if ("error" in gate) return gate.error;
  if (gate.profile?.role !== "grand_admin") {
    return NextResponse.json({ message: "Bu işlem için grand_admin olmalısınız" }, { status: 403 });
  }

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const body = await request.json().catch(() => null);

  if (!body || typeof body.tenant_id !== "string" || typeof body.email !== "string") {
    return NextResponse.json({ message: "tenant_id ve email zorunlu" }, { status: 400 });
  }

  const password = typeof body.password === "string" && body.password.length >= 6 ? body.password : crypto.randomUUID();

  const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
    email: body.email,
    password,
    email_confirm: true,
  });

  if (authError || !authUser?.user?.id) {
    console.error("Auth user creation error:", authError);
    return NextResponse.json({ message: authError?.message || "Auth kullanıcısı oluşturulamadı" }, { status: 500 });
  }

  const insertPayload: Database["public"]["Tables"]["users"]["Insert"] = {
    id: authUser.user.id,
    tenant_id: body.tenant_id,
    branch_id: body.branch_id ?? null,
    role: body.role ?? "sube_muduru",
    first_name: body.first_name ?? null,
    last_name: body.last_name ?? null,
    email: body.email,
    phone: body.phone ?? null,
    employee_code: body.employee_code ?? null,
    position: body.position ?? null,
    is_active: body.is_active ?? true,
  };

  const { error: insertError } = await supabaseAdmin.from("users").insert(insertPayload);

  if (insertError) {
    await supabaseAdmin.auth.admin.deleteUser(authUser.user.id);
    return NextResponse.json({ message: "Kullanıcı kaydedilemedi" }, { status: 500 });
  }

  return NextResponse.json({ id: authUser.user.id });
}

export async function PATCH(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const gate = await requireAllowed();
  if ("error" in gate) return gate.error;
  if (gate.profile?.role !== "grand_admin") {
    return NextResponse.json({ message: "Bu işlem için grand_admin olmalısınız" }, { status: 403 });
  }

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const body = await request.json().catch(() => null);

  if (!body || typeof body.id !== "string") {
    return NextResponse.json({ message: "id zorunlu" }, { status: 400 });
  }

  const { id, email, ...rest } = body as Record<string, unknown>;
  const userId = typeof id === "string" ? id : String(id);

  if (email && typeof email === "string") {
    await supabaseAdmin.auth.admin.updateUserById(userId, { email });
  }

  const updatePayload: Database["public"]["Tables"]["users"]["Update"] = {
    tenant_id: typeof rest.tenant_id === "string" ? rest.tenant_id : undefined,
    branch_id: typeof rest.branch_id === "string" ? rest.branch_id : rest.branch_id === null ? null : undefined,
    role: typeof rest.role === "string" ? rest.role : undefined,
    first_name: typeof rest.first_name === "string" ? rest.first_name : undefined,
    last_name: typeof rest.last_name === "string" ? rest.last_name : undefined,
    phone: typeof rest.phone === "string" ? rest.phone : undefined,
    employee_code: typeof rest.employee_code === "string" ? rest.employee_code : undefined,
    position: typeof rest.position === "string" ? rest.position : undefined,
    email: typeof email === "string" ? email : undefined,
    is_active: typeof rest.is_active === "boolean" ? rest.is_active : undefined,
  };

  const { error: updateError } = await supabaseAdmin.from("users").update(updatePayload).eq("id", userId);

  if (updateError) {
    return NextResponse.json({ message: "Kullanıcı güncellenemedi" }, { status: 500 });
  }

  return NextResponse.json({ id });
}

export async function DELETE(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const gate = await requireAllowed();
  if ("error" in gate) return gate.error;
  if (gate.profile?.role !== "grand_admin") {
    return NextResponse.json({ message: "Bu işlem için grand_admin olmalısınız" }, { status: 403 });
  }

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const url = new URL(request.url);
  const id = url.searchParams.get("id");

  if (!id) {
    return NextResponse.json({ message: "id zorunlu" }, { status: 400 });
  }

  await supabaseAdmin.auth.admin.deleteUser(id);
  await supabaseAdmin.from("users").delete().eq("id", id);

  return NextResponse.json({ id });
}
