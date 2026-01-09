"use client";

import type { ReactNode } from "react";
import { useMemo } from "react";
import Link from "next/link";
import type { Route } from "next";
import { usePathname } from "next/navigation";
import {
  Activity,
  ArrowLeftRight,
  Building,
  ClipboardList,
  Database,
  FileCheck,
  LayoutDashboard,
  Package,
  Settings,
  ShieldCheck,
  ShoppingBag,
  Timer,
  Users,
} from "lucide-react";
import { SignOutButton } from "@/components/auth/sign-out-button";
import type { LucideIcon } from "lucide-react";

export type DashboardRole = "grand_admin" | "firma_admin" | "bolge_muduru" | "sube_muduru";

export type DashboardProfile = {
  role: DashboardRole;
  first_name: string | null;
  last_name: string | null;
};

type NavigationItem = {
  href: Route;
  label: string;
  icon: LucideIcon;
};

const ROLE_NAVIGATION: Record<DashboardRole, NavigationItem[]> = {
  grand_admin: [
    { href: "/overview" as Route, label: "Genel Bakış", icon: LayoutDashboard },
    { href: "/tenants" as Route, label: "Firmalar", icon: Building },
    { href: "/users" as Route, label: "Kullanıcı Yetkileri", icon: Users },
    { href: "/operations" as Route, label: "Operasyon", icon: Database },
    { href: "/observability" as Route, label: "Gözlemlenebilirlik", icon: Activity },
    { href: "/settings" as Route, label: "Ayarlar", icon: Settings },
  ],
  firma_admin: [
    { href: "/overview" as Route, label: "Genel Bakış", icon: LayoutDashboard },
    { href: "/users" as Route, label: "Kullanıcılar", icon: Users },
  ],
  bolge_muduru: [
    { href: "/overview" as Route, label: "Genel Bakış", icon: LayoutDashboard },
  ],
  sube_muduru: [
    { href: "/overview" as Route, label: "Genel Bakış", icon: LayoutDashboard },
    { href: "/shifts" as Route, label: "Vardiya", icon: Timer },
    { href: "/tasks" as Route, label: "Görev", icon: ClipboardList },
    { href: "/skt" as Route, label: "SKT Kontrol", icon: ShieldCheck },
    { href: "/products" as Route, label: "Ürün Listesi", icon: Package },
    { href: "/personnel" as Route, label: "Personel", icon: Users },
    { href: "/forms" as Route, label: "Form Kontrol", icon: FileCheck },
    { href: "/transfers" as Route, label: "Depolar Arası Sevk", icon: ArrowLeftRight },
    { href: "/merch" as Route, label: "Mörş", icon: ShoppingBag },
  ],
};

export function DashboardShell({ profile, children }: { profile: DashboardProfile; children: ReactNode }) {
  const pathname = usePathname();

  const links = useMemo(() => ROLE_NAVIGATION[profile.role] ?? [], [profile.role]);
  const displayName = [profile.first_name, profile.last_name].filter(Boolean).join(" ") || "Kullanıcı";

  return (
    <div className="app-shell">
      <aside className="sidebar" aria-label="Panel gezinme">
        <div className="sidebar-header">
          <h1>Yotech Panel</h1>
          <div className="sidebar-subtitle">{displayName}</div>
        </div>
        <nav className="sidebar-nav">
          {links.map((item) => {
            const Icon = item.icon;
            const isActive = pathname === item.href;
            return (
              <Link key={item.href} href={item.href} className={isActive ? "active" : undefined}>
                <Icon size={18} />
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="sidebar-footer">
          Rol: {profile.role.replace("_", " ")}
          <div style={{ marginTop: "12px" }}>
            <SignOutButton />
          </div>
        </div>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}
