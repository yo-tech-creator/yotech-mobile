import { NextRequest, NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { createClient } from "@supabase/supabase-js";

// GET - Get announcement by ID
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const cookieStore = await cookies();
    
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return cookieStore.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) => {
              try {
                cookieStore.set(name, value, options);
              } catch {
                // ignore
              }
            });
          },
        },
      }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      return NextResponse.json({ error: "Yetkilendirme hatası" }, { status: 401 });
    }

    const supabaseAdmin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    // Get user details
    const { data: userData, error: userError } = await supabaseAdmin
      .from("users")
      .select("id, tenant_id, role, branch_id")
      .eq("id", user.id)
      .single();

    if (userError || !userData) {
      return NextResponse.json({ error: "Kullanıcı bulunamadı" }, { status: 404 });
    }

    // Get announcement
    const { data: announcement, error: fetchError } = await supabaseAdmin
      .from("announcements")
      .select(`
        *,
        publisher:published_by(id, first_name, last_name, role)
      `)
      .eq("id", id)
      .eq("tenant_id", userData.tenant_id)
      .single();

    if (fetchError || !announcement) {
      return NextResponse.json({ error: "Duyuru bulunamadı" }, { status: 404 });
    }

    // Get read count
    const { count: readCount } = await supabaseAdmin
      .from("announcement_reads")
      .select("*", { count: "exact", head: true })
      .eq("announcement_id", id);

    // Get reads list (last 100)
    const { data: readsData } = await supabaseAdmin
      .from("announcement_reads")
      .select("id, read_at, user_id, branch_id")
      .eq("announcement_id", id)
      .order("read_at", { ascending: false })
      .limit(100);

    // Get user and branch details for reads
    let reads: Array<{
      id: string;
      read_at: string;
      user: { first_name: string; last_name: string; role: string };
      branch: { name: string } | null;
    }> = [];

    if (readsData && readsData.length > 0) {
      const userIds = [...new Set(readsData.map(r => r.user_id))];
      const branchIds = [...new Set(readsData.map(r => r.branch_id).filter(Boolean))];

      const [usersRes, branchesRes] = await Promise.all([
        supabaseAdmin.from("users").select("id, first_name, last_name, role").in("id", userIds),
        branchIds.length > 0 
          ? supabaseAdmin.from("branches").select("id, name").in("id", branchIds as string[])
          : Promise.resolve({ data: [] })
      ]);

      const usersMap = new Map((usersRes.data || []).map(u => [u.id, u]));
      const branchesMap = new Map((branchesRes.data || []).map(b => [b.id, b]));

      reads = readsData.map(r => {
        const userInfo = usersMap.get(r.user_id);
        const branchInfo = r.branch_id ? branchesMap.get(r.branch_id) : null;
        return {
          id: r.id,
          read_at: r.read_at,
          user: {
            first_name: userInfo?.first_name || "",
            last_name: userInfo?.last_name || "",
            role: userInfo?.role || "",
          },
          branch: branchInfo ? { name: branchInfo.name } : null,
        };
      });
    }

    return NextResponse.json({
      announcement: {
        ...announcement,
        read_count: readCount || 0,
        reads,
      },
    });
  } catch (error) {
    console.error("Get announcement error:", error);
    return NextResponse.json({ error: "Duyuru yüklenemedi" }, { status: 500 });
  }
}

