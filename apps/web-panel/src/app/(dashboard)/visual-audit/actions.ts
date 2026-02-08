"use server";

import { getSupabaseServerClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

export type ActionResult<T = void> = 
  | { success: true; data: T }
  | { success: false; error: string };

// Helper function to get Turkey timezone date string (YYYY-MM-DD)
function getTurkeyDateString(date?: Date): string {
  const d = date || new Date();
  return d.toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
}

// ============================================
// GÖREV İŞLEMLERİ
// ============================================

// Generate tasks for today from all active plans
export async function generateTasksForToday(): Promise<ActionResult<{ message: string }>> {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return { success: false, error: "Oturum bulunamadı" };
    }
    
    const { data, error } = await supabase.rpc("generate_visual_audit_tasks_for_today" as never);
    
    if (error) {
      console.error("generateTasksForToday error:", error);
      return { success: false, error: error.message };
    }
    
    const result = data as { success: boolean; error?: string; message?: string };
    if (!result.success) {
      return { success: false, error: result.error || "Görevler oluşturulamadı" };
    }
    
    revalidatePath("/visual-audit");
    return { success: true, data: { message: result.message || "Görevler oluşturuldu" } };
  } catch (err) {
    console.error("generateTasksForToday unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}

// Tekrar seçeneklerine göre tarihleri hesapla
function calculateRecurrenceDates(
  recurrence: "none" | "daily" | "weekly",
  selectedDays: number[],
  recurrenceWeeks: number
): string[] {
  const dates: string[] = [];
  const todayStr = getTurkeyDateString();
  
  if (recurrence === "none") {
    // Tek seferlik - sadece bugün
    dates.push(todayStr);
  } else if (recurrence === "daily") {
    // Her gün - belirtilen hafta sayısı kadar
    const totalDays = recurrenceWeeks * 7;
    for (let i = 0; i < totalDays; i++) {
      const date = new Date(todayStr + 'T12:00:00');
      date.setDate(date.getDate() + i);
      dates.push(getTurkeyDateString(date));
    }
  } else if (recurrence === "weekly" && selectedDays.length > 0) {
    // Haftanın belirli günleri
    const totalDays = recurrenceWeeks * 7;
    for (let i = 0; i < totalDays; i++) {
      const date = new Date(todayStr + 'T12:00:00');
      date.setDate(date.getDate() + i);
      const dayOfWeek = date.getDay(); // 0=Pazar, 1=Pazartesi, ...
      if (selectedDays.includes(dayOfWeek)) {
        dates.push(getTurkeyDateString(date));
      }
    }
  }
  
  return dates;
}

// Yeni görev oluştur
export async function createTask(formData: {
  branch_ids: string[];
  section_ids: string[];
  deadline_minutes: number;
  min_photos: number;
  note?: string;
  scheduled_hour?: number;
  recurrence?: "none" | "daily" | "weekly";
  selectedDays?: number[];
  recurrenceWeeks?: number;
}): Promise<ActionResult<{ tasks_created?: number; plan_id?: string; plan_name?: string } | { task_id: string; branch_name: string; section_name: string }[]>> {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return { success: false, error: "Oturum bulunamadı" };
    }
    
    const recurrence = formData.recurrence || "none";
    const selectedDays = formData.selectedDays || [];
    const recurrenceWeeks = formData.recurrenceWeeks || 2;
    const scheduledHour = formData.scheduled_hour ?? 9;
    
    // Tek seferlik değilse, plan oluştur
    if (recurrence !== "none") {
      const { data, error } = await supabase.rpc("create_visual_audit_task_with_plan" as never, {
        p_section_ids: formData.section_ids,
        p_branch_ids: formData.branch_ids.length > 0 ? formData.branch_ids : null,
        p_scheduled_hour: scheduledHour,
        p_deadline_minutes: formData.deadline_minutes,
        p_min_photos: formData.min_photos,
        p_notes: formData.note || null,
        p_recurrence: recurrence,
        p_recurrence_days: selectedDays.length > 0 ? selectedDays : null,
      } as never);
      
      if (error) {
        console.error("createTask with plan error:", error);
        return { success: false, error: error.message };
      }
      
      const result = data as { success: boolean; error?: string; plan_id?: string; plan_name?: string; tasks_created?: number };
      if (!result.success) {
        return { success: false, error: result.error || "Plan oluşturulamadı" };
      }
      
      revalidatePath("/visual-audit");
      revalidatePath("/visual-audit/plans");
      return { 
        success: true, 
        data: { 
          tasks_created: result.tasks_created, 
          plan_id: result.plan_id,
          plan_name: result.plan_name 
        } 
      };
    }
    
    // Tek seferlik görev - sadece bugün için
    const today = getTurkeyDateString();
    
    const { data, error } = await supabase.rpc("create_visual_audit_task" as never, {
      p_branch_ids: formData.branch_ids.length > 0 ? formData.branch_ids : null,
      p_section_ids: formData.section_ids,
      p_deadline_minutes: formData.deadline_minutes,
      p_min_photos: formData.min_photos,
      p_note: formData.note || null,
      p_scheduled_date: today,
      p_scheduled_hour: scheduledHour,
    } as never);
    
    if (error) {
      console.error("createTask error:", error);
      return { success: false, error: error.message };
    }
    
    const result = data as { success: boolean; error?: string; tasks?: { task_id: string; branch_name: string; section_name: string }[] };
    if (!result.success) {
      return { success: false, error: result.error || "Görev oluşturulamadı" };
    }
    
    revalidatePath("/visual-audit");
    return { success: true, data: result.tasks || [] };
  } catch (err) {
    console.error("createTask unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}

// Görevleri sil (çoklu)
export async function deleteTasks(taskIds: string[]): Promise<ActionResult<{ deleted: number }>> {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return { success: false, error: "Oturum bulunamadı" };
    }
    
    if (!taskIds || taskIds.length === 0) {
      return { success: false, error: "Silinecek görev seçilmedi" };
    }
    
    // RPC fonksiyonu ile sil (RLS bypass)
    const { data, error } = await supabase.rpc("delete_visual_audit_tasks" as never, {
      p_task_ids: taskIds,
    } as never);
    
    if (error) {
      console.error("deleteTasks error:", error);
      return { success: false, error: error.message };
    }
    
    const result = data as { success: boolean; error?: string; deleted?: number };
    if (!result.success) {
      return { success: false, error: result.error || "Görevler silinemedi" };
    }
    
    revalidatePath("/visual-audit");
    return { success: true, data: { deleted: result.deleted || taskIds.length } };
  } catch (err) {
    console.error("deleteTasks unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}

// Görevleri getir
// date: null = tüm görevler, "YYYY-MM-DD" = belirli tarih
export async function getTasks(date?: string | null, status?: string, branchId?: string) {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data, error } = await supabase.rpc("get_visual_audit_tasks" as never, {
      p_date: date === undefined ? null : date, // undefined veya null = tüm görevler
      p_status: status || null,
      p_branch_id: branchId || null,
    } as never);
    
    if (error) {
      console.error("getTasks error:", error);
      return [];
    }
    
    return data || [];
  } catch (err) {
    console.error("getTasks unexpected error:", err);
    return [];
  }
}

// İstatistikleri getir
// date: null = tüm görevler, "YYYY-MM-DD" = belirli tarih
export async function getStats(date?: string | null) {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data, error } = await supabase.rpc("get_visual_audit_stats" as never, {
      p_date: date === undefined ? null : date, // undefined veya null = tüm görevler
    } as never);
    
    if (error) {
      console.error("getStats error:", error);
      return { total_tasks: 0, pending_tasks: 0, completed_tasks: 0, overdue_tasks: 0 };
    }
    
    // RPC returns array, get first item
    const stats = Array.isArray(data) ? data[0] : data;
    return stats || { total_tasks: 0, pending_tasks: 0, completed_tasks: 0, overdue_tasks: 0 };
  } catch (err) {
    console.error("getStats unexpected error:", err);
    return { total_tasks: 0, pending_tasks: 0, completed_tasks: 0, overdue_tasks: 0 };
  }
}

