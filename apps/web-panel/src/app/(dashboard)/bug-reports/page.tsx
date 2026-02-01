"use client";

import { useState, useEffect, useCallback } from "react";
import { toast } from "sonner";
import { CardActionButton, CardInlineActions, CardListShell, SoftBadge, cardStyles } from "@/components/ui/card-list";

interface BugReport {
  id: string;
  tenant_id: string | null;
  tenant_name: string | null;
  user_id: string;
  user_name: string | null;
  user_email: string | null;
  title: string;
  description: string;
  device_info: Record<string, unknown> | null;
  app_version: string | null;
  status: "open" | "in_progress" | "resolved" | "closed";
  priority: "low" | "normal" | "high" | "critical";
  admin_notes: string | null;
  resolved_by: string | null;
  resolved_by_name: string | null;
  resolved_at: string | null;
  created_at: string;
}

const STATUS_OPTIONS = [
  { value: "open", label: "Açık", tone: "info" as const },
  { value: "in_progress", label: "İşlemde", tone: "warn" as const },
  { value: "resolved", label: "Çözüldü", tone: "success" as const },
  { value: "closed", label: "Kapatıldı", tone: "muted" as const },
];

const PRIORITY_OPTIONS = [
  { value: "low", label: "Düşük", tone: "muted" as const },
  { value: "normal", label: "Normal", tone: "info" as const },
  { value: "high", label: "Yüksek", tone: "warn" as const },
  { value: "critical", label: "Kritik", tone: "danger" as const },
];

const emptyFilters = {
  status: "",
  priority: "",
  search: "",
};

