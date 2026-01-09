"use client";

import {
  Activity,
  Building,
  CircuitBoard,
  Database,
  ShieldCheck,
  SquarePen,
  Users,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";

type OverviewStats = {
  totalTenants: number;
  activeTenants: number;
  totalBranches: number;
  activeBranches: number;
  totalUsers: number;
  activeUsers: number;
};

type TenantSummary = {
  id: string;
  name: string | null;
  code: string | null;
  active: boolean | null;
  branchCount: number;
  userCount: number;
};

const quickActions = [
  {
    icon: Building,
    title: "Yeni Firma Kaydı",
    description: "Yeni bir tenant oluşturun, modülleri ve alt kullanıcıları tanımlayın.",
  },
  {
    icon: Users,
    title: "Kullanıcı Yetkileri",
    description: "Firma, bölge ve mağaza rollerine göre erişim izinlerini güncelleyin.",
  },
  {
    icon: Database,
    title: "Supabase Yönetimi",
    description: "Edge Function, RLS politikaları ve planlanan migrasyonları takip edin.",
  },
  {
    icon: SquarePen,
    title: "Modül Yetkilendirme",
    description: "Tenant özelinde aktif modülleri seçerek panel ve mobil deneyimi şekillendirin.",
  },
];

export function GrandAdminOverview() {
  const [stats, setStats] = useState<OverviewStats | null>(null);
  const [tenants, setTenants] = useState<TenantSummary[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [updatedAt, setUpdatedAt] = useState<string | null>(null);

  useEffect(() => {
    const controller = new AbortController();

    async function load() {
      setLoading(true);
      setError(null);
      try {
        const res = await fetch("/api/admin/overview", { signal: controller.signal });
        if (!res.ok) {
          setError("Genel bakış verisi alınamadı");
          return;
        }
        const data = (await res.json()) as { stats: OverviewStats; tenants: TenantSummary[]; updatedAt?: string };
        setStats(data.stats);
        setTenants(data.tenants ?? []);
        setUpdatedAt(data.updatedAt ?? null);
      } catch (err) {
        if ((err as DOMException)?.name === "AbortError") return;
        setError("Genel bakış verisi alınamadı");
      } finally {
        setLoading(false);
      }
    }

    void load();
    return () => controller.abort();
  }, []);

  const statCards = useMemo(() => {
    if (!stats) {
      return [
        { label: "Aktif Tenant", value: "-", trend: "", icon: Building },
        { label: "Toplam Kullanıcı", value: "-", trend: "", icon: Users },
        { label: "Toplam Şube", value: "-", trend: "", icon: CircuitBoard },
      ];
    }
    return [
      { label: "Aktif Tenant", value: String(stats.activeTenants), trend: `Toplam ${stats.totalTenants}`, icon: Building },
      { label: "Toplam Kullanıcı", value: String(stats.totalUsers), trend: `${stats.activeUsers} aktif`, icon: Users },
      { label: "Toplam Şube", value: String(stats.totalBranches), trend: `${stats.activeBranches} aktif`, icon: CircuitBoard },
    ];
  }, [stats]);

  const tenantSummary = useMemo(() => tenants.slice(0, 10), [tenants]);

  return (
    <>
      <header className="page-header">
        <h2>Grand Admin Panosu</h2>
        <p>
          Yeni tenant açılışları, Supabase altyapı sağlığı ve modül yetkilendirmeleri bu panel
          üzerinden yönetilir. Aşağıdaki yapı, canlı veriler bağlandığında operasyonel kontrol
          merkezi olarak hizmet verecek.
        </p>
        {error ? <p className="alert alert-error">{error}</p> : null}
      </header>

      <section className="section-grid three">
        {statCards.map((card) => (
          <article key={card.label} className="card">
            <card.icon size={24} color="#6366F1" />
            <div className="stat-value">{card.value}</div>
            <div>{card.label}</div>
            <div className="stat-trend">{card.trend}</div>
          </article>
        ))}
      </section>

      <section className="card">
        <h3>Tenant Genel Görünüm</h3>
        <p>Öne çıkan organizasyonlar, bağlı şube ve kullanıcı adetleri.</p>
        <ul className="list">
          {loading && tenants.length === 0 ? <li className="list-item">Yükleniyor...</li> : null}
          {tenantSummary.map((tenant) => (
            <li key={tenant.id} className="list-item">
              <div>
                <strong>{tenant.name ?? "İsimsiz"}</strong>
                <div className="time-stamp">{tenant.branchCount} şube · {tenant.userCount} kullanıcı</div>
              </div>
              <div className="badge">{tenant.code ?? "-"}</div>
            </li>
          ))}
        </ul>
      </section>

      <section className="card">
        <h3>Modül İzin Çerçevesi</h3>
        <p>
          Tenant bazlı modül erişimi bu bölümden yönetilir. Yakında Supabase fonksiyon çağrıları ile
          senkronize edilecek.
        </p>
        <div className="quick-actions">
          {quickActions.map((action) => (
            <div key={action.title} className="quick-action">
              <span className="icon-pill">
                <action.icon size={18} />
              </span>
              <div>
                <strong>{action.title}</strong>
                <span>{action.description}</span>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="section-grid two">
        <article className="card">
          <h3>Operasyon</h3>
          <p>Tenant, şube ve kullanıcı sayıları üretim verisinden çekildi.</p>
          <ul className="list">
            <li className="list-item">
              <div>
                <strong>Aktif Tenant</strong>
                <div className="time-stamp">{stats ? `${stats.activeTenants} / ${stats.totalTenants}` : "-"}</div>
              </div>
              <div className="badge">Canlı</div>
            </li>
            <li className="list-item">
              <div>
                <strong>Kullanıcılar</strong>
                <div className="time-stamp">{stats ? `${stats.activeUsers} aktif / ${stats.totalUsers} toplam` : "-"}</div>
              </div>
              <div className="badge">Supabase</div>
            </li>
            <li className="list-item">
              <div>
                <strong>Şubeler</strong>
                <div className="time-stamp">{stats ? `${stats.activeBranches} aktif / ${stats.totalBranches} toplam` : "-"}</div>
              </div>
              <div className="badge">Şube</div>
            </li>
          </ul>
        </article>

        <article className="card">
          <h3>Gözlemlenebilirlik</h3>
          <p>Özet metrikler Supabase kayıtlarından çekiliyor, API sağlığı izleniyor.</p>
          <ul className="list">
            <li className="list-item">
              <div>
                <strong>Veri Güncelleme</strong>
                <div className="time-stamp">{updatedAt ? new Date(updatedAt).toLocaleString() : loading ? "Yükleniyor" : "-"}</div>
              </div>
              <div className="badge">Supabase</div>
            </li>
            <li className="list-item">
              <div>
                <strong>API Durumu</strong>
                <div className="time-stamp">HTTP 200 /api/admin/overview</div>
              </div>
              <div className="badge">API</div>
            </li>
            <li className="list-item">
              <div>
                <strong>Aktif Kullanıcı Oranı</strong>
                <div className="time-stamp">
                  {stats && stats.totalUsers > 0 ? `${Math.round((stats.activeUsers / stats.totalUsers) * 100)}%` : "-"}
                </div>
              </div>
              <div className="badge">Durum</div>
            </li>
          </ul>
        </article>
      </section>

      <section className="card">
        <h3>Yapılandırma Notları</h3>
        <p>
          Rol bazlı layout, Supabase session-provider ile beslenecek. Onboarding için kontrol
          listesi, kişisel erişim anahtarları ve otomatik audit logları bu bölümde toplanacak.
        </p>
      </section>
    </>
  );
}
