import { NextResponse } from "next/server";
import type { SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const ALLOWED_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"]);

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

export async function GET() {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;

  const { supabase, profile } = gate;
  const PAGE_SIZE = 1000; // Supabase tek seferde en fazla 1000 satır döndürür
  const all: any[] = [];
  let page = 0;

  while (true) {
    const from = page * PAGE_SIZE;
    const to = from + PAGE_SIZE - 1;

    const { data, error } = await supabase
      .from("products")
      .select("id, barcode, name, brand, category, supplier, unit, price, active, alt_barcodes, created_at")
      .eq("tenant_id", profile.tenant_id)
      .order("name", { ascending: true })
      .range(from, to);

    if (error) {
      return NextResponse.json({ message: "Ürün listesi alınamadı", detail: error.message }, { status: 500 });
    }

    if (!data || data.length === 0) break;

    all.push(...data);

    if (data.length < PAGE_SIZE) break; // son sayfa
    page += 1;

    if (page > 20) {
      // güvenlik için hard limit (20*1000=20k)
      break;
    }
  }

  return NextResponse.json({ products: all });
}
