import { NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/types/database";

const ALLOWED_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"]);

export async function GET() {
  const supabase = await getSupabaseServerClient<Database>();
  const { data: userResp, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userResp?.user) {
    return NextResponse.json({ message: "Yetkisiz" }, { status: 401 });
  }

  const { data: profile, error: profileErr } = await supabase
    .from("users")
    .select("tenant_id, role")
    .eq("id", userResp.user.id)
    .maybeSingle();

  if (profileErr || !profile?.tenant_id || !ALLOWED_ROLES.has(profile.role ?? "")) {
    return NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 });
  }

  const { data, error } = await supabase
    .from("branches")
    .select("id, name")
    .eq("tenant_id", profile.tenant_id)
    .eq("active", true)
    .order("name", { ascending: true });

  if (error) {
    return NextResponse.json({ message: "Şubeler alınamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ branches: data ?? [] });
}
