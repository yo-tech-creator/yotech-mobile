"use client";

import { useEffect, useMemo, useState } from "react";
import { toast } from "sonner";
import "./merch.css";

type MerchPerson = {
  id: string;
  first_name: string;
  last_name: string;
  company_name: string;
  phone_number: string;
  rank: string;
};

type MerchResponse = { people: MerchPerson[] };

const RANK_OPTIONS = [
  { value: "merch", label: "Mörş" },
  { value: "plasiyer", label: "Plasiyer" },
  { value: "sevkiyat", label: "Sevkiyat" },
  { value: "sef", label: "Şef" },
  { value: "yonetici", label: "Yönetici" },
];

const emptyForm = {
  first_name: "",
  last_name: "",
  company_name: "",
  phone_number: "",
  rank: RANK_OPTIONS[0].value,
};

const emptyFilters = {
  name: "",
  company: "",
  phone: "",
  rank: "",
};

export default function MerchPage() {
  const [people, setPeople] = useState<MerchPerson[]>([]);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState(emptyFilters);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);

  useEffect(() => {
    fetchAll();
  }, []);

  async function fetchAll() {
    setLoading(true);
    try {
      const res = await fetch("/api/merch");
      if (!res.ok) throw new Error("Mörş listesi alınamadı");
      const body = (await res.json()) as MerchResponse;
      setPeople(body.people ?? []);
    } catch (error) {
      console.error(error);
      toast.error("Veriler alınamadı");
    } finally {
      setLoading(false);
    }
  }

  const filtered = useMemo(() => {
    const match = (target: string | null | undefined, term: string) => (target ?? "").toLowerCase().includes(term.toLowerCase().trim());
    return people.filter((p) => {
      if (filters.name && !match(`${p.first_name} ${p.last_name}`, filters.name)) return false;
      if (filters.company && !match(p.company_name, filters.company)) return false;
      if (filters.phone && !match(p.phone_number, filters.phone)) return false;
      if (filters.rank && p.rank !== filters.rank) return false;
      return true;
    });
  }, [filters, people]);

  function handleFilter(key: keyof typeof emptyFilters, value: string) {
    setFilters((prev) => ({ ...prev, [key]: value }));
  }

  function handleForm(key: keyof typeof emptyForm, value: string) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  function openCreate() {
    setEditingId(null);
    setForm(emptyForm);
    setDialogOpen(true);
  }

  function openEdit(person: MerchPerson) {
    setEditingId(person.id);
    setForm({
      first_name: person.first_name,
      last_name: person.last_name,
      company_name: person.company_name,
      phone_number: person.phone_number,
      rank: person.rank,
    });
    setDialogOpen(true);
  }

  async function handleSave() {
    if (!form.first_name || !form.last_name || !form.company_name || !form.phone_number) {
      toast.error("Zorunlu alanları doldurun");
      return;
    }
    try {
      const res = await fetch("/api/merch", {
        method: editingId ? "PATCH" : "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...form, id: editingId ?? undefined }),
      });
      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        throw new Error(detail?.message || "Kayıt başarısız");
      }
      toast.success(editingId ? "Güncellendi" : "Eklendi");
      setDialogOpen(false);
      setEditingId(null);
      setForm(emptyForm);
      fetchAll();
    } catch (error) {
      console.error(error);
      toast.error("Kayıt başarısız");
    }
  }

  async function handleDelete() {
    if (!deleteId) return;
    try {
      const res = await fetch(`/api/merch?id=${deleteId}`, { method: "DELETE" });
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

  async function handleSaveInline(person: MerchPerson, updates: Partial<MerchPerson>) {
    try {
      const res = await fetch("/api/merch", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: person.id, ...updates }),
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

  if (loading) {
    return <div className="flex h-full items-center justify-center text-sm text-gray-600">Yükleniyor…</div>;
  }

  return (
    <div className="page">
      <header className="page-header">
        <h2>Mörş / Plasiyer</h2>
        <p>Firmaya eklenmiş mörş bilgilerini görüntüleyin ve düzenleyin.</p>
      </header>

      <div className="card table-card">
        <div className="table-toolbar">
          <div className="toolbar-stat">Toplam: {people.length}</div>
          <div className="toolbar-stat">Filtrelenen: {filtered.length}</div>
          <button className="ghost" onClick={() => setFilters(emptyFilters)} type="button">
            Filtreleri sıfırla
          </button>
          <button className="primary" onClick={openCreate} type="button">
            Yeni Kayıt
          </button>
        </div>

        <div className="table-wrapper">
          <table className="merch-table">
            <thead>
              <tr>
                <th>Ad Soyad</th>
                <th>Firma</th>
                <th>Telefon</th>
                <th>Görev</th>
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
                    placeholder="Firma"
                    value={filters.company}
                    onChange={(e) => handleFilter("company", e.target.value)}
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
                    value={filters.rank}
                    onChange={(e) => handleFilter("rank", e.target.value)}
                  >
                    <option value="">Tümü</option>
                    {RANK_OPTIONS.map((opt) => (
                      <option key={opt.value} value={opt.value}>
                        {opt.label}
                      </option>
                    ))}
                  </select>
                </th>
                <th />
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={5} className="empty">
                    Kayıt bulunamadı.
                  </td>
                </tr>
              ) : (
                filtered.map((p) => (
                  <tr key={p.id}>
                    <td className="font-semibold">{p.first_name} {p.last_name}</td>
                    <td>{p.company_name}</td>
                    <td>+90 {p.phone_number}</td>
                    <td>
                      <select
                        className="filter-input"
                        value={p.rank}
                        onChange={(e) => handleSaveInline(p, { rank: e.target.value })}
                      >
                        {RANK_OPTIONS.map((opt) => (
                          <option key={opt.value} value={opt.value}>
                            {opt.label}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td className="text-right space-x-2">
                      <button className="ghost" onClick={() => openEdit(p)} type="button">
                        Düzenle
                      </button>
                      <button className="danger ghost" onClick={() => setDeleteId(p.id)} type="button">
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

      {dialogOpen && (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal-panel space-y-4 sm:max-w-lg">
            <div>
              <p className="text-lg font-semibold">{editingId ? "Mörş Düzenle" : "Yeni Mörş"}</p>
              <p className="text-sm text-gray-500">Zorunlu alanları doldurun.</p>
            </div>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <input
                className="filter-input"
                value={form.first_name}
                onChange={(e) => handleForm("first_name", e.target.value)}
                placeholder="Ad"
              />
              <input
                className="filter-input"
                value={form.last_name}
                onChange={(e) => handleForm("last_name", e.target.value)}
                placeholder="Soyad"
              />
            </div>
            <input
              className="filter-input"
              value={form.company_name}
              onChange={(e) => handleForm("company_name", e.target.value)}
              placeholder="Firma"
            />
            <input
              className="filter-input"
              value={form.phone_number}
              onChange={(e) => handleForm("phone_number", e.target.value)}
              placeholder="Telefon"
            />
            <select className="filter-input" value={form.rank} onChange={(e) => handleForm("rank", e.target.value)}>
              {RANK_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
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
          </div>
        </div>
      )}

      {Boolean(deleteId) && (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal-panel space-y-4 sm:max-w-md">
            <div>
              <p className="text-lg font-semibold">Silme Onayı</p>
              <p className="text-sm text-gray-500">Bu kaydı silmek istediğinize emin misiniz?</p>
            </div>
            <div className="flex justify-end gap-2">
              <button className="ghost" onClick={() => setDeleteId(null)} type="button">
                İptal
              </button>
              <button className="danger" onClick={handleDelete} type="button">
                Sil
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
