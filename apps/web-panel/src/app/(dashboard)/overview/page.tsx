import type { Route } from "next";
import { redirect } from "next/navigation";
import { GrandAdminOverview } from "@/components/dashboard/grand-admin-dashboard";
import { FirmaAdminOverview } from "@/components/dashboard/firma-admin-dashboard";
import { RegionManagerDashboard } from "@/components/dashboard/region-manager-dashboard";
import { StoreManagerDashboard } from "@/components/dashboard/store-manager-dashboard";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export default async function OverviewPage() {
  const supabase = await getSupabaseServerClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    redirect("/login" as Route);
  }

  const { data: profile, error } = await supabase
    .from("users")
    .select("role")
    .match({ id: session.user.id })
    .maybeSingle<{ role: string | null }>();

  if (error || !profile?.role) {
    redirect("/login?error=profile" as Route);
  }

  switch (profile.role) {
    case "grand_admin":
      return <GrandAdminOverview />;
    case "firma_admin":
      return <FirmaAdminOverview />;
    case "bolge_muduru":
      return <RegionManagerDashboard />;
    case "sube_muduru":
      return <StoreManagerDashboard />;
    default:
      redirect("/login?error=role" as Route);
  }
}
