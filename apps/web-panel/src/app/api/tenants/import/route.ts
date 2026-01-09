import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

type RequestBody = {
  tenant: {
    code: string;
    name: string;
    active: boolean;
    logo_url?: string | null;
    sap_integration_active?: boolean | null;
    sap_api_url?: string | null;
    sap_api_key?: string | null;
    module_flags?: Partial<{
      module_skt: boolean;
      module_tasks: boolean;
      module_attendance: boolean;
      module_shifts: boolean;
      module_forms: boolean;
      module_malfunctions: boolean;
      module_transfers: boolean;
      module_performance: boolean;
      module_payroll: boolean;
    }>;
  };
  modules: Array<{
    module_code: string;
    is_enabled: boolean;
    enabled_by_email?: string | null;
  }>;
};

const MODULE_FLAG_KEYS = [
  "module_skt",
  "module_tasks",
  "module_attendance",
  "module_shifts",
  "module_forms",
  "module_malfunctions",
  "module_transfers",
  "module_performance",
  "module_payroll",
] as const;

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

  if (!body || !body.tenant || !Array.isArray(body.modules)) {
    return NextResponse.json({ message: "Geçersiz istek gövdesi" }, { status: 400 });
  }

  const tenantCode = body.tenant.code?.trim().toUpperCase();
  const tenantName = body.tenant.name?.trim();
  const tenantActive = Boolean(body.tenant.active);

  const logoUrl = body.tenant.logo_url?.trim() || null;
  const sapIntegrationActive = Boolean(body.tenant.sap_integration_active ?? false);
  const sapApiUrl = body.tenant.sap_api_url?.trim() || null;
  const sapApiKey = body.tenant.sap_api_key?.trim() || null;
  const moduleFlags = MODULE_FLAG_KEYS.reduce((acc, key) => {
    const value = body.tenant.module_flags?.[key];
    acc[key] = typeof value === "boolean" ? value : true;
    return acc;
  }, {} as Record<(typeof MODULE_FLAG_KEYS)[number], boolean>);

  if (!tenantCode || !tenantName) {
    return NextResponse.json({ message: "Firma kodu ve adı zorunludur" }, { status: 400 });
  }

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role")
    .eq("id", session.user.id)
    .maybeSingle<{ role: string | null }>();

  if (profileError || profile?.role !== "grand_admin") {
    return NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 });
  }

  const { data: existingTenant } = await supabaseAdmin
    .from("tenants")
    .select("id")
    .eq("code", tenantCode)
    .maybeSingle();

  if (existingTenant) {
    return NextResponse.json({ message: `${tenantCode} kodlu firma zaten kayıtlı` }, { status: 409 });
  }

  const moduleCodes = body.modules.map((module) => module.module_code?.trim().toLowerCase()).filter(Boolean);
  const uniqueModuleCodes = Array.from(new Set(moduleCodes));

  if (uniqueModuleCodes.length === 0) {
    return NextResponse.json({ message: "Modül listesi boş olamaz" }, { status: 400 });
  }

  const { data: validModules, error: modulesError } = await supabaseAdmin
    .from("modules")
    .select("code")
    .in("code", uniqueModuleCodes);

  if (modulesError) {
    console.error("modules fetch error", modulesError);
    return NextResponse.json({ message: "Modül bilgileri alınamadı" }, { status: 500 });
  }

  const moduleCodeMap = new Map<string, string>();
  validModules?.forEach((module) => {
    if (module.code) {
      moduleCodeMap.set(module.code.toLowerCase(), module.code);
    }
  });

  const missingModules = uniqueModuleCodes.filter((code) => !moduleCodeMap.has(code));

  if (missingModules.length > 0) {
    return NextResponse.json(
      { message: `Sistemde bulunmayan modül kodları: ${missingModules.join(", ")}` },
      { status: 400 },
    );
  }

  const tenantId = crypto.randomUUID();
  const { error: insertTenantError } = await supabaseAdmin.from("tenants").insert({
    id: tenantId,
    code: tenantCode,
    name: tenantName,
    active: tenantActive,
    logo_url: logoUrl,
    sap_integration_active: sapIntegrationActive,
    sap_api_url: sapApiUrl,
    sap_api_key: sapApiKey,
    module_skt: moduleFlags.module_skt,
    module_tasks: moduleFlags.module_tasks,
    module_attendance: moduleFlags.module_attendance,
    module_shifts: moduleFlags.module_shifts,
    module_forms: moduleFlags.module_forms,
    module_malfunctions: moduleFlags.module_malfunctions,
    module_transfers: moduleFlags.module_transfers,
    module_performance: moduleFlags.module_performance,
    module_payroll: moduleFlags.module_payroll,
  });

  if (insertTenantError) {
    console.error("tenant insert error", insertTenantError);
    return NextResponse.json({ message: "Firma kaydedilemedi" }, { status: 500 });
  }

  const modulePayload: Array<{
    tenant_id: string;
    module_code: string;
    is_enabled: boolean;
    enabled_at: string | null;
    enabled_by: string | null;
  }> = [];

  for (const code of uniqueModuleCodes) {
    const moduleDefinition = body.modules.find((module) => module.module_code?.trim().toLowerCase() === code);
    const isEnabled = moduleDefinition?.is_enabled ?? true;
    let enabledBy: string | null = null;

    if (isEnabled) {
      const email = moduleDefinition?.enabled_by_email?.trim();
      if (email) {
        const { data: userLookup, error: userError } = await supabase
          .from("users")
          .select("id")
          .ilike("email", email)
          .maybeSingle<{ id: string }>();

        if (userError) {
          console.error("enabled_by email lookup error", userError);
          return NextResponse.json({ message: "Yetki veren kullanıcı sorgulanamadı" }, { status: 500 });
        }

        if (!userLookup?.id) {
          return NextResponse.json(
            { message: `enabled_by_email bulunamadı: ${email}` },
            { status: 400 },
          );
        }

        enabledBy = userLookup.id;
      } else {
        enabledBy = session.user.id;
      }
    }

    modulePayload.push({
      tenant_id: tenantId,
      module_code: moduleCodeMap.get(code) ?? code,
      is_enabled: isEnabled,
      enabled_at: isEnabled ? new Date().toISOString() : null,
      enabled_by: enabledBy,
    });
  }

  const { error: moduleInsertError } = await supabaseAdmin
    .from("tenant_modules")
    .upsert(modulePayload, { onConflict: "tenant_id,module_code" });

  if (moduleInsertError) {
    console.error("tenant_modules insert error", moduleInsertError);
    await supabaseAdmin.from("tenants").delete().eq("id", tenantId);
    return NextResponse.json({ message: "Modüller kaydedilirken hata oluştu" }, { status: 500 });
  }

  return NextResponse.json({ tenantCode }, { status: 201 });
}
