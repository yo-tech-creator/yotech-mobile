import Link from "next/link";
import { redirect } from "next/navigation";
import type { Route } from "next";
import { FormPublisher, type AllowedRole, type PublishedForm } from "@/components/forms/form-publisher";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";

type TenantRow = { id: string; name: string; code: string | null };

type Props = {
  params: Promise<{ versionId: string }>;
};

export default async function EditPublishedFormPage({ params }: Props) {
  const resolvedParams = await params;
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

  const tenantIdsToFetch = role === "grand_admin" ? tenants.map((t) => t.id) : profile.tenant_id ? [profile.tenant_id] : [];

  if (tenantIdsToFetch.length === 0) {
    redirect("/forms/published" as Route);
  }

  const { data: formData } = await supabase
    .from("v_store_scoring_published_forms")
    .select(
      "form_id, form_version_id, tenant_id, tenant, code, title, description, version, published_at, sections, visible_roles",
    )
    .eq("form_version_id", resolvedParams.versionId)
    .in("tenant_id", tenantIdsToFetch)
    .maybeSingle<PublishedForm>();

  if (!formData) {
    redirect("/forms/published" as Route);
  }

  return (
    <div className="page">
      <header className="page-header page-header--with-action">
        <div className="page-header__body">
          <h2>Yayınlanmış Formu Düzenle</h2>
          <p>Mevcut bir yayını yükleyip maddelerini güncelleyebilir, puanları değiştirebilir veya yeni maddeler ekleyebilirsiniz.</p>
        </div>
        <div className="button-row" style={{ display: "flex", gap: 12 }}>
          <Link className="button" href="/forms/published">
            Yayınlanmış formlara dön
          </Link>
        </div>
      </header>

      <FormPublisher
        role={role as AllowedRole}
        tenants={tenants}
        initialTenantId={initialTenantId}
        initialForm={formData}
      />
    </div>
  );
}
