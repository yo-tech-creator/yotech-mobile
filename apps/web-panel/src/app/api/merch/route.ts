import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

const ALLOWED_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"]);
const RANKS = new Set(["merch", "plasiyer", "sevkiyat", "sef", "yonetici"]);

async function getProfile() {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const { data: userResp, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userResp?.user) {
    return { error: NextResponse.json({ message: "Yetkisiz" }, { status: 401 }) } as const;
  }

  const { data: profile, error: profileErr } = await supabase
    .from("users")
    .select("id, role, tenant_id")
    .eq("id", userResp.user.id)
    .maybeSingle();

  if (profileErr || !profile?.tenant_id || !ALLOWED_ROLES.has(profile.role ?? "")) {
    return { error: NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 }) } as const;
  }

  return { profile: profile as { id: string; role: string | null; tenant_id: string } } as const;
}

function ensureConfig() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }
  return null;
}

export async function GET() {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const configErr = ensureConfig();
  if (configErr) return configErr;

  const supabaseAdmin = createClient<Database>(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
  const { data, error } = await supabaseAdmin
    .from("merch_people")
    .select("id, first_name, last_name, company_name, phone_number, rank, created_at, updated_at")
    .eq("tenant_id", gate.profile.tenant_id)
    .order("company_name", { ascending: true })
    .order("first_name", { ascending: true });

  if (error) {
    return NextResponse.json({ message: "Mörş listesi alınamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ people: data ?? [] });
}

export async function POST(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const configErr = ensureConfig();
  if (configErr) return configErr;

  const body = await request.json().catch(() => null);
  const firstName = typeof body?.first_name === "string" ? body.first_name.trim() : "";
  const lastName = typeof body?.last_name === "string" ? body.last_name.trim() : "";
  const companyName = typeof body?.company_name === "string" ? body.company_name.trim() : "";
  const phoneNumber = typeof body?.phone_number === "string" ? body.phone_number.trim() : "";
  const rank = typeof body?.rank === "string" ? body.rank.trim() : "";

  if (!firstName || !lastName || !companyName || !phoneNumber || !RANKS.has(rank)) {
    return NextResponse.json({ message: "Zorunlu alanlar eksik" }, { status: 400 });
  }

  const supabaseAdmin = createClient<Database>(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
  const { data, error } = await supabaseAdmin
    .from("merch_people")
    .insert({
      tenant_id: gate.profile.tenant_id,
      created_by: gate.profile.id,
      first_name: firstName,
      last_name: lastName,
      company_name: companyName,
      phone_number: phoneNumber,
      rank,
    })
    .select("id")
    .single();

  if (error) {
    return NextResponse.json({ message: "Kayıt başarısız", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ id: data?.id });
}

export async function PATCH(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const configErr = ensureConfig();
  if (configErr) return configErr;

  const body = await request.json().catch(() => null);
  const id = typeof body?.id === "string" ? body.id : null;
  if (!id) return NextResponse.json({ message: "id gerekli" }, { status: 400 });

  const updates: Database["public"]["Tables"]["merch_people"]["Update"] = {};
  if (typeof body?.first_name === "string") updates.first_name = body.first_name.trim();
  if (typeof body?.last_name === "string") updates.last_name = body.last_name.trim();
  if (typeof body?.company_name === "string") updates.company_name = body.company_name.trim();
  if (typeof body?.phone_number === "string") updates.phone_number = body.phone_number.trim();
  if (typeof body?.rank === "string" && RANKS.has(body.rank)) updates.rank = body.rank;
  updates.updated_at = new Date().toISOString();

  const supabaseAdmin = createClient<Database>(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
  const { data: existing, error: readErr } = await supabaseAdmin
    .from("merch_people")
    .select("id, tenant_id")
    .eq("id", id)
    .maybeSingle();

  if (readErr) {
    return NextResponse.json({ message: "Kayıt okunamadı", detail: readErr.message }, { status: 500 });
  }
  if (!existing || existing.tenant_id !== gate.profile.tenant_id) {
    return NextResponse.json({ message: "Kayıt bulunamadı" }, { status: 404 });
  }

  const { error } = await supabaseAdmin
    .from("merch_people")
    .update(updates)
    .eq("id", id)
    .eq("tenant_id", gate.profile.tenant_id);

  if (error) {
    return NextResponse.json({ message: "Güncelleme başarısız", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}

export async function DELETE(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const configErr = ensureConfig();
  if (configErr) return configErr;

  const url = new URL(request.url);
  const id = url.searchParams.get("id");
  if (!id) return NextResponse.json({ message: "id gerekli" }, { status: 400 });

  const supabaseAdmin = createClient<Database>(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
  const { data: existing, error: readErr } = await supabaseAdmin
    .from("merch_people")
    .select("id, tenant_id")
    .eq("id", id)
    .maybeSingle();

  if (readErr) {
    return NextResponse.json({ message: "Kayıt okunamadı", detail: readErr.message }, { status: 500 });
  }
  if (!existing || existing.tenant_id !== gate.profile.tenant_id) {
    return NextResponse.json({ message: "Kayıt bulunamadı" }, { status: 404 });
  }

  const { error } = await supabaseAdmin.from("merch_people").delete().eq("id", id).eq("tenant_id", gate.profile.tenant_id);
  if (error) {
    return NextResponse.json({ message: "Silme başarısız", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ id });
}
