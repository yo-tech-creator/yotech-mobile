import Link from "next/link";
import { redirect } from "next/navigation";
import type { Route } from "next";
import { CardInlineActions, CardListShell, SoftBadge, cardStyles } from "@/components/ui/card-list";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";

type TenantRow = { id: string; name: string; code: string | null };
type Section = { items?: Array<Record<string, unknown>> };
type PublishedFormRow = {
  form_id: string;
  form_version_id: string;
  tenant_id: string | null;
  code: string;
  title: string;
  description: string | null;
  version: number;
  sections: Section[];
  published_at: string | null;
  visible_roles?: string[] | null;
};

export default async function PublishedFormsPage() {
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

  const role = profile.role;

  let tenants: TenantRow[] = [];
  let initialTenantId: string | null = profile.tenant_id;

  // Kullanıcı RLS'e takılırsa da tenant isimleri gelsin diye admin ile oku
  if (role === "grand_admin") {
    const { data } = await supabaseAdmin.from("tenants").select("id, name, code").order("name");
    if (data) {
      tenants = data as TenantRow[];
      if (!initialTenantId && tenants.length > 0) initialTenantId = tenants[0].id;
    }
  } else if (profile.tenant_id) {
    const { data } = await supabaseAdmin
      .from("tenants")
      .select("id, name, code")
      .eq("id", profile.tenant_id)
      .maybeSingle<TenantRow>();
    if (data) tenants = [data];
  }

  const tenantLookup = new Map<string, { name: string; code: string | null }>();
  tenants.forEach((t) => tenantLookup.set(t.id, { name: t.name, code: t.code }));

  const roleLabels: Record<string, string> = {
    grand_admin: "Grand Admin",
    firma_admin: "Firma Admini",
    bolge_muduru: "Bölge Müdürü",
    sube_muduru: "Şube Müdürü",
    personel: "Personel",
    authenticated: "Authenticated",
    anonymous: "Anonim",
  };

  const formatRoles = (roles?: string[] | null) => {
    if (!roles || roles.length === 0) return "Tüm roller";
    return roles.map((r) => roleLabels[r] ?? r).join(", ");
  };

  const tenantIdsToFetch = role === "grand_admin" ? tenants.map((t) => t.id) : profile.tenant_id ? [profile.tenant_id] : [];

  let publishedForms: PublishedFormRow[] = [];
  if (tenantIdsToFetch.length > 0) {
    const { data } = await supabase
      .from("v_store_scoring_published_forms")
      .select("form_id, form_version_id, tenant_id, code, title, description, version, published_at, sections, visible_roles")
      .in("tenant_id", tenantIdsToFetch)
      .order("published_at", { ascending: false });
    if (data) publishedForms = data as PublishedFormRow[];
  }

  const getTenantLabel = (tenantId?: string | null) => {
    if (!tenantId) return "Tüm firmalar";
    const t = tenantLookup.get(tenantId);
    if (t) return `${t.name}${t.code ? ` (${t.code})` : ""}`;
    return "Bilinmeyen şube";
  };

  const cards = publishedForms.map((form) => {
    const itemCount = form.sections.reduce<number>((sum, section) => {
      const items = section.items ?? [];
      return sum + items.length;
    }, 0);

    return (
      <div
        key={`${form.form_id}-${form.form_version_id}`}
        style={{
          ...cardStyles.row,
          gridTemplateColumns: "1.35fr auto",
          gap: "12px",
          alignItems: "flex-start",
          border: "1px solid rgba(0,0,0,0.08)",
          boxShadow: "0 14px 30px rgba(0,0,0,0.12)",
          background: "linear-gradient(135deg, rgba(255,255,255,0.9), rgba(248,250,252,0.92))",
          padding: "18px 20px",
        }}
      >
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
            <SoftBadge tone="success" label={`v${form.version}`} />
            <div style={{ fontWeight: 800, fontSize: 16 }}>{form.title}</div>
          </div>
          <div style={{ color: "var(--text-subtle)", fontSize: 13 }}>{form.description ?? "Açıklama yok"}</div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
            <SoftBadge tone="info" label={getTenantLabel(form.tenant_id)} />
            <SoftBadge tone="muted" label={`Kod: ${form.code}`} />
            <SoftBadge tone="muted" label={`Madde: ${itemCount}`} />
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 10 }}>
          <SoftBadge tone="muted" label={form.published_at ? new Date(form.published_at).toLocaleDateString("tr-TR") : "Yayın tarihi yok"} />
          <div style={{ fontSize: 12, color: "var(--text-subtle)", textAlign: "right", maxWidth: 260 }}>{formatRoles(form.visible_roles)}</div>
          <CardInlineActions>
            <Link
              href={`/forms/published/${form.form_version_id}`}
              style={{
                ...cardStyles.actionButton,
                textDecoration: "none",
                display: "inline-flex",
                alignItems: "center",
                justifyContent: "center",
                minWidth: 140,
                background: "rgba(59,130,246,0.14)",
                border: "1px solid rgba(59,130,246,0.38)",
                color: "#0f305a",
                boxShadow: "0 10px 20px rgba(59,130,246,0.18)",
              }}
            >
              Yükle & düzenle
            </Link>
          </CardInlineActions>
        </div>
      </div>
    );
  });

  return (
    <CardListShell
      title="Yayınlanmış Formlar"
      description="Geçmiş yayınlanan form sürümlerini şube bilgisiyle birlikte görüntüleyin."
      stats={[{ label: "Toplam", value: publishedForms.length }]}
      actions={<Link className="button" href="/forms">Form yönetimine dön</Link>}
    >
      {publishedForms.length === 0 ? (
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          <p className="muted">Yayınlanmış form bulunamadı.</p>
          <div className="muted" style={{ fontSize: 12 }}>
            Sorgu bağlamı: rol = {role}, tenant filter = {tenantIdsToFetch.join(",") || "yok"}
          </div>
          <div className="muted" style={{ fontSize: 12 }}>
            Not: Supabase oturumu düzgün gelmiyorsa debug_effective_role boş dönebilir. Uygulama isteğiyle açıp tekrar deneyin.
          </div>
        </div>
      ) : (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(420px, 1fr))",
            gap: 16,
            maxWidth: 1220,
            width: "100%",
            margin: "0 auto",
          }}
        >
          {cards}
        </div>
      )}
    </CardListShell>
  );
}
