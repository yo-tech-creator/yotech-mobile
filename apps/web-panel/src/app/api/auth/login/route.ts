import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from "@/lib/supabase/env";
import type { Database } from "@/lib/types/database";
import { 
  checkRateLimit, 
  rateLimitResponse, 
  resetRateLimit 
} from "@/lib/security/rate-limiter";
import { z } from "zod";
import xss from "xss";

// Login request validation schema
const loginSchema = z.object({
  employee_code: z.string()
    .min(1, "Personel kodu gerekli")
    .max(50, "Personel kodu çok uzun")
    .transform(v => xss(v.trim())),
  password: z.string()
    .min(1, "Şifre gerekli")
    .max(128, "Şifre çok uzun"),
});

export async function POST(request: NextRequest) {
  // Strict rate limiting for auth endpoints (brute-force protection)
  const rateLimit = await checkRateLimit(request, 'auth');
  if (!rateLimit.success) {
    console.warn(`[SECURITY] Rate limit exceeded for login attempt from IP`);
    return rateLimitResponse(rateLimit);
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json({ message: "Sunucu yapılandırması eksik" }, { status: 500 });
  }

  // Input validation
  let body;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ message: "Geçersiz istek formatı" }, { status: 400 });
  }

  const validation = loginSchema.safeParse(body);
  if (!validation.success) {
    const issues = validation.error.issues || [];
    return NextResponse.json({ 
      message: "Doğrulama hatası", 
      errors: issues.map((e: z.ZodIssue) => ({ field: e.path.join('.'), message: e.message }))
    }, { status: 400 });
  }

  const { employee_code, password } = validation.data;

  const supabaseAdmin = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    // Get user email by employee code
    const { data: rpcData, error: rpcError } = await supabaseAdmin.rpc("get_user_email_by_sicil", {
      p_sicil_no: employee_code,
    });

    if (rpcError) {
      console.error("[LOGIN] RPC error:", rpcError.message);
      return NextResponse.json({ message: "Kullanıcı bilgisi alınamadı" }, { status: 500 });
    }

    const result = Array.isArray(rpcData) ? rpcData[0] : rpcData;

    if (!result || !result.email) {
      // Don't reveal if user exists or not
      return NextResponse.json({ message: "Geçersiz kimlik bilgileri" }, { status: 401 });
    }

    if (result.active === false) {
      return NextResponse.json({ message: "Kullanıcı hesabı aktif değil" }, { status: 403 });
    }

    // Attempt login using admin client to verify password
    // Note: This validates credentials but actual session should be created client-side
    const { data: signInData, error: signInError } = await supabaseAdmin.auth.signInWithPassword({
      email: result.email,
      password,
    });

    if (signInError) {
      // Log failed attempt
      console.warn(`[SECURITY] Failed login attempt for employee code: ${employee_code}`);
      return NextResponse.json({ message: "Geçersiz kimlik bilgileri" }, { status: 401 });
    }

    // Successful login - reset rate limit for this client
    await resetRateLimit(request, 'auth');

    // Return email for client-side session creation
    // We don't return the session tokens here for security - client will create its own session
    return NextResponse.json({ 
      success: true,
      email: result.email,
      message: "Giriş başarılı"
    });

  } catch (error) {
    console.error("[LOGIN] Unexpected error:", error);
    return NextResponse.json({ message: "Sunucu hatası" }, { status: 500 });
  }
}

// Rate limit status check endpoint
export async function GET(request: NextRequest) {
  const rateLimit = await checkRateLimit(request, 'auth');
  
  return NextResponse.json({
    remaining: rateLimit.remaining,
    limit: rateLimit.limit,
    resetTime: rateLimit.resetTime.toISOString(),
  });
}
