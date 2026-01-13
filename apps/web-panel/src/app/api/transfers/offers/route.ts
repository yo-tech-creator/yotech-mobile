import { NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { SupabaseClient } from "@supabase/supabase-js";

const ALLOWED_ROLES = new Set([
  "grand_admin",
  "firma_admin",
  "bolge_muduru",
  "sube_muduru",
]);

const RESERVED_STATUSES = new Set(["accepted", "delivered"]);

type Profile = {
  id: string;
  role: string | null;
  tenant_id: string | null;
  branch_id: string | null;
};

type OfferWithNotice = {
  id: string;
  notice_id: string;
  tenant_id: string;
  branch_id: string;
  branch_name?: string | null;
  offered_by: string;
  quantity: number;
  status: string;
  decision_by?: string | null;
  decision_at?: string | null;
  message?: string | null;
  notice?: {
    id: string;
    tenant_id: string;
    branch_id: string;
    created_by: string;
    quantity: number;
  } | null;
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

async function recalcNoticeStatus(
  supabase: SupabaseClient<any>,
  noticeId: string,
  tenantId: string,
) {
  const { data: notice, error } = await supabase
    .from("depot_notices")
    .select("id, quantity, offers:depot_notice_offers(status, quantity)")
    .eq("id", noticeId)
    .eq("tenant_id", tenantId)
    .maybeSingle();

  if (error || !notice) return;

  const offers = (notice.offers ?? []) as { status: string; quantity: number }[];
  const reserved = offers.reduce((sum, offer) => {
    return RESERVED_STATUSES.has(offer.status) ? sum + (offer.quantity ?? 0) : sum;
  }, 0);

  const nextStatus = reserved >= notice.quantity ? "fulfilled" : reserved > 0 ? "in_transfer" : "open";

  await supabase
    .from("depot_notices")
    .update({ status: nextStatus })
    .eq("id", noticeId)
    .eq("tenant_id", tenantId);
}

export async function POST(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile, userId } = gate;

  if (!profile.branch_id) {
    return NextResponse.json({ message: "Şube bilgisi bulunamadı" }, { status: 400 });
  }

  const body = await request.json().catch(() => null);
  const noticeId = typeof body?.notice_id === "string" ? body.notice_id : null;
  const quantity = Number(body?.quantity);
  const message = typeof body?.message === "string" && body.message.trim() ? body.message.trim() : null;

  if (!noticeId || !Number.isFinite(quantity) || quantity <= 0) {
    return NextResponse.json({ message: "İlan ve miktar zorunlu" }, { status: 400 });
  }

  const { data: notice, error: noticeErr } = await supabase
    .from("depot_notices")
    .select("id, tenant_id")
    .eq("id", noticeId)
    .maybeSingle();

  if (noticeErr) {
    return NextResponse.json({ message: "İlan okunamadı", detail: noticeErr.message }, { status: 500 });
  }

  if (!notice || notice.tenant_id !== profile.tenant_id) {
    return NextResponse.json({ message: "İlan bulunamadı" }, { status: 404 });
  }

  const { error } = await supabase.from("depot_notice_offers").insert({
    notice_id: noticeId,
    tenant_id: profile.tenant_id,
    branch_id: profile.branch_id,
    offered_by: userId,
    quantity: Math.round(quantity),
    message,
  });

  if (error) {
    return NextResponse.json({ message: "Talep oluşturulamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}

export async function PATCH(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile, userId } = gate;

  const body = await request.json().catch(() => null);
  const action = typeof body?.action === "string" ? body.action : null;
  const offerId = typeof body?.offer_id === "string" ? body.offer_id : null;
  const quantity = Number(body?.quantity);
  const message = typeof body?.message === "string" && body.message.trim() ? body.message.trim() : null;

  if (!action || !offerId) {
    return NextResponse.json({ message: "İşlem bilgisi eksik" }, { status: 400 });
  }

  const offerResp = await supabase
    .from("depot_notice_offers")
    .select(
      "id, notice_id, tenant_id, branch_id, branch_name, offered_by, quantity, status, decision_by, decision_at, message, notice:depot_notices(id, tenant_id, branch_id, created_by, quantity)"
    )
    .eq("id", offerId)
    .maybeSingle();

  const offer = offerResp.data as OfferWithNotice | null;
  const offerErr = offerResp.error;

  if (offerErr) {
    return NextResponse.json({ message: "Talep okunamadı", detail: offerErr.message }, { status: 500 });
  }

  if (!offer || offer.notice?.tenant_id !== profile.tenant_id) {
    return NextResponse.json({ message: "Talep bulunamadı" }, { status: 404 });
  }

  const noticeId = offer.notice_id as string;
  const tenantId = profile.tenant_id as string;

  if (action === "accept" || action === "reject") {
    if (offer.notice?.created_by !== userId) {
      return NextResponse.json({ message: "Sadece ilan sahibi yanıt verebilir" }, { status: 403 });
    }

    const nextStatus = action === "accept" ? "accepted" : "rejected";
    const { error } = await supabase
      .from("depot_notice_offers")
      .update({ status: nextStatus, decision_by: userId, decision_at: new Date().toISOString() })
      .eq("id", offerId)
      .eq("tenant_id", tenantId);

    if (error) {
      return NextResponse.json({ message: "Talep güncellenemedi", detail: error.message }, { status: 500 });
    }

    if (nextStatus === "accepted") {
      await recalcNoticeStatus(supabase, noticeId, tenantId);
    }

    return NextResponse.json({ ok: true });
  }

  if (action === "cancel") {
    if (offer.offered_by !== userId) {
      return NextResponse.json({ message: "Sadece kendi talebinizi iptal edebilirsiniz" }, { status: 403 });
    }
    const { error } = await supabase
      .from("depot_notice_offers")
      .update({ status: "cancelled", decision_by: userId, decision_at: new Date().toISOString() })
      .eq("id", offerId)
      .eq("tenant_id", tenantId);

    if (error) {
      return NextResponse.json({ message: "Talep iptal edilemedi", detail: error.message }, { status: 500 });
    }

    await recalcNoticeStatus(supabase, noticeId, tenantId);
    return NextResponse.json({ ok: true });
  }

  if (action === "deliver") {
    if (offer.offered_by !== userId) {
      return NextResponse.json({ message: "Sadece kendi talebinizi güncelleyebilirsiniz" }, { status: 403 });
    }

    const { error } = await supabase
      .from("depot_notice_offers")
      .update({ status: "delivered" })
      .eq("id", offerId)
      .eq("tenant_id", tenantId);

    if (error) {
      return NextResponse.json({ message: "Teslim bilgisi kaydedilemedi", detail: error.message }, { status: 500 });
    }

    await recalcNoticeStatus(supabase, noticeId, tenantId);
    return NextResponse.json({ ok: true });
  }

  if (action === "update") {
    if (offer.offered_by !== userId) {
      return NextResponse.json({ message: "Sadece kendi talebinizi düzenleyebilirsiniz" }, { status: 403 });
    }

    const update: Record<string, unknown> = {};
    if (Number.isFinite(quantity) && quantity > 0) {
      update.quantity = Math.round(quantity);
    }
    if (message !== null) {
      update.message = message;
    }

    if (!Object.keys(update).length) {
      return NextResponse.json({ message: "Güncellenecek alan yok" }, { status: 400 });
    }

    const { error } = await supabase
      .from("depot_notice_offers")
      .update(update)
      .eq("id", offerId)
      .eq("tenant_id", tenantId);

    if (error) {
      return NextResponse.json({ message: "Talep güncellenemedi", detail: error.message }, { status: 500 });
    }

    return NextResponse.json({ ok: true });
  }

  return NextResponse.json({ message: "Bilinmeyen işlem" }, { status: 400 });
}
