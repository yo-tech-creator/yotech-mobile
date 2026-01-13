import { NextResponse } from "next/server";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";

const ALLOWED_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"]);

type Profile = {
  id: string;
  role: string | null;
  tenant_id: string | null;
  branch_id: string | null;
};

async function getProfile() {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<any>;
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

  return { supabase, profile: profile as Profile } as const;
}

export async function GET() {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { profile } = gate;

  if (!profile.branch_id) {
    return NextResponse.json({ message: "Şube bilgisi bulunamadı" }, { status: 400 });
  }

  const adminClient = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
    ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false } })
    : (await getSupabaseServerClient()) as SupabaseClient<any>;

  const { data, error } = await adminClient
    .from("users")
    .select("id, first_name, last_name, email")
    .eq("tenant_id", profile.tenant_id)
    .eq("branch_id", profile.branch_id)
    .neq("id", profile.id)
    .order("first_name", { ascending: true });

  if (error) {
    return NextResponse.json({ message: "Personel listesi alınamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ users: data ?? [] });
}
