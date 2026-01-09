"use client";

import { useEffect, useMemo, useState } from "react";
import { Activity, CheckCircle2, Database, Gauge, Users, WifiOff } from "lucide-react";

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

type OverviewPayload = {
  stats: OverviewStats;
  tenants: TenantSummary[];
  updatedAt?: string;
};

function useOverviewData() {
  const [data, setData] = useState<OverviewPayload | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    async function load() {
      setLoading(true);
      setError(null);
      try {
        const res = await fetch("/api/admin/overview", { signal: controller.signal });
        if (!res.ok) {
          setError("Veri alınamadı");
          return;
        }
        const body = (await res.json()) as OverviewPayload;
        setData(body);
      } catch (err) {
        if ((err as DOMException)?.name === "AbortError") return;
        setError("Veri alınamadı");
      } finally {
        setLoading(false);
      }
    }
    void load();
    return () => controller.abort();
  }, []);

  return { data, loading, error };
}

export function OperationsPanel() {
  const { data, loading, error } = useOverviewData();
  const stats = data?.stats;
  const tenants = useMemo(() => (data?.tenants ?? []).slice(0, 10), [data?.tenants]);

  return (
    <div className="page">
      <header className="page-header">
        <h2>Operasyon</h2>
        <p>Aktif tenant, şube ve kullanıcı metrikleri Supabase kayıtlarından çekildi.</p>
        {error ? <p className="alert alert-error">{error}</p> : null}
      </header>

      <section className="section-grid three">
        <StatCard
          icon={Database}
          label="Aktif Tenant"
          value={stats ? `${stats.activeTenants} / ${stats.totalTenants}` : "-"}
          hint="Canlı tenant sayısı"
        />
        <StatCard
          icon={Users}
          label="Kullanıcılar"
          value={stats ? `${stats.activeUsers} / ${stats.totalUsers}` : "-"}
          hint="Aktif / toplam"
        />
        <StatCard
          icon={Gauge}
          label="Şubeler"
          value={stats ? `${stats.activeBranches} / ${stats.totalBranches}` : "-"}
          hint="Aktif / toplam"
        />
      </section>

      <section className="card">
        <h3>Tenant Listesi</h3>
        <p>İlk 10 tenant kullanıcı sayısına göre sıralandı.</p>
        <ul className="list">
          {loading && tenants.length === 0 ? <li className="list-item">Yükleniyor...</li> : null}
          {tenants.map((t) => (
            <li key={t.id} className="list-item">
              <div>
                <strong>{t.name ?? "İsimsiz"}</strong>
                <div className="time-stamp">{t.branchCount} şube · {t.userCount} kullanıcı</div>
              </div>
              <div className="badge">{t.code ?? "-"}</div>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

export function ObservabilityPanel() {
  const { data, loading, error } = useOverviewData();
  const stats = data?.stats;
  const updatedAt = data?.updatedAt ? new Date(data.updatedAt) : null;
  const activeUserRatio = stats && stats.totalUsers > 0 ? Math.round((stats.activeUsers / stats.totalUsers) * 100) : null;

  return (
    <div className="page">
      <header className="page-header">
        <h2>Gözlemlenebilirlik</h2>
        <p>API ve veri sağlık durumunu Supabase üzerinden özetliyoruz.</p>
        {error ? <p className="alert alert-error">{error}</p> : null}
      </header>

      <section className="section-grid three">
        <StatCard
          icon={CheckCircle2}
          label="API Sağlığı"
          value="HTTP 200"
          hint="/api/admin/overview"
        />
        <StatCard
          icon={Activity}
          label="Aktif Kullanıcı Oranı"
          value={activeUserRatio !== null ? `${activeUserRatio}%` : "-"}
          hint={stats ? `${stats.activeUsers} / ${stats.totalUsers}` : "-"}
        />
        <StatCard
          icon={Database}
          label="Veri Güncelleme"
          value={updatedAt ? updatedAt.toLocaleString() : loading ? "Yükleniyor" : "-"}
          hint="Supabase"
        />
      </section>

      <section className="card">
        <h3>Durum Özeti</h3>
        <ul className="list">
          <li className="list-item">
            <div>
              <strong>Aktif Kullanıcılar</strong>
              <div className="time-stamp">{stats ? stats.activeUsers : "-"}</div>
            </div>
            <div className="badge">Supabase</div>
          </li>
          <li className="list-item">
            <div>
              <strong>Aktif Şubeler</strong>
              <div className="time-stamp">{stats ? stats.activeBranches : "-"}</div>
            </div>
            <div className="badge">Şube</div>
          </li>
          <li className="list-item">
            <div>
              <strong>Aktif Tenant</strong>
              <div className="time-stamp">{stats ? stats.activeTenants : "-"}</div>
            </div>
            <div className="badge">Canlı</div>
          </li>
        </ul>
      </section>

      <section className="card">
        <h3>Uyarılar</h3>
        <p>Uyarı beslemesi hazır değil. Hata yakalanırsa burada listelenecek.</p>
        <div className="list">
          {error ? (
            <div className="list-item">
              <WifiOff size={16} />
              <span>Veri alınamadı</span>
            </div>
          ) : (
            <div className="list-item">
              <CheckCircle2 size={16} />
              <span>Şimdilik sorun yok</span>
            </div>
          )}
        </div>
      </section>
    </div>
  );
}

function StatCard({ icon: Icon, label, value, hint }: { icon: typeof Database; label: string; value: string; hint?: string }) {
  return (
    <article className="card">
      <Icon size={22} color="#6366F1" />
      <div className="stat-value">{value}</div>
      <div>{label}</div>
      {hint ? <div className="stat-trend">{hint}</div> : null}
    </article>
  );
}
