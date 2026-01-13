"use client";

import { useEffect, useMemo, useState } from "react";
import "./skt.css";

type SktRecord = {
  id: string;
  branch_id: string;
  product_id: string;
  expiry_date: string;
  quantity: number | null;
  notes: string | null;
  product_status: string | null;
  status: string | null;
  alarm_days_before: number | null;
  alarm_date?: string | null;
  alarm_sent?: boolean | null;
  products?: {
    id: string;
    name: string;
    barcode: string;
    alt_barcodes: string[] | null;
    category: string | null;
    brand: string | null;
  } | null;
  branches?: {
    id: string;
    name: string | null;
  } | null;
};

type UiRecord = {
  id: string;
  branchId: string;
  productId: string;
  product: string;
  barcode: string;
  altBarcodes: string[];
  category: string | null;
  brand: string | null;
  branch: string | null;
  expiry: string;
  daysLeft: number;
  quantity: number | null;
  productStatus: string | null;
  notes: string | null;
};

type StatusFilter = "all" | "expired" | "upcoming" | "normal";

type TimelineKey =
  | "all"
  | "week1"
  | "week2"
  | "week3"
  | "month1"
  | "month2"
  | "month3"
  | "expired";

const timelineOptions: { key: TimelineKey; label: string; range: { min?: number; max?: number; includeExpired?: boolean } }[] = [
  { key: "all", label: "Tümü", range: { includeExpired: true } },
  { key: "week1", label: "0-7 gün", range: { min: 0, max: 7 } },
  { key: "week2", label: "8-14 gün", range: { min: 8, max: 14 } },
  { key: "week3", label: "15-21 gün", range: { min: 15, max: 21 } },
  { key: "month1", label: "22-30 gün", range: { min: 22, max: 30 } },
  { key: "month2", label: "31-60 gün", range: { min: 31, max: 60 } },
  { key: "month3", label: "61-90 gün", range: { min: 61, max: 90 } },
  { key: "expired", label: "Süresi geçmiş", range: { includeExpired: true } },
];

type ModalState =
  | { type: "create" }
  | { type: "edit"; record: UiRecord }
  | { type: "assign" }
  | null;

type FormState = {
  productId: string;
  productSearch: string;
  expiryDate: string;
  quantity: string;
  notes: string;
  productStatus: string;
  alarmDays: string;
};

type Assignee = { id: string; name: string };
type ProductOption = { id: string; name: string; barcode: string; alt_barcodes?: string[] | null };

