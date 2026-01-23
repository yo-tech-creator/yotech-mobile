import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

export async function GET(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const url = new URL(request.url);
  const tenantId = url.searchParams.get("tenantId");

  if (!tenantId) {
    return NextResponse.json({ message: "tenantId zorunlu" }, { status: 400 });
  }

  const { data: userResp, error: userError } = await supabase.auth.getUser();

  if (userError || !userResp?.user) {
    return NextResponse.json({ message: "Yetkisiz" }, { status: 401 });
  }

  const { data: profile } = await supabase
    .from("users")
    .select("role, tenant_id")
    .eq("id", userResp.user.id)
    .maybeSingle<{ role: string | null; tenant_id: string | null }>();

  const isGrand = profile?.role === "grand_admin";
  const isFirma = profile?.role === "firma_admin" && profile.tenant_id;

  if (!isGrand && !isFirma) {
    return NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 });
  }

  if (isFirma && profile?.tenant_id !== tenantId) {
    return NextResponse.json({ message: "Bu firmayı görüntüleme yetkiniz yok" }, { status: 403 });
  }

  const { data, error } = await supabaseAdmin
    .from("branches")
    .select("id, name, code")
    .eq("tenant_id", tenantId)
    .order("name", { ascending: true });

  if (error) {
    return NextResponse.json({ message: "Şubeler alınamadı" }, { status: 500 });
  }

  return NextResponse.json({ branches: data ?? [] });
}
