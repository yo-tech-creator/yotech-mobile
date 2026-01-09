import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

export async function GET() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    return NextResponse.json({ message: "Yetkisiz" }, { status: 401 });
  }

  const { data: profile } = await supabase
    .from("users")
    .select("role")
    .eq("id", session.user.id)
    .maybeSingle<{ role: string | null }>();

  if (profile?.role !== "grand_admin") {
    return NextResponse.json({ message: "Bu işlem için grand_admin olmalısınız" }, { status: 403 });
  }

  const { data, error } = await supabaseAdmin
    .from("tenants")
    .select("id, code, name, active")
    .order("name", { ascending: true });

  if (error) {
    return NextResponse.json({ message: "Firmalar alınamadı" }, { status: 500 });
  }

  return NextResponse.json({ tenants: data ?? [] });
}
