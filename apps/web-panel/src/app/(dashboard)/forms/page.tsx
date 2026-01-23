import Link from "next/link";
import { redirect } from "next/navigation";
import type { Route } from "next";
import { FormPublisher, type AllowedRole } from "@/components/forms/form-publisher";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";

type TenantRow = { id: string; name: string; code: string | null };

export default async function FormsPage() {
  const supabase = await getSupabaseServerClient();
  const supabaseAdmin = getSupabaseAdminClient();
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

  const role = profile.role as AllowedRole | string;

  let tenants: TenantRow[] = [];
  let initialTenantId: string | null = profile.tenant_id;

  if (role === "grand_admin") {
    const { data, error } = await supabaseAdmin.from("tenants").select("id, name, code").order("name");
    if (!error && data) {
      tenants = data as TenantRow[];
      if (!initialTenantId && tenants.length > 0) {
        initialTenantId = tenants[0].id;
      }
    }
  } else if (role === "firma_admin" && profile.tenant_id) {
    const { data } = await supabase
      .from("tenants")
      .select("id, name, code")
      .eq("id", profile.tenant_id)
      .maybeSingle<TenantRow>();
    if (data) {
      tenants = [data];
    }
  } else if (profile.tenant_id) {
    const { data } = await supabase
      .from("tenants")
      .select("id, name, code")
      .eq("id", profile.tenant_id)
      .maybeSingle<TenantRow>();
    if (data) {
      tenants = [data];
    }
  }

  return (
    <div className="page">
      <header className="page-header page-header--with-action">
        <div className="page-header__body">
          <h2>Formlar</h2>
          <p>
            Excel şablonu indirip doldurun, ardından yeni formu yayınlayın. Grand admin tüm firmalar için, firma admini kendi
            firması için, bölge/şube müdürü ise kendi firmasında form oluşturabilir.
          </p>
        </div>
        <div className="button-row" style={{ display: "flex", gap: 12 }}>
          <Link
            className="button button--primary"
            style={{ boxShadow: "0 14px 28px -12px rgba(99, 102, 241, 0.75)", letterSpacing: 0.25 }}
            href="/forms/published"
          >
            Yayınlanmış formları görüntüle
          </Link>
        </div>
      </header>

      <FormPublisher role={role as AllowedRole} tenants={tenants} initialTenantId={initialTenantId} />
    </div>
  );
}
