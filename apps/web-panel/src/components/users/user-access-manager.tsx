"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import type { Database } from "@/lib/types/database";

type Tenant = Pick<Database["public"]["Tables"]["tenants"]["Row"], "id" | "code" | "name" | "active">;
type Branch = Pick<Database["public"]["Tables"]["branches"]["Row"], "id" | "name" | "code">;
type UserRow = Pick<
  Database["public"]["Tables"]["users"]["Row"],
  "id" | "tenant_id" | "branch_id" | "role" | "first_name" | "last_name" | "email" | "phone" | "employee_code" | "position" | "active"
>;

const ROLES = [
  { value: "grand_admin", label: "Grand Admin" },
  { value: "firma_admin", label: "Firma Admin" },
  { value: "bolge_muduru", label: "Bölge Müdürü" },
  { value: "sube_muduru", label: "Şube Müdürü" },
];

const CARD_ROW_STYLE = {
  display: "grid",
  gridTemplateColumns: "1.4fr 1fr auto",
  gap: "12px",
  alignItems: "center",
  padding: "14px",
  borderRadius: 14,
  border: "1px solid var(--surface-strong-border)",
  background: "linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02))",
  boxShadow: "0 8px 24px rgba(0,0,0,0.14)",
};

const ROLE_BADGE_STYLE: Record<string, React.CSSProperties> = {
  grand_admin: { background: "rgba(79, 70, 229, 0.16)", color: "#1e1b4b", border: "1px solid rgba(79,70,229,0.45)" },
  firma_admin: { background: "rgba(16, 185, 129, 0.16)", color: "#065f46", border: "1px solid rgba(16,185,129,0.38)" },
  bolge_muduru: { background: "rgba(234,179,8,0.16)", color: "#713f12", border: "1px solid rgba(234,179,8,0.38)" },
  sube_muduru: { background: "rgba(14,165,233,0.16)", color: "#0f355a", border: "1px solid rgba(14,165,233,0.42)" },
  personel: { background: "rgba(148,163,184,0.18)", color: "#1f2937", border: "1px solid rgba(148,163,184,0.38)" },
};

const STATUS_PILL = {
  active: { background: "rgba(34,197,94,0.16)", color: "#166534", border: "1px solid rgba(34,197,94,0.38)" },
  passive: { background: "rgba(248,113,113,0.16)", color: "#7f1d1d", border: "1px solid rgba(248,113,113,0.4)" },
};

const AVATAR_STYLE = {
  width: 42,
  height: 42,
  borderRadius: "50%",
  background: "linear-gradient(135deg, #7c3aed, #2563eb)",
  color: "#fff",
  display: "grid",
  placeItems: "center" as const,
  fontWeight: 800,
  letterSpacing: 0.4,
};
const SORT_OPTIONS = [
  { value: "name_asc", label: "İsim A-Z" },
  { value: "name_desc", label: "İsim Z-A" },
  { value: "branch_asc", label: "Şube A-Z" },
  { value: "branch_desc", label: "Şube Z-A" },
];

const ROLE_FILTER_OPTIONS = [
  { value: "", label: "Tüm roller" },
  { value: "grand_admin", label: "Grand Admin" },
  { value: "firma_admin", label: "Firma Admin" },
  { value: "bolge_muduru", label: "Bölge Müdürü" },
  { value: "sube_muduru", label: "Şube Müdürü" },
  { value: "personel", label: "Personel" },
];

const HEADER_CARD_STYLE = {
  display: "flex",
  flexWrap: "wrap" as const,
  alignItems: "center",
  justifyContent: "space-between",
  gap: "12px",
  padding: "14px",
  borderRadius: 14,
  background: "linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.03))",
  border: "1px solid var(--surface-strong-border)",
  boxShadow: "0 10px 30px rgba(0,0,0,0.18)",
};

const HEADER_SELECT_BOX_STYLE = {
  display: "flex",
  flexDirection: "column" as const,
  gap: "6px",
  padding: "10px 12px",
  borderRadius: 10,
  background: "rgba(255,255,255,0.03)",
  border: "1px solid var(--surface-strong-border)",
  minWidth: "240px",
};

