import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

const READ_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"]);
const WRITE_ROLES = new Set(["grand_admin", "firma_admin"]);

type Profile = {
  id: string;
  role: string | null;
  tenant_id: string | null;
};

type ParsedProduct = {
  id?: string;
  tenant_id?: string;
  barcode?: string;
  name?: string;
  brand?: string | null;
  category?: string | null;
  supplier?: string | null;
  unit?: string | null;
  price?: number | null;
  active?: boolean | null;
  alt_barcodes?: string[] | null;
};

async function getProfile(opts?: { allowRoles?: Set<string> }) {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const { data: userResp, error: userErr } = await supabase.auth.getUser();

  if (userErr || !userResp?.user) {
    return { error: NextResponse.json({ message: "Yetkisiz" }, { status: 401 }) } as const;
  }

  const userId = userResp.user.id;

  const { data: profile, error: profileErr } = await supabase
    .from("users")
    .select("id, role, tenant_id")
    .eq("id", userId)
    .maybeSingle<Profile>();

  if (profileErr || !profile?.role || (opts?.allowRoles && !opts.allowRoles.has(profile.role))) {
    return { error: NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 }) } as const;
  }

  return { supabase, profile: profile as Profile } as const;
}

function parseProductPayload(body: unknown): ParsedProduct {
  const obj = body as Record<string, unknown>;
  const pickString = (key: string) => (typeof obj[key] === "string" ? (obj[key] as string).trim() : undefined);
  const pickNullableString = (key: string) => (typeof obj[key] === "string" ? (obj[key] as string).trim() : obj[key] === null ? null : undefined);
  const pickBoolean = (key: string) => (typeof obj[key] === "boolean" ? (obj[key] as boolean) : undefined);
  const pickNumber = (key: string) => {
    const val = obj[key];
    if (typeof val === "number") return val;
    if (typeof val === "string" && val.trim()) {
      const n = Number(val.replace(",", "."));
      return Number.isFinite(n) ? n : undefined;
    }
    return undefined;
  };

  const altRaw = obj.alt_barcodes;
  const alt = Array.isArray(altRaw)
    ? altRaw.map((a) => (typeof a === "string" ? a.trim() : "")).filter(Boolean)
    : typeof altRaw === "string"
    ? altRaw
        .split(",")
        .map((a) => a.trim())
        .filter(Boolean)
    : undefined;

  return {
    id: pickString("id"),
    tenant_id: pickString("tenant_id"),
    barcode: pickString("barcode"),
    name: pickString("name"),
    brand: pickNullableString("brand"),
    category: pickNullableString("category"),
    supplier: pickNullableString("supplier"),
    unit: pickNullableString("unit"),
    price: pickNumber("price") ?? null,
    active: pickBoolean("active"),
    alt_barcodes: alt,
  };
}

export async function GET() {
  const gate = await getProfile({ allowRoles: READ_ROLES });
  if ("error" in gate) return gate.error;

  const { supabase, profile } = gate;
  const PAGE_SIZE = 1000;
  const all: Database["public"]["Tables"]["products"]["Row"][] = [];
  let page = 0;

  while (true) {
    const from = page * PAGE_SIZE;
    const to = from + PAGE_SIZE - 1;

    let query = supabase
      .from("products")
      .select("id, tenant_id, barcode, name, brand, category, supplier, unit, price, active, alt_barcodes, created_at")
      .order("name", { ascending: true })
      .range(from, to);

    if (profile.role !== "grand_admin" && profile.tenant_id) {
      query = query.eq("tenant_id", profile.tenant_id);
    }

    const { data, error } = await query;

    if (error) {
      return NextResponse.json({ message: "Ürün listesi alınamadı", detail: error.message }, { status: 500 });
    }

    if (!data || data.length === 0) break;

    all.push(...data);

    if (data.length < PAGE_SIZE) break;
    page += 1;

    if (page > 20) break;
  }

  return NextResponse.json({ products: all });
}

