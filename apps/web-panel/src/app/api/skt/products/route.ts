import { NextResponse } from "next/server";
import type { SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const ALLOWED_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru", "personel"]);

type Profile = {
  id: string;
  role: string | null;
  tenant_id: string | null;
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
    .select("id, role, tenant_id")
    .eq("id", userId)
    .maybeSingle();

  if (profileErr || !profile?.tenant_id || !ALLOWED_ROLES.has(profile.role ?? "")) {
    return { error: NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 }) } as const;
  }

  return { supabase, profile: profile as Profile } as const;
}

export async function GET(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile } = gate;

  const url = new URL(request.url);
  const query = url.searchParams.get("query")?.trim() ?? "";
  if (query.length < 2) {
    return NextResponse.json({ products: [] });
  }

  const sanitized = query.replaceAll("%", "\\%").replaceAll("_", "\\_");
  const pattern = `%${sanitized}%`;

  const { data, error } = await supabase
    .from("products")
    .select("id, name, barcode, alt_barcodes")
    .eq("tenant_id", profile.tenant_id)
    .eq("active", true)
    .or(`barcode.eq.${sanitized},barcode.ilike.${pattern},name.ilike.${pattern}`)
    .limit(20);

  if (error) {
    return NextResponse.json({ message: "Ürünler alınamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ products: data ?? [] });
}
