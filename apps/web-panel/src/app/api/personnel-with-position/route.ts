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

  return { profile: profile as { id: string; role: string | null; tenant_id: string; branch_id: string | null } } as const;
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
    .select("*")
    .eq("tenant_id", profile.tenant_id)
    .eq("active", true)
    .order("first_name", { ascending: true });

  if (profile.branch_id) {
    query = query.eq("branch_id", profile.branch_id);
  }

  const { data, error } = await query;
  if (error) {
    return NextResponse.json({ message: "Personel alınamadı", detail: error.message }, { status: 500 });
  }

  type UserWithLeave = (typeof data)[number] & { annual_leave_days?: number | null };
  const rows = (data || []) as UserWithLeave[];
  const people = rows.map((p) => ({
    id: p.id,
    name: [p.first_name, p.last_name].filter(Boolean).join(" ") || "İsimsiz",
    position: p.position || "Bilinmiyor",
    annual_leave_days: p.annual_leave_days ?? null,
  }));

  return NextResponse.json({ people });
}
