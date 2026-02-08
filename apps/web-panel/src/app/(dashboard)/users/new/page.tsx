"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import type { Database } from "@/lib/types/database";

const ROLES = [
  { value: "grand_admin", label: "Grand Admin" },
  { value: "firma_admin", label: "Firma Admin" },
  { value: "bolge_muduru", label: "Bölge Müdürü" },
  { value: "sube_muduru", label: "Şube Müdürü" },
  { value: "personel", label: "Personel" },
];

type Tenant = Pick<Database["public"]["Tables"]["tenants"]["Row"], "id" | "code" | "name" | "is_active">;
type Branch = Pick<Database["public"]["Tables"]["branches"]["Row"], "id" | "name" | "code">;

const CARD_STYLE = {
  borderRadius: 14,
  border: "1px solid rgba(255,255,255,0.12)",
  background: "linear-gradient(135deg, rgba(103,155,240,0.10), rgba(126,87,194,0.10))",
  boxShadow: "0 18px 50px rgba(0,0,0,0.16)",
  padding: "16px",
  backdropFilter: "blur(6px)",
};

const SECTION_TITLE_STYLE = {
  fontWeight: 700,
  fontSize: 13,
  marginBottom: 10,
  letterSpacing: 0.2,
};

const FIELD_LABEL_STYLE = {
  display: "flex",
  flexDirection: "column" as const,
  gap: "6px",
  fontSize: 12,
  fontWeight: 700,
};

const INPUT_STYLE = {
  width: "100%",
  borderRadius: 10,
  border: "1px solid rgba(255,255,255,0.16)",
  background: "rgba(255,255,255,0.16)",
  padding: "11px 12px",
  color: "var(--text-strong)",
  boxShadow: "inset 0 1px 0 rgba(255,255,255,0.1)",
};

