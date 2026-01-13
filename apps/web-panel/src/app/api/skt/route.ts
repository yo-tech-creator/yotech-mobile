import { NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { SupabaseClient } from "@supabase/supabase-js";

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

export async function GET() {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;

  const { supabase, profile } = gate;

  let query = supabase
    .from("skt_records")
    .select(
      "id, tenant_id, branch_id, product_id, expiry_date, quantity, notes, product_status, status, alarm_days_before, alarm_date, alarm_sent, products(id, name, barcode, alt_barcodes, category, brand), branches(id, name)"
    )
    .eq("tenant_id", profile.tenant_id)
    .order("expiry_date", { ascending: true });

  if (profile.branch_id) {
    query = query.eq("branch_id", profile.branch_id);
  }

  const { data, error } = await query;

  if (error) {
    return NextResponse.json({ message: "SKT kayıtları alınamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ records: data ?? [] });
}

function computeStatus(expiryIso: string, alarmDays: number) {
  const expiry = new Date(expiryIso);
  const alarmDate = new Date(expiry);
  alarmDate.setDate(alarmDate.getDate() - (Number.isFinite(alarmDays) ? alarmDays : 7));
  const now = new Date();
  const days = Math.floor((expiry.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
  let status = "normal";
  if (days < 0) status = "gecmis";
  else if (days <= 7) status = "yaklasan";
  return { status, alarmIso: alarmDate.toISOString() };
}

export async function POST(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile, userId } = gate;

  if (!profile.branch_id) {
    return NextResponse.json({ message: "Şube bilgisi bulunamadı" }, { status: 400 });
  }

  const body = await request.json().catch(() => null);
  const productId = typeof body?.product_id === "string" ? body.product_id.trim() : "";
  const expiryDate = typeof body?.expiry_date === "string" ? body.expiry_date : null;
  const quantity = typeof body?.quantity === "number" ? body.quantity : null;
  const notes = typeof body?.notes === "string" ? body.notes.trim() : null;
  const productStatus = typeof body?.product_status === "string" ? body.product_status.trim() : null;
  const alarmDaysBefore = Number.isFinite(body?.alarm_days_before) ? Number(body.alarm_days_before) : 7;

  if (!productId || !expiryDate) {
    return NextResponse.json({ message: "Ürün ve SKT zorunlu" }, { status: 400 });
  }

  const expiry = new Date(expiryDate);
  if (Number.isNaN(expiry.getTime())) {
    return NextResponse.json({ message: "Geçersiz SKT" }, { status: 400 });
  }

  const { status, alarmIso } = computeStatus(expiry.toISOString(), alarmDaysBefore);

  const payload = {
    tenant_id: profile.tenant_id,
    branch_id: profile.branch_id,
    product_id: productId,
    user_id: userId,
    expiry_date: expiry.toISOString(),
    quantity,
    notes,
    product_status: productStatus,
    status,
    alarm_days_before: alarmDaysBefore,
    alarm_date: alarmIso,
    alarm_sent: false,
  };

  const { error } = await supabase.from("skt_records").insert(payload);
  if (error) {
    return NextResponse.json({ message: "Kayıt oluşturulamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}

export async function PATCH(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile } = gate;

  const body = await request.json().catch(() => null);
  const id = typeof body?.id === "string" ? body.id : null;
  if (!id) {
    return NextResponse.json({ message: "Kayıt id gerekli" }, { status: 400 });
  }

  const expiryDate = typeof body?.expiry_date === "string" ? body.expiry_date : null;
  const quantity = typeof body?.quantity === "number" ? body.quantity : null;
  const notes = typeof body?.notes === "string" ? body.notes.trim() : null;
  const productStatus = typeof body?.product_status === "string" ? body.product_status.trim() : null;
  const alarmDaysBefore = Number.isFinite(body?.alarm_days_before) ? Number(body.alarm_days_before) : 7;

  if (!expiryDate) {
    return NextResponse.json({ message: "SKT zorunlu" }, { status: 400 });
  }

  const expiry = new Date(expiryDate);
  if (Number.isNaN(expiry.getTime())) {
    return NextResponse.json({ message: "Geçersiz SKT" }, { status: 400 });
  }

  const { status, alarmIso } = computeStatus(expiry.toISOString(), alarmDaysBefore);

  const update: Record<string, unknown> = {
    expiry_date: expiry.toISOString(),
    quantity,
    notes,
    product_status: productStatus,
    status,
    alarm_days_before: alarmDaysBefore,
    alarm_date: alarmIso,
  };

  const { error } = await supabase
    .from("skt_records")
    .update(update)
    .eq("id", id)
    .eq("tenant_id", profile.tenant_id)
    .maybeSingle();

  if (error) {
    return NextResponse.json({ message: "Kayıt güncellenemedi", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}

export async function DELETE(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile } = gate;

  const body = await request.json().catch(() => null);
  const ids = Array.isArray(body?.ids) ? (body.ids as string[]) : [];
  if (!ids.length) {
    return NextResponse.json({ message: "Silinecek kayıt yok" }, { status: 400 });
  }

  const query = supabase.from("skt_records").delete().in("id", ids).eq("tenant_id", profile.tenant_id);
  const { error } = await query;

  if (error) {
    return NextResponse.json({ message: "Silme başarısız", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
