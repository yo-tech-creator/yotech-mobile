import { createServerClient } from "@supabase/ssr";
import type { NextRequest } from "next/server";
import { SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/supabase/env";

type RoleResult = { role: string | null } | null;

// Kullanıcının rolünü güvenli şekilde çeker; hata durumunda null döner.
export async function getUserRoleSafe(request: NextRequest): Promise<RoleResult> {
  try {
    const supabase = createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        // Middleware içinde yanıtı mutasyona uğratmamak için no-op setter.
        setAll() {
          // no-op
        },
      },
    });

    const { data, error } = await supabase.rpc("current_user_role");
    if (error) {
      console.error("getUserRoleSafe rpc error", error);
      return null;
    }
    return { role: (data as string | null) ?? null };
  } catch (error) {
    console.error("getUserRoleSafe unexpected error", error);
    return null;
  }
}