export default function NewUserPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const tenantQuery = searchParams.get("tenantId") ?? "";

  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [selectedTenantId, setSelectedTenantId] = useState<string>(tenantQuery);

  const [form, setForm] = useState({
    first_name: "",
    last_name: "",
    email: "",
    role: "sube_muduru",
    branch_id: "",
    phone: "",
    employee_code: "",
    position: "",
    is_active: true,
    password: "",
  });

  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<{ type: "error" | "success"; text: string } | null>(null);

  const branchLookup = useMemo(() => {
    const map = new Map<string, Branch>();
    branches.forEach((b) => map.set(b.id, b));
    return map;
  }, [branches]);

  useEffect(() => {
    void loadTenants();
  }, []);

  useEffect(() => {
    if (!selectedTenantId) return;
    void loadBranches(selectedTenantId);
  }, [selectedTenantId]);

  const loadTenants = async () => {
    setMessage(null);
    const res = await fetch("/api/admin/user-directory/tenants");
    if (!res.ok) {
      setMessage({ type: "error", text: "Firmalar alınamadı" });
      return;
    }
    const data = (await res.json()) as { tenants: Tenant[] };
    setTenants(data.tenants);
    if (!selectedTenantId && data.tenants.length > 0) {
      setSelectedTenantId(data.tenants[0].id);
    }
  };

  const loadBranches = async (tenantId: string) => {
    const res = await fetch(`/api/admin/user-directory/branches?tenantId=${tenantId}`);
    if (!res.ok) {
      setMessage({ type: "error", text: "Şubeler alınamadı" });
      return;
    }
    const data = (await res.json()) as { branches: Branch[] };
    setBranches(data.branches);
  };

  const handleCreate = async () => {
    if (!selectedTenantId) return;
    setLoading(true);
    setMessage(null);
    const payload = {
      ...form,
      tenant_id: selectedTenantId,
      branch_id: form.branch_id || null,
    };
    const res = await fetch("/api/admin/user-directory/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setMessage({ type: "error", text: body.message ?? "Kullanıcı eklenemedi" });
      setLoading(false);
      return;
    }
    setMessage({ type: "success", text: "Kullanıcı eklendi" });
    setLoading(false);
    router.push("/users");
  };

  const selectedTenant = tenants.find((t) => t.id === selectedTenantId);

  return (
    <div className="page" style={{ maxWidth: 1320, margin: "0 auto" }}>
      <header className="page-header" style={{ marginBottom: 12 }}>
        <h2 style={{ display: "flex", alignItems: "center", gap: 10 }}>
          Personel Ekle
          <span style={{ fontSize: 12, padding: "4px 10px", borderRadius: 999, background: "linear-gradient(135deg, #6fc8ff, #9f7aea)", color: "#0c1024", fontWeight: 700 }}>
            Yeni kayıt
          </span>
        </h2>
        <p>Önce firma ve rolü belirleyin, ardından kullanıcı bilgilerini tamamlayın.</p>
      </header>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "16px" }}>
        <div style={CARD_STYLE}>
          <div style={SECTION_TITLE_STYLE}>Organizasyon</div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: "10px" }}>
            <label style={FIELD_LABEL_STYLE}>
              Firma
              <select value={selectedTenantId} onChange={(e) => setSelectedTenantId(e.target.value)} style={INPUT_STYLE}>
                {tenants.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.name} ({t.code})
                  </option>
                ))}
              </select>
            </label>
            <label style={FIELD_LABEL_STYLE}>
              Şube
              <select value={form.branch_id} onChange={(e) => setForm((p) => ({ ...p, branch_id: e.target.value }))} style={INPUT_STYLE}>
                <option value="">(Merkez)</option>
                {branches.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name} ({b.code})
                  </option>
                ))}
              </select>
            </label>
            <label style={FIELD_LABEL_STYLE}>
              Rol
              <select value={form.role} onChange={(e) => setForm((p) => ({ ...p, role: e.target.value }))} style={INPUT_STYLE}>
                {ROLES.map((r) => (
                  <option key={r.value} value={r.value}>
                    {r.label}
                  </option>
                ))}
              </select>
            </label>
            <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
              <span style={{ fontSize: 12, fontWeight: 700 }}>Durum</span>
              <label
                className="checkbox"
                style={{
                  alignItems: "center",
                  padding: "10px 12px",
                  border: "1px solid rgba(255,255,255,0.16)",
                  borderRadius: 10,
                  gap: "10px",
                  background: "linear-gradient(135deg, rgba(111,200,255,0.12), rgba(159,122,234,0.12))",
                }}
              >
                <input
                  type="checkbox"
                  checked={form.is_active}
                  onChange={(e) => setForm((p) => ({ ...p, is_active: e.target.checked }))}
                />
                Aktif
              </label>
            </div>
          </div>
          {selectedTenant ? (
            <div style={{ fontSize: 13, color: "var(--text-weak)", marginTop: 10 }}>
              Seçili firma: <strong>{selectedTenant.name}</strong> <span style={{ opacity: 0.6 }}>({selectedTenant.code})</span>
            </div>
          ) : null}
        </div>

        <div style={CARD_STYLE}>
          <div style={SECTION_TITLE_STYLE}>Kimlik</div>
          <div className="grid two" style={{ gap: "12px" }}>
            <label style={FIELD_LABEL_STYLE}>
              Ad
              <input value={form.first_name} onChange={(e) => setForm((p) => ({ ...p, first_name: e.target.value }))} style={INPUT_STYLE} />
            </label>
            <label style={FIELD_LABEL_STYLE}>
              Soyad
              <input value={form.last_name} onChange={(e) => setForm((p) => ({ ...p, last_name: e.target.value }))} style={INPUT_STYLE} />
            </label>
          </div>
        </div>

        <div style={CARD_STYLE}>
          <div style={SECTION_TITLE_STYLE}>İletişim</div>
          <div className="grid two" style={{ gap: "12px" }}>
            <label style={FIELD_LABEL_STYLE}>
              Email
              <input value={form.email} onChange={(e) => setForm((p) => ({ ...p, email: e.target.value }))} style={INPUT_STYLE} />
            </label>
            <label style={FIELD_LABEL_STYLE}>
              Telefon
              <input value={form.phone} onChange={(e) => setForm((p) => ({ ...p, phone: e.target.value }))} style={INPUT_STYLE} />
            </label>
          </div>
        </div>

        <div style={CARD_STYLE}>
          <div style={SECTION_TITLE_STYLE}>İş Bilgileri</div>
          <div className="grid two" style={{ gap: "12px" }}>
            <label style={FIELD_LABEL_STYLE}>
              Sicil / Kod
              <input value={form.employee_code} onChange={(e) => setForm((p) => ({ ...p, employee_code: e.target.value }))} style={INPUT_STYLE} />
            </label>
            <label style={FIELD_LABEL_STYLE}>
              Pozisyon
              <input value={form.position} onChange={(e) => setForm((p) => ({ ...p, position: e.target.value }))} style={INPUT_STYLE} />
            </label>
          </div>
        </div>

        <div style={CARD_STYLE}>
          <div style={SECTION_TITLE_STYLE}>Güvenlik</div>
          <label style={FIELD_LABEL_STYLE}>
            Parola (opsiyonel)
            <input value={form.password} onChange={(e) => setForm((p) => ({ ...p, password: e.target.value }))} style={INPUT_STYLE} />
          </label>
        </div>
      </div>

      {message ? <p className={`alert alert-${message.type}`} style={{ marginTop: 14 }}>{message.text}</p> : null}

      <div
        className="actions"
        style={{
          justifyContent: "flex-end",
          gap: "12px",
          paddingTop: "20px",
        }}
      >
        <button
          type="button"
          onClick={() => router.push("/users")}
          style={{
            borderRadius: 10,
            padding: "10px 14px",
            border: "1px solid rgba(255,255,255,0.16)",
            background: "rgba(255,255,255,0.12)",
            color: "var(--text-strong)",
            fontWeight: 700,
            boxShadow: "0 8px 20px rgba(0,0,0,0.12)",
          }}
        >
          Vazgeç
        </button>
        <button
          type="button"
          className="primary"
          onClick={handleCreate}
          disabled={loading || !selectedTenantId}
          style={{
            borderRadius: 10,
            padding: "10px 16px",
            fontWeight: 800,
            background: "linear-gradient(135deg, #6fc8ff, #9f7aea)",
            color: "#0c1024",
            border: "1px solid rgba(255,255,255,0.25)",
            boxShadow: "0 10px 26px rgba(111,200,255,0.35)",
          }}
        >
          {loading ? "Kaydediliyor" : "Kaydet"}
        </button>
      </div>
    </div>
  );
}