const TENANT_PILL_STYLE = {
  display: "inline-flex",
  alignItems: "center",
  gap: "6px",
  padding: "8px 12px",
  borderRadius: 999,
  background: "rgba(255,255,255,0.08)",
  border: "1px solid rgba(255,255,255,0.12)",
  fontWeight: 600,
  color: "var(--text-strong)",
};

const FILTER_CARD_STYLE = {
  display: "flex",
  flexDirection: "column" as const,
  gap: "12px",
  padding: "16px",
  marginBottom: "12px",
  borderRadius: 16,
  background: "linear-gradient(145deg, rgba(255,255,255,0.08), rgba(255,255,255,0.03))",
  border: "1px solid rgba(255,255,255,0.12)",
  boxShadow: "0 14px 36px rgba(0,0,0,0.18)",
};

const FILTER_FIELD_STYLE = {
  display: "flex",
  flexDirection: "column" as const,
  gap: "6px",
  padding: "10px 12px",
  borderRadius: 12,
  border: "1px solid rgba(255,255,255,0.12)",
  background: "rgba(255,255,255,0.06)",
  boxShadow: "inset 0 1px 0 rgba(255,255,255,0.08), 0 6px 18px rgba(0,0,0,0.08)",
};

const FILTER_PILL_STYLE = {
  display: "inline-flex",
  alignItems: "center",
  padding: "6px 10px",
  borderRadius: 999,
  background: "rgba(255,255,255,0.1)",
  border: "1px solid rgba(255,255,255,0.2)",
  fontSize: 12,
  fontWeight: 700,
  color: "var(--text-strong)",
};

const INPUT_STYLE = {
  width: "100%",
  borderRadius: 10,
  border: "1px solid rgba(255,255,255,0.28)",
  background: "rgba(255,255,255,0.22)",
  padding: "11px 12px",
  color: "var(--text-strong)",
  boxShadow: "inset 0 1px 0 rgba(255,255,255,0.14), 0 6px 16px rgba(0,0,0,0.08)",
};

const ACTION_BUTTON = {
  padding: "10px 14px",
  borderRadius: 12,
  border: "1px solid rgba(255,255,255,0.22)",
  background: "linear-gradient(135deg, #4f9cff, #7f5dff)",
  color: "#fff",
  fontWeight: 700,
  boxShadow: "0 12px 30px rgba(0,0,0,0.18)",
};

const ACTION_BUTTON_GHOST = {
  padding: "10px 14px",
  borderRadius: 12,
  border: "1px solid rgba(255,255,255,0.22)",
  background: "rgba(255,255,255,0.08)",
  color: "var(--text-strong)",
  fontWeight: 700,
  boxShadow: "0 8px 20px rgba(0,0,0,0.12)",
};

const ACTION_BUTTON_DANGER = {
  padding: "10px 14px",
  borderRadius: 12,
  border: "1px solid rgba(248,113,113,0.4)",
  background: "linear-gradient(135deg, rgba(248,113,113,0.16), rgba(248,113,113,0.32))",
  color: "#7f1d1d",
  fontWeight: 800,
  boxShadow: "0 10px 26px rgba(248,113,113,0.2)",
};

