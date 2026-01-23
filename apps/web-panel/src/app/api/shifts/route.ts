import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

const ALLOWED_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru", "personel"]);

type Profile = { id: string; role: string | null; tenant_id: string; branch_id: string | null };
type ShiftData = { assignments: Record<string, string>; leaveRemaining?: Record<string, number>; patterns?: any[] };
type ShiftRow = {
  id?: string;
  tenant_id: string;
  branch_id: string;
  week_start_date: string;
  week_end_date: string;
  shift_data: ShiftData;
  created_by: string;
};

 async function getProfile() {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<Database>;
  const { data: userResp, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userResp?.user) {
    return { error: NextResponse.json({ message: "Yetkisiz" }, { status: 401 }) } as const;
  }

  const userId = userResp.user.id;
  const { data: profile, error: profileErr } = await supabase
    .from("users")
    .select("id, role, tenant_id, branch_id")
    .eq("id", userId)
    .maybeSingle();

  if (profileErr || !profile?.tenant_id || !ALLOWED_ROLES.has(profile.role ?? "")) {
    return { error: NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 }) } as const;
  }

  return { profile: profile as Profile, userId } as const;
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
  const { profile } = gate;

  const envErr = ensureEnv();
  if (envErr) return envErr;

  const supabaseAdmin = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!) as SupabaseClient<any>;

  let query = supabaseAdmin
    .from("shifts")
    .select("id, tenant_id, branch_id, week_start_date, week_end_date, shift_data, created_by, created_at, updated_at")
    .eq("tenant_id", profile.tenant_id)
    .order("week_start_date", { ascending: false });

  if (profile.branch_id) {
    query = query.eq("branch_id", profile.branch_id);
  }

  const { data, error } = await query;
  if (error) {
    return NextResponse.json({ message: "Vardiyalar alınamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ weeks: data || [] });
}

export async function POST(req: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { profile, userId } = gate;

  if (!profile.branch_id) {
    return NextResponse.json({ message: "Şube bilgisi bulunamadı" }, { status: 400 });
  }

  const envErr = ensureEnv();
  if (envErr) return envErr;

  const body = (await req.json()) as { weekStartIso?: string; weekEndIso?: string; assignments?: Record<string, string>; leaveRemaining?: Record<string, number>; patterns?: any[] };
  const { weekStartIso, weekEndIso, assignments, leaveRemaining, patterns } = body;

  if (!weekStartIso || !weekEndIso || !assignments) {
    return NextResponse.json({ message: "Eksik veri" }, { status: 400 });
  }

  const payload: ShiftRow = {
    tenant_id: profile.tenant_id,
    branch_id: profile.branch_id,
    week_start_date: weekStartIso,
    week_end_date: weekEndIso,
    shift_data: { assignments, leaveRemaining: leaveRemaining || {}, patterns: patterns || [] },
    created_by: userId,
  };

  const supabaseAdmin = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!) as SupabaseClient<any>;
  const { data, error } = await supabaseAdmin
    .from("shifts")
    .upsert([payload as any], { onConflict: "tenant_id,branch_id,week_start_date" })
    .select("id, week_start_date, week_end_date, shift_data")
    .single();

  if (error) {
    return NextResponse.json({ message: "Vardiya kaydedilemedi", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ week: data });
}