// ============================================
// BÖLÜM İŞLEMLERİ
// ============================================

// Bölümleri getir (includeInactive: true ise tüm bölümleri getirir)
export async function getSections(includeInactive: boolean = false) {
  try {
    const supabase = await getSupabaseServerClient();
    
    let query = supabase
      .from("visual_audit_sections" as never)
      .select("id, name, color, is_active")
      .order("name");
    
    if (!includeInactive) {
      query = query.eq("is_active", true);
    }
    
    const { data, error } = await query;
    
    if (error) {
      console.error("getSections error:", error);
      return [];
    }
    
    return (data || []) as { id: string; name: string; color: string; is_active: boolean }[];
  } catch (err) {
    console.error("getSections unexpected error:", err);
    return [];
  }
}

// Bölüm ekle
export async function createSection(name: string, color: string): Promise<ActionResult<{ id: string }>> {
  try {
    const supabase = await getSupabaseServerClient();
    
    // Tenant ID al
    const { data: userData } = await supabase.auth.getUser();
    if (!userData.user) {
      return { success: false, error: "Oturum bulunamadı" };
    }
    
    const { data: userProfile } = await supabase
      .from("users" as never)
      .select("tenant_id")
      .eq("id", userData.user.id)
      .single();
    
    const tenantId = (userProfile as { tenant_id: string } | null)?.tenant_id;
    if (!tenantId) {
      return { success: false, error: "Tenant bulunamadı" };
    }
    
    const { data, error } = await supabase
      .from("visual_audit_sections" as never)
      .insert({ name, color, tenant_id: tenantId, is_active: true } as never)
      .select("id")
      .single();
    
    if (error) {
      console.error("createSection error:", error);
      return { success: false, error: error.message };
    }
    
    revalidatePath("/visual-audit");
    revalidatePath("/visual-audit/settings");
    return { success: true, data: data as { id: string } };
  } catch (err) {
    console.error("createSection unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}

// Bölüm güncelle
export async function updateSection(id: string, name: string, color: string): Promise<ActionResult> {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { error } = await supabase
      .from("visual_audit_sections" as never)
      .update({ name, color } as never)
      .eq("id", id);
    
    if (error) {
      console.error("updateSection error:", error);
      return { success: false, error: error.message };
    }
    
    revalidatePath("/visual-audit");
    revalidatePath("/visual-audit/settings");
    return { success: true, data: undefined };
  } catch (err) {
    console.error("updateSection unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}

// Bölüm aktifliğini toggle et
export async function toggleSectionActive(id: string, isActive: boolean): Promise<ActionResult> {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { error } = await supabase
      .from("visual_audit_sections" as never)
      .update({ is_active: isActive } as never)
      .eq("id", id);
    
    if (error) {
      console.error("toggleSectionActive error:", error);
      return { success: false, error: error.message };
    }
    
    revalidatePath("/visual-audit");
    revalidatePath("/visual-audit/settings");
    return { success: true, data: undefined };
  } catch (err) {
    console.error("toggleSectionActive unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}

// Bölüm sil (hard delete - kalıcı silme)
export async function deleteSection(id: string): Promise<ActionResult> {
  try {
    const supabase = await getSupabaseServerClient();
    
    // Önce bu bölümle ilişkili görev var mı kontrol et
    const { count, error: countError } = await supabase
      .from("visual_audit_tasks" as never)
      .select("*", { count: "exact", head: true })
      .eq("section_id", id);
    
    if (countError) {
      console.error("deleteSection count error:", countError);
      return { success: false, error: countError.message };
    }
    
    if (count && count > 0) {
      return { success: false, error: `Bu bölüme ait ${count} görev var. Önce görevleri silmeniz veya bölümü pasif yapmanız gerekir.` };
    }
    
    const { error } = await supabase
      .from("visual_audit_sections" as never)
      .delete()
      .eq("id", id);
    
    if (error) {
      console.error("deleteSection error:", error);
      return { success: false, error: error.message };
    }
    
    revalidatePath("/visual-audit");
    revalidatePath("/visual-audit/settings");
    return { success: true, data: undefined };
  } catch (err) {
    console.error("deleteSection unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}

// ============================================
// FOTOĞRAF & YORUM İŞLEMLERİ
// ============================================

// Görev fotoğraflarını getir
export async function getTaskPhotos(taskId: string) {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data, error } = await supabase
      .from("visual_audit_photos" as never)
      .select(`
        id,
        photo_url,
        created_at,
        uploaded_by,
        users:uploaded_by (first_name, last_name)
      `)
      .eq("task_id", taskId)
      .order("created_at", { ascending: false });
    
    if (error) {
      console.error("getTaskPhotos error:", error);
      return [];
    }
    
    // Transform to include full_name and rename created_at to uploaded_at for UI
    return (data || []).map((item: { id: string; photo_url: string; created_at: string; uploaded_by: string; users: { first_name: string; last_name: string } | null }) => ({
      id: item.id,
      photo_url: item.photo_url,
      uploaded_at: item.created_at,
      uploaded_by: item.uploaded_by,
      users: item.users ? { full_name: `${item.users.first_name || ""} ${item.users.last_name || ""}`.trim() } : null
    }));
  } catch (err) {
    console.error("getTaskPhotos unexpected error:", err);
    return [];
  }
}

// Görev yorumlarını getir
export async function getTaskComments(taskId: string) {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data, error } = await supabase
      .from("visual_audit_comments" as never)
      .select(`
        id,
        message,
        created_at,
        user_id,
        users:user_id (first_name, last_name)
      `)
      .eq("task_id", taskId)
      .order("created_at", { ascending: true });
    
    if (error) {
      console.error("getTaskComments error:", error);
      return [];
    }
    
    // Transform to include full_name and rename message to comment for UI
    return (data || []).map((item: { id: string; message: string; created_at: string; user_id: string; users: { first_name: string; last_name: string } | null }) => ({
      id: item.id,
      comment: item.message,
      created_at: item.created_at,
      user_id: item.user_id,
      users: item.users ? { full_name: `${item.users.first_name || ""} ${item.users.last_name || ""}`.trim() } : null
    }));
  } catch (err) {
    console.error("getTaskComments unexpected error:", err);
    return [];
  }
}

// Yorum ekle
export async function addComment(taskId: string, comment: string): Promise<ActionResult> {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return { success: false, error: "Oturum bulunamadı" };
    }
    
    // Tenant ID al
    const { data: userProfile } = await supabase
      .from("users" as never)
      .select("tenant_id")
      .eq("id", user.id)
      .single();
    
    const tenantId = (userProfile as { tenant_id: string } | null)?.tenant_id;
    
    const { error } = await supabase
      .from("visual_audit_comments" as never)
      .insert({
        task_id: taskId,
        user_id: user.id,
        tenant_id: tenantId,
        message: comment,
        comment_type: "comment",
      } as never);
    
    if (error) {
      console.error("addComment error:", error);
      return { success: false, error: error.message };
    }
    
    revalidatePath("/visual-audit");
    return { success: true, data: undefined };
  } catch (err) {
    console.error("addComment unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}

// ============================================
// ŞUBE İŞLEMLERİ
// ============================================

// Şubeleri getir
export async function getBranches() {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data, error } = await supabase
      .from("branches" as never)
      .select("id, name")
      .eq("is_active", true)
      .order("name");
    
    if (error) {
      console.error("getBranches error:", error);
      return [];
    }
    
    return (data || []) as { id: string; name: string }[];
  } catch (err) {
    console.error("getBranches unexpected error:", err);
    return [];
  }
}

// ============================================
// PLAN İŞLEMLERİ
// ============================================

export interface Plan {
  id: string;
  name: string;
  section_ids: string[];
  branch_ids: string[];
  section_names: string[];
  branch_names: string[];
  scheduled_hour: number;
  deadline_minutes: number;
  min_photos: number;
  notes: string | null;
  recurrence: "daily" | "weekly";
  recurrence_days: number[];
  start_date: string;
  end_date: string;
  is_active: boolean;
  created_by: string | null;
  created_by_name: string | null;
  created_at: string;
  total_tasks: number;
  completed_tasks: number;
  pending_tasks: number;
}

// Planları getir
export async function getPlans(): Promise<Plan[]> {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data, error } = await supabase.rpc("get_visual_audit_plans" as never);
    
    if (error) {
      console.error("getPlans error:", error);
      return [];
    }
    
    return (data || []) as Plan[];
  } catch (err) {
    console.error("getPlans unexpected error:", err);
    return [];
  }
}

// Plan oluştur
export async function createPlan(formData: {
  name: string;
  section_ids: string[];
  branch_ids: string[];
  scheduled_hour: number;
  deadline_minutes: number;
  min_photos: number;
  notes?: string;
  recurrence: "daily" | "weekly";
  recurrence_days: number[];
  start_date: string;
  end_date: string;
}): Promise<ActionResult<{ plan_id: string; tasks_created: number }>> {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data, error } = await supabase.rpc("create_visual_audit_plan" as never, {
      p_name: formData.name,
      p_section_ids: formData.section_ids,
      p_branch_ids: formData.branch_ids.length > 0 ? formData.branch_ids : null,
      p_scheduled_hour: formData.scheduled_hour,
      p_deadline_minutes: formData.deadline_minutes,
      p_min_photos: formData.min_photos,
      p_notes: formData.notes || null,
      p_recurrence: formData.recurrence,
      p_recurrence_days: formData.recurrence_days,
      p_start_date: formData.start_date,
      p_end_date: formData.end_date,
    } as never);
    
    if (error) {
      console.error("createPlan error:", error);
      return { success: false, error: error.message };
    }
    
    const result = data as { success: boolean; error?: string; plan_id?: string; tasks_created?: number };
    if (!result.success) {
      return { success: false, error: result.error || "Plan oluşturulamadı" };
    }
    
    revalidatePath("/visual-audit");
    revalidatePath("/visual-audit/plans");
    return { success: true, data: { plan_id: result.plan_id!, tasks_created: result.tasks_created! } };
  } catch (err) {
    console.error("createPlan unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}

// Plan güncelle
export async function updatePlan(
  planId: string,
  formData: {
    name?: string;
    section_ids?: string[];
    branch_ids?: string[];
    scheduled_hour?: number;
    deadline_minutes?: number;
    min_photos?: number;
    notes?: string;
    recurrence?: "daily" | "weekly";
    recurrence_days?: number[];
    end_date?: string;
    is_active?: boolean;
  }
): Promise<ActionResult<{ tasks_created: number; tasks_deleted: number; tasks_updated: number }>> {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data, error } = await supabase.rpc("update_visual_audit_plan" as never, {
      p_plan_id: planId,
      p_name: formData.name || null,
      p_section_ids: formData.section_ids || null,
      p_branch_ids: formData.branch_ids || null,
      p_scheduled_hour: formData.scheduled_hour ?? null,
      p_deadline_minutes: formData.deadline_minutes ?? null,
      p_min_photos: formData.min_photos ?? null,
      p_notes: formData.notes ?? null,
      p_recurrence: formData.recurrence || null,
      p_recurrence_days: formData.recurrence_days || null,
      p_end_date: formData.end_date || null,
      p_is_active: formData.is_active ?? null,
    } as never);
    
    if (error) {
      console.error("updatePlan error:", error);
      return { success: false, error: error.message };
    }
    
    const result = data as { success: boolean; error?: string; tasks_created?: number; tasks_deleted?: number; tasks_updated?: number };
    if (!result.success) {
      return { success: false, error: result.error || "Plan güncellenemedi" };
    }
    
    revalidatePath("/visual-audit");
    revalidatePath("/visual-audit/plans");
    return { 
      success: true, 
      data: { 
        tasks_created: result.tasks_created || 0, 
        tasks_deleted: result.tasks_deleted || 0, 
        tasks_updated: result.tasks_updated || 0 
      } 
    };
  } catch (err) {
    console.error("updatePlan unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}

// Plan sil
export async function deletePlan(planId: string): Promise<ActionResult<{ tasks_deleted: number }>> {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data, error } = await supabase.rpc("delete_visual_audit_plan" as never, {
      p_plan_id: planId,
    } as never);
    
    if (error) {
      console.error("deletePlan error:", error);
      return { success: false, error: error.message };
    }
    
    const result = data as { success: boolean; error?: string; tasks_deleted?: number };
    if (!result.success) {
      return { success: false, error: result.error || "Plan silinemedi" };
    }
    
    revalidatePath("/visual-audit");
    revalidatePath("/visual-audit/plans");
    return { success: true, data: { tasks_deleted: result.tasks_deleted || 0 } };
  } catch (err) {
    console.error("deletePlan unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}

// Plan kopyala
export async function copyPlan(
  planId: string,
  newName?: string,
  startDate?: string,
  endDate?: string
): Promise<ActionResult<{ plan_id: string; tasks_created: number }>> {
  try {
    const supabase = await getSupabaseServerClient();
    
    const { data, error } = await supabase.rpc("copy_visual_audit_plan" as never, {
      p_plan_id: planId,
      p_new_name: newName || null,
      p_start_date: startDate || null,
      p_end_date: endDate || null,
    } as never);
    
    if (error) {
      console.error("copyPlan error:", error);
      return { success: false, error: error.message };
    }
    
    const result = data as { success: boolean; error?: string; plan_id?: string; tasks_created?: number };
    if (!result.success) {
      return { success: false, error: result.error || "Plan kopyalanamadı" };
    }
    
    revalidatePath("/visual-audit");
    revalidatePath("/visual-audit/plans");
    return { success: true, data: { plan_id: result.plan_id!, tasks_created: result.tasks_created! } };
  } catch (err) {
    console.error("copyPlan unexpected error:", err);
    return { success: false, error: "Beklenmeyen hata oluştu" };
  }
}
