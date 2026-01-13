import { Metadata } from "next";
import { redirect } from "next/navigation";
import Link from "next/link";
import { LoginForm } from "@/components/auth/login-form";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: "Yotech Web Panel | Giriş",
};

export default async function LoginPage() {
  const supabase = await getSupabaseServerClient();
  const { data: userResp } = await supabase.auth.getUser();

  if (userResp?.user) {
    redirect("/");
  }

  return (
    <main className="login-page">
      <section className="login-panel">
        <h1>Yotech Web Panel</h1>
        <p>Personel kodu ve belirlenmiş şifrenizle giriş yapın; rolünüze uygun panel otomatik açılır.</p>
        <LoginForm />
        <footer>
          <small>
            Sorun yaşıyorsanız <Link href="mailto:support@yotech.com">support@yotech.com</Link>
            ile iletişime geçin.
          </small>
        </footer>
      </section>
    </main>
  );
}