export async function POST(request: Request) {
  const gate = await getProfile({ allowRoles: WRITE_ROLES });
  if ("error" in gate) return gate.error;
  const { profile } = gate;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const body = await request.json().catch(() => null);
  const parsed = parseProductPayload(body);

  const tenantId = profile.role === "grand_admin" ? parsed.tenant_id : profile.tenant_id;
  if (!tenantId) {
    return NextResponse.json({ message: "Firma (tenant_id) zorunlu" }, { status: 400 });
  }

  const barcode = parsed.barcode;
  const name = parsed.name;
  if (!barcode || !name) {
    return NextResponse.json({ message: "Barkod ve ürün adı zorunlu" }, { status: 400 });
  }

  const payload: Database["public"]["Tables"]["products"]["Insert"] = {
    id: crypto.randomUUID(),
    tenant_id: tenantId,
    barcode,
    name,
    brand: parsed.brand ?? null,
    category: parsed.category ?? null,
    supplier: parsed.supplier ?? null,
    unit: parsed.unit ?? null,
    price: parsed.price ?? null,
    active: parsed.active ?? true,
    alt_barcodes: parsed.alt_barcodes ?? [],
  };

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { error } = await supabaseAdmin.from("products").insert(payload);
  if (error) {
    return NextResponse.json({ message: "Ürün eklenemedi", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ id: payload.id });
}

export async function PATCH(request: Request) {
  const gate = await getProfile({ allowRoles: WRITE_ROLES });
  if ("error" in gate) return gate.error;
  const { profile } = gate;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const body = await request.json().catch(() => null);
  const parsed = parseProductPayload(body);
  if (!parsed.id) {
    return NextResponse.json({ message: "id gerekli" }, { status: 400 });
  }

  const supabaseAdmin = getSupabaseAdminClient();
  const { data: existing, error: readErr } = await supabaseAdmin
    .from("products")
    .select("id, tenant_id")
    .eq("id", parsed.id)
    .maybeSingle();

  if (readErr) {
    return NextResponse.json({ message: "Kayıt okunamadı", detail: readErr.message }, { status: 500 });
  }
  if (!existing) {
    return NextResponse.json({ message: "Ürün bulunamadı" }, { status: 404 });
  }
  if (profile.role === "firma_admin" && profile.tenant_id && existing.tenant_id !== profile.tenant_id) {
    return NextResponse.json({ message: "Bu ürün farklı firmaya ait" }, { status: 403 });
  }

  const updatePayload: Database["public"]["Tables"]["products"]["Update"] = {
    barcode: parsed.barcode,
    name: parsed.name,
    brand: parsed.brand,
    category: parsed.category,
    supplier: parsed.supplier,
    unit: parsed.unit,
    price: parsed.price,
    active: parsed.active,
    alt_barcodes: parsed.alt_barcodes,
  };

  const { error } = await supabaseAdmin.from("products").update(updatePayload).eq("id", parsed.id);
  if (error) {
    return NextResponse.json({ message: "Güncelleme başarısız", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}

export async function DELETE(request: Request) {
  const gate = await getProfile({ allowRoles: WRITE_ROLES });
  if ("error" in gate) return gate.error;
  const { profile } = gate;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const url = new URL(request.url);
  const id = url.searchParams.get("id");
  if (!id) {
    return NextResponse.json({ message: "id gerekli" }, { status: 400 });
  }

  const supabaseAdmin = getSupabaseAdminClient();
  const { data: existing, error: readErr } = await supabaseAdmin
    .from("products")
    .select("id, tenant_id")
    .eq("id", id)
    .maybeSingle();

  if (readErr) {
    return NextResponse.json({ message: "Kayıt okunamadı", detail: readErr.message }, { status: 500 });
  }
  if (!existing) {
    return NextResponse.json({ message: "Ürün bulunamadı" }, { status: 404 });
  }
  if (profile.role === "firma_admin" && profile.tenant_id && existing.tenant_id !== profile.tenant_id) {
    return NextResponse.json({ message: "Bu ürün farklı firmaya ait" }, { status: 403 });
  }

  const { error } = await supabaseAdmin.from("products").delete().eq("id", id);
  if (error) {
    return NextResponse.json({ message: "Silme başarısız", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ id });
}
