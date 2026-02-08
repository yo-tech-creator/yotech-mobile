import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

const ALLOWED_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"]);

export async function GET() {
  const supabase = await getSupabaseServerClient();
  const { data: userResp, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userResp?.user) {
    return NextResponse.json({ message: "Yetkisiz" }, { status: 401 });
  }

  const { data: profile, error: profileErr } = await supabase
    .from("users")
    .select("id, tenant_id, role, branch_id")
    .eq("id", userResp.user.id)
    .maybeSingle();

  if (profileErr || !profile?.tenant_id || !ALLOWED_ROLES.has(profile.role ?? "")) {
    return NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 });
  }

  // Bölge müdürü için: sadece kendi bölgesindeki şubeleri getir
  if (profile.role === "bolge_muduru") {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
    }

    const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Kullanıcının yönettiği bölgeleri bul
    const { data: managedRegions, error: regErr } = await supabaseAdmin
      .from("regions")
      .select("id")
      .eq("manager_id", profile.id)
      .eq("tenant_id", profile.tenant_id);

    if (regErr) {
      return NextResponse.json({ message: "Bölgeler alınamadı", detail: regErr.message }, { status: 500 });
    }

    const regionIds = (managedRegions ?? []).map((r) => r.id);

    if (regionIds.length === 0) {
      // Bölge müdürünün yönettiği bölge yok, sadece kendi şubesini göster
      if (profile.branch_id) {
        const { data, error } = await supabaseAdmin
          .from("branches")
          .select("id, name")
          .eq("id", profile.branch_id)
          .eq("is_active", true);

        if (error) {
          return NextResponse.json({ message: "Şubeler alınamadı", detail: error.message }, { status: 500 });
        }

        return NextResponse.json({ branches: data ?? [] });
      }
      return NextResponse.json({ branches: [] });
    }

    // Bu bölgelerdeki şubeleri getir
    const { data, error } = await supabaseAdmin
      .from("branches")
      .select("id, name")
      .eq("tenant_id", profile.tenant_id)
      .in("region_id", regionIds)
      .eq("is_active", true)
      .order("name", { ascending: true });

    if (error) {
      return NextResponse.json({ message: "Şubeler alınamadı", detail: error.message }, { status: 500 });
    }

    return NextResponse.json({ branches: data ?? [] });
  }

  // Şube müdürü için: sadece kendi şubesini göster
  if (profile.role === "sube_muduru" && profile.branch_id) {
    const { data, error } = await supabase
      .from("branches")
      .select("id, name")
      .eq("id", profile.branch_id)
      .eq("is_active", true);

    if (error) {
      return NextResponse.json({ message: "Şubeler alınamadı", detail: error.message }, { status: 500 });
    }

    return NextResponse.json({ branches: data ?? [] });
  }

  // grand_admin ve firma_admin için: tüm şubeler
  const { data, error } = await supabase
    .from("branches")
    .select("id, name")
    .eq("tenant_id", profile.tenant_id)
    .eq("is_active", true)
    .order("name", { ascending: true });

  if (error) {
    return NextResponse.json({ message: "Şubeler alınamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ branches: data ?? [] });
}
