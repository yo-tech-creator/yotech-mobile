import Link from "next/link";
import type { Route } from "next";
import { redirect } from "next/navigation";
import { TenantDirectory } from "@/components/tenants/tenant-directory";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { TenantSummary } from "@/types/tenants";

export default async function TenantsPage() {
  const supabase = await getSupabaseServerClient();
  const { data: userResp, error: userErr } = await supabase.auth.getUser();

  if (userErr || !userResp?.user) {
    redirect("/login" as Route);
  }

  const { data: profile, error: profileError } = await supabase
    .from("users")
    .select("role")
    .match({ id: userResp.user.id })
    .maybeSingle<{ role: string | null }>();

  if (profileError || !profile?.role) {
    redirect("/login?error=profile" as Route);
  }

  if (profile.role !== "grand_admin") {
    return (
      <div>
        <header className="page-header">
          <h2>Firmalar</h2>
          <p>Firmaları görüntüleme ve yönetme yetkisi yalnızca grand admin kullanıcılarına açıktır.</p>
        </header>
        <div className="card">
          <p>Bu sayfaya erişim yetkiniz bulunmuyor.</p>
        </div>
      </div>
    );
  }

  const { data, error } = await supabase.rpc("get_all_tenants");

  if (error) {
    console.error("get_all_tenants hata", error);
    return (
      <div>
        <header className="page-header">
          <h2>Firmalar</h2>
          <p>Firmalar yüklenirken bir hata oluştu. Lütfen daha sonra tekrar deneyin.</p>
        </header>
        <div className="card">
          <p>Detaylar: {error.message}</p>
        </div>
      </div>
    );
  }

  const tenants = ((data ?? []) as TenantSummary[]).sort((a, b) => a.name.localeCompare(b.name));

  return (
    <>
      <header className="page-header page-header--with-action">
        <div className="page-header__body">
          <h2>Firmalar</h2>
          <p>Var olan firmaları görüntüleyin, yönetim aksiyonlarını başlatın ve yeni firmaları Excel şablonlarıyla ekleyin.</p>
        </div>
        <Link href="/tenants/import" className="button button--primary">
          Yeni Firma Ekle
        </Link>
      </header>

      {tenants.length === 0 ? (
        <div className="card">
          <h3>Henüz firma bulunamadı</h3>
          <p>Yeni bir firma oluşturduğunuzda listede görünecektir.</p>
        </div>
      ) : (
        <TenantDirectory tenants={tenants} />
      )}
    </>
  );
}
