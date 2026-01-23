"use client";

import { useEffect, useMemo, useState } from "react";
import { Dialog, DialogPanel } from "@tremor/react";
import { toast } from "sonner";
import { CardActionButton, CardInlineActions, CardListShell, SoftBadge, cardStyles } from "@/components/ui/card-list";
import "./personnel.css";

type Branch = { id: string; name: string };
type UserRow = {
  id: string;
  first_name: string | null;
  last_name: string | null;
  email: string | null;
  phone: string | null;
  role: string | null;
  branch_id: string | null;
  position: string | null;
  branches?: { name: string | null } | null;
};

type UsersResponse = { users: UserRow[]; branchId: string | null };

const ROLE_OPTIONS = [
  { value: "sube_muduru", label: "Şube Müdürü" },
  { value: "personel", label: "Personel" },
];

const emptyFilters = {
  name: "",
  email: "",
  phone: "",
  role: "",
  branch: "",
  position: "",
};

export default function PersonnelPage() {
  const [users, setUsers] = useState<UserRow[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editUser, setEditUser] = useState<UserRow | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [filters, setFilters] = useState(emptyFilters);
  const [currentRole, setCurrentRole] = useState<string | null>(null);
  const [currentBranchId, setCurrentBranchId] = useState<string | null>(null);
  const [form, setForm] = useState({
    first_name: "",
    last_name: "",
    email: "",
    phone: "",
    position: "",
    branch_id: "",
    role: ROLE_OPTIONS[1].value,
  });

  useEffect(() => {
    fetchProfile();
    fetchAll();
  }, []);

  async function fetchProfile() {
    try {
      const res = await fetch("/api/me");
      if (!res.ok) return;
      const body = (await res.json()) as { role?: string | null; branch_id?: string | null };
      setCurrentRole(body.role ?? null);
      if (body.branch_id) setCurrentBranchId(body.branch_id);
    } catch (error) {
      console.error(error);
    }
  }

  async function fetchAll() {
    setLoading(true);
    try {
      const [usersRes, branchesRes] = await Promise.all([fetch("/api/personnel"), fetch("/api/personnel/branches")]);
      if (!usersRes.ok) throw new Error("Personel alınamadı");
      if (!branchesRes.ok) throw new Error("Şubeler alınamadı");
      const usersJson = (await usersRes.json()) as UsersResponse;
      const branchJson = (await branchesRes.json()) as { branches: Branch[] };
      setUsers(usersJson.users ?? []);
      setBranches(branchJson.branches ?? []);
      if (!form.branch_id && usersJson.branchId) {
        setForm((prev) => ({ ...prev, branch_id: usersJson.branchId ?? "" }));
      }
      if (!currentBranchId && usersJson.branchId) {
        setCurrentBranchId(usersJson.branchId);
      }
    } catch (error) {
      console.error(error);
      toast.error("Veriler alınamadı");
    } finally {
      setLoading(false);
    }
  }

  function fullName(user: UserRow) {
    const parts = [user.first_name, user.last_name].filter(Boolean);
    return parts.join(" ") || "-";
  }

  function handleChange(field: keyof typeof form, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  function handleFilter(field: keyof typeof emptyFilters, value: string) {
    setFilters((prev) => ({ ...prev, [field]: value }));
  }

  function resetForm() {
    setForm({ first_name: "", last_name: "", email: "", phone: "", position: "", branch_id: "", role: ROLE_OPTIONS[1].value });
    setEditUser(null);
  }

  const cancelInlineEdit = () => {
    resetForm();
  };

  async function handleSave() {
    if (!form.email || !form.branch_id) {
      toast.error("Email ve şube zorunlu");
      return;
    }
    const payload = { ...form };
    const isEdit = Boolean(editUser);
    try {
      const res = await fetch("/api/personnel", {
        method: isEdit ? "PATCH" : "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(isEdit ? { id: editUser?.id, ...payload } : payload),
      });
      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        throw new Error(detail?.message || (isEdit ? "Güncelleme başarısız" : "Kayıt başarısız"));
      }
      toast.success(isEdit ? "Güncellendi" : "Personel eklendi");
      setDialogOpen(false);
      resetForm();
      fetchAll();
    } catch (error) {
      console.error(error);
      toast.error(isEdit ? "Güncelleme başarısız" : "Kayıt başarısız");
    }
  }

  async function handleDelete() {
    if (!deleteId) return;
    try {
      const res = await fetch(`/api/personnel?id=${deleteId}`, { method: "DELETE" });
      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        throw new Error(detail?.message || "Silme başarısız");
      }
      toast.success("Silindi");
      setDeleteId(null);
      fetchAll();
    } catch (error) {
      console.error(error);
      toast.error("Silme başarısız");
    }
  }

  const filtered = useMemo(() => {
    const match = (target: string | null | undefined, term: string) => (target ?? "").toLowerCase().includes(term.toLowerCase().trim());

    return users.filter((u) => {
      if (filters.name && !match(fullName(u), filters.name)) return false;
      if (filters.email && !match(u.email, filters.email)) return false;
      if (filters.phone && !match(u.phone, filters.phone)) return false;
      if (filters.position && !match(u.position, filters.position)) return false;
      if (filters.role && u.role !== filters.role) return false;
      if (filters.branch && u.branch_id !== filters.branch) return false;
      // Bölge müdürü firma adminini görmesin
      if (currentRole === "bolge_muduru" && u.role === "firma_admin") return false;

      return true;
    });
  }, [filters, users, currentRole]);

  const filterContent = (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 10 }}>
      <input className="filter-input" placeholder="Ad / Soyad" value={filters.name} onChange={(e) => handleFilter("name", e.target.value)} />
      <input className="filter-input" placeholder="E-posta" value={filters.email} onChange={(e) => handleFilter("email", e.target.value)} />
      <input className="filter-input" placeholder="Telefon" value={filters.phone} onChange={(e) => handleFilter("phone", e.target.value)} />
      <input className="filter-input" placeholder="Pozisyon" value={filters.position} onChange={(e) => handleFilter("position", e.target.value)} />
      <select className="filter-input" value={filters.role} onChange={(e) => handleFilter("role", e.target.value)}>
        <option value="">Tümü</option>
        {ROLE_OPTIONS.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
      <select className="filter-input" value={filters.branch} onChange={(e) => handleFilter("branch", e.target.value)}>
        <option value="">Tümü</option>
        {branches.map((branch) => (
          <option key={branch.id} value={branch.id}>
            {branch.name}
          </option>
        ))}
      </select>
    </div>
  );

  const filterPills = [
    filters.name ? { label: `Ad: ${filters.name}` } : null,
    filters.email ? { label: `E-posta: ${filters.email}` } : null,
    filters.phone ? { label: `Telefon: ${filters.phone}` } : null,
    filters.position ? { label: `Pozisyon: ${filters.position}` } : null,
    filters.role ? { label: `Rol: ${filters.role}` } : null,
    filters.branch ? { label: `Şube: ${branches.find((b) => b.id === filters.branch)?.name ?? filters.branch}` } : null,
  ].filter(Boolean) as { label: string; tone?: "info" | "success" | "warn" | "danger" | "muted" }[];

  const canEdit = (user: UserRow) => {
    if (currentRole === "grand_admin" || currentRole === "firma_admin") return true;
    if (currentRole === "bolge_muduru") {
      // Bölge müdürü için branch bilgisi yoksa geniş izin ver; varsa şube eşleşmesini kontrol et.
      if (!currentBranchId) return true;
      return user.branch_id === currentBranchId;
    }
    if (currentRole === "sube_muduru" && currentBranchId && user.branch_id === currentBranchId) return true;
    return false;
  };

  const canDelete = (user: UserRow) => {
    if (currentRole !== "sube_muduru") return false;
    if (!currentBranchId || user.branch_id !== currentBranchId) return false;
    if (user.role === "sube_muduru") return false;
    return true;
  };

  const cards = filtered.map((user) => {
    const roleLabel = ROLE_OPTIONS.find((r) => r.value === user.role)?.label || "Görev yok";
    const branchLabel = branches.find((b) => b.id === user.branch_id)?.name ?? "Şube yok";
    const positionLabel = user.position && user.position.trim() ? user.position.trim() : "Pozisyon yok";

    return (
      <div key={user.id} style={{ ...cardStyles.row, alignItems: "flex-start", padding: "16px 18px" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <div style={{ fontWeight: 800 }}>{fullName(user)}</div>
          <div style={{ color: "var(--text-subtle)", fontSize: 13 }}>{user.email ?? "-"}</div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
            <SoftBadge tone="muted" label={user.phone ?? "-"} />
            <SoftBadge tone="info" label={`Pozisyon: ${positionLabel}`} />
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          <SoftBadge tone="success" label={roleLabel} />
          <SoftBadge tone="muted" label={branchLabel} />
          <SoftBadge tone="info" label={positionLabel} />
        </div>

        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 8 }}>
          <CardInlineActions>
            {canEdit(user) ? (
              <CardActionButton
                tone="info"
                onClick={() => {
                  setEditUser(user);
                  setForm({
                    first_name: user.first_name ?? "",
                    last_name: user.last_name ?? "",
                    email: user.email ?? "",
                    phone: user.phone ?? "",
                    position: user.position ?? "",
                    branch_id: user.branch_id ?? currentBranchId ?? "",
                    role: user.role ?? ROLE_OPTIONS[1].value,
                  });
                }}
                label="Düzenle"
              />
            ) : null}
            {canDelete(user) ? <CardActionButton tone="danger" onClick={() => setDeleteId(user.id)} label="Sil" /> : null}
          </CardInlineActions>
        </div>

        {editUser?.id === user.id ? (
          <div
            style={{
              marginTop: 10,
              width: "100%",
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
              gap: 10,
            }}
          >
            <input className="filter-input" placeholder="Ad" value={form.first_name} onChange={(e) => handleChange("first_name", e.target.value)} />
            <input className="filter-input" placeholder="Soyad" value={form.last_name} onChange={(e) => handleChange("last_name", e.target.value)} />
            <input className="filter-input" placeholder="E-posta" value={form.email} onChange={(e) => handleChange("email", e.target.value)} />
            <input className="filter-input" placeholder="Telefon" value={form.phone} onChange={(e) => handleChange("phone", e.target.value)} />
            <input className="filter-input" placeholder="Pozisyon" value={form.position} onChange={(e) => handleChange("position", e.target.value)} />
            <select className="filter-input" value={form.role} onChange={(e) => handleChange("role", e.target.value)}>
              {ROLE_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
            <select className="filter-input" value={form.branch_id} onChange={(e) => handleChange("branch_id", e.target.value)}>
              <option value="">Şube seç</option>
              {branches.map((branch) => (
                <option key={branch.id} value={branch.id}>
                  {branch.name}
                </option>
              ))}
            </select>
            <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <CardActionButton tone="success" label="Kaydet" onClick={handleSave} />
              <CardActionButton tone="muted" label="İptal" onClick={cancelInlineEdit} />
            </div>
          </div>
        ) : null}
      </div>
    );
  });

  return (
    <CardListShell
      title="Personel"
      description="Şube personelini görüntüle, ekle ve güncelle."
      stats={[
        { label: "Toplam", value: users.length },
        { label: "Filtrelenen", value: filtered.length },
      ]}
      actions={
        <>
          <CardActionButton tone="muted" label="Filtreleri sıfırla" onClick={() => setFilters(emptyFilters)} />
          <CardActionButton
            tone="success"
            label="Personel Ekle"
            onClick={() => {
              resetForm();
              setDialogOpen(true);
            }}
          />
        </>
      }
      filterContent={filterContent}
      pills={filterPills}
    >
      {loading ? <p>Yükleniyor...</p> : null}

      {!loading && filtered.length === 0 ? <p className="muted">Kayıt bulunamadı.</p> : null}

      {!loading ? <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>{cards}</div> : null}

      <Dialog open={dialogOpen && !editUser} onClose={setDialogOpen} static={true}>
        <DialogPanel className="space-y-4 sm:max-w-lg">
          <div>
            <p className="text-lg font-semibold">Yeni Personel</p>
            <p className="text-sm text-gray-500">Bilgileri doldurun.</p>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <input
              className="filter-input"
              value={form.first_name}
              onChange={(e) => handleChange("first_name", e.target.value)}
              placeholder="Ad"
            />
            <input
              className="filter-input"
              value={form.last_name}
              onChange={(e) => handleChange("last_name", e.target.value)}
              placeholder="Soyad"
            />
          </div>
          <input
            className="filter-input"
            value={form.email}
            onChange={(e) => handleChange("email", e.target.value)}
            placeholder="E-posta"
            type="email"
          />
          <input
            className="filter-input"
            value={form.phone}
            onChange={(e) => handleChange("phone", e.target.value)}
            placeholder="Telefon"
          />
          <input
            className="filter-input"
            value={form.position}
            onChange={(e) => handleChange("position", e.target.value)}
            placeholder="Pozisyon"
          />
          <select className="filter-input" value={form.role} onChange={(e) => handleChange("role", e.target.value)}>
            {ROLE_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
          <select className="filter-input" value={form.branch_id} onChange={(e) => handleChange("branch_id", e.target.value)}>
            {branches.map((branch) => (
              <option key={branch.id} value={branch.id}>
                {branch.name}
              </option>
            ))}
          </select>
          <div className="flex justify-end gap-2 pt-1">
            <button className="ghost" onClick={() => setDialogOpen(false)} type="button">
              İptal
            </button>
            <button className="primary" onClick={handleSave} type="button">
              Kaydet
            </button>
          </div>
        </DialogPanel>
      </Dialog>

      <Dialog open={Boolean(deleteId)} onClose={() => setDeleteId(null)} static={true}>
        <DialogPanel className="space-y-4 sm:max-w-md">
          <div>
            <p className="text-lg font-semibold">Silme Onayı</p>
            <p className="text-sm text-gray-500">Bu personeli silmek istediğinize emin misiniz?</p>
          </div>
          <div className="flex justify-end gap-2">
            <button className="ghost" onClick={() => setDeleteId(null)} type="button">
              İptal
            </button>
            <button className="danger" onClick={handleDelete} type="button">
              Sil
            </button>
          </div>
        </DialogPanel>
      </Dialog>
    </CardListShell>
  );
}
