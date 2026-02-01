import { NextRequest, NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { createClient } from "@supabase/supabase-js";

// POST - Mark announcement as read
export async function POST(
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
      .select("id, tenant_id, branch_id")
      .eq("id", user.id)
      .single();

    if (userError || !userData) {
      return NextResponse.json({ error: "Kullanıcı bulunamadı" }, { status: 404 });
    }

    // Check if announcement exists
    const { data: announcement, error: fetchError } = await supabaseAdmin
      .from("announcements")
      .select("id, tenant_id")
      .eq("id", id)
      .eq("tenant_id", userData.tenant_id)
      .single();

    if (fetchError || !announcement) {
      return NextResponse.json({ error: "Duyuru bulunamadı" }, { status: 404 });
    }

    // Check if already read
    const { data: existingRead } = await supabaseAdmin
      .from("announcement_reads")
      .select("id")
      .eq("announcement_id", id)
      .eq("user_id", userData.id)
      .maybeSingle();

    if (existingRead) {
      // Already read, return success
      return NextResponse.json({ success: true, already_read: true });
    }

    // Insert read record (branch_id is not in the table schema)
    const { error: insertError } = await supabaseAdmin
      .from("announcement_reads")
      .insert({
        announcement_id: id,
        user_id: userData.id,
        read_at: new Date().toISOString(),
      });

    if (insertError) {
      console.error("Error marking as read:", insertError);
      return NextResponse.json({ error: "Okundu olarak işaretlenemedi" }, { status: 500 });
    }

    return NextResponse.json({ success: true, already_read: false });
  } catch (error) {
    console.error("Mark as read error:", error);
    return NextResponse.json({ error: "İşlem başarısız" }, { status: 500 });
  }
}

// GET - Get read count for announcement
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

    // Get read count
    const { count } = await supabaseAdmin
      .from("announcement_reads")
      .select("*", { count: "exact", head: true })
      .eq("announcement_id", id);

    return NextResponse.json({ count: count || 0 });
  } catch (error) {
    console.error("Get read count error:", error);
    return NextResponse.json({ error: "İşlem başarısız" }, { status: 500 });
  }
}
