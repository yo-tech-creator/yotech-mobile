import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

type RegionInput = {
  region_code: string;
  region_name: string;
  is_active?: boolean;
};

type RequestBody = {
  tenantCode: string;
  regions: RegionInput[];
};

function toNullableTrimmed(value: string | null | undefined): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function toNullableUpper(value: string | null | undefined): string | null {
  const trimmed = toNullableTrimmed(value);
  return trimmed ? trimmed.toUpperCase() : null;
}

export async function POST(request: Request) {
  const supabase = await getSupabaseServerClient();
  const supabaseAdmin = SUPABASE_SERVICE_ROLE_KEY
    ? createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false } })
    : supabase;

  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    return NextResponse.json({ message: "Oturum bulunamadı" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as RequestBody | null;

  if (!body || typeof body.tenantCode !== "string" || !Array.isArray(body.regions)) {
    return NextResponse.json({ message: "Geçersiz istek gövdesi" }, { status: 400 });
  }

  const tenantCode = body.tenantCode.trim();

  if (!tenantCode) {
    return NextResponse.json({ message: "Tenant kodu zorunludur" }, { status: 400 });
  }

  if (body.regions.length === 0) {
    return NextResponse.json({ message: "En az bir bölge tanımı sağlanmalıdır" }, { status: 400 });
  }

  const normalisedRegions = body.regions.map((region) => {
    const regionCode = typeof region.region_code === "string" ? region.region_code.trim().toUpperCase() : "";
    const regionName = typeof region.region_name === "string" ? region.region_name.trim() : "";
    const isActive = typeof region.is_active === "boolean" ? region.is_active : true;

    return {
      region_code: regionCode,
      region_name: regionName,
      is_active: isActive,
    } satisfies RegionInput;
  });

  const invalidRegion = normalisedRegions.find((region) => !region.region_code || !region.region_name);
  if (invalidRegion) {
    return NextResponse.json({ message: "Bölge kayıtlarında zorunlu alanlar eksik" }, { status: 400 });
  }

  const regionCodes = normalisedRegions.map((region) => region.region_code);
  const uniqueRegionCodes = new Set(regionCodes);

  if (uniqueRegionCodes.size !== regionCodes.length) {
    return NextResponse.json({ message: "Aynı bölge kodu birden fazla kez gönderildi" }, { status: 400 });
  }

  const uuidRegex = /^[0-9a-fA-F-]{36}$/;
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

  const regionCodeList = Array.from(uniqueRegionCodes);

  const { data: existingRegions, error: existingRegionsError } = await supabaseAdmin
    .from("regions")
    .select("code")
    .eq("tenant_id", tenant.id)
    .in("code", regionCodeList);

  if (existingRegionsError) {
    console.error("regions fetch error", existingRegionsError);
    return NextResponse.json({ message: "Bölge bilgileri alınamadı" }, { status: 500 });
  }

  if (existingRegions && existingRegions.length > 0) {
    const duplicates = existingRegions.map((region) => region.code).filter(Boolean);
    return NextResponse.json(
      { message: `Sistemde kayıtlı olan bölge kodları: ${duplicates.join(", ")}` },
      { status: 409 },
    );
  }

  const regionPayload = normalisedRegions.map((region) => ({
    tenant_id: tenant.id,
    code: region.region_code,
    name: region.region_name,
    is_active: region.is_active,
  }));

  const { error: insertRegionsError } = await supabaseAdmin.from("regions").insert(regionPayload);

  if (insertRegionsError) {
    console.error("regions insert error", insertRegionsError);
    return NextResponse.json({ message: "Bölgeler kaydedilemedi" }, { status: 500 });
  }

  return NextResponse.json({ tenantCode, regionCount: regionPayload.length }, { status: 200 });
}
