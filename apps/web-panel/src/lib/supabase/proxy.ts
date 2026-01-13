import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { SUPABASE_ANON_KEY, SUPABASE_URL } from "./env";

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });
  const isLoginPage = request.nextUrl.pathname.startsWith("/login");

  const supabase = createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookies) {
        response = NextResponse.next({ request });
        cookies.forEach(({ name, value, options }) => {
          request.cookies.set(name, value);
          response.cookies.set(name, value, options);
        });
      },
    },
  });
  try {
    const { data, error } = await supabase.auth.getUser();
    const user = data?.user;

    if (error || !user) {
      // Token bozulmuşsa Supabase auth çerezlerini temizle
      request.cookies.getAll().forEach((cookie) => {
        if (cookie.name.startsWith("sb-") || cookie.name.startsWith("supabase-")) {
          response.cookies.set(cookie.name, "", { maxAge: 0, path: "/" });
        }
      });

      if (isLoginPage) {
        return response;
      }

      const url = request.nextUrl.clone();
      url.pathname = "/login";
      return NextResponse.redirect(url);
    }

    return response;
  } catch (err) {
    console.error("supabase auth getUser failed", err);
    if (!isLoginPage) {
      const url = request.nextUrl.clone();
      url.pathname = "/login";
      return NextResponse.redirect(url);
    }
    return response;
  }
}
