import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

async function requireGrandAdmin() {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const { data: userResp, error: userErr } = await supabase.auth.getUser();

  if (userErr || !userResp?.user) {
    return { error: NextResponse.json({ message: "Yetkisiz" }, { status: 401 }) } as const;
  }

  const { data: profile } = await supabase
    .from("users")
    .select("role")
    .eq("id", userResp.user.id)
    .maybeSingle<{ role: string | null }>();

  if (profile?.role !== "grand_admin") {
    return { error: NextResponse.json({ message: "Bu işlem için grand_admin olmalısınız" }, { status: 403 }) } as const;
  }

  return { supabase } as const;
}

export async function GET() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  const gate = await requireGrandAdmin();
  if ("error" in gate) return gate.error;

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const [tenantsRes, branchesRes, usersRes] = await Promise.all([
    supabaseAdmin.from("tenants").select("id, name, code, is_active"),
    supabaseAdmin.from("branches").select("id, tenant_id, is_active"),
    supabaseAdmin.from("users").select("id, tenant_id, branch_id, is_active"),
  ]);

  if (tenantsRes.error || branchesRes.error || usersRes.error) {
    return NextResponse.json({ message: "Genel bakış verisi alınamadı" }, { status: 500 });
  }

  const tenants = tenantsRes.data ?? [];
  const branches = branchesRes.data ?? [];
  const users = usersRes.data ?? [];

  const branchCountByTenant = new Map<string, number>();
  branches.forEach((b) => branchCountByTenant.set(b.tenant_id, (branchCountByTenant.get(b.tenant_id) ?? 0) + 1));

  const userCountByTenant = new Map<string, number>();
  users.forEach((u) => {
    if (u.tenant_id) {
      userCountByTenant.set(u.tenant_id, (userCountByTenant.get(u.tenant_id) ?? 0) + 1);
    }
  });

  const tenantsSummary = tenants.map((t) => ({
    id: t.id,
    name: t.name,
    code: t.code,
    is_active: t.is_active,
    branchCount: branchCountByTenant.get(t.id) ?? 0,
    userCount: userCountByTenant.get(t.id) ?? 0,
  }));

  tenantsSummary.sort((a, b) => b.userCount - a.userCount);

  const stats = {
    totalTenants: tenants.length,
    activeTenants: tenants.filter((t) => t.is_active).length,
    totalBranches: branches.length,
    activeBranches: branches.filter((b) => b.is_active ?? false).length,
    totalUsers: users.length,
    activeUsers: users.filter((u) => u.is_active ?? false).length,
  };

  return NextResponse.json({
    stats,
    tenants: tenantsSummary,
    updatedAt: new Date().toISOString(),
  });
}
