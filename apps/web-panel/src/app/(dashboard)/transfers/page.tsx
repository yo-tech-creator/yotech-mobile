"use client";

import { useEffect, useMemo, useState } from "react";
import "./transfers.css";

type Offer = {
  id: string;
  notice_id: string;
  tenant_id: string;
  branch_id: string;
  branch_name?: string | null;
  offered_by: string;
  quantity: number;
  status: string;
  decision_by?: string | null;
  decision_at?: string | null;
  message?: string | null;
  created_at: string;
  updated_at?: string | null;
};

type Notice = {
  id: string;
  tenant_id: string;
  branch_id: string;
  branch_name?: string | null;
  created_by: string;
  product_id?: string | null;
  product_name: string;
  quantity: number;
  unit: string;
  type: "surplus" | "shortage" | string;
  status: "open" | "in_transfer" | "fulfilled" | "cancelled" | string;
  note?: string | null;
  expires_at?: string | null;
  created_at: string;
  updated_at?: string | null;
  offers?: Offer[] | null;
};

type Viewer = { id: string; branchId: string | null };

type TabKey = "all" | "mine" | "offers";

type ModalState =
  | { type: "create" }
  | { type: "offer"; notice: Notice }
  | { type: "detail"; notice: Notice }
  | { type: "edit-offer"; notice: Notice; offer: Offer }
  | { type: "edit-notice"; notice: Notice };

const RESERVED_STATUSES = new Set(["accepted", "delivered"]);

type ProductOption = {
  id: string;
  name: string;
  barcode: string;
  alt_barcodes?: string[] | null;
  unit?: string | null;
};

