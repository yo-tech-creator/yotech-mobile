import { NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { createClient } from "@supabase/supabase-js";
import { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } from "@/lib/supabase/env";

export async function GET(request: Request) {
  try {
    const supabase = await getSupabaseServerClient();
    
    // Get current user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    // Get URL params
    const { searchParams } = new URL(request.url);
    const dateParam = searchParams.get("date");
    const teamOnly = searchParams.get("team") === "true";
    const branchIdParam = searchParams.get("branchId"); // For branch filtering

    // Parse date or use today
    let since: Date;
    if (dateParam) {
      since = new Date(dateParam);
    } else {
      const now = new Date();
      since = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    }
    const sinceIso = since.toISOString();

    // Get user profile using regular client (respects RLS)
    const { data: profile, error: profileError } = await supabase
      .from("users")
      .select("id, tenant_id, branch_id, role")
      .eq("id", user.id)
      .maybeSingle();

    if (profileError) {
      console.error("Profile query error:", profileError);
      return NextResponse.json({ error: "Profile not found", detail: profileError.message }, { status: 404 });
    }
    
    if (!profile) {
      console.error("Profile is null for user:", user.id);
      return NextResponse.json({ error: "Profile not found", userId: user.id }, { status: 404 });
    }

    // Create admin client for bypassing RLS when needed
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
    }
    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    let breaks;
    let branches: { id: string; name: string }[] = [];

    // For bolge_muduru, get branches in their region
    if (profile.role === "bolge_muduru") {
      // First find regions where this user is the manager
      const { data: managedRegions, error: regionsError } = await supabaseAdmin
        .from("regions")
        .select("id")
        .eq("tenant_id", profile.tenant_id)
        .eq("manager_id", user.id);

      if (regionsError) {
        console.error("Regions query error:", regionsError);
      }

      const regionIds = (managedRegions || []).map(r => r.id);
      console.log("Bolge muduru managed regions:", regionIds);

      if (regionIds.length > 0) {
        const { data: branchData, error: branchError } = await supabaseAdmin
          .from("branches")
          .select("id, name")
          .eq("tenant_id", profile.tenant_id)
          .in("region_id", regionIds)
          .eq("active", true)
          .order("name");

        if (branchError) {
          console.error("Branches query error:", branchError);
        }
        console.log("Branches found:", branchData?.length || 0);
        branches = branchData || [];
      }
    }

    if (teamOnly) {
      // Use RPC for hierarchical access - use admin client
      const { data, error } = await supabaseAdmin.rpc("get_branch_break_sessions", {
        p_user_id: user.id,
      });

      if (error) {
        console.error("RPC error:", error);
        return NextResponse.json({ error: error.message }, { status: 500 });
      }

      // Filter by date
      breaks = (data || []).filter((b: { started_at: string }) => {
        const startedAt = new Date(b.started_at);
        return startedAt >= since;
      });

      // Filter by branch if specified (for bolge_muduru)
      if (branchIdParam && profile.role === "bolge_muduru") {
        breaks = breaks.filter((b: { branch_id: string }) => b.branch_id === branchIdParam);
      }
    } else {
      // Get own breaks - use admin client to avoid RLS issues
      console.log("Fetching own breaks for user:", user.id);
      const { data, error } = await supabaseAdmin
        .from("break_sessions")
        .select("*")
        .eq("user_id", user.id)
        .gte("started_at", sinceIso)
        .order("started_at", { ascending: false });

      if (error) {
        console.error("Own breaks query error:", error);
        return NextResponse.json({ error: error.message }, { status: 500 });
      }
      breaks = data || [];
    }

    // Get user names for team breaks
    if (teamOnly && breaks.length > 0) {
      const userIds = [...new Set(breaks.map((b: { user_id: string }) => b.user_id))];
      
      const { data: users } = await supabase
        .from("users")
        .select("id, first_name, last_name, employee_code")
        .eq("tenant_id", profile.tenant_id)
        .in("id", userIds);

      const userMap = new Map();
      (users || []).forEach((u: { id: string; first_name?: string; last_name?: string; employee_code?: string }) => {
        const name = [u.first_name, u.last_name].filter(Boolean).join(" ").trim() || u.employee_code || u.id.slice(0, 8);
        userMap.set(u.id, name);
      });

      breaks = breaks.map((b: { user_id: string }) => ({
        ...b,
        user_name: userMap.get(b.user_id) || b.user_id.slice(0, 8),
      }));
    }

    return NextResponse.json({ breaks, role: profile.role, branches });
  } catch (err) {
    console.error("Breaks API error:", err);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
