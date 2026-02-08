"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import type { UrlObject } from "url";
import { Building2, Cog, PlusSquare, ShieldCheck, Users } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import type { TenantSummary } from "@/types/tenants";

type TenantAction = {
  key: string;
  label: string;
  description: string;
  icon: LucideIcon;
  getHref: (tenant: TenantSummary) => UrlObject;
};

const tenantActions: TenantAction[] = [
  {
    key: "modules",
    label: "Modül İzinlerini Yönet",
    description: "Tenant için aktif modülleri açın veya kapatın.",
    icon: ShieldCheck,
    getHref: (tenant) => ({ pathname: "/modules", query: { tenantId: tenant.id } }),
  },
  {
    key: "branches",
    label: "Şube Excel Şablonu",
    description: "Şube ve bağlı ekipleri içe aktarmak için Excel şablonunu indirin.",
    icon: Building2,
    getHref: (tenant) => ({ pathname: "/tenants/import", query: { focus: "branches", tenantId: tenant.id } }),
  },
  {
    key: "staff",
    label: "Personel Excel Şablonu",
    description: "Personel, yetki ve rol atamalarını içe aktarın.",
    icon: Users,
    getHref: (tenant) => ({ pathname: "/tenants/import", query: { focus: "staff", tenantId: tenant.id } }),
  },
  {
    key: "settings",
    label: "Tenant Ayarları",
    description: "Gelişmiş tenant ayarları ve Supabase seed işlemleri.",
    icon: Cog,
    getHref: (tenant) => ({ pathname: "/tenants", query: { tenantId: tenant.id, view: "settings" } }),
  },
];

export function TenantDirectory({ tenants }: { tenants: TenantSummary[] }) {
  const [selectedTenantId, setSelectedTenantId] = useState<string | null>(tenants[0]?.id ?? null);

  const selectedTenant = useMemo(
    () => tenants.find((tenant) => tenant.id === selectedTenantId) ?? null,
    [selectedTenantId, tenants],
  );

  return (
    <section className="tenant-directory">
      <aside className="tenant-directory__list">
        <header>
          <h3>Firmalar</h3>
          <p>{tenants.length} firma listelendi</p>
        </header>
        <ul>
          {tenants.map((tenant) => {
            const isActive = tenant.id === selectedTenantId;
            return (
              <li key={tenant.id}>
                <button
                  type="button"
                  className={isActive ? "tenant-directory__item active" : "tenant-directory__item"}
                  onClick={() => setSelectedTenantId(tenant.id)}
                >
                  <strong>{tenant.name}</strong>
                  <span>
                    {tenant.total_users} kullanıcı · {tenant.active_modules} aktif modül
                  </span>
                </button>
              </li>
            );
          })}
        </ul>
      </aside>

      <div className="tenant-directory__details">
        {selectedTenant ? (
          <div className="card tenant-directory__card">
            <header>
              <h3>{selectedTenant.name}</h3>
              <span className={selectedTenant.is_active ? "status-badge status-badge--success" : "status-badge"}>
                {selectedTenant.is_active ? "Aktif" : "Pasif"}
              </span>
            </header>
            <p>
              Firma kodu <strong>{selectedTenant.code}</strong>. Toplam {selectedTenant.total_users} kullanıcı ve
              {" "}
              {selectedTenant.active_modules} aktif modül bulunuyor.
            </p>

            <div className="tenant-directory__actions">
              {tenantActions.map((action) => {
                const Icon = action.icon;
                return (
                  <Link key={action.key} href={action.getHref(selectedTenant)} className="tenant-action">
                    <span className="tenant-action__icon">
                      <Icon size={18} />
                    </span>
                    <div>
                      <strong>{action.label}</strong>
                      <p>{action.description}</p>
                    </div>
                    <PlusSquare size={16} aria-hidden />
                  </Link>
                );
              })}
            </div>
          </div>
        ) : (
          <div className="card tenant-directory__card">
            <h3>Firma seçin</h3>
            <p>Detayları ve yönetim aksiyonlarını görmek için listeden bir firma seçin.</p>
          </div>
        )}
      </div>
    </section>
  );
}
