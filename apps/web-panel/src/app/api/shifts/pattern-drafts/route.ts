import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

const ALLOWED_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"]);

async function getProfile() {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const { data: userResp, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userResp?.user) {
    return { error: NextResponse.json({ message: "Yetkisiz" }, { status: 401 }) } as const;
  }

  const userId = userResp.user.id;
  const { data: profile, error: profileErr } = await supabase
    .from("users")
    .select("id, role, tenant_id")
    .eq("id", userId)
    .maybeSingle();

  if (profileErr || !profile?.tenant_id || !ALLOWED_ROLES.has(profile.role ?? "")) {
    return { error: NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 }) } as const;
  }

  return { profile, userId } as const;
}

function ensureEnv() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }
  return null;
}

export async function GET() {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { profile, userId } = gate;

  const envErr = ensureEnv();
  if (envErr) return envErr;

  const supabaseAdmin = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!) as SupabaseClient<any>;
  const { data, error } = await supabaseAdmin
    .from("shift_pattern_drafts")
    .select("patterns")
    .eq("user_id", userId)
    .eq("tenant_id", profile.tenant_id)
    .maybeSingle();

  if (error && error.code !== "PGRST116") {
    return NextResponse.json({ message: "Şablonlar alınamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ patterns: (data as any)?.patterns || [] });
}

export async function POST(req: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { profile, userId } = gate;

  const envErr = ensureEnv();
  if (envErr) return envErr;

  const body = (await req.json()) as { patterns?: any[] };
  const patterns = Array.isArray(body.patterns) ? body.patterns : [];

  const supabaseAdmin = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!) as SupabaseClient<any>;
  const { error } = await supabaseAdmin
    .from("shift_pattern_drafts")
    .upsert(
      [
        {
          user_id: userId,
          tenant_id: profile.tenant_id,
          patterns,
        },
      ],
      { onConflict: "user_id,tenant_id" }
    );

  if (error) {
    return NextResponse.json({ message: "Şablonlar kaydedilemedi", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
