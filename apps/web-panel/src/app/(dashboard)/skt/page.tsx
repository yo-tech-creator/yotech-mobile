"use client";

import { useEffect, useMemo, useState } from "react";
import { CardActionButton, CardInlineActions, CardListShell, SoftBadge, cardStyles } from "@/components/ui/card-list";
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

type ViewMode = "all" | "requests";

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
  const [viewMode, setViewMode] = useState<ViewMode>("all");
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
      // View mode filtresi - talepler sadece product_status dolu olanları gösterir
      if (viewMode === "requests" && !r.productStatus) return false;

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
  }, [mapped, search, category, timeline, statusFilter, viewMode]);

  // Talep sayısı hesapla
  const requestCount = useMemo(() => mapped.filter((r) => r.productStatus).length, [mapped]);

  const allSelected = filtered.length > 0 && filtered.every((r) => selected.has(r.id));

  const toggleSelect = (id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const selectAllFiltered = () => setSelected(new Set(filtered.map((r) => r.id)));
  const clearSelection = () => setSelected(new Set());

  const openCreate = () => {
    setForm({ productId: "", productSearch: "", expiryDate: "", quantity: "", notes: "", productStatus: "", alarmDays: "7" });
    setModal({ type: "create" });
    setProductOptions([]);
  };

  const openEdit = (record?: UiRecord) => {
    const target = record ?? (selected.size === 1 ? mapped.find((r) => r.id === Array.from(selected)[0]) : null);
    if (!target) return;
    setSelected(new Set([target.id]));
    setForm({
      productId: target.productId,
      productSearch: `${target.product} (${target.barcode})`,
      expiryDate: target.expiry.slice(0, 10),
      quantity: target.quantity?.toString() ?? "",
      notes: target.notes ?? "",
      productStatus: target.productStatus ?? "",
      alarmDays: "7",
    });
    setModal({ type: "edit", record: target });
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

  const deleteSelected = async (idsOverride?: string[]) => {
    const ids = idsOverride ?? Array.from(selected);
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
    setSelected(new Set());
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

  const filterContent = (
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      {/* Görünüm Seçici - Tüm Kayıtlar / Talepler */}
      <div style={{ display: "flex", gap: 8, marginBottom: 4 }}>
        <button
          type="button"
          className={`filter-tab ${viewMode === "all" ? "active" : ""}`}
          onClick={() => setViewMode("all")}
          style={{
            padding: "8px 16px",
            borderRadius: 8,
            border: viewMode === "all" ? "2px solid var(--primary)" : "1px solid var(--border)",
            background: viewMode === "all" ? "var(--primary-light)" : "transparent",
            fontWeight: viewMode === "all" ? 700 : 400,
            cursor: "pointer",
          }}
        >
          📋 Tüm Kayıtlar ({mapped.length})
        </button>
        <button
          type="button"
          className={`filter-tab ${viewMode === "requests" ? "active" : ""}`}
          onClick={() => setViewMode("requests")}
          style={{
            padding: "8px 16px",
            borderRadius: 8,
            border: viewMode === "requests" ? "2px solid var(--primary)" : "1px solid var(--border)",
            background: viewMode === "requests" ? "var(--primary-light)" : "transparent",
            fontWeight: viewMode === "requests" ? 700 : 400,
            cursor: "pointer",
            position: "relative",
          }}
        >
          📨 Şube Talepleri
          {requestCount > 0 && (
            <span
              style={{
                position: "absolute",
                top: -6,
                right: -6,
                background: "var(--danger)",
                color: "white",
                borderRadius: "50%",
                width: 20,
                height: 20,
                fontSize: 11,
                fontWeight: 700,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              {requestCount}
            </span>
          )}
        </button>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: 10 }}>
        <input
          className="filter-input"
          placeholder="Ürün adı, barkod veya alt barkod"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select className="filter-input" value={category ?? ""} onChange={(e) => setCategory(e.target.value || null)}>
          <option value="">Kategori: Tümü</option>
          {categories.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
        <select className="filter-input" value={timeline} onChange={(e) => setTimeline(e.target.value as TimelineKey)}>
          {timelineOptions.map((opt) => (
            <option key={opt.key} value={opt.key}>
              {opt.label}
            </option>
          ))}
        </select>
        <select className="filter-input" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value as StatusFilter)}>
          <option value="all">Durum: Tümü</option>
          <option value="upcoming">Yaklaşan (≤7 gün)</option>
          <option value="normal">Normal (&gt;7 gün)</option>
          <option value="expired">Süresi geçmiş</option>
        </select>
      </div>
    </div>
  );

  const filterPills = [
    viewMode === "requests" ? { label: "📨 Şube Talepleri", tone: "info" as const } : null,
    search.trim() ? { label: `Arama: ${search}` } : null,
    category ? { label: `Kategori: ${category}` } : null,
    timeline !== "all" ? { label: `Zaman: ${timelineOptions.find((t) => t.key === timeline)?.label ?? timeline}` } : null,
    statusFilter !== "all" ? { label: `Durum: ${statusFilter}` } : null,
  ].filter(Boolean) as { label: string; tone?: "info" | "success" | "warn" | "danger" | "muted" }[];

  const inlineActionsBar = filtered.length > 0 ? (
    <CardInlineActions>
      <span style={{ fontWeight: 700 }}>Seçili: {selected.size}</span>
      <button className="ghost" type="button" onClick={allSelected ? clearSelection : selectAllFiltered}>
        {allSelected ? "Seçimi temizle" : "Filtreleneni seç"}
      </button>
    </CardInlineActions>
  ) : null;

  const cards = filtered.map((r) => {
    const isExpired = r.daysLeft < 0;
    const isSoon = !isExpired && r.daysLeft <= 7;
    const tone: "danger" | "warn" | "success" = isExpired ? "danger" : isSoon ? "warn" : "success";

    return (
      <div key={r.id} style={{ ...cardStyles.row, border: selected.has(r.id) ? "1px solid rgba(124,58,237,0.5)" : cardStyles.row.border }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12, minWidth: 220 }}>
          <input type="checkbox" checked={selected.has(r.id)} onChange={() => toggleSelect(r.id)} />
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            <div style={{ fontWeight: 800 }}>{r.product}</div>
            <div style={{ color: "var(--text-subtle)", fontSize: 13 }}>{r.brand ?? "-"}</div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
              <SoftBadge tone="muted" label={`Barkod ${r.barcode}`} />
              {r.altBarcodes.length ? <SoftBadge tone="muted" label={`Alt: ${r.altBarcodes.join(", ")}`} /> : null}
            </div>
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <SoftBadge tone="info" label={`Kategori: ${r.category ?? "-"}`} />
          <SoftBadge tone="info" label={`Şube: ${r.branch ?? "-"}`} />
          <SoftBadge tone="muted" label={`Adet: ${r.quantity ?? "-"}`} />
          {r.productStatus && (
            <SoftBadge tone="warn" label={`📨 Talep: ${r.productStatus}`} />
          )}
        </div>

        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 8 }}>
          <SoftBadge tone={tone} label={`SKT ${new Date(r.expiry).toLocaleDateString("tr-TR")}`} />
          <SoftBadge tone={tone} label={`${r.daysLeft} gün`} />
          <div style={{ color: "var(--text-subtle)", fontSize: 12, textAlign: "right", maxWidth: 320 }}>{r.notes || "-"}</div>
          <CardInlineActions>
            <CardActionButton tone="info" onClick={() => openEdit(r)} label="Düzenle" />
            <CardActionButton
              tone="muted"
              onClick={() => {
                setSelected(new Set([r.id]));
                setModal({ type: "assign" });
                void loadAssignees();
              }}
              label="Görev"
            />
            <CardActionButton
              tone="danger"
              onClick={() => {
                if (!window.confirm("Bu kayıt silinsin mi?")) return;
                void deleteSelected([r.id])
                  .then(loadRecords)
                  .catch((err) => setError((err as Error).message));
              }}
              label="Sil"
            />
          </CardInlineActions>
        </div>
      </div>
    );
  });

  return (
    <CardListShell
      title="SKT Kontrol"
      description="Şube müdürü kendi şubesindeki SKT kayıtlarını izler, filtreler ve aksiyon alır."
      stats={[
        { label: "Toplam", value: mapped.length },
        { label: "Talepler", value: requestCount },
        { label: "Filtrelenen", value: filtered.length },
        { label: "Seçili", value: selected.size },
      ]}
      actions={
        <>
          <CardActionButton tone="info" label="Yenile" onClick={() => void loadRecords()} disabled={loading} />
          <CardActionButton tone="success" label="Yeni SKT" onClick={openCreate} />
          <CardActionButton tone="info" label="Düzenle" onClick={() => openEdit()} disabled={selected.size !== 1} />
          <CardActionButton
            tone="muted"
            label="Görev Ata"
            onClick={() => {
              if (selected.size === 0) return;
              setModal({ type: "assign" });
              void loadAssignees();
            }}
            disabled={selected.size === 0}
          />
          <CardActionButton
            tone="danger"
            label="Sil"
            onClick={() => {
              if (selected.size === 0) return;
              if (!window.confirm("Seçili kayıtlar silinsin mi?")) return;
              void deleteSelected()
                .then(loadRecords)
                .catch((err) => setError((err as Error).message));
            }}
            disabled={selected.size === 0}
          />
        </>
      }
      inlineActions={inlineActionsBar}
      filterContent={filterContent}
      pills={filterPills}
    >
      {loading ? <p>Yükleniyor...</p> : null}
      {error ? <p className="error">{error}</p> : null}

      {!loading && !error && filtered.length === 0 ? <p className="muted">Kayıt bulunamadı.</p> : null}

      {!loading && !error ? cards : null}

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
    </CardListShell>
  );
}
