import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";

export async function GET() {
  try {
    const serviceSupabase = SUPABASE_SERVICE_ROLE_KEY
      ? createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false } })
      : null;

    const supabase = serviceSupabase ?? (await getSupabaseServerClient());

    const { data, error } = await supabase.from("modules").select("code, name").order("code");

    if (error) {
      throw error;
    }

    const modules = (data ?? []).map((row) => ({ module_code: row.code, name: (row as any).name ?? null }));
    return NextResponse.json(modules, { status: 200 });
  } catch (error) {
    console.error("modules list api error", error);
    // Geriye boş liste dönerek istemcinin varsayılan şablonla devam edebilmesini sağla.
    return NextResponse.json([], { status: 200, headers: { "x-warning": "modules-list-failed" } });
  }
}