export function UserAccessManager() {
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [users, setUsers] = useState<UserRow[]>([]);
  const [selectedTenantId, setSelectedTenantId] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [message, setMessage] = useState<{ type: "error" | "success"; text: string } | null>(null);

  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState<Partial<UserRow> | null>(null);
  const longPressTimer = useRef<NodeJS.Timeout | null>(null);

  const [branchFilter, setBranchFilter] = useState<string>("");
  const [roleFilter, setRoleFilter] = useState<string>("");
  const [searchTerm, setSearchTerm] = useState<string>("");
  const [sortKey, setSortKey] = useState<(typeof SORT_OPTIONS)[number]["value"]>("name_asc");
  const [pageSize, setPageSize] = useState<number>(100);
  const [page, setPage] = useState<number>(1);
  const [total, setTotal] = useState<number>(0);
  const [pageCount, setPageCount] = useState<number>(1);

  const renderPagination = () => (
    <div
      style={{
        display: "flex",
        flexWrap: "wrap",
        gap: "12px",
        alignItems: "center",
        justifyContent: "flex-end",
        marginTop: "8px",
      }}
    >
      <span>
        Gösterilen {users.length} / {total}
      </span>
      <div style={{ display: "flex", gap: "8px", alignItems: "center", flexWrap: "wrap" }}>
        <button type="button" onClick={() => setPage(1)} disabled={page === 1}>
          İlk
        </button>
        <button type="button" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page === 1}>
          Önceki
        </button>
        <span>
          Sayfa {page} / {pageCount}
        </span>
        <button type="button" onClick={() => setPage((p) => Math.min(pageCount, p + 1))} disabled={page === pageCount}>
          Sonraki
        </button>
        <button type="button" onClick={() => setPage(pageCount)} disabled={page === pageCount}>
          Son
        </button>
      </div>
    </div>
  );

  const router = useRouter();

  const branchLookup = useMemo(() => {
    const map = new Map<string, Branch>();
    branches.forEach((b) => map.set(b.id, b));
    return map;
  }, [branches]);

  const handleOpenCreate = () => {
    if (!selectedTenantId) return;
    const url = `/users/new${selectedTenantId ? `?tenantId=${selectedTenantId}` : ""}`;
    router.push(url);
  };

  const activeFilters = useMemo(() => {
    const items: string[] = [];
    if (branchFilter) {
      const branchName = branchLookup.get(branchFilter)?.name ?? "Şube";
      items.push(`Şube: ${branchName}`);
    }
    if (roleFilter) {
      const roleLabel = ROLE_FILTER_OPTIONS.find((r) => r.value === roleFilter)?.label ?? roleFilter;
      items.push(`Rol: ${roleLabel}`);
    }
    if (searchTerm.trim()) {
      items.push(`Arama: ${searchTerm.trim()}`);
    }
    const sortLabel = SORT_OPTIONS.find((opt) => opt.value === sortKey)?.label;
    if (sortLabel && sortKey !== "name_asc") {
      items.push(`Sıralama: ${sortLabel}`);
    }
    return items;
  }, [branchFilter, roleFilter, searchTerm, sortKey, branchLookup]);

  const clearFilters = () => {
    setBranchFilter("");
    setRoleFilter("");
    setSearchTerm("");
    setSortKey("name_asc");
    setPage(1);
  };

  useEffect(() => {
    setPage(1);
  }, [branchFilter, roleFilter, searchTerm, sortKey, pageSize, selectedTenantId]);

  useEffect(() => {
    void loadTenants();
  }, []);

  const loadTenants = async () => {
    setMessage(null);
    const res = await fetch("/api/admin/user-directory/tenants");
    if (!res.ok) {
      setMessage({ type: "error", text: "Firmalar alınamadı" });
      return;
    }
    const data = (await res.json()) as { tenants: Tenant[] };
    setTenants(data.tenants);
    if (data.tenants.length > 0) {
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

  const loadUsers = async (tenantId: string, opts?: { signal?: AbortSignal }) => {
    try {
      setLoading(true);
      const params = new URLSearchParams();
      params.set("tenantId", tenantId);
      if (branchFilter) params.set("branchId", branchFilter);
      if (roleFilter) params.set("role", roleFilter);
      if (searchTerm.trim()) params.set("search", searchTerm.trim());
      params.set("sort", sortKey);
      params.set("page", String(page));
      params.set("pageSize", String(pageSize));

      const res = await fetch(`/api/admin/user-directory/users?${params.toString()}`, { signal: opts?.signal });
      if (!res.ok) {
        setMessage({ type: "error", text: "Kullanıcılar alınamadı" });
        return;
      }
      const data = (await res.json()) as { users: UserRow[]; total: number; page: number; pageSize: number; pageCount: number };
      setUsers(data.users);
      setTotal(data.total ?? 0);
      setPageCount(data.pageCount ?? 1);
      if (data.page && data.page !== page) {
        setPage(data.page);
      }
    } catch (err) {
      if ((err as DOMException)?.name === "AbortError") return;
      setMessage({ type: "error", text: "Kullanıcılar alınamadı" });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!selectedTenantId) return;
    void loadBranches(selectedTenantId);
  }, [selectedTenantId]);

  useEffect(() => {
    if (!selectedTenantId) return;
    const controller = new AbortController();
    void loadUsers(selectedTenantId, { signal: controller.signal });
    return () => controller.abort();
  }, [selectedTenantId, branchFilter, roleFilter, searchTerm, sortKey, pageSize, page]);

  const filteredUsers = useMemo(() => {
    if (!roleFilter) return users;
    return users.filter((u) => u.role === roleFilter);
  }, [users, roleFilter]);

  const handleUpdate = async (id: string, patch: Partial<UserRow>) => {
    setSavingId(id);
    setMessage(null);
    const res = await fetch("/api/admin/user-directory/users", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id, ...patch }),
    });
    setSavingId(null);
    if (!res.ok) {
      setMessage({ type: "error", text: "Güncelleme başarısız" });
      return;
    }
    setUsers((prev) => prev.map((u) => (u.id === id ? { ...u, ...patch } : u)));
    setMessage({ type: "success", text: "Kullanıcı güncellendi" });
  };

  const handleDelete = async (id: string) => {
    setDeletingId(id);
    setMessage(null);
    const res = await fetch(`/api/admin/user-directory/users?id=${id}`, { method: "DELETE" });
    setDeletingId(null);
    if (!res.ok) {
      setMessage({ type: "error", text: "Silme başarısız" });
      return;
    }
    setUsers((prev) => prev.filter((u) => u.id !== id));
    setMessage({ type: "success", text: "Kullanıcı silindi" });
  };

  const selectedTenant = tenants.find((t) => t.id === selectedTenantId);
  const createCtaLabel = "+ Personel Ekle";

  const getInitials = (u: UserRow) => {
    const first = u.first_name?.[0] ?? "";
    const last = u.last_name?.[0] ?? "";
    return (first + last || "?").toUpperCase();
  };

  const roleLabel = (role: string | null | undefined) => ROLES.find((r) => r.value === role)?.label ?? role ?? "-";

  const startEdit = (user: UserRow) => {
    setEditingId(user.id);
    setDraft({ ...user });
  };

  const cancelEdit = () => {
    setEditingId(null);
    setDraft(null);
  };

  const commitEdit = async () => {
    if (!editingId || !draft) return;
    await handleUpdate(editingId, draft as Partial<UserRow>);
    cancelEdit();
  };

  const handleLongPressStart = (user: UserRow) => {
    if (longPressTimer.current) clearTimeout(longPressTimer.current);
    longPressTimer.current = setTimeout(() => startEdit(user), 550);
  };

  const handleLongPressEnd = () => {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  };

  return (
    <div className="page">
      <header className="page-header">
        <h2>Kullanıcı Yetkileri</h2>
        <p>Firma seçin; sağ tık veya uzun basarak satır bazlı düzenleyin.</p>
      </header>

      <div className="card" style={HEADER_CARD_STYLE}>
        <div style={{ display: "flex", gap: "14px", alignItems: "center", flexWrap: "wrap" }}>
          <label style={HEADER_SELECT_BOX_STYLE}>
            <span style={{ fontSize: 12, fontWeight: 700 }}>Firma seç</span>
            <select value={selectedTenantId} onChange={(e) => setSelectedTenantId(e.target.value)} style={{ ...INPUT_STYLE, minWidth: 240 }}>
              {tenants.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name} ({t.code})
                </option>
              ))}
            </select>
          </label>
          {selectedTenant ? (
            <div style={TENANT_PILL_STYLE}>
              <span style={{ opacity: 0.7, fontSize: 12 }}>Seçilen</span>
              <span>{selectedTenant.name}</span>
            </div>
          ) : null}
        </div>
        <button
          type="button"
          className="primary"
          onClick={handleOpenCreate}
          disabled={!selectedTenantId}
          style={{
            padding: "12px 16px",
            borderRadius: 12,
            fontWeight: 700,
            boxShadow: "0 12px 30px rgba(0,0,0,0.2)",
            background: "linear-gradient(135deg, #4f9cff, #7f5dff)",
            border: "1px solid rgba(255,255,255,0.22)",
            color: "#fff",
          }}
        >
          {createCtaLabel}
        </button>
        {message ? <p className={`alert alert-${message.type}`}>{message.text}</p> : null}
      </div>

      <div className="card" style={{ padding: "12px" }}>
        <div className="card-header">
          <h3>Kullanıcılar</h3>
          {loading ? (
            <span>Yükleniyor...</span>
          ) : (
            <span>
              {filteredUsers.length} kayıt
            </span>
          )}
        </div>
        <div style={FILTER_CARD_STYLE}>
            <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "space-between", gap: "14px", alignItems: "center" }}>
              <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
                <span style={{ fontSize: 14, fontWeight: 800, color: "var(--text-strong)" }}>Filtreler</span>
                <div style={{ display: "flex", gap: "8px", flexWrap: "wrap", alignItems: "center" }}>
                  {activeFilters.length ? (
                    activeFilters.map((tag) => (
                      <span key={tag} style={FILTER_PILL_STYLE}>
                        {tag}
                      </span>
                    ))
                  ) : (
                    <span style={{ color: "var(--text-weak)", fontSize: 13 }}>Aktif filtre yok</span>
                  )}
                </div>
              </div>
              <div style={{ display: "flex", gap: "12px", alignItems: "center", flexWrap: "wrap" }}>
                <span style={{ color: "var(--text-weak)", fontSize: 13 }}>
                  Gösterilen {filteredUsers.length} / {total}
                </span>
                <button
                  type="button"
                  onClick={clearFilters}
                  disabled={!activeFilters.length && sortKey === "name_asc" && !searchTerm.trim() && !branchFilter && !roleFilter}
                  style={ACTION_BUTTON_GHOST}
                >
                  Filtreleri temizle
                </button>
              </div>
            </div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))", gap: "12px", alignItems: "end" }}>
            <label style={FILTER_FIELD_STYLE}>
              <span style={{ fontSize: 12, fontWeight: 700 }}>Şube filtresi</span>
              <select value={branchFilter} onChange={(e) => setBranchFilter(e.target.value)} style={INPUT_STYLE}>
                <option value="">Tümü</option>
                {branches.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name} ({b.code})
                  </option>
                ))}
              </select>
            </label>
            <label style={FILTER_FIELD_STYLE}>
              <span style={{ fontSize: 12, fontWeight: 700 }}>Rol filtresi</span>
              <select value={roleFilter} onChange={(e) => setRoleFilter(e.target.value)} style={INPUT_STYLE}>
                {ROLE_FILTER_OPTIONS.map((r) => (
                  <option key={r.value || "all"} value={r.value}>
                    {r.label}
                  </option>
                ))}
              </select>
            </label>
            <label style={FILTER_FIELD_STYLE}>
              <span style={{ fontSize: 12, fontWeight: 700 }}>İsim / e-posta ara</span>
              <input value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} placeholder="İsim veya e-posta" style={INPUT_STYLE} />
            </label>
            <label style={FILTER_FIELD_STYLE}>
              <span style={{ fontSize: 12, fontWeight: 700 }}>Sırala</span>
              <select value={sortKey} onChange={(e) => setSortKey(e.target.value as (typeof SORT_OPTIONS)[number]["value"])} style={INPUT_STYLE}>
                {SORT_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </label>
            <label style={FILTER_FIELD_STYLE}>
              <span style={{ fontSize: 12, fontWeight: 700 }}>Sayfa başına kayıt</span>
              <select value={pageSize} onChange={(e) => setPageSize(Number(e.target.value))} style={INPUT_STYLE}>
                {[10, 100, 500].map((size) => (
                  <option key={size} value={size}>
                    {size} kullanıcı
                  </option>
                ))}
              </select>
            </label>
          </div>
        </div>
        {renderPagination()}
        <div style={{ display: "flex", flexDirection: "column", gap: "12px", width: "100%" }}>
          {filteredUsers.map((u) => {
            const isEditing = editingId === u.id;
            const rowDraft = isEditing && draft ? (draft as UserRow) : u;
            return (
              <div
                key={u.id}
                onContextMenu={(e) => {
                  e.preventDefault();
                  startEdit(u);
                }}
                onPointerDown={() => handleLongPressStart(u)}
                onPointerUp={handleLongPressEnd}
                onPointerLeave={handleLongPressEnd}
                style={CARD_ROW_STYLE}
              >
                <div style={{ display: "flex", gap: "12px", alignItems: "center" }}>
                  <div style={AVATAR_STYLE}>{getInitials(u)}</div>
                  <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                    <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>
                      {isEditing ? (
                        <>
                          <input
                            value={rowDraft.first_name ?? ""}
                            onChange={(e) => setDraft((p) => ({ ...p, first_name: e.target.value }))}
                            style={{ width: 140 }}
                          />
                          <input
                            value={rowDraft.last_name ?? ""}
                            onChange={(e) => setDraft((p) => ({ ...p, last_name: e.target.value }))}
                            style={{ width: 140 }}
                          />
                        </>
                      ) : (
                        <div style={{ fontWeight: 700, fontSize: 15 }}>
                          {u.first_name} {u.last_name}
                        </div>
                      )}
                      <span
                        style={{
                          padding: "6px 10px",
                          borderRadius: 999,
                          fontSize: 12,
                          fontWeight: 700,
                          ...(ROLE_BADGE_STYLE[u.role ?? "personel"] ?? ROLE_BADGE_STYLE.personel),
                        }}
                      >
                        {roleLabel(u.role)}
                      </span>
                      <span
                        style={{
                          padding: "5px 10px",
                          borderRadius: 999,
                          fontSize: 12,
                          fontWeight: 700,
                          ...(u.active ? STATUS_PILL.active : STATUS_PILL.passive),
                        }}
                      >
                        {u.active ? "Aktif" : "Pasif"}
                      </span>
                    </div>
                    <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center", color: "var(--text-muted)" }}>
                      {isEditing ? (
                        <select value={rowDraft.branch_id ?? ""} onChange={(e) => setDraft((p) => ({ ...p, branch_id: e.target.value || null }))}>
                          <option value="">(Merkez)</option>
                          {branches.map((b) => (
                            <option key={b.id} value={b.id}>
                              {b.name} ({b.code})
                            </option>
                          ))}
                        </select>
                      ) : (
                        <span style={{ fontWeight: 600 }}>{u.branch_id ? branchLookup.get(u.branch_id)?.name ?? "Şube" : "Merkez"}</span>
                      )}
                      <span style={{ fontSize: 12, opacity: 0.7 }}>{u.employee_code ? `Sicil: ${u.employee_code}` : "Sicil yok"}</span>
                    </div>
                  </div>
                </div>

                <div style={{ display: "grid", gap: 6 }}>
                  <label style={{ display: "flex", gap: 8, alignItems: "center" }}>
                    <span style={{ fontSize: 12, opacity: 0.7 }}>Email</span>
                    {isEditing ? (
                      <input value={rowDraft.email ?? ""} onChange={(e) => setDraft((p) => ({ ...p, email: e.target.value }))} />
                    ) : (
                      <span style={{ fontWeight: 600 }}>{u.email}</span>
                    )}
                  </label>
                  <label style={{ display: "flex", gap: 8, alignItems: "center" }}>
                    <span style={{ fontSize: 12, opacity: 0.7 }}>Telefon</span>
                    {isEditing ? (
                      <input value={rowDraft.phone ?? ""} onChange={(e) => setDraft((p) => ({ ...p, phone: e.target.value }))} />
                    ) : (
                      <span style={{ fontWeight: 600 }}>{u.phone}</span>
                    )}
                  </label>
                  {isEditing ? (
                    <label style={{ display: "flex", gap: 8, alignItems: "center" }}>
                      <input
                        type="checkbox"
                        checked={!!rowDraft.active}
                        onChange={(e) => setDraft((p) => ({ ...p, active: e.target.checked }))}
                      />
                      <span style={{ fontSize: 12 }}>Aktif</span>
                    </label>
                  ) : null}
                </div>

                <div style={{ display: "flex", gap: 10, justifyContent: "flex-end", alignItems: "center", flexWrap: "wrap" }}>
                  {isEditing ? (
                    <>
                      <button type="button" className="primary" onClick={commitEdit} disabled={savingId === u.id}>
                        {savingId === u.id ? "Kaydediliyor" : "Kaydet"}
                      </button>
                      <button type="button" onClick={cancelEdit}>Vazgeç</button>
                    </>
                  ) : (
                    <>
                      <button type="button" onClick={() => startEdit(u)} style={ACTION_BUTTON_GHOST}>
                        Düzenle
                      </button>
                      <button
                        type="button"
                        className="danger"
                        onClick={() => handleDelete(u.id)}
                        disabled={deletingId === u.id}
                        style={ACTION_BUTTON_DANGER}
                      >
                        {deletingId === u.id ? "Siliniyor" : "Sil"}
                      </button>
                    </>
                  )}
                </div>
              </div>
            );
          })}
        </div>
        {renderPagination()}
      </div>

      {/* Personel ekleme artık /users/new sayfasında yapılacak. */}
    </div>
  );
}
