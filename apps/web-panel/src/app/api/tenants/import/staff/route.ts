import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { randomUUID } from "crypto";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

const uuidRegex = /^[0-9a-fA-F-]{36}$/;

const ROLE_PRIORITY = ["firma_admin", "bolge_muduru", "sube_muduru", "personel"] as const;

function mapRoleToPosition(role: string): string | null {
  if (role === "sube_muduru") return "Mağaza Sorumlusu";
  if (role === "firma_admin") return "Firma Yöneticisi";
  if (role === "bolge_muduru") return "Bölge Müdürü";
  if (role === "personel") return "Mağaza Personeli";
  return null;
}

type PersonnelInput = {
  sicil_no: string;
  first_name: string;
  last_name: string;
  email: string | null;
  phone: string | null;
  branch_code: string | null;
  is_active: boolean;
};

type RoleAssignmentInput = {
  sicil_no: string;
  role: string;
  scope_type: "tenant" | "branch" | "region";
  scope_code: string;
};

type RequestBody = {
  tenantCode: string;
  personnel: PersonnelInput[];
  roleAssignments?: RoleAssignmentInput[];
};

function pickRole(assignments: RoleAssignmentInput[]): string {
  // Choose the highest priority role among assignments; default personel
  const found = ROLE_PRIORITY.find((role) => assignments.some((a) => a.role === role));
  return found ?? "personel";
}

function generatePasswordFromName(firstName: string, fallback: string): string {
  const base = firstName.trim().toLowerCase() || fallback.trim().toLowerCase() || "user";
  return `${base}1234`;
}

