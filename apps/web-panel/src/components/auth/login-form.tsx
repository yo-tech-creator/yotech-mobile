"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import type { Database } from "@/lib/types/database";

type RpcRow = {
  email: string | null;
  active: boolean | null;
};

type RpcPayload = RpcRow | RpcRow[] | null;

export function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(searchParams.get("error"));

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError(null);
    setLoading(true);
    const supabase = getSupabaseBrowserClient();

    try {
      const employeeCode = identifier.trim();
      if (!employeeCode) {
        setError("Personel kodu gerekli");
        setLoading(false);
        return;
      }

      const { data: rpcData, error: rpcError } = await (supabase as any).rpc("get_user_email_by_sicil", {
        p_sicil_no: employeeCode,
      } as Database["public"]["Functions"]["get_user_email_by_sicil"]["Args"]);

      if (rpcError) {
        console.error("get_user_email_by_sicil RPC hatası", rpcError);
        throw new Error("Kullanıcı bilgisi alınamadı");
      }

      const payload = (rpcData ?? null) as RpcPayload;
      const result = Array.isArray(payload) ? payload[0] ?? null : payload;

      if (!result || !result.email) {
        throw new Error("Kullanıcı bulunamadı");
      }

      if (result.active === false) {
        throw new Error("Kullanıcı hesabı aktif değil");
      }

      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: result.email,
        password,
      });

      if (signInError) {
        throw new Error(signInError.message);
      }

      router.replace("/");
      router.refresh();

      // Router bazen senkron olarak güncellenmediğinde sayfayı yenileyerek garantile
      setTimeout(() => {
        window.location.assign("/");
      }, 250);
    } catch (submitError) {
      const message = submitError instanceof Error ? submitError.message : "Giriş başarısız";
      setError(message);
      setLoading(false);
    } finally {
      setLoading(false);
    }
  };

  return (
    <form className="login-form" onSubmit={handleSubmit}>
      <label htmlFor="identifier">Personel Kodu</label>
      <input
        id="identifier"
        type="text"
        value={identifier}
        onChange={(event) => setIdentifier(event.target.value)}
        placeholder="fm00123"
        required
        autoComplete="username"
      />
      <span className="field-hint">Personel kodu doğrudan Supabase üzerindeki kaydınızla eşleştirilir.</span>

      <label htmlFor="password">Şifre</label>
      <input
        id="password"
        type="password"
        value={password}
        onChange={(event) => setPassword(event.target.value)}
        placeholder="••••••••"
        required
        autoComplete="current-password"
      />

      {error ? <p className="form-error">{error}</p> : null}

      <button type="submit" disabled={loading}>
        {loading ? "Giriş yapılıyor..." : "Giriş Yap"}
      </button>
    </form>
  );
}
