import type { NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/proxy";
import { NextResponse } from "next/server";
import { getUserRoleSafe } from "@/lib/user-role";

export async function middleware(request: NextRequest) {
  const sessionResponse = await updateSession(request);

  // Eğer updateSession bir redirect/response döndürdüyse aynı cevabı kullan.
  if (sessionResponse.redirected || sessionResponse.status !== 200) {
    return sessionResponse;
  }

  // Login sayfasında rol engeli uygulama (loop engeli).
  if (request.nextUrl.pathname.startsWith("/login")) {
    return sessionResponse;
  }

  // Rol kontrolü: Personel rolü web panel erişimine kapalı.
  const roleResult = await getUserRoleSafe(request);
  if (roleResult?.role === "personel") {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("error", "Personel girişi için uygun değil.");
    return NextResponse.redirect(url);
  }

  return sessionResponse;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