export async function POST(request: Request) {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const supabaseAdmin: SupabaseClient<Database> = SUPABASE_SERVICE_ROLE_KEY
    ? createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false } })
    : supabase;

  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    return NextResponse.json({ message: "Oturum bulunamadı" }, { status: 401 });
  }

  const body = (await request.json().catch(() => null)) as RequestBody | null;

  if (!body || typeof body.tenantCode !== "string" || !Array.isArray(body.personnel)) {
    return NextResponse.json({ message: "Geçersiz istek gövdesi" }, { status: 400 });
  }

  if (body.personnel.length === 0) {
    return NextResponse.json({ message: "En az bir personel satırı olmalı" }, { status: 400 });
  }

  const tenantCode = body.tenantCode.trim();

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role")
    .eq("id", session.user.id)
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

  const rawRoleAssignments = Array.isArray(body.roleAssignments) ? body.roleAssignments : [];
  const roleAssignments: RoleAssignmentInput[] = [];

  rawRoleAssignments.forEach((assignment) => {
    const sicil = typeof assignment.sicil_no === "string" ? assignment.sicil_no.trim().toUpperCase() : "";
    const role = typeof assignment.role === "string" ? assignment.role.trim().toLowerCase() : "";
    const scopeType = typeof assignment.scope_type === "string" ? assignment.scope_type.trim().toLowerCase() : "";
    const scopeCode = typeof assignment.scope_code === "string" ? assignment.scope_code.trim().toUpperCase() : "";

    if (!sicil || !role || !scopeType || !scopeCode) {
      return;
    }

    if (scopeType !== "tenant" && scopeType !== "branch" && scopeType !== "region") {
      return;
    }

    roleAssignments.push({ sicil_no: sicil, role, scope_type: scopeType as "tenant" | "branch" | "region", scope_code: scopeCode });
  });

  const branchCodes = Array.from(
    new Set([
      ...body.personnel
        .map((p) => (typeof p.branch_code === "string" ? p.branch_code.trim().toUpperCase() : ""))
        .filter((code) => !!code),
      ...roleAssignments.filter((a) => a.scope_type === "branch").map((a) => a.scope_code),
    ]),
  );

  const branchMap = new Map<string, string>();

  if (branchCodes.length > 0) {
    const { data: branches, error: branchesError } = (await supabaseAdmin
      .from("branches")
      .select("id, code")
      .eq("tenant_id", tenant.id)
      .in("code", branchCodes)) as { data: { id: string; code: string | null }[] | null; error: any };

    if (branchesError) {
      console.error("branches fetch error", branchesError);
      return NextResponse.json({ message: "Şube bilgileri alınamadı" }, { status: 500 });
    }

    branches?.forEach((branch) => {
      if (branch.code && branch.id) {
        branchMap.set(branch.code.toUpperCase(), branch.id);
      }
    });

    const missingBranches = branchCodes.filter((code) => !branchMap.has(code.toUpperCase()));

    if (missingBranches.length > 0) {
      return NextResponse.json({ message: `Sistemde bulunmayan şube kodları: ${missingBranches.join(", ")}` }, { status: 400 });
    }
  }

  const regionCodes = Array.from(new Set(roleAssignments.filter((a) => a.scope_type === "region").map((a) => a.scope_code)));
  const regionMap = new Map<string, string>();

  if (regionCodes.length > 0) {
    const { data: regions, error: regionsError } = (await supabaseAdmin
      .from("regions")
      .select("id, code")
      .eq("tenant_id", tenant.id)
      .in("code", regionCodes)) as { data: { id: string; code: string | null }[] | null; error: any };

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
      return NextResponse.json({ message: `Sistemde bulunmayan bölge kodları: ${missingRegions.join(", ")}` }, { status: 400 });
    }
  }

  const sicilList = body.personnel.map((p) => (typeof p.sicil_no === "string" ? p.sicil_no.trim().toUpperCase() : ""));
  const uniqueSicil = new Set(sicilList);

  if (uniqueSicil.size !== sicilList.length) {
    return NextResponse.json({ message: "Aynı sicil_no birden fazla kez gönderildi" }, { status: 400 });
  }

  const emailList = body.personnel
    .map((p) => (typeof p.email === "string" ? p.email.trim().toLowerCase() : ""))
    .filter((e) => !!e);
  const uniqueEmails = new Set(emailList);

  if (uniqueEmails.size !== emailList.length) {
    return NextResponse.json({ message: "Aynı e-posta birden fazla kez gönderildi" }, { status: 400 });
  }

  const { data: existingUsers, error: existingUsersError } = (await supabaseAdmin
    .from("users")
    .select("employee_code")
    .eq("tenant_id", tenant.id)
    .in("employee_code", sicilList)) as { data: { employee_code: string | null }[] | null; error: any };

  if (existingUsersError) {
    console.error("users fetch error", existingUsersError);
    return NextResponse.json({ message: "Personel bilgileri alınamadı" }, { status: 500 });
  }

  if (existingUsers && existingUsers.length > 0) {
    const duplicates = existingUsers.map((u) => u.employee_code).filter(Boolean);
    return NextResponse.json({ message: `Sistemde kayıtlı olan sicil_no değerleri: ${duplicates.join(", ")}` }, { status: 409 });
  }

  if (emailList.length > 0) {
    const { data: existingEmails, error: existingEmailsError } = (await supabaseAdmin
      .from("users")
      .select("email, employee_code")
      .in("email", emailList)) as { data: { email: string | null; employee_code: string | null }[] | null; error: any };

    if (existingEmailsError) {
      console.error("email fetch error", existingEmailsError);
      return NextResponse.json({ message: "E-posta kontrolü yapılamadı" }, { status: 500 });
    }

    if (existingEmails && existingEmails.length > 0) {
      const duplicates = existingEmails.map((u) => u.email).filter(Boolean);
      return NextResponse.json({ message: `Sistemde kayıtlı olan e-posta adresleri: ${duplicates.join(", ")}` }, { status: 409 });
    }
  }

  const rolesBySicil = new Map<string, RoleAssignmentInput[]>();

  roleAssignments.forEach((assignment) => {
    const current = rolesBySicil.get(assignment.sicil_no) ?? [];
    current.push(assignment);
    rolesBySicil.set(assignment.sicil_no, current);
  });

  for (const [sicil, assignments] of rolesBySicil.entries()) {
    const branchScoped = assignments.filter((a) => a.scope_type === "branch" && a.scope_code);
    const missingBranch = branchScoped.find((a) => !branchMap.has(a.scope_code));
    if (missingBranch) {
      return NextResponse.json({ message: `${sicil} için tanımlanan şube kodu bulunamadı: ${missingBranch.scope_code}` }, { status: 400 });
    }

    const regionScoped = assignments.filter((a) => a.scope_type === "region" && a.scope_code);
    const missingRegion = regionScoped.find((a) => !regionMap.has(a.scope_code));
    if (missingRegion) {
      return NextResponse.json({ message: `${sicil} için tanımlanan bölge kodu bulunamadı: ${missingRegion.scope_code}` }, { status: 400 });
    }
  }

  const passwordCache = new Map<string, string>();

  for (const person of body.personnel) {
    const sicil = person.sicil_no.trim().toUpperCase();
    const branchCode = typeof person.branch_code === "string" ? person.branch_code.trim().toUpperCase() : "";
    const branchId = branchCode ? branchMap.get(branchCode) ?? null : null;
    const assignedRoles = rolesBySicil.get(sicil) ?? [];
    const finalRole = pickRole(assignedRoles);

    const password = generatePasswordFromName(person.first_name, sicil);
    passwordCache.set(sicil, password);

    const { data: rpcResult, error: rpcError } = await supabaseAdmin.rpc("add_personel", {
      p_employee_code: sicil,
      p_password: password,
      p_tenant_id: tenant.id,
    }) as unknown as { data: { success: boolean; user_id?: string; email?: string; error?: string } | null; error: any };

    if (rpcError || !rpcResult || !rpcResult.success || !rpcResult.user_id) {
      console.error("add_personel rpc error", rpcError ?? rpcResult?.error);
      return NextResponse.json({ message: `${sicil} oluşturulamadı` }, { status: 500 });
    }

    const userId = rpcResult.user_id;
    const finalEmail = person.email?.trim() || rpcResult.email || null;
    const position = mapRoleToPosition(finalRole);

    const { error: updateUserError } = await supabaseAdmin
      .from("users")
      .update({
        first_name: person.first_name.trim(),
        last_name: person.last_name.trim(),
        email: finalEmail,
        phone: person.phone?.trim() || null,
        branch_id: branchId,
        role: finalRole,
        position,
        active: person.is_active,
      })
      .eq("id", userId);

    if (updateUserError) {
      console.error("users update error", updateUserError);
      return NextResponse.json({ message: `${sicil} bilgileri güncellenemedi` }, { status: 500 });
    }

    if (finalEmail) {
      if (!SUPABASE_SERVICE_ROLE_KEY) {
        console.error("auth email update skipped: missing service role key");
        return NextResponse.json({ message: `${sicil} e-posta güncellenemedi` }, { status: 500 });
      }

      const { error: updateAuthError } = await supabaseAdmin.auth.admin.updateUserById(userId, {
        email: finalEmail,
        email_confirm: true,
      });

      if (updateAuthError) {
        console.error("auth email update error", updateAuthError);
        return NextResponse.json({ message: `${sicil} e-posta güncellenemedi` }, { status: 500 });
      }
    }

    const regionManagerAssignments = assignedRoles.filter(
      (assignment) => assignment.scope_type === "region" && assignment.role === "bolge_muduru",
    );

    for (const regionAssignment of regionManagerAssignments) {
      const regionId = regionMap.get(regionAssignment.scope_code);
      if (!regionId) {
        continue;
      }

      const regionUpdate: Database["public"]["Tables"]["regions"]["Update"] = { manager_id: userId };

      const { error: updateRegionError } = await supabaseAdmin.from("regions").update(regionUpdate).eq("id", regionId);

      if (updateRegionError) {
        console.error("region manager update error", updateRegionError);
        return NextResponse.json(
          { message: `${sicil} için bölge yöneticisi atanamadı (${regionAssignment.scope_code})` },
          { status: 500 },
        );
      }
    }
  }

  return NextResponse.json({ tenantCode, personnelCount: body.personnel.length }, { status: 201 });
}
