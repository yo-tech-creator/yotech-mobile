import { NextRequest, NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { createClient } from "@supabase/supabase-js";

// POST - Create new announcement
export async function POST(request: NextRequest) {
  try {
    const cookieStore = await cookies();
    
    // Create server client for auth check
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

    // Get current user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      return NextResponse.json({ error: "Yetkilendirme hatası" }, { status: 401 });
    }

    // Create admin client for bypassing RLS
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

    // Check role permissions
    const allowedRoles = ["firma_admin", "bolge_muduru", "sube_muduru"];
    if (!allowedRoles.includes(userData.role)) {
      return NextResponse.json({ error: "Duyuru oluşturma yetkiniz yok" }, { status: 403 });
    }

    // Parse request body
    const body = await request.json();
    const {
      title,
      content,
      summary,
      target_scope,
      target_branches,
      target_users,
      include_region_managers,
      managers_only,
      priority,
      pinned,
      expires_at,
    } = body;

    // Validation
    if (!title?.trim()) {
      return NextResponse.json({ error: "Başlık zorunludur" }, { status: 400 });
    }

    if (!content?.trim()) {
      return NextResponse.json({ error: "İçerik zorunludur" }, { status: 400 });
    }

    // Prepare target_branches for specific scopes
    let finalTargetBranches: string[] | null = null;
    let finalTargetRoles: string[] | null = null;

    // Calculate target branches based on scope and role
    if (target_scope === "all_branches") {
      // All branches in tenant - leave target_branches null
      finalTargetBranches = null;
    } else if (target_scope === "selected_branches") {
      if (!target_branches || target_branches.length === 0) {
        return NextResponse.json({ error: "En az bir şube seçmelisiniz" }, { status: 400 });
      }
      finalTargetBranches = target_branches;
    } else if (target_scope === "selected_personnel") {
      // For selected personnel, we don't set target_branches
      // The announcement_reads table will track who has read
      finalTargetBranches = null;
    } else if (target_scope === "my_branch") {
      // Only for sube_muduru - set their branch
      if (!userData.branch_id) {
        return NextResponse.json({ error: "Şube bilgisi bulunamadı" }, { status: 400 });
      }
      finalTargetBranches = [userData.branch_id];
    }

    // If managers_only, set target_roles to manager roles
    if (managers_only) {
      finalTargetRoles = ["firma_admin", "bolge_muduru", "sube_muduru"];
    } else if (include_region_managers) {
      // Include region managers in the target roles
      finalTargetRoles = ["bolge_muduru"];
    }

    // Insert announcement
    const { data: announcement, error: insertError } = await supabaseAdmin
      .from("announcements")
      .insert({
        tenant_id: userData.tenant_id,
        title: title.trim(),
        content: content.trim(),
        target_branches: finalTargetBranches,
        target_roles: finalTargetRoles,
        published_by: userData.id,
        published_at: new Date().toISOString(),
        expires_at: expires_at || null,
        is_active: true,
      })
      .select()
      .single();

    if (insertError) {
      console.error("Error creating announcement:", insertError);
      return NextResponse.json(
        { error: insertError.message || "Duyuru oluşturulurken bir hata oluştu" },
        { status: 500 }
      );
    }

    // If selected_personnel, create individual announcement_reads or target records
    // For now, the mobile app will handle visibility based on target_branches and target_roles

    return NextResponse.json({
      success: true,
      announcement,
    });
  } catch (error) {
    console.error("Create announcement error:", error);
    return NextResponse.json(
      { error: "Duyuru oluşturulurken bir hata oluştu" },
      { status: 500 }
    );
  }
}

// GET - List announcements
export async function GET(request: NextRequest) {
  try {
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

    // Create admin client for bypassing RLS
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

    // Query announcements based on role
    let query = supabaseAdmin
      .from("announcements")
      .select(`
        *,
        publisher:published_by(id, first_name, last_name)
      `)
      .eq("tenant_id", userData.tenant_id)
      .eq("is_active", true)
      .order("pinned", { ascending: false })
      .order("pinned_at", { ascending: false, nullsFirst: false })
      .order("priority", { ascending: false })
      .order("published_at", { ascending: false });

    const { data: announcements, error: queryError } = await query;

    if (queryError) {
      console.error("Error fetching announcements:", queryError);
      return NextResponse.json({ error: "Duyurular yüklenemedi" }, { status: 500 });
    }

    // Get read counts for all announcements
    const announcementIds = (announcements || []).map(a => a.id);
    
    let readCounts: Record<string, number> = {};
    let responseCounts: Record<string, number> = {};
    
    if (announcementIds.length > 0) {
      // Get read counts
      const { data: reads } = await supabaseAdmin
        .from("announcement_reads")
        .select("announcement_id")
        .in("announcement_id", announcementIds);
      
      // Count reads per announcement
      (reads || []).forEach(r => {
        readCounts[r.announcement_id] = (readCounts[r.announcement_id] || 0) + 1;
      });

      // Get response counts for surveys
      const surveyIds = (announcements || []).filter(a => a.type === 'survey').map(a => a.id);
      if (surveyIds.length > 0) {
        const { data: responses } = await supabaseAdmin
          .from("survey_responses")
          .select("announcement_id")
          .in("announcement_id", surveyIds);
        
        // Count responses per survey
        (responses || []).forEach(r => {
          responseCounts[r.announcement_id] = (responseCounts[r.announcement_id] || 0) + 1;
        });
      }
    }

    // Add read_count and response_count to each announcement
    const announcementsWithCounts = (announcements || []).map(a => ({
      ...a,
      read_count: readCounts[a.id] || 0,
      response_count: responseCounts[a.id] || 0,
    }));

    return NextResponse.json({ announcements: announcementsWithCounts });
  } catch (error) {
    console.error("Get announcements error:", error);
    return NextResponse.json({ error: "Duyurular yüklenemedi" }, { status: 500 });
  }
}
