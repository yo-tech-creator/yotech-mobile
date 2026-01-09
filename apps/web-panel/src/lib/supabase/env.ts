export function requirePublicEnv(value: string | undefined, key: string): string {
  if (!value) {
    throw new Error(`${key} ortam değişkeni eksik`);
  }
  return value;
}

export const SUPABASE_URL = requirePublicEnv(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  "NEXT_PUBLIC_SUPABASE_URL",
);

export const SUPABASE_ANON_KEY = requirePublicEnv(
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  "NEXT_PUBLIC_SUPABASE_ANON_KEY",
);

// Opsiyonel servis rolü anahtarı; sadece sunucu tarafında kullanılır.
export const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