export default function TransfersPage() {
  const [notices, setNotices] = useState<Notice[]>([]);
  const [viewer, setViewer] = useState<Viewer | null>(null);
  const [tab, setTab] = useState<TabKey>("all");
  const [search, setSearch] = useState("");
  const [typeFilter, setTypeFilter] = useState<"all" | "surplus" | "shortage">("all");
  const [statusFilter, setStatusFilter] = useState<"all" | Notice["status"]>("all");
  const [modal, setModal] = useState<ModalState | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    product_id: "",
    product_search: "",
    quantity: "",
    unit: "adet",
    type: "surplus" as "surplus" | "shortage",
    note: "",
    expires_at: "",
  });
  const [productOptions, setProductOptions] = useState<ProductOption[]>([]);
  const [productLoading, setProductLoading] = useState(false);
  const [offerForm, setOfferForm] = useState({ quantity: "", message: "" });

  useEffect(() => {
    void loadData();
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    const timer = setTimeout(() => {
      const q = form.product_search.trim();
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
  }, [form.product_search]);

  async function loadData() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/transfers");
      if (!res.ok) throw new Error("Sevk kayıtları alınamadı");
      const body = (await res.json()) as { notices: Notice[]; viewer?: Viewer };
      setNotices(body.notices ?? []);
      setViewer(body.viewer ?? null);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  }

  const derived = useMemo(() => {
    const needle = search.trim().toLowerCase();
    return notices.map((notice) => {
      const offers = notice.offers ?? [];
      const reserved = offers.reduce((sum, offer) =>
        RESERVED_STATUSES.has(offer.status) ? sum + (offer.quantity ?? 0) : sum,
      0);
      const remaining = Math.max(0, notice.quantity - reserved);
      const owner = viewer?.id === notice.created_by;
      const matchesSearch =
        needle.length === 0 ||
        notice.product_name.toLowerCase().includes(needle) ||
        (notice.branch_name ?? "").toLowerCase().includes(needle);
      const matchesType = typeFilter === "all" || notice.type === typeFilter;
      const matchesStatus = statusFilter === "all" || notice.status === statusFilter;
      return { notice, reserved, remaining, owner, matches: matchesSearch && matchesType && matchesStatus };
    });
  }, [notices, search, typeFilter, statusFilter, viewer?.id]);

  const filtered = derived.filter((item) => item.matches);
  const myNotices = filtered.filter((item) => item.owner);
  const myOffers = useMemo(() => {
    const userId = viewer?.id;
    if (!userId) return [] as { offer: Offer; notice: Notice }[];
    const rows: { offer: Offer; notice: Notice }[] = [];
    for (const notice of notices) {
      for (const offer of notice.offers ?? []) {
        if (offer.offered_by === userId) {
          rows.push({ offer, notice });
        }
      }
    }
    return rows.sort((a, b) =>
      new Date(b.offer.created_at).getTime() - new Date(a.offer.created_at).getTime(),
    );
  }, [notices, viewer?.id]);

  async function handleCreateNotice() {
    if (!form.product_id.trim() || !form.quantity.trim()) {
      throw new Error("Ürün ve miktar zorunlu");
    }
    const payload = {
      product_id: form.product_id.trim(),
      quantity: Number(form.quantity),
      unit: form.unit.trim() || "adet",
      type: form.type,
      note: form.note.trim() ? form.note.trim() : null,
      expires_at: form.expires_at || null,
    };
    const res = await fetch("/api/transfers", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const detail = await res.text();
      throw new Error(detail || "İlan kaydedilemedi");
    }
  }

  async function handleDeleteNotice(id: string) {
    const res = await fetch("/api/transfers", {
      method: "DELETE",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ids: [id] }),
    });
    if (!res.ok) {
      const detail = await res.text();
      throw new Error(detail || "İlan silinemedi");
    }
  }

  async function handleOfferSubmit(noticeId: string) {
    if (!offerForm.quantity.trim()) {
      throw new Error("Miktar gerekli");
    }
    const res = await fetch("/api/transfers/offers", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        notice_id: noticeId,
        quantity: Number(offerForm.quantity),
        message: offerForm.message.trim() || undefined,
      }),
    });
    if (!res.ok) {
      const detail = await res.text();
      throw new Error(detail || "Talep gönderilemedi");
    }
  }

  async function handleOfferAction(action: string, offer: Offer, quantity?: number, message?: string) {
    const res = await fetch("/api/transfers/offers", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        action,
        offer_id: offer.id,
        quantity,
        message,
      }),
    });
    if (!res.ok) {
      const detail = await res.text();
      throw new Error(detail || "İşlem tamamlanamadı");
    }
  }

  async function handleUpdateNotice(id: string) {
    const payload: Record<string, unknown> = { id };
    if (form.product_id.trim()) payload.product_id = form.product_id.trim();
    if (form.quantity.trim()) payload.quantity = Number(form.quantity);
    if (form.unit.trim()) payload.unit = form.unit.trim();
    if (form.type) payload.type = form.type;
    payload.note = form.note.trim() ? form.note.trim() : null;
    payload.expires_at = form.expires_at || null;

    const res = await fetch("/api/transfers", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const detail = await res.text();
      throw new Error(detail || "İlan güncellenemedi");
    }
  }

  const activeDetailNotice = useMemo(() => {
    if (modal?.type !== "detail") return null;
    const latest = notices.find((n) => n.id === modal.notice.id);
    return latest ?? modal.notice;
  }, [modal, notices]);

  function resetForms() {
    setForm({ product_id: "", product_search: "", quantity: "", unit: "adet", type: "surplus", note: "", expires_at: "" });
    setOfferForm({ quantity: "", message: "" });
  }

  const renderNoticeRow = (item: (typeof filtered)[number]) => {
    const { notice, reserved, remaining, owner } = item;
    return (
      <tr key={notice.id}>
        <td>
          <div className="cell-main">{notice.product_name}</div>
          <div className="cell-sub">{notice.branch_name ?? "Şube"}</div>
        </td>
        <td>
          <span className={`pill pill-${notice.type === "surplus" ? "surplus" : "shortage"}`}>
            {notice.type === "surplus" ? "Fazla" : "Eksik"}
          </span>
        </td>
        <td>
          <strong>{notice.quantity}</strong> {notice.unit}
          <div className="cell-sub">Kalan: {remaining}</div>
        </td>
        <td>{statusLabel(notice.status)}</td>
        <td>{new Date(notice.created_at).toLocaleDateString("tr-TR")}</td>
        <td>
          <div className="actions">
            {owner ? (
              <>
                <button
                  onClick={() => {
                    setForm({
                      product_id: "",
                      product_search: notice.product_name,
                      quantity: String(notice.quantity),
                      unit: notice.unit,
                      type: notice.type as "surplus" | "shortage",
                      note: notice.note ?? "",
                      expires_at: notice.expires_at ? notice.expires_at.slice(0, 10) : "",
                    });
                    setProductOptions([]);
                    setModal({ type: "edit-notice", notice });
                  }}
                >
                  Düzenle
                </button>
                <button
                  className="ghost"
                  onClick={() => {
                    if (!window.confirm("Bu ilan iptal edilsin mi?")) return;
                    handleDeleteNotice(notice.id)
                      .then(loadData)
                      .catch((err) => setError((err as Error).message));
                  }}
                >
                  İptal
                </button>
              </>
            ) : (
              <>
                <button onClick={() => setModal({ type: "detail", notice })}>İncele</button>
                {notice.status === "open" ? (
                  <button className="ghost" onClick={() => {
                    setOfferForm({ quantity: "", message: "" });
                    setModal({ type: "offer", notice });
                  }}>
                    Talep Gönder
                  </button>
                ) : null}
              </>
            )}
          </div>
        </td>
      </tr>
    );
  };

  return (
    <div className="page">
      <header className="page-header">
        <h2>Depolar Arası Sevk</h2>
        <p>Şubeler arası fazla/eksik ürün ilanları, talepler ve onay akışı.</p>
      </header>

      <div className="card transfer-card">
        <div className="transfer-toolbar">
          <div className="transfer-search">
            <input
              placeholder="Ürün veya şube ara"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="transfer-filters">
            <select value={typeFilter} onChange={(e) => setTypeFilter(e.target.value as any)}>
              <option value="all">Tip: Tümü</option>
              <option value="surplus">Fazla</option>
              <option value="shortage">Eksik</option>
            </select>
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value as any)}>
              <option value="all">Durum: Tümü</option>
              <option value="open">İlan</option>
              <option value="in_transfer">Transferde</option>
              <option value="fulfilled">Tamamlandı</option>
              <option value="cancelled">İptal</option>
            </select>
          </div>
          <div className="transfer-actions">
            <button
              className="primary"
              onClick={() => {
                resetForms();
                setProductOptions([]);
                setModal({ type: "create" });
              }}
            >
              İlan Oluştur
            </button>
          </div>
        </div>

        <div className="transfer-tabs">
          {(["all", "mine", "offers"] as TabKey[]).map((key) => (
            <button
              key={key}
              className={tab === key ? "tab active" : "tab"}
              onClick={() => setTab(key)}
            >
              {tabLabel(key)}
            </button>
          ))}
        </div>

        {loading ? <p>Yükleniyor...</p> : null}
        {error ? <p className="error">{error}</p> : null}

        {!loading && !error ? (
          <div className="table-wrapper">
            {tab === "all" || tab === "mine" ? (
              <table className="transfer-table">
                <thead>
                  <tr>
                    <th>İlan</th>
                    <th>Tip</th>
                    <th>Miktar</th>
                    <th>Durum</th>
                    <th>Oluşturma</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {(tab === "all" ? filtered : myNotices).length === 0 ? (
                    <tr>
                      <td colSpan={6} className="empty">Kayıt yok</td>
                    </tr>
                  ) : (
                    (tab === "all" ? filtered : myNotices).map((item) => renderNoticeRow(item))
                  )}
                </tbody>
              </table>
            ) : null}

            {tab === "offers" ? (
              <div className="offers-list">
                {myOffers.length === 0 ? (
                  <p className="empty">Henüz talebiniz yok.</p>
                ) : (
                  myOffers.map(({ offer, notice }) => (
                    <div key={offer.id} className="offer-card">
                      <div className="offer-main">
                        <div>
                          <div className="cell-main">{notice.product_name}</div>
                          <div className="cell-sub">{notice.branch_name ?? "Şube"}</div>
                        </div>
                        <div className="pill-row">
                          <span className={`pill pill-${notice.type === "surplus" ? "surplus" : "shortage"}`}>
                            {notice.type === "surplus" ? "Fazla" : "Eksik"}
                          </span>
                          <span className="pill">
                            {offer.quantity} {notice.unit}
                          </span>
                          <span className={`pill pill-status-${offer.status}`}>{offerStatusLabel(offer.status)}</span>
                        </div>
                      </div>
                      {offer.message ? <div className="cell-sub">{offer.message}</div> : null}
                      <div className="actions">
                        {offer.status === "pending" ? (
                          <>
                            <button
                              onClick={() => {
                                setModal({ type: "edit-offer", notice, offer });
                                setOfferForm({ quantity: String(offer.quantity), message: offer.message ?? "" });
                              }}
                            >
                              Düzenle
                            </button>
                            <button
                              className="ghost"
                              onClick={() =>
                                handleOfferAction("cancel", offer)
                                  .then(loadData)
                                  .catch((err) => setError((err as Error).message))
                              }
                            >
                              İptal
                            </button>
                          </>
                        ) : null}
                        {offer.status === "accepted" ? (
                          <button
                            onClick={() =>
                              handleOfferAction("deliver", offer)
                                .then(loadData)
                                .catch((err) => setError((err as Error).message))
                            }
                          >
                            Teslim Edildi
                          </button>
                        ) : null}
                      </div>
                    </div>
                  ))
                )}
              </div>
            ) : null}
          </div>
        ) : null}
      </div>

      {modal ? (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal">
            {modal.type === "create" ? (
              <>
                <h3>Yeni İlan</h3>
                <label className="field">
                  <span>Ürün ara (ad, barkod)</span>
                  <input
                    value={form.product_search}
                    onChange={(e) => setForm((p) => ({ ...p, product_search: e.target.value }))}
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
                              product_id: p.id,
                              product_search: `${p.name} (${p.barcode})`,
                              unit: p.unit?.trim() || prev.unit,
                            }));
                            setProductOptions([]);
                          }}
                        >
                          <div className="cell-main">{p.name}</div>
                          <div className="cell-sub">{p.barcode}</div>
                          {p.alt_barcodes?.length ? (
                            <div className="cell-sub">Alt: {p.alt_barcodes.join(", ")}</div>
                          ) : null}
                          {p.unit ? <div className="cell-sub">Birim: {p.unit}</div> : null}
                        </button>
                      ))}
                    </div>
                  ) : null}
                  {form.product_id ? (
                    <span className="hint">Seçili ürün: {form.product_search || form.product_id}</span>
                  ) : null}
                </label>
                <div className="grid-2">
                  <label className="field">
                    <span>Miktar</span>
                    <input
                      type="number"
                      value={form.quantity}
                      onChange={(e) => setForm((p) => ({ ...p, quantity: e.target.value }))}
                    />
                  </label>
                  <label className="field">
                    <span>Birim</span>
                    <select value={form.unit} onChange={(e) => setForm((p) => ({ ...p, unit: e.target.value }))}>
                      <option value="adet">adet</option>
                      <option value="kg">kg</option>
                    </select>
                  </label>
                </div>
                <label className="field">
                  <span>Tip</span>
                  <div className="pill-row">
                    <button
                      className={form.type === "surplus" ? "pill toggle active" : "pill toggle"}
                      onClick={() => setForm((p) => ({ ...p, type: "surplus" }))}
                    >
                      Fazla
                    </button>
                    <button
                      className={form.type === "shortage" ? "pill toggle active" : "pill toggle"}
                      onClick={() => setForm((p) => ({ ...p, type: "shortage" }))}
                    >
                      Eksik
                    </button>
                  </div>
                </label>
                <label className="field">
                  <span>Bitiş (opsiyonel)</span>
                  <input
                    type="date"
                    value={form.expires_at}
                    onChange={(e) => setForm((p) => ({ ...p, expires_at: e.target.value }))}
                  />
                </label>
                <label className="field">
                  <span>Not</span>
                  <textarea
                    rows={3}
                    value={form.note}
                    onChange={(e) => setForm((p) => ({ ...p, note: e.target.value }))}
                    placeholder="Detay ekle (opsiyonel)"
                  />
                </label>
                <div className="modal-actions">
                  <button onClick={() => setModal(null)}>İptal</button>
                  <button
                    className="primary"
                    disabled={saving}
                    onClick={() => {
                      setSaving(true);
                      handleCreateNotice()
                        .then(() => {
                          setModal(null);
                          resetForms();
                          return loadData();
                        })
                        .catch((err) => setError((err as Error).message))
                        .finally(() => setSaving(false));
                    }}
                  >
                    Kaydet
                  </button>
                </div>
              </>
            ) : null}

            {modal.type === "offer" ? (
              <>
                <h3>Talep Gönder</h3>
                <p className="hint">{modal.notice.product_name}</p>
                <label className="field">
                  <span>Miktar</span>
                  <input
                    type="number"
                    value={offerForm.quantity}
                    onChange={(e) => setOfferForm((p) => ({ ...p, quantity: e.target.value }))}
                  />
                </label>
                <label className="field">
                  <span>Mesaj (opsiyonel)</span>
                  <textarea
                    rows={3}
                    value={offerForm.message}
                    onChange={(e) => setOfferForm((p) => ({ ...p, message: e.target.value }))}
                  />
                </label>
                <div className="modal-actions">
                  <button onClick={() => setModal(null)}>İptal</button>
                  <button
                    className="primary"
                    disabled={saving}
                    onClick={() => {
                      setSaving(true);
                      handleOfferSubmit(modal.notice.id)
                        .then(() => {
                          setModal(null);
                          resetForms();
                          return loadData();
                        })
                        .catch((err) => setError((err as Error).message))
                        .finally(() => setSaving(false));
                    }}
                  >
                    Gönder
                  </button>
                </div>
              </>
            ) : null}

            {modal.type === "edit-notice" ? (
              <>
                <h3>İlanı Düzenle</h3>
                <label className="field">
                  <span>Ürün ara (ad, barkod)</span>
                  <input
                    value={form.product_search}
                    onChange={(e) => setForm((p) => ({ ...p, product_search: e.target.value }))}
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
                              product_id: p.id,
                              product_search: `${p.name} (${p.barcode})`,
                              unit: p.unit?.trim() || prev.unit,
                            }));
                            setProductOptions([]);
                          }}
                        >
                          <div className="cell-main">{p.name}</div>
                          <div className="cell-sub">{p.barcode}</div>
                          {p.alt_barcodes?.length ? (
                            <div className="cell-sub">Alt: {p.alt_barcodes.join(", ")}</div>
                          ) : null}
                          {p.unit ? <div className="cell-sub">Birim: {p.unit}</div> : null}
                        </button>
                      ))}
                    </div>
                  ) : null}
                  {form.product_id ? (
                    <span className="hint">Seçili ürün: {form.product_search || form.product_id}</span>
                  ) : null}
                </label>
                <div className="grid-2">
                  <label className="field">
                    <span>Miktar</span>
                    <input
                      type="number"
                      value={form.quantity}
                      onChange={(e) => setForm((p) => ({ ...p, quantity: e.target.value }))}
                    />
                  </label>
                  <label className="field">
                    <span>Birim</span>
                    <select value={form.unit} onChange={(e) => setForm((p) => ({ ...p, unit: e.target.value }))}>
                      <option value="adet">adet</option>
                      <option value="kg">kg</option>
                    </select>
                  </label>
                </div>
                <label className="field">
                  <span>Tip</span>
                  <div className="pill-row">
                    <button
                      className={form.type === "surplus" ? "pill toggle active" : "pill toggle"}
                      onClick={() => setForm((p) => ({ ...p, type: "surplus" }))}
                    >
                      Fazla
                    </button>
                    <button
                      className={form.type === "shortage" ? "pill toggle active" : "pill toggle"}
                      onClick={() => setForm((p) => ({ ...p, type: "shortage" }))}
                    >
                      Eksik
                    </button>
                  </div>
                </label>
                <label className="field">
                  <span>Bitiş (opsiyonel)</span>
                  <input
                    type="date"
                    value={form.expires_at}
                    onChange={(e) => setForm((p) => ({ ...p, expires_at: e.target.value }))}
                  />
                </label>
                <label className="field">
                  <span>Not</span>
                  <textarea
                    rows={3}
                    value={form.note}
                    onChange={(e) => setForm((p) => ({ ...p, note: e.target.value }))}
                    placeholder="Detay ekle (opsiyonel)"
                  />
                </label>
                <div className="modal-actions">
                  <button onClick={() => setModal(null)}>İptal</button>
                  <button
                    className="primary"
                    disabled={saving}
                    onClick={() => {
                      if (modal.type !== "edit-notice") return;
                      setSaving(true);
                      handleUpdateNotice(modal.notice.id)
                        .then(() => {
                          setModal(null);
                          resetForms();
                          return loadData();
                        })
                        .catch((err) => setError((err as Error).message))
                        .finally(() => setSaving(false));
                    }}
                  >
                    Kaydet
                  </button>
                </div>
              </>
            ) : null}

            {modal.type === "edit-offer" ? (
              <>
                <h3>Talebi Düzenle</h3>
                <p className="hint">{modal.notice.product_name}</p>
                <label className="field">
                  <span>Miktar</span>
                  <input
                    type="number"
                    value={offerForm.quantity}
                    onChange={(e) => setOfferForm((p) => ({ ...p, quantity: e.target.value }))}
                  />
                </label>
                <label className="field">
                  <span>Mesaj</span>
                  <textarea
                    rows={3}
                    value={offerForm.message}
                    onChange={(e) => setOfferForm((p) => ({ ...p, message: e.target.value }))}
                  />
                </label>
                <div className="modal-actions">
                  <button onClick={() => setModal(null)}>İptal</button>
                  <button
                    className="primary"
                    onClick={() =>
                      handleOfferAction(
                        "update",
                        modal.offer,
                        Number(offerForm.quantity),
                        offerForm.message.trim() || undefined,
                      )
                        .then(() => {
                          setModal(null);
                          resetForms();
                          return loadData();
                        })
                        .catch((err) => setError((err as Error).message))
                    }
                  >
                    Kaydet
                  </button>
                </div>
              </>
            ) : null}

            {modal.type === "detail" && activeDetailNotice ? (
              <>
                <h3>{activeDetailNotice.product_name}</h3>
                <div className="detail-grid">
                  <div>
                    <div className="cell-sub">Şube</div>
                    <div>{activeDetailNotice.branch_name ?? "Şube"}</div>
                  </div>
                  <div>
                    <div className="cell-sub">Tip</div>
                    <div className="pill-row">
                      <span className={`pill pill-${activeDetailNotice.type === "surplus" ? "surplus" : "shortage"}`}>
                        {activeDetailNotice.type === "surplus" ? "Fazla" : "Eksik"}
                      </span>
                      <span className={`pill pill-status-${activeDetailNotice.status}`}>
                        {statusLabel(activeDetailNotice.status)}
                      </span>
                    </div>
                  </div>
                  <div>
                    <div className="cell-sub">Miktar</div>
                    <div>
                      {activeDetailNotice.quantity} {activeDetailNotice.unit}
                    </div>
                  </div>
                  {activeDetailNotice.note ? (
                    <div className="note-block">
                      <div className="cell-sub">Not</div>
                      <div>{activeDetailNotice.note}</div>
                    </div>
                  ) : null}
                </div>

                <div className="offers-list">
                  <div className="list-title">Teklifler</div>
                  {(activeDetailNotice.offers ?? []).length === 0 ? (
                    <p className="empty">Henüz teklif yok.</p>
                  ) : (
                    (activeDetailNotice.offers ?? []).map((offer) => {
                      const isOwner = viewer?.id === activeDetailNotice.created_by;
                      const isMine = viewer?.id === offer.offered_by;
                      return (
                        <div key={offer.id} className="offer-card">
                          <div className="offer-main">
                            <div>
                              <div className="cell-main">{offer.branch_name ?? "Şube"}</div>
                              {offer.message ? <div className="cell-sub">{offer.message}</div> : null}
                            </div>
                            <div className="pill-row">
                              <span className="pill">{offer.quantity} {activeDetailNotice.unit}</span>
                              <span className={`pill pill-status-${offer.status}`}>
                                {offerStatusLabel(offer.status)}
                              </span>
                            </div>
                          </div>
                          <div className="actions">
                            {isOwner && offer.status === "pending" ? (
                              <>
                                <button
                                  className="primary"
                                  onClick={() =>
                                    handleOfferAction("accept", offer)
                                      .then(loadData)
                                      .catch((err) => setError((err as Error).message))
                                  }
                                >
                                  Onayla
                                </button>
                                <button
                                  className="ghost"
                                  onClick={() =>
                                    handleOfferAction("reject", offer)
                                      .then(loadData)
                                      .catch((err) => setError((err as Error).message))
                                  }
                                >
                                  Reddet
                                </button>
                              </>
                            ) : null}
                            {isMine && offer.status === "pending" ? (
                              <button
                                onClick={() => {
                                  setModal({ type: "edit-offer", notice: activeDetailNotice, offer });
                                  setOfferForm({ quantity: String(offer.quantity), message: offer.message ?? "" });
                                }}
                              >
                                Düzenle
                              </button>
                            ) : null}
                            {isMine && offer.status === "accepted" ? (
                              <button
                                onClick={() =>
                                  handleOfferAction("deliver", offer)
                                    .then(loadData)
                                    .catch((err) => setError((err as Error).message))
                                }
                              >
                                Teslim Edildi
                              </button>
                            ) : null}
                            {isMine && offer.status === "pending" ? (
                              <button
                                className="ghost"
                                onClick={() =>
                                  handleOfferAction("cancel", offer)
                                    .then(loadData)
                                    .catch((err) => setError((err as Error).message))
                                }
                              >
                                İptal
                              </button>
                            ) : null}
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>

                <div className="modal-actions">
                  <button onClick={() => setModal(null)}>Kapat</button>
                  {viewer?.id === activeDetailNotice.created_by ? (
                    <button
                      className="danger"
                      onClick={() => {
                        if (!window.confirm("Bu ilan silinsin mi?")) return;
                        handleDeleteNotice(activeDetailNotice.id)
                          .then(() => {
                            setModal(null);
                            return loadData();
                          })
                          .catch((err) => setError((err as Error).message));
                      }}
                    >
                      İlanı Sil
                    </button>
                  ) : null}
                </div>
              </>
            ) : null}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function statusLabel(status: string) {
  switch (status) {
    case "open":
      return "İlan Aşaması";
    case "in_transfer":
      return "Transferde";
    case "fulfilled":
      return "Tamamlandı";
    case "cancelled":
      return "İptal";
    default:
      return status;
  }
}

function offerStatusLabel(status: string) {
  switch (status) {
    case "pending":
      return "Beklemede";
    case "accepted":
      return "Onaylandı";
    case "rejected":
      return "Reddedildi";
    case "cancelled":
      return "İptal";
    case "delivered":
      return "Teslim Edildi";
    case "expired":
      return "Süresi Doldu";
    default:
      return status;
  }
}

function tabLabel(key: TabKey) {
  if (key === "mine") return "İlanlarım";
  if (key === "offers") return "Taleplerim";
  return "Tüm İlanlar";
}