export default function BugReportsPage() {
  const [reports, setReports] = useState<BugReport[]>([]);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState(emptyFilters);
  const [messageReport, setMessageReport] = useState<BugReport | null>(null);
  const [adminMessage, setAdminMessage] = useState("");
  const [updating, setUpdating] = useState(false);

  const fetchReports = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (filters.status) params.set("status", filters.status);

      const res = await fetch(`/api/bug-reports?${params.toString()}`);
      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.error || "Veriler alınamadı");
      }

      setReports(data.reports || []);
    } catch (err) {
      console.error("Failed to fetch bug reports:", err);
      toast.error(err instanceof Error ? err.message : "Veriler alınamadı");
    } finally {
      setLoading(false);
    }
  }, [filters.status]);

  useEffect(() => {
    fetchReports();
  }, [fetchReports]);

  const handleUpdateReport = async (
    reportId: string,
    updates: { status?: string; priority?: string; adminNotes?: string }
  ) => {
    setUpdating(true);
    try {
      const res = await fetch("/api/bug-reports", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ reportId, ...updates }),
      });

      if (res.ok) {
        toast.success("Güncellendi");
        await fetchReports();
      } else {
        toast.error("Güncelleme başarısız");
      }
    } catch {
      toast.error("Güncelleme başarısız");
    } finally {
      setUpdating(false);
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString("tr-TR", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  const handleFilter = (field: keyof typeof emptyFilters, value: string) => {
    setFilters((prev) => ({ ...prev, [field]: value }));
  };

  // Filter reports
  const filteredReports = reports.filter((report) => {
    if (filters.priority && report.priority !== filters.priority) return false;
    if (filters.search) {
      const searchLower = filters.search.toLowerCase();
      const matchTitle = report.title.toLowerCase().includes(searchLower);
      const matchDesc = report.description.toLowerCase().includes(searchLower);
      const matchUser = (report.user_name || "").toLowerCase().includes(searchLower);
      if (!matchTitle && !matchDesc && !matchUser) return false;
    }
    return true;
  });

  const stats = {
    total: reports.length,
    open: reports.filter((r) => r.status === "open").length,
    inProgress: reports.filter((r) => r.status === "in_progress").length,
    resolved: reports.filter((r) => r.status === "resolved").length,
  };

  const filterContent = (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 10 }}>
      <input
        className="filter-input"
        placeholder="Ara (başlık, açıklama, kullanıcı)"
        value={filters.search}
        onChange={(e) => handleFilter("search", e.target.value)}
      />
      <select
        className="filter-input"
        value={filters.status}
        onChange={(e) => handleFilter("status", e.target.value)}
      >
        <option value="">Tüm Durumlar</option>
        {STATUS_OPTIONS.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
      <select
        className="filter-input"
        value={filters.priority}
        onChange={(e) => handleFilter("priority", e.target.value)}
      >
        <option value="">Tüm Öncelikler</option>
        {PRIORITY_OPTIONS.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </div>
  );

  const filterPills = [
    filters.search ? { label: `Arama: ${filters.search}` } : null,
    filters.status ? { label: `Durum: ${STATUS_OPTIONS.find((s) => s.value === filters.status)?.label}` } : null,
    filters.priority ? { label: `Öncelik: ${PRIORITY_OPTIONS.find((p) => p.value === filters.priority)?.label}` } : null,
  ].filter(Boolean) as { label: string }[];

  const cards = filteredReports.map((report) => {
    const statusOpt = STATUS_OPTIONS.find((s) => s.value === report.status) || STATUS_OPTIONS[0];
    const priorityOpt = PRIORITY_OPTIONS.find((p) => p.value === report.priority) || PRIORITY_OPTIONS[1];

    return (
      <div key={report.id} style={{ ...cardStyles.row, alignItems: "flex-start", padding: "16px 18px" }}>
        {/* Sol: Ana Bilgiler */}
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          <div style={{ fontWeight: 800, fontSize: 15 }}>{report.title}</div>
          <div style={{ color: "var(--text-subtle)", fontSize: 13, lineHeight: 1.5, maxWidth: 400 }}>
            {report.description.length > 120 ? `${report.description.slice(0, 120)}...` : report.description}
          </div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginTop: 4 }}>
            <SoftBadge tone={statusOpt.tone} label={statusOpt.label} />
            <SoftBadge tone={priorityOpt.tone} label={`Öncelik: ${priorityOpt.label}`} />
          </div>
        </div>

        {/* Orta: Kullanıcı & Firma Bilgileri */}
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <div style={{ ...cardStyles.avatar, width: 36, height: 36, fontSize: 12 }}>
              {(report.user_name || "?").charAt(0).toUpperCase()}
            </div>
            <div>
              <div style={{ fontWeight: 600, fontSize: 13 }}>{report.user_name || "Bilinmeyen"}</div>
              <div style={{ color: "var(--text-subtle)", fontSize: 12 }}>{report.user_email || "-"}</div>
            </div>
          </div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginTop: 4 }}>
            <SoftBadge tone="muted" label={report.tenant_name || "Firma yok"} />
            <SoftBadge tone="info" label={`v${report.app_version || "?"}`} />
          </div>
          <div style={{ color: "var(--text-subtle)", fontSize: 11, marginTop: 4 }}>
            📅 {formatDate(report.created_at)}
          </div>
        </div>

        {/* Sağ: Aksiyonlar */}
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 8 }}>
          <CardInlineActions>
            {report.status === "open" && (
              <CardActionButton
                tone="warn"
                label="İşleme Al"
                onClick={() => handleUpdateReport(report.id, { status: "in_progress" })}
                disabled={updating}
              />
            )}
            {report.status === "in_progress" && (
              <CardActionButton
                tone="success"
                label="Çözüldü"
                onClick={() => handleUpdateReport(report.id, { status: "closed" })}
                disabled={updating}
              />
            )}
            {(report.status === "open" || report.status === "in_progress") && (
              <CardActionButton
                tone="info"
                label="Mesaj Gönder"
                onClick={() => {
                  setMessageReport(report);
                  setAdminMessage("");
                }}
              />
            )}
          </CardInlineActions>
        </div>
      </div>
    );
  });

  return (
    <>
      <CardListShell
        title="🐛 Hata Bildirimleri"
        description="Kullanıcılardan gelen hata ve öneri bildirimleri"
        stats={[
          { label: "Toplam", value: stats.total },
          { label: "Açık", value: stats.open },
          { label: "İşlemde", value: stats.inProgress },
          { label: "Çözüldü", value: stats.resolved },
        ]}
        actions={
          <>
            <CardActionButton tone="muted" label="Filtreleri Sıfırla" onClick={() => setFilters(emptyFilters)} />
            <CardActionButton tone="info" label="Yenile" onClick={fetchReports} disabled={loading} />
          </>
        }
        filterContent={filterContent}
        pills={filterPills}
      >
        {loading && <p>Yükleniyor...</p>}

        {!loading && filteredReports.length === 0 && (
          <div style={{ textAlign: "center", padding: 40 }}>
            <div style={{ fontSize: 48, marginBottom: 16 }}>🎉</div>
            <p style={{ color: "var(--text-subtle)" }}>Hata bildirimi bulunamadı.</p>
          </div>
        )}

        {!loading && <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>{cards}</div>}
      </CardListShell>

      {/* Mesaj Gönder Modalı - Custom CSS Modal */}
      {messageReport && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            zIndex: 9999,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            backgroundColor: "rgba(0, 0, 0, 0.4)",
            backdropFilter: "blur(4px)",
          }}
          onClick={() => setMessageReport(null)}
        >
          <div
            style={{
              background: "#ffffff",
              borderRadius: 16,
              padding: 24,
              maxWidth: 500,
              width: "90%",
              boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.25)",
              border: "1px solid #e2e8f0",
              color: "#1e293b",
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
              <h3 style={{ margin: 0, fontSize: 18, fontWeight: 700, color: "#1e293b" }}>💬 Kullanıcıya Mesaj Gönder</h3>

              {/* Report Info */}
              <div
                style={{
                  background: "#f8fafc",
                  borderRadius: 12,
                  padding: 14,
                  border: "1px solid #e2e8f0",
                }}
              >
                <div style={{ fontWeight: 600, marginBottom: 8, color: "#334155" }}>{messageReport.title}</div>
                <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                  <SoftBadge tone="muted" label={messageReport.user_name || "Bilinmeyen"} />
                  <SoftBadge tone="info" label={messageReport.tenant_name || "Firma yok"} />
                </div>
              </div>

              {/* Message Input */}
              <div>
                <label style={{ fontWeight: 600, display: "block", marginBottom: 8, color: "#334155" }}>📝 Mesajınız</label>
                <textarea
                  value={adminMessage}
                  onChange={(e) => setAdminMessage(e.target.value)}
                  placeholder="Kullanıcıya göndermek istediğiniz mesajı yazın..."
                  rows={4}
                  style={{
                    width: "100%",
                    resize: "vertical",
                    padding: 12,
                    borderRadius: 10,
                    border: "1px solid #cbd5e1",
                    background: "#ffffff",
                    color: "#1e293b",
                    fontSize: 14,
                    outline: "none",
                  }}
                />
              </div>

              {/* Actions */}
              <div style={{ display: "flex", justifyContent: "space-between", marginTop: 8 }}>
                <CardActionButton tone="muted" label="İptal" onClick={() => setMessageReport(null)} />
                <CardActionButton
                  tone="success"
                  label="Mesaj Gönder"
                  onClick={async () => {
                    if (!adminMessage.trim()) {
                      toast.error("Lütfen bir mesaj yazın");
                      return;
                    }
                    setUpdating(true);
                    try {
                      const res = await fetch("/api/bug-reports", {
                        method: "PATCH",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({
                          reportId: messageReport.id,
                          sendMessage: true,
                          message: adminMessage.trim(),
                        }),
                      });
                      if (res.ok) {
                        toast.success("Mesaj kullanıcıya gönderildi");
                        setMessageReport(null);
                        await fetchReports();
                      } else {
                        toast.error("Mesaj gönderilemedi");
                      }
                    } catch {
                      toast.error("Mesaj gönderilemedi");
                    } finally {
                      setUpdating(false);
                    }
                  }}
                  disabled={updating || !adminMessage.trim()}
                />
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
