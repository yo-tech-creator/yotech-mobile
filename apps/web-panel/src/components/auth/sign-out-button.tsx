"use client";

import type { Route } from "next";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";

export function SignOutButton() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  const handleSignOut = async () => {
    if (loading) {
      return;
    }

    setLoading(true);
    const supabase = getSupabaseBrowserClient();

    try {
      const { error } = await supabase.auth.signOut();
      if (error) {
        console.error("Supabase signOut error", error);
      }

      router.replace("/login" as Route);
      router.refresh();

      setTimeout(() => {
        window.location.assign("/login");
      }, 200);
    } catch (error) {
      console.error("Sign out failed", error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <button className="sign-out" type="button" onClick={handleSignOut} disabled={loading}>
      {loading ? "Çıkış yapılıyor..." : "Çıkış Yap"}
    </button>
  );
}
