"use client";

import { useEffect, useMemo, useState } from "react";
import { Dialog, DialogPanel } from "@tremor/react";
import { toast } from "sonner";
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
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [filters, setFilters] = useState(emptyFilters);
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
    fetchAll();
  }, []);

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

  async function handleCreate() {
    if (!form.email || !form.branch_id) {
      toast.error("Email ve şube zorunlu");
      return;
    }
    try {
      const res = await fetch("/api/personnel", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(form),
      });
      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        throw new Error(detail?.message || "Kayıt başarısız");
      }
      toast.success("Personel eklendi");
      setDialogOpen(false);
      setForm({ ...form, first_name: "", last_name: "", email: "", phone: "", position: "" });
      fetchAll();
    } catch (error) {
      console.error(error);
      toast.error("Kayıt başarısız");
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

  async function handleUpdate(user: UserRow, updates: Partial<UserRow>) {
    try {
      const res = await fetch("/api/personnel", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: user.id, branch_id: updates.branch_id, role: updates.role, position: updates.position }),
      });
      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        throw new Error(detail?.message || "Güncelleme başarısız");
      }
      toast.success("Güncellendi");
      fetchAll();
    } catch (error) {
      console.error(error);
      toast.error("Güncelleme başarısız");
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
      return true;
    });
  }, [filters, users]);

  if (loading) {
    return <div className="flex h-full items-center justify-center text-sm text-gray-600">Yükleniyor…</div>;
  }

  return (
    <div className="page">
      <header className="page-header">
        <h2>Personel</h2>
        <p>Şube personelini görüntüle, ekle ve güncelle.</p>
      </header>

      <div className="card table-card">
        <div className="table-toolbar">
          <div className="toolbar-stat">Toplam: {users.length}</div>
          <div className="toolbar-stat">Filtrelenen: {filtered.length}</div>
          <button className="ghost" onClick={() => setFilters(emptyFilters)} type="button">
            Filtreleri sıfırla
          </button>
          <button className="primary" onClick={() => setDialogOpen(true)} type="button">
            Personel Ekle
          </button>
        </div>

        <div className="table-wrapper">
          <table className="personnel-table">
            <thead>
              <tr>
                <th>Ad Soyad</th>
                <th>E-posta</th>
                <th>Telefon</th>
                <th>Görev</th>
                <th>Şube</th>
                <th>Pozisyon</th>
                <th className="text-right">İşlemler</th>
              </tr>
              <tr className="filter-row">
                <th>
                  <input
                    className="filter-input"
                    placeholder="Ad / Soyad"
                    value={filters.name}
                    onChange={(e) => handleFilter("name", e.target.value)}
                  />
                </th>
                <th>
                  <input
                    className="filter-input"
                    placeholder="E-posta"
                    value={filters.email}
                    onChange={(e) => handleFilter("email", e.target.value)}
                  />
                </th>
                <th>
                  <input
                    className="filter-input"
                    placeholder="Telefon"
                    value={filters.phone}
                    onChange={(e) => handleFilter("phone", e.target.value)}
                  />
                </th>
                <th>
                  <select
                    className="filter-input"
                    value={filters.role}
                    onChange={(e) => handleFilter("role", e.target.value)}
                  >
                    <option value="">Tümü</option>
                    {ROLE_OPTIONS.map((opt) => (
                      <option key={opt.value} value={opt.value}>
                        {opt.label}
                      </option>
                    ))}
                  </select>
                </th>
                <th>
                  <select
                    className="filter-input"
                    value={filters.branch}
                    onChange={(e) => handleFilter("branch", e.target.value)}
                  >
                    <option value="">Tümü</option>
                    {branches.map((branch) => (
                      <option key={branch.id} value={branch.id}>
                        {branch.name}
                      </option>
                    ))}
                  </select>
                </th>
                <th>
                  <input
                    className="filter-input"
                    placeholder="Pozisyon"
                    value={filters.position}
                    onChange={(e) => handleFilter("position", e.target.value)}
                  />
                </th>
                <th />
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={7} className="empty">
                    Kayıt bulunamadı.
                  </td>
                </tr>
              ) : (
                filtered.map((user) => (
                  <tr key={user.id}>
                    <td className="font-semibold">{fullName(user)}</td>
                    <td>{user.email ?? "-"}</td>
                    <td>{user.phone ?? "-"}</td>
                    <td>
                      <select
                        className="filter-input"
                        value={user.role ?? ""}
                        onChange={(e) => handleUpdate(user, { role: e.target.value })}
                      >
                        {ROLE_OPTIONS.map((opt) => (
                          <option key={opt.value} value={opt.value}>
                            {opt.label}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td>
                      <select
                        className="filter-input"
                        value={user.branch_id ?? ""}
                        onChange={(e) => handleUpdate(user, { branch_id: e.target.value })}
                      >
                        {branches.map((branch) => (
                          <option key={branch.id} value={branch.id}>
                            {branch.name}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td>
                      <input
                        className="filter-input"
                        value={user.position ?? ""}
                        onChange={(e) => handleUpdate(user, { position: e.target.value })}
                        placeholder="Pozisyon"
                      />
                    </td>
                    <td className="text-right">
                      <button className="danger ghost" onClick={() => setDeleteId(user.id)} type="button">
                        Sil
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      <Dialog open={dialogOpen} onClose={setDialogOpen} static={true}>
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
            <button className="primary" onClick={handleCreate} type="button">
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
    </div>
  );
}
