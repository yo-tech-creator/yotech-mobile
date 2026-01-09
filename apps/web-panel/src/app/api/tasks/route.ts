import { NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SupabaseClient } from "@supabase/supabase-js";

const ALLOWED_CREATOR_ROLES = new Set(["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"]);

async function getProfile() {
  const supabase = (await getSupabaseServerClient()) as SupabaseClient<any>;
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    return { error: NextResponse.json({ message: "Yetkisiz" }, { status: 401 }) } as const;
  }

  const { data: profile, error } = await supabase
    .from("users")
    .select("id, role, tenant_id, branch_id")
    .eq("id", session.user.id)
    .maybeSingle();

  if (error || !profile) {
    return { error: NextResponse.json({ message: "Profil bulunamadı" }, { status: 403 }) } as const;
  }

  return { supabase, profile, userId: session.user.id } as const;
}

export async function GET(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;

  const { supabase, profile } = gate;
  const url = new URL(request.url);
  const scope = url.searchParams.get("scope") ?? "mine";

  let query = supabase
    .from("tasks")
    .select("id, title, description, status, priority, due_date, completed_at, completion_percentage, branch_id, created_by, created_at, parent_task_id, task_assignees(user_id)")
    .eq("tenant_id", profile.tenant_id)
    .order("created_at", { ascending: false });

  if (scope === "branch" && profile.branch_id) {
    query = query.eq("branch_id", profile.branch_id);
  }

  const { data, error } = await query;
  if (error) {
    return NextResponse.json({ message: "Görevler alınamadı", detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ tasks: data ?? [] });
}

export async function POST(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile, userId } = gate;

  if (!ALLOWED_CREATOR_ROLES.has(profile.role)) {
    return NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  if (!body || typeof body.title !== "string" || !body.title.trim()) {
    return NextResponse.json({ message: "Başlık zorunlu" }, { status: 400 });
  }

  const branchId = profile.branch_id;
  if (!branchId) {
    return NextResponse.json({ message: "Şube bilgisi bulunamadı" }, { status: 400 });
  }

  const taskPayload = {
    tenant_id: profile.tenant_id,
    branch_id: branchId,
    title: body.title.trim(),
    description: typeof body.description === "string" ? body.description : null,
    created_by: userId,
    priority: typeof body.priority === "string" ? body.priority : "orta",
    due_date: body.due_date ?? null,
    parent_task_id: typeof body.parent_task_id === "string" && body.parent_task_id.length > 0 ? body.parent_task_id : null,
  } as Record<string, unknown>;

  const { data: inserted, error: insertError } = await supabase.from("tasks").insert(taskPayload).select("id").maybeSingle();
  if (insertError || !inserted?.id) {
    return NextResponse.json({ message: "Görev oluşturulamadı" }, { status: 500 });
  }

  const assigneeIds: string[] = Array.isArray(body.assigneeIds)
    ? (body.assigneeIds as unknown[]).filter((x: unknown): x is string => typeof x === "string" && x.length > 0)
    : [];
  const uniqueAssignees = [...new Set(assigneeIds.length > 0 ? assigneeIds : [userId])];

  const assigneeRows = uniqueAssignees.map((uid) => ({ task_id: inserted.id, user_id: uid }));
  if (assigneeRows.length > 0) {
    await supabase.from("task_assignees").insert(assigneeRows);
  }

  return NextResponse.json({ id: inserted.id });
}

export async function PATCH(request: Request) {
  const gate = await getProfile();
  if ("error" in gate) return gate.error;
  const { supabase, profile, userId } = gate;

  const body = await request.json().catch(() => null);
  if (!body || typeof body.taskId !== "string") {
    return NextResponse.json({ message: "Geçersiz istek" }, { status: 400 });
  }

  const completion = body.completion_percentage;
  const hasCompletion = completion !== undefined;
  if (hasCompletion && (typeof completion !== "number" || Number.isNaN(completion) || completion < 0 || completion > 100)) {
    return NextResponse.json({ message: "İlerleme 0-100 aralığında olmalı" }, { status: 400 });
  }

  const { data: task, error: taskError } = await supabase
    .from("tasks")
    .select("id, branch_id, created_by, parent_task_id, task_assignees(user_id)")
    .eq("id", body.taskId)
    .eq("tenant_id", profile.tenant_id)
    .maybeSingle();

  if (taskError) {
    return NextResponse.json({ message: "Görev bulunamadı", detail: taskError.message }, { status: 500 });
  }
  if (!task) {
    return NextResponse.json({ message: "Görev bulunamadı" }, { status: 404 });
  }

  const isCreator = task.created_by === userId;
  const isAssignee = (task.task_assignees ?? []).some((a) => a.user_id === userId);
  const sameBranchManager = ALLOWED_CREATOR_ROLES.has(profile.role) && profile.branch_id === task.branch_id;

  if (!isCreator && !isAssignee && !sameBranchManager) {
    return NextResponse.json({ message: "Bu işlem için yetkiniz yok" }, { status: 403 });
  }

  const now = new Date().toISOString();
  const update: Record<string, unknown> = {};
  if (hasCompletion) {
    update.completion_percentage = Math.round(completion);
    update.completed_at = completion >= 100 ? now : null;
  }

  if (Object.keys(update).length === 0) {
    return NextResponse.json({ message: "Güncellenecek veri yok" }, { status: 400 });
  }

  const { error: updateError } = await supabase.from("tasks").update(update).eq("id", body.taskId);
  if (updateError) {
    return NextResponse.json({ message: "Görev güncellenemedi", detail: updateError.message }, { status: 500 });
  }

  // Eğer üst görev tamamlandıysa tüm alt görevleri tamamla
  if (hasCompletion && completion >= 100) {
    let queue: string[] = [body.taskId];
    while (queue.length > 0) {
      const { data: children, error: childErr } = await supabase.from("tasks").select("id").in("parent_task_id", queue);
      if (childErr || !children || children.length === 0) {
        queue = [];
        break;
      }
      const childIds = children.map((c) => c.id);
      await supabase
        .from("tasks")
        .update({ completion_percentage: 100, completed_at: now })
        .in("id", childIds);
      queue = childIds;
    }
  }

  // Alt görevler değiştiyse üst görevlerin ortalama tamamlanmasını güncelle
  let parentId: string | null = task.parent_task_id;
  while (parentId) {
    const { data: siblings, error: siblingsErr } = await supabase
      .from("tasks")
      .select("id, completion_percentage")
      .eq("parent_task_id", parentId);
    if (siblingsErr) break;
    if (!siblings || siblings.length === 0) break;

    const avg = siblings.reduce((acc, cur) => acc + (cur.completion_percentage ?? 0), 0) / siblings.length;
    const parentUpdate = {
      completion_percentage: Math.round(avg),
      completed_at: avg >= 100 ? now : null,
    } as Record<string, unknown>;
    await supabase.from("tasks").update(parentUpdate).eq("id", parentId);

    const { data: parentRow } = await supabase
      .from("tasks")
      .select("parent_task_id")
      .eq("id", parentId)
      .maybeSingle();
    parentId = parentRow?.parent_task_id ?? null;
  }

  return NextResponse.json({ ok: true });
}
