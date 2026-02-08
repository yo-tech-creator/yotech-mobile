import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

const uuidRegex = /^[0-9a-fA-F-]{36}$/;

type ProductInput = {
  barcode: string;
  name: string;
  brand?: string | null;
  category?: string | null;
  supplier?: string | null;
  unit?: string | null;
  price?: number | null;
  alt_barcodes?: string[] | string | null;
  is_active?: boolean | null;
};

type RequestBody = {
  tenantCode: string;
  products: ProductInput[];
};

const MAX_PRODUCTS = 5000;
const INSERT_BATCH_SIZE = 500;

export async function POST(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error("missing supabase env", { hasUrl: !!SUPABASE_URL, hasServiceKey: !!SUPABASE_SERVICE_ROLE_KEY });
    return NextResponse.json({ message: "Sunucu yapılandırması eksik (Supabase erişimi)" }, { status: 500 });
  }

  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const supabaseAdmin: SupabaseClient<Database> = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false },
  });

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return NextResponse.json({ message: "Oturum doğrulanamadı" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as RequestBody | null;

  if (!body || typeof body.tenantCode !== "string" || !Array.isArray(body.products)) {
    return NextResponse.json({ message: "Geçersiz istek gövdesi" }, { status: 400 });
  }

  if (body.products.length === 0) {
    return NextResponse.json({ message: "En az bir ürün satırı olmalı" }, { status: 400 });
  }

  if (body.products.length > MAX_PRODUCTS) {
    return NextResponse.json({ message: `Maksimum ${MAX_PRODUCTS} ürün aynı anda yüklenebilir` }, { status: 400 });
  }

  const tenantCode = body.tenantCode.trim();

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role")
    .eq("id", user.id)
    .maybeSingle<{ role: string | null }>();

  if (profileError || profile?.role !== "grand_admin") {
    return NextResponse.json({ message: "Bu işlem için grand_admin olmalısınız" }, { status: 403 });
  }

  let tenant: { id: string } | null = null;

  const { data: tenantByCode, error: tenantByCodeError } = await supabaseAdmin
    .from("tenants")
    .select("id")
    .ilike("code", tenantCode)
    .maybeSingle<{ id: string }>();

  if (tenantByCodeError) {
    console.error("tenant fetch error", tenantByCodeError);
    return NextResponse.json({ message: "Firma bilgisi alınamadı" }, { status: 500 });
  }

  if (tenantByCode) {
    tenant = tenantByCode;
  } else if (uuidRegex.test(tenantCode)) {
    const { data: tenantById, error: tenantByIdError } = await supabaseAdmin
      .from("tenants")
      .select("id")
      .eq("id", tenantCode)
      .maybeSingle<{ id: string }>();

    if (tenantByIdError) {
      console.error("tenant fetch by id error", tenantByIdError);
      return NextResponse.json({ message: "Firma bilgisi alınamadı" }, { status: 500 });
    }

    tenant = tenantById ?? null;
  }

  if (!tenant) {
    return NextResponse.json({ message: `${tenantCode} kodlu firma bulunamadı` }, { status: 404 });
  }

  // Mevcut barkod/alt barkodları önceden al ve çakışanları yükleme sırasında atla
  let existingCodes = new Set<string>();
  try {
    const existingResult = (await supabaseAdmin.from("products").select("barcode, alt_barcodes").eq("tenant_id", tenant.id)) as {
      data: { barcode: string | null; alt_barcodes: string[] | null }[] | null;
      error: any;
    };

    if (existingResult.error) {
      console.error("products fetch error", existingResult.error);
      return NextResponse.json({ message: "Ürün kontrolü yapılamadı" }, { status: 500 });
    }

    existingResult.data?.forEach((row) => {
      if (row.barcode) existingCodes.add(row.barcode.trim());
      row.alt_barcodes?.forEach((code) => {
        const trimmed = typeof code === "string" ? code.trim() : "";
        if (trimmed) existingCodes.add(trimmed);
      });
    });
  } catch (error) {
    console.error("products fetch network error", error);
    return NextResponse.json({ message: "Ürün kontrolü sırasında Supabase bağlantısı sağlanamadı" }, { status: 502 });
  }

  const payload: Database["public"]["Tables"]["products"]["Insert"][] = [];
  const seenCodes = new Set<string>();
  const allAltCodes = new Set<string>();
  const skipped: string[] = [];

  for (let index = 0; index < body.products.length; index += 1) {
    const raw = body.products[index];
    const rowNumber = index + 2;

    if (!raw || typeof raw.barcode !== "string" || typeof raw.name !== "string") {
      return NextResponse.json({ message: `${rowNumber}. satırda barcode ve name zorunlu` }, { status: 400 });
    }

    const barcode = raw.barcode.trim();
    const name = raw.name.trim();

    if (!barcode || !name) {
      return NextResponse.json({ message: `${rowNumber}. satırda barcode ve name boş olamaz` }, { status: 400 });
    }

    if (existingCodes.has(barcode)) {
      skipped.push(`${barcode} (sistemde mevcut)`);
      continue;
    }
    if (seenCodes.has(barcode)) {
      skipped.push(`${barcode} (yükleme listesinde tekrar)`);
      continue;
    }
    seenCodes.add(barcode);

    const altCodes: string[] = Array.isArray(raw.alt_barcodes)
      ? raw.alt_barcodes
      : typeof raw.alt_barcodes === "string"
        ? raw.alt_barcodes.split(",")
        : [];

    const cleanedAlt = altCodes
      .map((c) => (typeof c === "string" ? c.trim() : ""))
      .filter((c) => !!c);

    if (cleanedAlt.length > 10) {
      return NextResponse.json({ message: `${barcode} alt barkod sayısı 10'dan fazla olamaz` }, { status: 400 });
    }

    const altSet = new Set<string>();
    for (const code of cleanedAlt) {
      if (code === barcode) {
        skipped.push(`${barcode} (alt barkod ana barkod ile aynı)`);
        altSet.clear();
        break;
      }
      if (existingCodes.has(code)) {
        skipped.push(`${barcode} (${code} sistemde mevcut)`);
        altSet.clear();
        break;
      }
      if (seenCodes.has(code) || allAltCodes.has(code) || altSet.has(code)) {
        skipped.push(`${barcode} (${code} çakışıyor)`);
        altSet.clear();
        break;
      }
      altSet.add(code);
      allAltCodes.add(code);
    }

    if (altSet.size === 0 && cleanedAlt.length > 0) {
      // Alt barkod çakışmasından ötürü atlandı
      continue;
    }

    const priceValue = raw.price === undefined || raw.price === null ? null : Number(raw.price);
    if (priceValue !== null && Number.isNaN(priceValue)) {
      return NextResponse.json({ message: `${barcode} fiyat değeri numerik olmalı` }, { status: 400 });
    }

    payload.push({
      tenant_id: tenant.id,
      barcode,
      name,
      brand: raw.brand?.trim() || null,
      category: raw.category?.trim() || null,
      supplier: raw.supplier?.trim() || null,
      unit: (raw.unit?.trim() || "adet") || null,
      price: priceValue,
      is_active: raw.is_active ?? true,
      alt_barcodes: cleanedAlt.length > 0 ? cleanedAlt : null,
    });
  }

  for (let start = 0; start < payload.length; start += INSERT_BATCH_SIZE) {
    const chunk = payload.slice(start, start + INSERT_BATCH_SIZE);

    try {
      const { error: insertError } = await supabaseAdmin
        .from("products")
        .upsert(chunk, { onConflict: "tenant_id,barcode", ignoreDuplicates: true });

      if (insertError) {
        // 23505 unique violation: yine de devam et, çünkü ignoreDuplicates bazen PostgREST sürümüne göre yüzeysel kalabiliyor
        if (insertError.code === "23505") {
          console.warn("products insert duplicate skipped", insertError, { chunkStart: start, chunkSize: chunk.length });
          continue;
        }
        console.error("products insert error", insertError, { chunkStart: start, chunkSize: chunk.length });
        return NextResponse.json({ message: "Ürünler eklenemedi" }, { status: 500 });
      }
    } catch (error) {
      console.error("products insert network error", error, { chunkStart: start, chunkSize: chunk.length });
      return NextResponse.json({ message: "Ürünler eklenemedi (Supabase bağlantısı sağlanamadı)" }, { status: 502 });
    }
  }

  return NextResponse.json({ tenantCode, productCount: payload.length, skipped }, { status: 201 });
}