// PATCH - Update announcement (pin/unpin, etc.)
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const cookieStore = await cookies();
    
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return cookieStore.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) => {
              try {
                cookieStore.set(name, value, options);
              } catch {
                // ignore
              }
            });
          },
        },
      }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      return NextResponse.json({ error: "Yetkilendirme hatası" }, { status: 401 });
    }

    const supabaseAdmin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    // Get user details
    const { data: userData, error: userError } = await supabaseAdmin
      .from("users")
      .select("id, tenant_id, role")
      .eq("id", user.id)
      .single();

    if (userError || !userData) {
      return NextResponse.json({ error: "Kullanıcı bulunamadı" }, { status: 404 });
    }

    // Check if announcement exists and belongs to tenant
    const { data: existing, error: existError } = await supabaseAdmin
      .from("announcements")
      .select("id, published_by, tenant_id")
      .eq("id", id)
      .eq("tenant_id", userData.tenant_id)
      .single();

    if (existError || !existing) {
      return NextResponse.json({ error: "Duyuru bulunamadı" }, { status: 404 });
    }

    // Check permission (only owner or admin can update)
    const allowedRoles = ["firma_admin", "grand_admin"];
    if (existing.published_by !== userData.id && !allowedRoles.includes(userData.role)) {
      return NextResponse.json({ error: "Bu işlem için yetkiniz yok" }, { status: 403 });
    }

    const body = await request.json();
    const updateData: Record<string, unknown> = {};

    // Allow updating specific fields
    if (typeof body.pinned === "boolean") {
      updateData.pinned = body.pinned;
      // Set pinned_at timestamp when pinning, null when unpinning
      updateData.pinned_at = body.pinned ? new Date().toISOString() : null;
    }
    if (typeof body.active === "boolean") {
      updateData.active = body.active;
    }
    if (body.expires_at !== undefined) {
      updateData.expires_at = body.expires_at;
    }

    if (Object.keys(updateData).length === 0) {
      return NextResponse.json({ error: "Güncellenecek alan yok" }, { status: 400 });
    }

    const { data: updated, error: updateError } = await supabaseAdmin
      .from("announcements")
      .update(updateData)
      .eq("id", id)
      .select()
      .single();

    if (updateError) {
      console.error("Update error:", updateError);
      return NextResponse.json({ error: "Güncelleme başarısız" }, { status: 500 });
    }

    return NextResponse.json({ success: true, announcement: updated });
  } catch (error) {
    console.error("Update announcement error:", error);
    return NextResponse.json({ error: "Güncelleme başarısız" }, { status: 500 });
  }
}

// DELETE - Delete announcement
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const cookieStore = await cookies();
    
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return cookieStore.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) => {
              try {
                cookieStore.set(name, value, options);
              } catch {
                // ignore
              }
            });
          },
        },
      }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      return NextResponse.json({ error: "Yetkilendirme hatası" }, { status: 401 });
    }

    const supabaseAdmin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    // Get user details
    const { data: userData, error: userError } = await supabaseAdmin
      .from("users")
      .select("id, tenant_id, role")
      .eq("id", user.id)
      .single();

    if (userError || !userData) {
      return NextResponse.json({ error: "Kullanıcı bulunamadı" }, { status: 404 });
    }

    // Check if announcement exists and belongs to tenant
    const { data: existing, error: existError } = await supabaseAdmin
      .from("announcements")
      .select("id, published_by, tenant_id")
      .eq("id", id)
      .eq("tenant_id", userData.tenant_id)
      .single();

    if (existError || !existing) {
      return NextResponse.json({ error: "Duyuru bulunamadı" }, { status: 404 });
    }

    // Check permission (only owner or admin can delete)
    const allowedRoles = ["firma_admin", "grand_admin"];
    if (existing.published_by !== userData.id && !allowedRoles.includes(userData.role)) {
      return NextResponse.json({ error: "Bu işlem için yetkiniz yok" }, { status: 403 });
    }

    // Delete related records first
    await supabaseAdmin
      .from("announcement_reads")
      .delete()
      .eq("announcement_id", id);

    // Delete announcement
    const { error: deleteError } = await supabaseAdmin
      .from("announcements")
      .delete()
      .eq("id", id);

    if (deleteError) {
      console.error("Delete error:", deleteError);
      return NextResponse.json({ error: "Silme başarısız" }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Delete announcement error:", error);
    return NextResponse.json({ error: "Silme başarısız" }, { status: 500 });
  }
}
