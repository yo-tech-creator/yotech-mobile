import { NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

export async function GET() {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<any>;
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    return NextResponse.json({ message: "Yetkisiz" }, { status: 401 });
  }

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("id, tenant_id, branch_id")
    .eq("id", session.user.id)
    .maybeSingle();

  if (profileError || !profile) {
    return NextResponse.json({ message: "Profil bulunamadı" }, { status: 403 });
  }

  if (!profile.branch_id) {
    return NextResponse.json({ assignees: [] });
  }

  const supabaseAdmin: SupabaseClient<Database> = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
    ? createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
        auth: { autoRefreshToken: false },
      })
    : (supabase as SupabaseClient<Database>);

  const { data, error } = await supabaseAdmin
    .from("users")
    .select("id, first_name, last_name, email, role")
    .eq("tenant_id", profile.tenant_id)
    .eq("branch_id", profile.branch_id)
    .in("role", ["sube_muduru", "personel", "bolge_muduru", "firma_admin", "grand_admin"]);

  if (error) {
    return NextResponse.json({ message: "Personel alınamadı" }, { status: 500 });
  }

  return NextResponse.json({ assignees: data ?? [] });
}
