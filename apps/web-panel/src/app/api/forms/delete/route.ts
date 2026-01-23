import { NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";

export async function POST(request: Request) {
  try {
    const supabase = await getSupabaseServerClient();
    const admin = getSupabaseAdminClient();
    const { data: userResp, error: userErr } = await supabase.auth.getUser();

    if (userErr || !userResp?.user) {
      return NextResponse.json({ message: "Yetkisiz" }, { status: 401 });
    }

    const { data: profile, error: profileErr } = await supabase
      .from("users")
      .select("role, tenant_id")
      .match({ id: userResp.user.id })
      .maybeSingle<{ role: string | null; tenant_id: string | null }>();

    if (profileErr || !profile?.role) {
      return NextResponse.json({ message: "Profil bulunamadı" }, { status: 403 });
    }

    const payload = await request.json().catch(() => null) as { formVersionId?: string } | null;
    if (!payload?.formVersionId) {
      return NextResponse.json({ message: "formVersionId zorunlu" }, { status: 400 });
    }

    // Formu ve tenantını doğrula
    const { data: formRow, error: formErr } = await supabase
      .from("v_store_scoring_published_forms")
      .select("form_version_id, tenant_id")
      .eq("form_version_id", payload.formVersionId)
      .maybeSingle<{ form_version_id: string; tenant_id: string | null }>();

    if (formErr || !formRow) {
      return NextResponse.json({ message: "Form bulunamadı" }, { status: 404 });
    }

    if (profile.role === "firma_admin" && profile.tenant_id && formRow.tenant_id !== profile.tenant_id) {
      return NextResponse.json({ message: "Bu formu silme yetkiniz yok" }, { status: 403 });
    }

    // Form versiyonunu sil. İlgili maddelerin cascade ile silindiği varsayılır.
    const { error: deleteErr } = await admin
      .from("store_scoring_form_versions")
      .delete()
      .eq("id", payload.formVersionId);

    if (deleteErr) {
      return NextResponse.json({ message: "Silme başarısız" }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (err) {
    console.error("/api/forms/delete error", err);
    return NextResponse.json({ message: "Beklenmeyen hata" }, { status: 500 });
  }
}
