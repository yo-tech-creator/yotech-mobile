import type { ReactNode } from "react";
import type { Route } from "next";
import { redirect } from "next/navigation";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DashboardShell, type DashboardProfile, type DashboardRole } from "@/components/dashboard/dashboard-shell";

export default async function DashboardLayout({ children }: { children: ReactNode }) {
  const supabase = await getSupabaseServerClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    redirect("/login" as Route);
  }

  const { data: profile, error } = await supabase
    .from("users")
    .select("role, first_name, last_name")
    .match({ id: session.user.id })
    .maybeSingle<{ role: string | null; first_name: string | null; last_name: string | null }>();

  if (error || !profile?.role) {
    redirect("/login?error=profile" as Route);
  }

  const role = profile.role as DashboardRole | undefined;

  if (!role) {
    redirect("/login?error=role" as Route);
  }

  const dashboardProfile: DashboardProfile = {
    role,
    first_name: profile.first_name,
    last_name: profile.last_name,
  };

  return <DashboardShell profile={dashboardProfile}>{children}</DashboardShell>;
}