export default function SktPage() {
  const [records, setRecords] = useState<SktRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState<string | null>(null);
  const [timeline, setTimeline] = useState<TimelineKey>("all");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [modal, setModal] = useState<ModalState>(null);
  const [form, setForm] = useState<FormState>({
    productId: "",
    productSearch: "",
    expiryDate: "",
    quantity: "",
    notes: "",
    productStatus: "",
    alarmDays: "7",
  });
  const [productOptions, setProductOptions] = useState<ProductOption[]>([]);
  const [productLoading, setProductLoading] = useState(false);
  const [assignForm, setAssignForm] = useState<{ assigneeId: string; dueDate: string }>(
    { assigneeId: "", dueDate: "" }
  );
  const [assignees, setAssignees] = useState<Assignee[]>([]);
  const [assignLoading, setAssignLoading] = useState(false);

  useEffect(() => {
    void loadRecords();
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    const timer = setTimeout(() => {
      const q = form.productSearch.trim();
      if (q.length < 2) {
        setProductOptions([]);
        return;
      }
      setProductLoading(true);
      fetch(`/api/skt/products?query=${encodeURIComponent(q)}`, { signal: controller.signal })
        .then(async (res) => {
          if (!res.ok) throw new Error("Ürün aranamadı");
          const body = (await res.json()) as { products: ProductOption[] };
          setProductOptions(body.products ?? []);
        })
        .catch(() => {})
        .finally(() => setProductLoading(false));
    }, 250);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [form.productSearch]);

  async function loadRecords() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/skt");
      if (!res.ok) throw new Error("SKT kayıtları alınamadı");
      const body = (await res.json()) as { records: SktRecord[] };
      setRecords(body.records ?? []);
      setSelected(new Set());
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  }

  const mapped = useMemo<UiRecord[]>(() => {
    const today = new Date();
    return records.map((r) => {
      const product = r.products;
      const expiry = new Date(r.expiry_date);
      const daysLeft = Math.floor((expiry.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
      return {
        id: r.id,
        branchId: r.branch_id,
        productId: r.product_id,
        product: product?.name ?? "İsimsiz ürün",
        barcode: product?.barcode ?? "-",
        altBarcodes: (product?.alt_barcodes ?? []).filter(Boolean) as string[],
        category: product?.category ?? null,
        brand: product?.brand ?? null,
        branch: r.branches?.name ?? null,
        expiry: expiry.toISOString(),
        daysLeft,
        quantity: typeof r.quantity === "number" ? r.quantity : null,
        productStatus: r.product_status,
        notes: r.notes,
      };
    });
  }, [records]);

  const categories = useMemo(() => {
    const set = new Set<string>();
    mapped.forEach((r) => {
      if (r.category) set.add(r.category);
    });
    return Array.from(set).sort((a, b) => a.localeCompare(b, "tr"));
  }, [mapped]);

  const filtered = useMemo(() => {
    const needle = search.trim().toLowerCase();
    const option = timelineOptions.find((t) => t.key === timeline);
    const min = option?.range.min ?? null;
    const max = option?.range.max ?? null;
    const includeExpired = option?.range.includeExpired ?? false;

    return mapped.filter((r) => {
      const matchesSearch =
        needle.length === 0 ||
        r.product.toLowerCase().includes(needle) ||
        r.barcode.toLowerCase().includes(needle) ||
        r.altBarcodes.some((code) => code.toLowerCase().includes(needle));

      const matchesCategory = !category || r.category?.toLowerCase() === category.toLowerCase();

      const days = r.daysLeft;
      const isExpired = days < 0;
      const matchesTimeline = (() => {
        if (timeline === "expired") return isExpired;
        if (isExpired && !includeExpired) return false;
        if (min !== null && days < min) return false;
        if (max !== null && days > max) return false;
        return true;
      })();

      const matchesStatus = (() => {
        switch (statusFilter) {
          case "expired":
            return isExpired;
          case "upcoming":
            return !isExpired && days <= 7;
          case "normal":
            return !isExpired && days > 7;
          default:
            return true;
        }
      })();

      return matchesSearch && matchesCategory && matchesTimeline && matchesStatus;
    });
  }, [mapped, search, category, timeline, statusFilter]);

  const allSelected = filtered.length > 0 && filtered.every((r) => selected.has(r.id));

  const openCreate = () => {
    setForm({ productId: "", productSearch: "", expiryDate: "", quantity: "", notes: "", productStatus: "", alarmDays: "7" });
    setModal({ type: "create" });
    setProductOptions([]);
  };

  const openEdit = () => {
    if (selected.size !== 1) return;
    const id = Array.from(selected)[0];
    const record = mapped.find((r) => r.id === id);
    if (!record) return;
    setForm({
      productId: record.productId,
      productSearch: `${record.product} (${record.barcode})`,
      expiryDate: record.expiry.slice(0, 10),
      quantity: record.quantity?.toString() ?? "",
      notes: record.notes ?? "",
      productStatus: record.productStatus ?? "",
      alarmDays: "7",
    });
    setModal({ type: "edit", record });
  };

  const saveRecord = async () => {
    if (!form.productId.trim()) {
      throw new Error("Ürün seçiniz");
    }
    const payload = {
      product_id: form.productId.trim(),
      expiry_date: form.expiryDate,
      quantity: form.quantity ? Number(form.quantity) : null,
      notes: form.notes.trim() || null,
      product_status: form.productStatus.trim() || null,
      alarm_days_before: form.alarmDays ? Number(form.alarmDays) : 7,
    };

    const url = "/api/skt";
    const method = modal?.type === "edit" ? "PATCH" : "POST";
    const body = modal?.type === "edit" ? { ...payload, id: modal.record.id } : payload;

    const res = await fetch(url, {
      method,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const detail = await res.text();
      throw new Error(detail || "Kayıt kaydedilemedi");
    }
  };

  const deleteSelected = async () => {
    const ids = Array.from(selected);
    if (!ids.length) return;
    const res = await fetch("/api/skt", {
      method: "DELETE",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ids }),
    });
    if (!res.ok) {
      const detail = await res.text();
      throw new Error(detail || "Kayıtlar silinemedi");
    }
  };

  const loadAssignees = async () => {
    if (assignees.length > 0) return;
    try {
      const res = await fetch("/api/skt/assignees");
      if (!res.ok) throw new Error("Personel listesi alınamadı");
      const body = (await res.json()) as { users: { id: string; first_name: string | null; last_name: string | null; email: string | null }[] };
      const mappedUsers: Assignee[] = (body.users ?? []).map((u) => {
        const name = [u.first_name, u.last_name].filter(Boolean).join(" ");
        return { id: u.id, name: name || u.email || u.id };
      });
      setAssignees(mappedUsers);
    } catch (err) {
      setError((err as Error).message);
    }
  };

  const createTaskForSelection = async () => {
    if (!assignForm.assigneeId || selected.size === 0) {
      throw new Error("Personel ve kayıt seçimi gerekli");
    }
    setAssignLoading(true);
    try {
      const res = await fetch("/api/skt/tasks", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          recordIds: Array.from(selected),
          assigneeId: assignForm.assigneeId,
          dueDate: assignForm.dueDate || null,
        }),
      });
      if (!res.ok) {
        const detail = await res.text();
        throw new Error(detail || "Görev oluşturulamadı");
      }
    } finally {
      setAssignLoading(false);
    }
  };

  const closeModal = () => setModal(null);

  return (
    <div className="page">
      <header className="page-header">
        <h2>SKT Kontrol</h2>
        <p>Şube müdürü kendi şubesindeki SKT kayıtlarını izler, filtreler ve aksiyon alır.</p>
      </header>

      <div className="card skt-card">
        <div className="skt-toolbar">
          <div className="skt-search">
            <input
              placeholder="Ürün adı, barkod veya alt barkod"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="skt-filters">
            <select value={category ?? ""} onChange={(e) => setCategory(e.target.value || null)}>
              <option value="">Kategori: Tümü</option>
              {categories.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
            <select value={timeline} onChange={(e) => setTimeline(e.target.value as TimelineKey)}>
              {timelineOptions.map((opt) => (
                <option key={opt.key} value={opt.key}>
                  {opt.label}
                </option>
              ))}
            </select>
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value as StatusFilter)}>
              <option value="all">Durum: Tümü</option>
              <option value="upcoming">Yaklaşan (≤7 gün)</option>
              <option value="normal">Normal (&gt;7 gün)</option>
              <option value="expired">Süresi geçmiş</option>
            </select>
          </div>
          <div className="skt-actions">
            <button onClick={openCreate} className="primary">Yeni SKT</button>
            <button onClick={openEdit} disabled={selected.size !== 1}>Düzenle</button>
            <button
              onClick={() => {
                if (selected.size === 0) return;
                if (!window.confirm("Seçili kayıtlar silinsin mi?")) return;
                void deleteSelected().then(loadRecords).catch((err) => setError((err as Error).message));
              }}
              disabled={selected.size === 0}
              className="danger"
            >
              Sil
            </button>
            <button
              onClick={() => {
                setModal({ type: "assign" });
                void loadAssignees();
              }}
              disabled={selected.size === 0}
            >
              Görev Ata
            </button>
          </div>
          <div className="skt-stats">
            <span>Toplam: {mapped.length}</span>
            <span>Filtrelenen: {filtered.length}</span>
            <span>Seçili: {selected.size}</span>
          </div>
        </div>

        {loading ? <p>Yükleniyor...</p> : null}
        {error ? <p className="error">{error}</p> : null}

        {!loading && !error ? (
          <div className="table-wrapper">
            <table className="skt-table">
              <thead>
                <tr>
                  <th>
                    <input
                      type="checkbox"
                      checked={allSelected}
                      onChange={() => {
                        if (allSelected) {
                          setSelected(new Set());
                        } else {
                          setSelected(new Set(filtered.map((r) => r.id)));
                        }
                      }}
                    />
                  </th>
                  <th>Ürün</th>
                  <th>Barkod</th>
                  <th>Alt Barkodlar</th>
                  <th>Kategori</th>
                  <th>Şube</th>
                  <th>SKT</th>
                  <th>Gün</th>
                  <th>Adet</th>
                  <th>Durum</th>
                  <th>Not</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={11} className="empty">
                      Kayıt bulunamadı.
                    </td>
                  </tr>
                ) : (
                  filtered.map((r) => {
                    const isExpired = r.daysLeft < 0;
                    const isSoon = !isExpired && r.daysLeft <= 7;
                    const checked = selected.has(r.id);
                    return (
                      <tr key={r.id} className={checked ? "row-selected" : ""}>
                        <td>
                          <input
                            type="checkbox"
                            checked={checked}
                            onChange={(e) => {
                              const next = new Set(selected);
                              if (e.target.checked) next.add(r.id);
                              else next.delete(r.id);
                              setSelected(next);
                            }}
                          />
                        </td>
                        <td>
                          <div className="cell-main">{r.product}</div>
                          {r.brand ? <div className="cell-sub">{r.brand}</div> : null}
                        </td>
                        <td>{r.barcode}</td>
                        <td className="cell-sub">{r.altBarcodes.length ? r.altBarcodes.join(", ") : "-"}</td>
                        <td>{r.category ?? "-"}</td>
                        <td>{r.branch ?? "-"}</td>
                        <td>{new Date(r.expiry).toLocaleDateString("tr-TR")}</td>
                        <td>
                          <span className={isExpired ? "status-chip danger" : isSoon ? "status-chip warn" : "status-chip ok"}>
                            {r.daysLeft}
                          </span>
                        </td>
                        <td>{r.quantity ?? "-"}</td>
                        <td>{isExpired ? "Süresi geçmiş" : isSoon ? "Yaklaşıyor" : "Normal"}</td>
                        <td className="cell-sub">{r.notes || "-"}</td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        ) : null}
      </div>

      {modal ? (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal">
            {modal.type === "assign" ? (
              <>
                <h3>Görev Ata</h3>
                <label className="field">
                  <span>Personel</span>
                  <select
                    value={assignForm.assigneeId}
                    onChange={(e) => setAssignForm((p) => ({ ...p, assigneeId: e.target.value }))}
                  >
                    <option value="">Seç</option>
                    {assignees.map((u) => (
                      <option key={u.id} value={u.id}>
                        {u.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="field">
                  <span>Teslim tarihi (opsiyonel)</span>
                  <input
                    type="date"
                    value={assignForm.dueDate}
                    onChange={(e) => setAssignForm((p) => ({ ...p, dueDate: e.target.value }))}
                  />
                </label>
                <p className="hint">Seçili {selected.size} kayıt görev olarak atanacak.</p>
                <div className="modal-actions">
                  <button onClick={closeModal}>İptal</button>
                  <button
                    className="primary"
                    disabled={assignLoading}
                    onClick={() =>
                      createTaskForSelection()
                        .then(() => {
                          closeModal();
                        })
                        .catch((err) => setError((err as Error).message))
                    }
                  >
                    {assignLoading ? "Oluşturuluyor..." : "Görev Oluştur"}
                  </button>
                </div>
              </>
            ) : (
              <>
                <h3>{modal.type === "create" ? "Yeni SKT Kaydı" : "SKT Kaydını Düzenle"}</h3>
                <label className="field">
                  <span>Ürün ara (ad, barkod)</span>
                  <input
                    value={form.productSearch}
                    onChange={(e) => setForm((p) => ({ ...p, productSearch: e.target.value }))}
                    placeholder="Ürün adı veya barkod"
                  />
                  {productLoading ? <span className="hint">Aranıyor...</span> : null}
                  {productOptions.length > 0 ? (
                    <div className="option-list">
                      {productOptions.map((p) => (
                        <button
                          key={p.id}
                          type="button"
                          className="option-item"
                          onClick={() => {
                            setForm((prev) => ({
                              ...prev,
                              productId: p.id,
                              productSearch: `${p.name} (${p.barcode})`,
                            }));
                            setProductOptions([]);
                          }}
                        >
                          <div className="cell-main">{p.name}</div>
                          <div className="cell-sub">{p.barcode}</div>
                          {p.alt_barcodes?.length ? (
                            <div className="cell-sub">Alt: {p.alt_barcodes.join(", ")}</div>
                          ) : null}
                        </button>
                      ))}
                    </div>
                  ) : null}
                  {form.productId ? <span className="hint">Seçili ürün: {form.productSearch || form.productId}</span> : null}
                </label>
                <label className="field">
                  <span>SKT</span>
                  <input
                    type="date"
                    value={form.expiryDate}
                    onChange={(e) => setForm((p) => ({ ...p, expiryDate: e.target.value }))}
                  />
                </label>
                <label className="field">
                  <span>Adet</span>
                  <input
                    type="number"
                    value={form.quantity}
                    onChange={(e) => setForm((p) => ({ ...p, quantity: e.target.value }))}
                  />
                </label>
                <label className="field">
                  <span>Ürün durumu</span>
                  <input
                    value={form.productStatus}
                    onChange={(e) => setForm((p) => ({ ...p, productStatus: e.target.value }))}
                    placeholder="Örn: raf, depoda, iade"
                  />
                </label>
                <label className="field">
                  <span>Alarm (gün önce)</span>
                  <input
                    type="number"
                    value={form.alarmDays}
                    onChange={(e) => setForm((p) => ({ ...p, alarmDays: e.target.value }))}
                  />
                </label>
                <label className="field">
                  <span>Not</span>
                  <textarea
                    value={form.notes}
                    onChange={(e) => setForm((p) => ({ ...p, notes: e.target.value }))}
                    rows={3}
                  />
                </label>
                <div className="modal-actions">
                  <button onClick={closeModal}>İptal</button>
                  <button
                    className="primary"
                    onClick={() =>
                      saveRecord()
                        .then(() => {
                          closeModal();
                          void loadRecords();
                        })
                        .catch((err) => setError((err as Error).message))
                    }
                  >
                    Kaydet
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}
