"use client";

import { useEffect, useMemo, useRef, useState } from "react";
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

const TABLE_COLS = [
  "minmax(120px, 1.05fr)",
  "minmax(120px, 1.05fr)",
  "minmax(140px, 1.15fr)",
  "minmax(120px, 1fr)",
  "minmax(200px, 1.6fr)",
  "minmax(150px, 1.1fr)",
  "minmax(90px, 0.7fr)",
  "minmax(140px, 0.85fr)",
].join(" ");
const TABLE_COLUMN_DIVIDER = "1px solid #d1d5db";
const TABLE_CELL_STYLE = {
  display: "flex",
  alignItems: "center",
  padding: "0 8px",
};
const TABLE_HEAD_CELL_STYLE = {
  ...TABLE_CELL_STYLE,
  justifyContent: "center" as const,
  textAlign: "center" as const,
  fontWeight: 600,
};
const SORT_OPTIONS = [
  { value: "name_asc", label: "İsim A-Z" },
  { value: "name_desc", label: "İsim Z-A" },
  { value: "branch_asc", label: "Şube A-Z" },
  { value: "branch_desc", label: "Şube Z-A" },
];

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

  const [showCreateModal, setShowCreateModal] = useState(false);

  const [branchFilter, setBranchFilter] = useState<string>("");
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

  const [createForm, setCreateForm] = useState({
    first_name: "",
    last_name: "",
    email: "",
    role: "sube_muduru",
    branch_id: "",
    phone: "",
    employee_code: "",
    position: "",
    active: true,
    password: "",
  });

  const branchLookup = useMemo(() => {
    const map = new Map<string, Branch>();
    branches.forEach((b) => map.set(b.id, b));
    return map;
  }, [branches]);

  useEffect(() => {
    setPage(1);
  }, [branchFilter, searchTerm, sortKey, pageSize, selectedTenantId]);

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
  }, [selectedTenantId, branchFilter, searchTerm, sortKey, pageSize, page]);

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

  const handleCreate = async () => {
    if (!selectedTenantId) return false;
    setMessage(null);
    const payload = {
      ...createForm,
      tenant_id: selectedTenantId,
      branch_id: createForm.branch_id || null,
    };
    const res = await fetch("/api/admin/user-directory/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setMessage({ type: "error", text: body.message ?? "Kullanıcı eklenemedi" });
      return false;
    }
    const data = (await res.json()) as { id: string };
    setUsers((prev) => [
      ...prev,
      {
        id: data.id,
        tenant_id: selectedTenantId,
        branch_id: createForm.branch_id || null,
        role: createForm.role,
        first_name: createForm.first_name,
        last_name: createForm.last_name,
        email: createForm.email,
        phone: createForm.phone,
        employee_code: createForm.employee_code,
        position: createForm.position,
        active: createForm.active,
      } as UserRow,
    ]);
    setCreateForm({
      first_name: "",
      last_name: "",
      email: "",
      role: "sube_muduru",
      branch_id: "",
      phone: "",
      employee_code: "",
      position: "",
      active: true,
      password: "",
    });
    setMessage({ type: "success", text: "Kullanıcı eklendi" });
    return true;
  };

  const selectedTenant = tenants.find((t) => t.id === selectedTenantId);

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

      <div className="card">
        <div className="controls" style={{ justifyContent: "space-between", gap: "12px" }}>
          <div style={{ display: "flex", gap: "12px", alignItems: "center" }}>
            <label>
              Firma
              <select value={selectedTenantId} onChange={(e) => setSelectedTenantId(e.target.value)}>
                {tenants.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.name} ({t.code})
                  </option>
                ))}
              </select>
            </label>
            {selectedTenant ? <span>Seçilen: {selectedTenant.name}</span> : null}
          </div>
          <button type="button" className="primary" onClick={() => setShowCreateModal(true)} disabled={!selectedTenantId}>
            Personel Ekle
          </button>
        </div>
        {message ? <p className={`alert alert-${message.type}`}>{message.text}</p> : null}
      </div>

      <div className="card" style={{ padding: "12px" }}>
        <div className="card-header">
          <h3>Kullanıcılar</h3>
          {loading ? (
            <span>Yükleniyor...</span>
          ) : (
            <span>
              {total} kayıt
            </span>
          )}
        </div>
        <div className="controls" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: "12px", marginBottom: "12px" }}>
          <label>
            Şube filtresi
            <select value={branchFilter} onChange={(e) => setBranchFilter(e.target.value)}>
              <option value="">Tümü</option>
              {branches.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.name} ({b.code})
                </option>
              ))}
            </select>
          </label>
          <label>
            İsim / e-posta ara
            <input value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} placeholder="İsim veya e-posta" />
          </label>
          <label>
            Sırala
            <select value={sortKey} onChange={(e) => setSortKey(e.target.value as (typeof SORT_OPTIONS)[number]["value"])}>
              {SORT_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </label>
          <label>
            Sayfa başına kayıt
            <select value={pageSize} onChange={(e) => setPageSize(Number(e.target.value))}>
              {[10, 100, 500].map((size) => (
                <option key={size} value={size}>
                  {size} kullanıcı
                </option>
              ))}
            </select>
          </label>
        </div>
        {renderPagination()}
        <div
          className="table dense"
          style={{
            gap: "0",
            border: "1px solid #e5e7eb",
            borderRadius: 8,
            overflow: "hidden",
            boxShadow: "0 1px 2px rgba(0,0,0,0.05)",
            width: "100%",
          }}
        >
          <div
            className="table-row table-head"
            style={{
              display: "grid",
              gridTemplateColumns: TABLE_COLS,
              alignItems: "center",
              padding: "10px 12px",
              background: "#f8fafc",
              borderBottom: "1px solid #e5e7eb",
              columnGap: "0",
            }}
          >
            <div style={{ ...TABLE_HEAD_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>Ad</div>
            <div style={{ ...TABLE_HEAD_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>Soyad</div>
            <div style={{ ...TABLE_HEAD_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>Şube</div>
            <div style={{ ...TABLE_HEAD_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>Rol</div>
            <div style={{ ...TABLE_HEAD_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>Email</div>
            <div style={{ ...TABLE_HEAD_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>Telefon</div>
            <div style={{ ...TABLE_HEAD_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>Aktif</div>
            <div style={TABLE_HEAD_CELL_STYLE}>İşlem</div>
          </div>
          {users.map((u, idx) => {
            const isEditing = editingId === u.id;
            const rowDraft = isEditing && draft ? (draft as UserRow) : u;
            return (
              <div
                key={u.id}
                className="table-row"
                onContextMenu={(e) => {
                  e.preventDefault();
                  startEdit(u);
                }}
                onPointerDown={() => handleLongPressStart(u)}
                onPointerUp={handleLongPressEnd}
                onPointerLeave={handleLongPressEnd}
                style={{
                  display: "grid",
                  gridTemplateColumns: TABLE_COLS,
                  alignItems: "center",
                  gap: "6px",
                  padding: "10px 12px",
                  background: idx % 2 === 0 ? "#ffffff" : "#f9fafb",
                  borderBottom: "1px solid #e5e7eb",
                }}
              >
                <div style={{ ...TABLE_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>
                  {isEditing ? <input value={rowDraft.first_name ?? ""} onChange={(e) => setDraft((p) => ({ ...p, first_name: e.target.value }))} /> : <span>{u.first_name}</span>}
                </div>
                <div style={{ ...TABLE_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>
                  {isEditing ? <input value={rowDraft.last_name ?? ""} onChange={(e) => setDraft((p) => ({ ...p, last_name: e.target.value }))} /> : <span>{u.last_name}</span>}
                </div>
                <div style={{ ...TABLE_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>
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
                    <span>{u.branch_id ? branchLookup.get(u.branch_id)?.name ?? "Şube" : "Merkez"}</span>
                  )}
                </div>
                <div style={{ ...TABLE_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>
                  {isEditing ? (
                    <select value={rowDraft.role ?? "sube_muduru"} onChange={(e) => setDraft((p) => ({ ...p, role: e.target.value }))}>
                      {ROLES.map((r) => (
                        <option key={r.value} value={r.value}>
                          {r.label}
                        </option>
                      ))}
                    </select>
                  ) : (
                    <span>{u.role}</span>
                  )}
                </div>
                <div style={{ ...TABLE_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>{isEditing ? <input value={rowDraft.email ?? ""} onChange={(e) => setDraft((p) => ({ ...p, email: e.target.value }))} /> : <span>{u.email}</span>}</div>
                <div style={{ ...TABLE_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>{isEditing ? <input value={rowDraft.phone ?? ""} onChange={(e) => setDraft((p) => ({ ...p, phone: e.target.value }))} /> : <span>{u.phone}</span>}</div>
                <div style={{ ...TABLE_CELL_STYLE, borderRight: TABLE_COLUMN_DIVIDER }}>
                  {isEditing ? (
                    <label className="checkbox">
                      <input
                        type="checkbox"
                        checked={!!rowDraft.active}
                        onChange={(e) => setDraft((p) => ({ ...p, active: e.target.checked }))}
                      />
                      Aktif
                    </label>
                  ) : (
                    <span>{u.active ? "Aktif" : "Pasif"}</span>
                  )}
                </div>
                <div className="actions" style={{ gap: "6px", justifyContent: "center" }}>
                  {isEditing ? (
                    <>
                      <button type="button" className="primary" onClick={commitEdit} disabled={savingId === u.id}>
                        {savingId === u.id ? "Kaydediliyor" : "Kaydet"}
                      </button>
                      <button type="button" onClick={cancelEdit}>Vazgeç</button>
                    </>
                  ) : (
                    <>
                      <button type="button" onClick={() => startEdit(u)}>Düzenle</button>
                      <button type="button" className="danger" onClick={() => handleDelete(u.id)} disabled={deletingId === u.id}>
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

      {showCreateModal ? (
        <div className="modal-backdrop">
          <div className="modal">
            <h3>Personel Ekle</h3>
            <div className="grid two" style={{ maxHeight: "60vh", overflow: "auto" }}>
              <label>
                Ad
                <input value={createForm.first_name} onChange={(e) => setCreateForm((p) => ({ ...p, first_name: e.target.value }))} />
              </label>
              <label>
                Soyad
                <input value={createForm.last_name} onChange={(e) => setCreateForm((p) => ({ ...p, last_name: e.target.value }))} />
              </label>
              <label>
                Email
                <input value={createForm.email} onChange={(e) => setCreateForm((p) => ({ ...p, email: e.target.value }))} />
              </label>
              <label>
                Telefon
                <input value={createForm.phone} onChange={(e) => setCreateForm((p) => ({ ...p, phone: e.target.value }))} />
              </label>
              <label>
                Rol
                <select value={createForm.role} onChange={(e) => setCreateForm((p) => ({ ...p, role: e.target.value }))}>
                  {ROLES.map((r) => (
                    <option key={r.value} value={r.value}>
                      {r.label}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Şube
                <select value={createForm.branch_id} onChange={(e) => setCreateForm((p) => ({ ...p, branch_id: e.target.value }))}>
                  <option value="">(Merkez)</option>
                  {branches.map((b) => (
                    <option key={b.id} value={b.id}>
                      {b.name} ({b.code})
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Sicil / Kod
                <input value={createForm.employee_code} onChange={(e) => setCreateForm((p) => ({ ...p, employee_code: e.target.value }))} />
              </label>
              <label>
                Pozisyon
                <input value={createForm.position} onChange={(e) => setCreateForm((p) => ({ ...p, position: e.target.value }))} />
              </label>
              <label>
                Parola (opsiyonel)
                <input value={createForm.password} onChange={(e) => setCreateForm((p) => ({ ...p, password: e.target.value }))} />
              </label>
              <label className="checkbox" style={{ alignItems: "center" }}>
                <input
                  type="checkbox"
                  checked={createForm.active}
                  onChange={(e) => setCreateForm((p) => ({ ...p, active: e.target.checked }))}
                />
                Aktif
              </label>
            </div>
            <div className="actions" style={{ justifyContent: "flex-end", gap: "8px", marginTop: "12px" }}>
              <button type="button" onClick={() => setShowCreateModal(false)}>
                Vazgeç
              </button>
              <button
                type="button"
                className="primary"
                onClick={async () => {
                  const ok = await handleCreate();
                  if (ok) setShowCreateModal(false);
                }}
                disabled={!selectedTenantId}
              >
                Kaydet
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
