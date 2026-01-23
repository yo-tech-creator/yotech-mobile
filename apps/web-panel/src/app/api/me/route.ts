import { NextResponse } from "next/server";
import type { SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/types/database";

export async function GET() {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const { data: userResp, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userResp?.user) {
    return NextResponse.json({ message: "Yetkisiz" }, { status: 401 });
  }

  const { data: profile, error } = await supabase
    .from("users")
    .select("id, role, tenant_id")
    .eq("id", userResp.user.id)
    .maybeSingle<{ id: string; role: string | null; tenant_id: string | null }>();

  if (error || !profile?.role) {
    return NextResponse.json({ message: "Profil bulunamadı" }, { status: 404 });
  }

  return NextResponse.json({ id: profile.id, role: profile.role, tenant_id: profile.tenant_id });
}
