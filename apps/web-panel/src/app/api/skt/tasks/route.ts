import { NextResponse } from "next/server";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";

const ALLOWED_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"]);

type Profile = {
  id: string;
  role: string | null;
  tenant_id: string | null;
  branch_id: string | null;
};

async function getProfile() {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<any>;
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

  return { supabase, profile: profile as Profile, userId } as const;
}

export async function POST(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile, userId } = gate;

  if (!profile.branch_id) {
    return NextResponse.json({ message: "Şube bilgisi bulunamadı" }, { status: 400 });
  }

  const body = await request.json().catch(() => null);
  const recordIds = Array.isArray(body?.recordIds) ? (body.recordIds as string[]) : [];
  const assigneeId = typeof body?.assigneeId === "string" ? (body.assigneeId as string).trim() : "";
  const dueDate = typeof body?.dueDate === "string" && body.dueDate.length > 0 ? body.dueDate : null;

  if (!recordIds.length) {
    return NextResponse.json({ message: "Kayıt listesi gerekli" }, { status: 400 });
  }
  if (!assigneeId) {
    return NextResponse.json({ message: "Personel seçimi gerekli" }, { status: 400 });
  }

  const { data: records, error: recordsErr } = await supabase
    .from("skt_records")
    .select("id, expiry_date, products(name, barcode)")
    .in("id", recordIds)
    .eq("tenant_id", profile.tenant_id)
    .eq("branch_id", profile.branch_id);

  if (recordsErr) {
    return NextResponse.json({ message: "SKT kayıtları alınamadı", detail: recordsErr.message }, { status: 500 });
  }

  if (!records || records.length === 0) {
    return NextResponse.json({ message: "Kayıt bulunamadı" }, { status: 404 });
  }

  const title = `SKT kontrolü (${records.length} ürün)`;
  const lines = records.map((r) => {
    const dateLabel = r.expiry_date ? new Date(r.expiry_date as string).toISOString().slice(0, 10) : "-";
    const productName = (r as any).products?.name ?? "İsimsiz ürün";
    const barcode = (r as any).products?.barcode ?? "-";
    return `- ${productName} (${barcode}) · SKT ${dateLabel}`;
  });
  const description = lines.join("\n");

  const { data: inserted, error: insertErr } = await supabase
    .from("tasks")
    .insert({
      tenant_id: profile.tenant_id,
      branch_id: profile.branch_id,
      title,
      description,
      created_by: userId,
      priority: "orta",
      due_date: dueDate,
      parent_task_id: null,
      status: null,
    })
    .select("id")
    .maybeSingle();

  if (insertErr || !inserted?.id) {
    return NextResponse.json({ message: "Görev oluşturulamadı", detail: insertErr?.message }, { status: 500 });
  }

  const { error: assignErr } = await supabase.from("task_assignees").insert({ task_id: inserted.id, user_id: assigneeId });
  if (assignErr) {
    return NextResponse.json({ message: "Görev ataması yapılamadı", detail: assignErr.message }, { status: 500 });
  }

  return NextResponse.json({ taskId: inserted.id });
}
