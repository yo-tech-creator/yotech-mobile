import type { Route } from "next";
import { redirect } from "next/navigation";
import { ModulePermissionsManager } from "@/components/modules/module-permissions-manager";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { TenantSummary } from "@/types/tenants";

export default async function ModulesPage() {
  const supabase = await getSupabaseServerClient();
  const { data: userResp, error: userErr } = await supabase.auth.getUser();

  if (userErr || !userResp?.user) {
    redirect("/login" as Route);
  }

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role, tenant_id")
    .match({ id: userResp.user.id })
    .maybeSingle<{ role: string | null; tenant_id: string | null }>();

  if (profileError || !profile?.role) {
    redirect("/login?error=profile" as Route);
  }

  if (profile.role !== "grand_admin") {
    return (
      <div>
        <header className="page-header">
          <h2>Modül İzinleri</h2>
          <p>Modül izinleri yalnızca grand admin kullanıcıları tarafından yönetilebilir.</p>
        </header>
        <div className="card">
          <p>Bu sayfaya erişim yetkiniz bulunmuyor.</p>
        </div>
      </div>
    );
  }

  const { data, error: tenantsError } = await supabase.rpc("get_all_tenants");

  if (tenantsError) {
    console.error("get_all_tenants hata", tenantsError);
    return (
      <div>
        <header className="page-header">
          <h2>Modül İzinleri</h2>
          <p>Modül izinleri yalnızca grand admin kullanıcıları tarafından yönetilebilir.</p>
        </header>
        <div className="card">
          <p>Firmalar yüklenirken sorun oluştu. Lütfen tekrar deneyin.</p>
        </div>
      </div>
    );
  }

  const tenants = ((data ?? []) as TenantSummary[]).filter((tenant) => tenant.is_active);

  if (tenants.length === 0) {
    return (
      <div>
        <header className="page-header">
          <h2>Modül İzinleri</h2>
          <p>Modül izinleri yalnızca grand admin kullanıcıları tarafından yönetilebilir.</p>
        </header>
        <div className="card">
          <p>Aktif firma bulunamadı.</p>
        </div>
      </div>
    );
  }

  const sortedTenants = [...tenants].sort((a, b) => a.name.localeCompare(b.name));

  return <ModulePermissionsManager tenants={sortedTenants} />;
}
