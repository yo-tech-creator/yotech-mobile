import { NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { createClient } from "@supabase/supabase-js";

// This endpoint provides branches, regions, and users data for announcement/survey creation

export async function GET() {
  try {
    const cookieStore = await cookies();
    
    // Create a client with anon key for auth
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

    // Verify user is authenticated
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    // Create admin client for bypassing RLS
    const supabaseAdmin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    // Get user profile with role and tenant
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("users")
      .select("id, role, tenant_id, branch_id")
      .eq("id", user.id)
      .maybeSingle();

    if (profileError || !profile) {
      return NextResponse.json({ error: "Profile not found" }, { status: 404 });
    }

    const role = profile.role;
    const tenantId = profile.tenant_id;

    // Get all regions for tenant
    const { data: regionsData } = await supabaseAdmin
      .from("regions")
      .select("id, name, manager_id")
      .eq("tenant_id", tenantId)
      .order("name");

    // Get all branches for tenant
    const { data: branchesData } = await supabaseAdmin
      .from("branches")
      .select("id, name, region_id")
      .eq("tenant_id", tenantId)
      .eq("is_active", true)
      .order("name");

    // For bölge müdürü: find their managed regions
    let managedRegionIds: string[] = [];
    let filteredBranches = branchesData || [];
    let filteredRegions = regionsData || [];

    if (role === "bolge_muduru") {
      // Find regions where this user is the manager
      const managedRegions = (regionsData || []).filter(r => r.manager_id === user.id);
      managedRegionIds = managedRegions.map(r => r.id);
      
      // Filter branches to only those in managed regions
      filteredBranches = (branchesData || []).filter(b => 
        managedRegionIds.includes(b.region_id || "")
      );
      
      // Only show managed regions
      filteredRegions = managedRegions;
    } else if (role === "sube_muduru") {
      // Only show their own branch
      filteredBranches = (branchesData || []).filter(b => b.id === profile.branch_id);
      filteredRegions = [];
    }

    // Get personnel for sube_muduru
    let personnel: { id: string; first_name: string; last_name: string; role: string; branch_id: string }[] = [];
    if (role === "sube_muduru" && profile.branch_id) {
      const { data: personnelData } = await supabaseAdmin
        .from("users")
        .select("id, first_name, last_name, role, branch_id")
        .eq("tenant_id", tenantId)
        .eq("branch_id", profile.branch_id)
        .neq("id", user.id);
      personnel = personnelData || [];
    }

    return NextResponse.json({
      role,
      branch_id: profile.branch_id,
      managed_region_ids: managedRegionIds,
      regions: filteredRegions,
      branches: filteredBranches,
      personnel,
    });
  } catch (error) {
    console.error("Lookup API error:", error);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
