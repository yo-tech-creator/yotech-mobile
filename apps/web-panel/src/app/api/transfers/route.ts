import { NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { SupabaseClient } from "@supabase/supabase-js";

const ALLOWED_ROLES = new Set([
  "grand_admin",
  "firma_admin",
  "bolge_muduru",
  "sube_muduru",
]);

type Profile = {
  id: string;
  role: string | null;
  tenant_id: string | null;
  branch_id: string | null;
};

type NoticeInsert = {
  product_id: string;
  quantity: number;
  unit: string;
  type: "surplus" | "shortage";
  note?: string | null;
  expires_at?: string | null;
};

type NoticeUpdate = {
  id: string;
  product_id?: string | null;
  quantity?: number | null;
  unit?: string | null;
  type?: "surplus" | "shortage" | null;
  note?: string | null;
  expires_at?: string | null;
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

  const { supabase, profile, userId } = gate;

  const { data, error } = await supabase
    .from("depot_notices")
    .select(
      "id, tenant_id, branch_id, branch_name, created_by, product_name, quantity, unit, type, status, note, expires_at, created_at, updated_at, offers:depot_notice_offers(id, notice_id, tenant_id, branch_id, branch_name, offered_by, quantity, status, decision_by, decision_at, message, created_at, updated_at)"
    )
    .eq("tenant_id", profile.tenant_id)
    .order("created_at", { ascending: false });

  if (error) {
    return NextResponse.json({ message: "Sevk kayıtları alınamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ notices: data ?? [], viewer: { id: userId, branchId: profile.branch_id } });
}

export async function POST(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile, userId } = gate;

  if (!profile.branch_id) {
    return NextResponse.json({ message: "Şube bilgisi bulunamadı" }, { status: 400 });
  }

  const body = (await request.json().catch(() => null)) as Partial<NoticeInsert> | null;
  const productId = typeof body?.product_id === "string" ? body.product_id.trim() : "";
  const quantityRaw = body?.quantity;
  const quantity = Number(quantityRaw);
  const unitRaw = typeof body?.unit === "string" && body.unit.trim() ? body.unit.trim() : null;
  const type = body?.type;
  const note = typeof body?.note === "string" && body.note.trim() ? body.note.trim() : null;
  const expiresAt = typeof body?.expires_at === "string" && body.expires_at ? body.expires_at : null;

  if (!productId || !Number.isFinite(quantity) || quantity <= 0) {
    return NextResponse.json({ message: "Ürün ve miktar zorunlu" }, { status: 400 });
  }

  if (type !== "surplus" && type !== "shortage") {
    return NextResponse.json({ message: "Geçersiz ilan tipi" }, { status: 400 });
  }

  let expiresIso: string | null = null;
  if (expiresAt) {
    const dt = new Date(expiresAt);
    if (Number.isNaN(dt.getTime())) {
      return NextResponse.json({ message: "Geçersiz tarih" }, { status: 400 });
    }
    expiresIso = dt.toISOString();
  }

  const { data: product, error: productErr } = await supabase
    .from("products")
    .select("id, name, unit, tenant_id")
    .eq("id", productId)
    .eq("tenant_id", profile.tenant_id)
    .maybeSingle();

  if (productErr) {
    return NextResponse.json({ message: "Ürün okunamadı", detail: productErr.message }, { status: 500 });
  }
  if (!product) {
    return NextResponse.json({ message: "Ürün bulunamadı" }, { status: 404 });
  }

  const finalUnit = unitRaw || product.unit || "adet";

  const payload = {
    tenant_id: profile.tenant_id,
    branch_id: profile.branch_id,
    created_by: userId,
    product_name: product.name,
    quantity: Math.round(quantity),
    unit: finalUnit,
    type,
    status: "open",
    note,
    expires_at: expiresIso,
  } as const;

  const { error } = await supabase.from("depot_notices").insert(payload);
  if (error) {
    return NextResponse.json({ message: "İlan oluşturulamadı", detail: error.message }, { status: 500 });
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
    return NextResponse.json({ message: "Silinecek ilan yok" }, { status: 400 });
  }

  const { error } = await supabase
    .from("depot_notices")
    .delete()
    .in("id", ids)
    .eq("tenant_id", profile.tenant_id);

  if (error) {
    return NextResponse.json({ message: "İlanlar silinemedi", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}

export async function PATCH(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile, userId } = gate;

  const body = (await request.json().catch(() => null)) as Partial<NoticeUpdate> | null;
  const id = typeof body?.id === "string" ? body.id : null;
  if (!id) {
    return NextResponse.json({ message: "Kayıt id gerekli" }, { status: 400 });
  }

  const { data: existing, error: existingErr } = await supabase
    .from("depot_notices")
    .select("id, tenant_id, branch_id, created_by, product_name, quantity, unit, type, note, expires_at")
    .eq("id", id)
    .maybeSingle();

  if (existingErr) {
    return NextResponse.json({ message: "Kayıt okunamadı", detail: existingErr.message }, { status: 500 });
  }
  if (!existing || existing.tenant_id !== profile.tenant_id) {
    return NextResponse.json({ message: "Kayıt bulunamadı" }, { status: 404 });
  }
  if (existing.created_by !== userId && profile.role !== "grand_admin" && profile.role !== "firma_admin" && profile.role !== "bolge_muduru") {
    return NextResponse.json({ message: "Sadece kendi ilanınızı düzenleyebilirsiniz" }, { status: 403 });
  }

  const quantity = Number.isFinite(body?.quantity) ? Number(body?.quantity) : null;
  const unit = typeof body?.unit === "string" && body.unit.trim() ? body.unit.trim() : null;
  const type = body?.type === "surplus" || body?.type === "shortage" ? body.type : null;
  const note = body?.note === undefined ? undefined : (typeof body.note === "string" && body.note.trim() ? body.note.trim() : null);
  const expiresAtRaw = typeof body?.expires_at === "string" ? body.expires_at : null;
  const productId = typeof body?.product_id === "string" && body.product_id.trim() ? body.product_id.trim() : null;

  let expiresIso: string | null | undefined = undefined;
  if (expiresAtRaw !== null) {
    if (!expiresAtRaw) {
      expiresIso = null;
    } else {
      const dt = new Date(expiresAtRaw);
      if (Number.isNaN(dt.getTime())) {
        return NextResponse.json({ message: "Geçersiz tarih" }, { status: 400 });
      }
      expiresIso = dt.toISOString();
    }
  }

  let productName: string | undefined;
  let finalUnit = unit;
  if (productId) {
    const { data: product, error: productErr } = await supabase
      .from("products")
      .select("id, name, unit, tenant_id")
      .eq("id", productId)
      .eq("tenant_id", profile.tenant_id)
      .maybeSingle();

    if (productErr) {
      return NextResponse.json({ message: "Ürün okunamadı", detail: productErr.message }, { status: 500 });
    }
    if (!product) {
      return NextResponse.json({ message: "Ürün bulunamadı" }, { status: 404 });
    }
    productName = product.name;
    finalUnit = finalUnit ?? product.unit ?? existing.unit ?? "adet";
  }

  const update: Record<string, unknown> = {};
  if (productName !== undefined) update.product_name = productName;
  if (quantity !== null) {
    if (quantity <= 0) {
      return NextResponse.json({ message: "Miktar 0'dan büyük olmalı" }, { status: 400 });
    }
    update.quantity = Math.round(quantity);
  }
  if (finalUnit) update.unit = finalUnit;
  if (type) update.type = type;
  if (note !== undefined) update.note = note;
  if (expiresIso !== undefined) update.expires_at = expiresIso;

  if (Object.keys(update).length === 0) {
    return NextResponse.json({ message: "Güncellenecek alan yok" }, { status: 400 });
  }

  const { error } = await supabase
    .from("depot_notices")
    .update(update)
    .eq("id", id)
    .eq("tenant_id", profile.tenant_id)
    .maybeSingle();

  if (error) {
    return NextResponse.json({ message: "Kayıt güncellenemedi", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
