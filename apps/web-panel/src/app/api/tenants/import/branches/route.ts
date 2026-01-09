import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

type BranchInput = {
  branch_code: string;
  branch_name: string;
  region_code?: string | null;
  city?: string | null;
  district?: string | null;
  address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  geofence_radius?: number | null;
  is_active: boolean;
};

type BranchModuleInput = {
  branch_code: string;
  module_code: string;
  is_enabled: boolean;
};

const MODULE_CODE_ALIASES: Record<string, string> = {
  shift_manager: "shift_management",
};

type RequestBody = {
  tenantCode: string;
  branches: BranchInput[];
  branchModules?: BranchModuleInput[];
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

  if (!body || typeof body.tenantCode !== "string" || !Array.isArray(body.branches)) {
    return NextResponse.json({ message: "Geçersiz istek gövdesi" }, { status: 400 });
  }

  const tenantCode = body.tenantCode.trim();

  if (!tenantCode) {
    return NextResponse.json({ message: "Tenant kodu zorunludur" }, { status: 400 });
  }

  if (body.branches.length === 0) {
    return NextResponse.json({ message: "En az bir şube tanımı sağlanmalıdır" }, { status: 400 });
  }

  const normalisedBranches = body.branches.map((branch) => {
    const branchCode = typeof branch.branch_code === "string" ? branch.branch_code.trim().toUpperCase() : "";
    const branchName = typeof branch.branch_name === "string" ? branch.branch_name.trim() : "";
    const isActive = typeof branch.is_active === "boolean" ? branch.is_active : true;

    return {
      branch_code: branchCode,
      branch_name: branchName,
      region_code: toNullableUpper(branch.region_code ?? null),
      city: toNullableTrimmed(branch.city ?? null),
      district: toNullableTrimmed(branch.district ?? null),
      address: toNullableTrimmed(branch.address ?? null),
      latitude:
        typeof branch.latitude === "number" && Number.isFinite(branch.latitude) ? branch.latitude : null,
      longitude:
        typeof branch.longitude === "number" && Number.isFinite(branch.longitude) ? branch.longitude : null,
      geofence_radius:
        typeof branch.geofence_radius === "number" && Number.isFinite(branch.geofence_radius)
          ? Math.round(branch.geofence_radius)
          : null,
      is_active: isActive,
    } satisfies BranchInput;
  });

  const invalidBranch = normalisedBranches.find(
    (branch) => !branch.branch_code || !branch.branch_name,
  );

  if (invalidBranch) {
    return NextResponse.json({ message: "Şube kayıtlarında zorunlu alanlar eksik" }, { status: 400 });
  }

  const branchCodes = normalisedBranches.map((branch) => branch.branch_code);
  const uniqueBranchCodes = new Set(branchCodes);

  if (uniqueBranchCodes.size !== branchCodes.length) {
    return NextResponse.json({ message: "Aynı şube kodu birden fazla kez gönderildi" }, { status: 400 });
  }

  if (normalisedBranches.some((branch) => branch.geofence_radius !== null && branch.geofence_radius <= 0)) {
    return NextResponse.json({ message: "geofence_radius 0'dan büyük olmalıdır" }, { status: 400 });
  }

  const rawBranchModules = Array.isArray(body.branchModules) ? body.branchModules : [];
  const normalisedBranchModules = rawBranchModules.map((module) => {
    const rawCode = typeof module.module_code === "string" ? module.module_code.trim().toLowerCase() : "";
    const aliasedCode = MODULE_CODE_ALIASES[rawCode] ?? rawCode;

    return {
      branch_code: typeof module.branch_code === "string" ? module.branch_code.trim().toUpperCase() : "",
      module_code: aliasedCode,
      is_enabled: typeof module.is_enabled === "boolean" ? module.is_enabled : true,
    } satisfies BranchModuleInput;
  });

  const invalidModule = normalisedBranchModules.find((module) => !module.branch_code || !module.module_code);

  if (invalidModule) {
    return NextResponse.json({ message: "BranchModules verilerinde zorunlu alanlar eksik" }, { status: 400 });
  }

  const unknownBranchReference = normalisedBranchModules.find(
    (module) => !uniqueBranchCodes.has(module.branch_code),
  );

  if (unknownBranchReference) {
    return NextResponse.json({ message: `${unknownBranchReference.branch_code} kodu Branches sekmesinde tanımlı değil` }, { status: 400 });
  }

  const moduleCodes = Array.from(new Set(normalisedBranchModules.map((module) => module.module_code)));

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role")
    .eq("id", session.user.id)
    .maybeSingle<{ role: string | null }>();

  if (profileError || profile?.role !== "grand_admin") {
    return NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 });
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

  const branchCodeList = Array.from(uniqueBranchCodes);

  const { data: existingBranches, error: existingBranchesError } = await supabaseAdmin
    .from("branches")
    .select("code")
    .eq("tenant_id", tenant.id)
    .in("code", branchCodeList);

  if (existingBranchesError) {
    console.error("branches fetch error", existingBranchesError);
    return NextResponse.json({ message: "Şube bilgileri alınamadı" }, { status: 500 });
  }

  if (existingBranches && existingBranches.length > 0) {
    const duplicates = existingBranches.map((branch) => branch.code).filter(Boolean);
    return NextResponse.json(
      { message: `Sistemde kayıtlı olan şube kodları: ${duplicates.join(", ")}` },
      { status: 409 },
    );
  }

  const regionCodes = Array.from(
    new Set(
      normalisedBranches
        .map((branch) => branch.region_code)
        .filter((code): code is string => !!code),
    ),
  );

  const regionMap = new Map<string, string>();

  if (regionCodes.length > 0) {
    const { data: regions, error: regionsError } = await supabaseAdmin
      .from("regions")
      .select("id, code")
      .eq("tenant_id", tenant.id)
      .in("code", regionCodes);

    if (regionsError) {
      console.error("regions fetch error", regionsError);
      return NextResponse.json({ message: "Bölge bilgileri alınamadı" }, { status: 500 });
    }

    regions?.forEach((region) => {
      if (region.code && region.id) {
        regionMap.set(region.code.toUpperCase(), region.id);
      }
    });

    const missingRegions = regionCodes.filter((code) => !regionMap.has(code.toUpperCase()));

    if (missingRegions.length > 0) {
      return NextResponse.json(
        { message: `Sistemde bulunmayan bölge kodları: ${missingRegions.join(", ")}` },
        { status: 400 },
      );
    }
  }

  const branchPayload = normalisedBranches.map((branch) => ({
    tenant_id: tenant.id,
    code: branch.branch_code,
    name: branch.branch_name,
    region_id: branch.region_code ? regionMap.get(branch.region_code.toUpperCase()) ?? null : null,
    city: branch.city ?? null,
    district: branch.district ?? null,
    address: branch.address ?? null,
    latitude: branch.latitude ?? null,
    longitude: branch.longitude ?? null,
    geofence_radius: branch.geofence_radius ?? null,
    active: branch.is_active,
  }));

  const { error: insertBranchesError } = await supabaseAdmin.from("branches").insert(branchPayload);

  if (insertBranchesError) {
    console.error("branches insert error", insertBranchesError);
    return NextResponse.json({ message: "Şubeler kaydedilemedi" }, { status: 500 });
  }

  let enabledModulesCount = 0;

  if (moduleCodes.length > 0) {
    const { data: modules, error: modulesError } = await supabaseAdmin
      .from("modules")
      .select("code")
      .in("code", moduleCodes);

    if (modulesError) {
      console.error("modules fetch error", modulesError);
      await supabaseAdmin
        .from("branches")
        .delete()
        .eq("tenant_id", tenant.id)
        .in("code", branchCodeList);
      return NextResponse.json({ message: "Modül bilgileri alınamadı" }, { status: 500 });
    }

    const moduleMap = new Map<string, string>();
    modules?.forEach((module) => {
      if (module.code) {
        moduleMap.set(module.code.toLowerCase(), module.code);
      }
    });

    const missingModules = moduleCodes.filter((code) => !moduleMap.has(code.toLowerCase()));

    if (missingModules.length > 0) {
      await supabaseAdmin
        .from("branches")
        .delete()
        .eq("tenant_id", tenant.id)
        .in("code", branchCodeList);
      return NextResponse.json(
        { message: `Sistemde bulunmayan modül kodları: ${missingModules.join(", ")}` },
        { status: 400 },
      );
    }

    const modulesToEnable = Array.from(
      new Set(
        normalisedBranchModules
          .filter((module) => module.is_enabled)
          .map((module) => module.module_code.toLowerCase()),
      ),
    );

    enabledModulesCount = modulesToEnable.length;

    if (modulesToEnable.length > 0) {
      const timestamp = new Date().toISOString();
      const modulePayload = modulesToEnable.map((code) => ({
        tenant_id: tenant.id,
        module_code: moduleMap.get(code) ?? code,
        is_enabled: true,
        enabled_at: timestamp,
        enabled_by: session.user.id,
      }));

      const { error: moduleUpsertError } = await supabaseAdmin
        .from("tenant_modules")
        .upsert(modulePayload, { onConflict: "tenant_id,module_code" });

      if (moduleUpsertError) {
        console.error("tenant_modules upsert error", moduleUpsertError);
        await supabaseAdmin
          .from("branches")
          .delete()
          .eq("tenant_id", tenant.id)
          .in("code", branchCodeList);
        return NextResponse.json({ message: "Modüller güncellenemedi" }, { status: 500 });
      }
    }
  }

  return NextResponse.json({ tenantCode, branchCount: branchPayload.length, enabledModules: enabledModulesCount }, { status: 201 });
}
