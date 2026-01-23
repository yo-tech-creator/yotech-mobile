"use client";

import { useEffect, useMemo, useState } from "react";
import { CardActionButton, CardListShell, SoftBadge, cardStyles } from "@/components/ui/card-list";
import "./products.css";

type Product = {
  id: string;
  barcode: string;
  name: string;
  brand: string | null;
  category: string | null;
  supplier: string | null;
  unit: string | null;
  price: number | null;
  active: boolean | null;
  alt_barcodes: string[] | null;
};

type Filters = {
  barcode: string;
  name: string;
  brand: string;
  category: string;
  supplier: string;
  unit: string;
  status: "all" | "active" | "inactive";
  minPrice: string;
  maxPrice: string;
};

type DashboardRole = "grand_admin" | "firma_admin" | "bolge_muduru" | "sube_muduru";

const emptyFilters: Filters = {
  barcode: "",
  name: "",
  brand: "",
  category: "",
  supplier: "",
  unit: "",
  status: "all",
  minPrice: "",
  maxPrice: "",
};

let cachedProducts: Product[] | null = null;
let cachedAt: number | null = null;

const loadProductsFromApi = async (): Promise<Product[]> => {
  const res = await fetch("/api/products");
  if (!res.ok) {
    throw new Error("Ürünler alınamadı");
  }
  const body = (await res.json()) as { products: Product[] };
  return body.products ?? [];
};

const formatPrice = (price: number | null) => {
  if (typeof price !== "number") return "-";
  return price.toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};

const getInitials = (name: string) => {
  const parts = name.trim().split(" ").filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
};

export default function ProductsPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [filters, setFilters] = useState<Filters>(emptyFilters);
  const [loading, setLoading] = useState(true);
  const [pageError, setPageError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [altInput, setAltInput] = useState<string>("");
  const [pageSize, setPageSize] = useState<number>(12);
  const [page, setPage] = useState<number>(1);
  const [lastSync, setLastSync] = useState<number | null>(cachedAt);
  const [role, setRole] = useState<DashboardRole | null>(null);
  const [tenantId, setTenantId] = useState<string | null>(null);
  const [editState, setEditState] = useState<
    | { mode: "create"; form: Product }
    | { mode: "edit"; form: Product; id: string }
    | null
  >(null);
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;

    const loadEverything = async () => {
      try {
        const [profileRes, productsRes] = await Promise.all([fetch("/api/me"), cachedProducts ? Promise.resolve(null) : loadProductsFromApi()]);

        if (profileRes.ok) {
          const body = (await profileRes.json()) as { role?: DashboardRole; tenant_id?: string | null };
          if (mounted) {
            setRole(body.role ?? null);
            setTenantId(body.tenant_id ?? null);
          }
        }

        if (cachedProducts && mounted) {
          setProducts(cachedProducts);
          setLoading(false);
          return;
        }

        if (productsRes) {
          cachedProducts = productsRes;
          cachedAt = Date.now();
          if (mounted) {
            setProducts(productsRes);
            setLastSync(cachedAt);
          }
        }
      } catch (err) {
        if (mounted) setPageError((err as Error).message);
      } finally {
        if (mounted) setLoading(false);
      }
    };

    void loadEverything();
    return () => {
      mounted = false;
    };
  }, []);

  const handleSync = async () => {
    setLoading(true);
    setPageError(null);
    try {
      const data = await loadProductsFromApi();
      cachedProducts = data;
      cachedAt = Date.now();
      setProducts(data);
      setLastSync(cachedAt);
    } catch (err) {
      setPageError((err as Error).message);
    } finally {
      setLoading(false);
    }
  };

  const handleFilterChange = (key: keyof Filters, value: string) => {
    setFilters((prev) => ({ ...prev, [key]: value }));
    setPage(1);
  };

  const resetFilters = () => setFilters(emptyFilters);

  const filtered = useMemo(() => {
    const toLower = (val: string | null | undefined) => (val ?? "").toLowerCase();
    const includes = (haystack: (string | null | undefined)[], needle: string) => {
      if (!needle.trim()) return true;
      const lower = needle.toLowerCase();
      return haystack.some((h) => toLower(h).includes(lower));
    };

    const min = filters.minPrice ? parseFloat(filters.minPrice.replace(",", ".")) : null;
    const max = filters.maxPrice ? parseFloat(filters.maxPrice.replace(",", ".")) : null;

    return products.filter((p) => {
      if (!includes([p.barcode, ...(p.alt_barcodes ?? [])], filters.barcode)) return false;
      if (!includes([p.name], filters.name)) return false;
      if (!includes([p.brand], filters.brand)) return false;
      if (!includes([p.category], filters.category)) return false;
      if (!includes([p.supplier], filters.supplier)) return false;
      if (!includes([p.unit], filters.unit)) return false;

      if (filters.status === "active" && !p.active) return false;
      if (filters.status === "inactive" && p.active) return false;

      const price = typeof p.price === "number" ? p.price : null;
      if (min !== null && (price === null || price < min)) return false;
      if (max !== null && (price === null || price > max)) return false;

      return true;
    });
  }, [filters, products]);

  const activeFilters = useMemo(() => {
    const items: string[] = [];
    if (filters.barcode) items.push(`Barkod: ${filters.barcode}`);
    if (filters.name) items.push(`Ürün: ${filters.name}`);
    if (filters.brand) items.push(`Marka: ${filters.brand}`);
    if (filters.category) items.push(`Kategori: ${filters.category}`);
    if (filters.supplier) items.push(`Tedarikçi: ${filters.supplier}`);
    if (filters.unit) items.push(`Birim: ${filters.unit}`);
    if (filters.status !== "all") items.push(`Durum: ${filters.status === "active" ? "Aktif" : "Pasif"}`);
    if (filters.minPrice) items.push(`Min: ${filters.minPrice}`);
    if (filters.maxPrice) items.push(`Max: ${filters.maxPrice}`);
    return items;
  }, [filters]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize));
  const currentPage = Math.min(page, totalPages);
  const start = (currentPage - 1) * pageSize;
  const paginated = filtered.slice(start, start + pageSize);

  const canEdit = role === "grand_admin" || role === "firma_admin";

  const renderPagination = () => (
    <div
      style={{
        display: "flex",
        flexWrap: "wrap",
        gap: "10px",
        alignItems: "center",
        justifyContent: "flex-end",
        fontSize: 13,
      }}
    >
      <span style={{ whiteSpace: "nowrap" }}>
        Gösterilen {paginated.length} / {filtered.length}
      </span>
      <div style={{ display: "flex", gap: "6px", alignItems: "center", flexWrap: "wrap" }}>
        <label style={{ display: "flex", alignItems: "center", gap: 6, whiteSpace: "nowrap" }}>
          <span>Sayfa</span>
          <select
            className="filter-input page-size"
            style={{ padding: "6px 10px", fontSize: 13, height: 32 }}
            value={pageSize}
            onChange={(e) => {
              const next = Number(e.target.value);
              setPageSize(next);
              setPage(1);
            }}
          >
            {[12, 24, 60, 100].map((n) => (
              <option key={n} value={n}>
                {n} ürün
              </option>
            ))}
          </select>
        </label>
        <button
          type="button"
          className="ghost"
          style={{ padding: "6px 9px", fontSize: 13, height: 32 }}
          onClick={() => setPage(1)}
          disabled={currentPage === 1}
        >
          İlk
        </button>
        <button
          type="button"
          className="ghost"
          style={{ padding: "6px 9px", fontSize: 13, height: 32 }}
          onClick={() => setPage((p) => Math.max(1, p - 1))}
          disabled={currentPage === 1}
        >
          Önceki
        </button>
        <span style={{ minWidth: 90, textAlign: "center" }}>
          Sayfa {currentPage} / {totalPages}
        </span>
        <button
          type="button"
          className="ghost"
          style={{ padding: "6px 9px", fontSize: 13, height: 32 }}
          onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
          disabled={currentPage === totalPages}
        >
          Sonraki
        </button>
        <button
          type="button"
          className="ghost"
          style={{ padding: "6px 9px", fontSize: 13, height: 32 }}
          onClick={() => setPage(totalPages)}
          disabled={currentPage === totalPages}
        >
          Son
        </button>
      </div>
    </div>
  );

  const filterContent = (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 10 }}>
      <input
        className="filter-input"
        placeholder="Barkod / Alt barkod"
        value={filters.barcode}
        onChange={(e) => handleFilterChange("barcode", e.target.value)}
      />
      <input
        className="filter-input"
        placeholder="Ürün adı"
        value={filters.name}
        onChange={(e) => handleFilterChange("name", e.target.value)}
      />
      <input
        className="filter-input"
        placeholder="Marka"
        value={filters.brand}
        onChange={(e) => handleFilterChange("brand", e.target.value)}
      />
      <input
        className="filter-input"
        placeholder="Kategori"
        value={filters.category}
        onChange={(e) => handleFilterChange("category", e.target.value)}
      />
      <input
        className="filter-input"
        placeholder="Tedarikçi"
        value={filters.supplier}
        onChange={(e) => handleFilterChange("supplier", e.target.value)}
      />
      <input
        className="filter-input"
        placeholder="Birim"
        value={filters.unit}
        onChange={(e) => handleFilterChange("unit", e.target.value)}
      />
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(120px, 1fr))", gap: 8 }}>
        <input
          className="filter-input"
          placeholder="Min fiyat"
          value={filters.minPrice}
          onChange={(e) => handleFilterChange("minPrice", e.target.value)}
          inputMode="decimal"
        />
        <input
          className="filter-input"
          placeholder="Max fiyat"
          value={filters.maxPrice}
          onChange={(e) => handleFilterChange("maxPrice", e.target.value)}
          inputMode="decimal"
        />
      </div>
      <select
        className="filter-input"
        value={filters.status}
        onChange={(e) => handleFilterChange("status", e.target.value as Filters["status"])}
      >
        <option value="all">Durum: Tümü</option>
        <option value="active">Aktif</option>
        <option value="inactive">Pasif</option>
      </select>
    </div>
  );

  const openCreate = () => {
    if (!tenantId && role === "grand_admin") return;
    setFormError(null);
    setAltInput("");
    setEditState({
      mode: "create",
      form: {
        id: "",
        barcode: "",
        name: "",
        brand: "",
        category: "",
        supplier: "",
        unit: "",
        price: null,
        active: true,
        alt_barcodes: [],
      },
    });
  };

  const openEdit = (p: Product) => {
    setFormError(null);
    setAltInput((p.alt_barcodes ?? []).join(", "));
    setEditState({ mode: "edit", id: p.id, form: { ...p } });
  };

  const closeEdit = () => {
    setFormError(null);
    setAltInput("");
    setEditState(null);
  };

  const saveProduct = async () => {
    if (!editState) return;
    const { form } = editState;
    setSaving(true);
    setFormError(null);
    setPageError(null);
    try {
      const payload: Record<string, unknown> = {
        barcode: form.barcode.trim(),
        name: form.name.trim(),
        brand: form.brand?.trim() || null,
        category: form.category?.trim() || null,
        supplier: form.supplier?.trim() || null,
        unit: form.unit?.trim() || null,
        price: typeof form.price === "number" ? form.price : null,
        active: form.active ?? true,
        alt_barcodes: form.alt_barcodes ?? [],
      };

      if (editState.mode === "edit") {
        payload.id = editState.id;
      } else if (role === "grand_admin") {
        payload.tenant_id = tenantId;
      }

      const res = await fetch("/api/products", {
        method: editState.mode === "edit" ? "PATCH" : "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        throw new Error(detail?.detail || detail?.message || "Ürün kaydedilemedi");
      }

      cachedProducts = null;
      const fresh = await loadProductsFromApi();
      cachedProducts = fresh;
      cachedAt = Date.now();
      setProducts(fresh);
      setLastSync(cachedAt);
      closeEdit();
    } catch (err) {
      setFormError((err as Error).message);
    } finally {
      setSaving(false);
    }
  };

  const deleteProduct = async (id: string) => {
    setDeletingId(id);
    setPageError(null);
    try {
      const res = await fetch(`/api/products?id=${id}`, { method: "DELETE" });
      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        throw new Error(detail?.detail || detail?.message || "Silme başarısız");
      }
      cachedProducts = null;
      const fresh = await loadProductsFromApi();
      cachedProducts = fresh;
      setProducts(fresh);
      cachedAt = Date.now();
      setLastSync(cachedAt);
    } catch (err) {
      setPageError((err as Error).message);
    } finally {
      setDeletingId(null);
    }
  };

  const toggleActive = async (p: Product) => {
    setSaving(true);
    setPageError(null);
    try {
      const res = await fetch("/api/products", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: p.id, active: !p.active }),
      });
      if (!res.ok) {
        const detail = await res.json().catch(() => null);
        throw new Error(detail?.detail || detail?.message || "Güncelleme başarısız");
      }
      cachedProducts = null;
      const fresh = await loadProductsFromApi();
      cachedProducts = fresh;
      setProducts(fresh);
      cachedAt = Date.now();
      setLastSync(cachedAt);
    } catch (err) {
      setPageError((err as Error).message);
    } finally {
      setSaving(false);
    }
  };

  const updateForm = (key: keyof Product, value: unknown) => {
    setEditState((prev) => (prev ? { ...prev, form: { ...prev.form, [key]: value } as Product } : prev));
  };

  const renderEditPanel = (title: string) => {
    if (!editState) return null;
    const formatAlt = (value: string) =>
      value
        .split(/[\s,]+/)
        .map((a) => a.trim())
        .filter(Boolean);
    return (
      <div style={{ ...cardStyles.filterCard, marginTop: 8 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 12 }}>
          <h3 style={{ margin: 0 }}>{title}</h3>
          <div style={{ display: "flex", gap: 8 }}>
            <CardActionButton tone="muted" onClick={closeEdit} disabled={saving} label="Kapat" />
            <CardActionButton tone="success" onClick={saveProduct} disabled={saving} label={saving ? "Kaydediliyor..." : "Kaydet"} />
          </div>
        </div>
        {role === "grand_admin" ? (
          <p className="muted" style={{ margin: 0 }}>
            Tenant ID: {tenantId ?? "-"}
          </p>
        ) : null}
        <div className="grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px,1fr))", gap: 10 }}>
          <input className="filter-input" placeholder="Barkod" value={editState.form.barcode} onChange={(e) => updateForm("barcode", e.target.value)} />
          <input className="filter-input" placeholder="Ürün adı" value={editState.form.name} onChange={(e) => updateForm("name", e.target.value)} />
          <input className="filter-input" placeholder="Marka" value={editState.form.brand || ""} onChange={(e) => updateForm("brand", e.target.value)} />
          <input className="filter-input" placeholder="Kategori" value={editState.form.category || ""} onChange={(e) => updateForm("category", e.target.value)} />
          <input className="filter-input" placeholder="Tedarikçi" value={editState.form.supplier || ""} onChange={(e) => updateForm("supplier", e.target.value)} />
          <input className="filter-input" placeholder="Birim" value={editState.form.unit || ""} onChange={(e) => updateForm("unit", e.target.value)} />
          <input
            className="filter-input"
            placeholder="Fiyat"
            inputMode="decimal"
            value={editState.form.price ?? ""}
            onChange={(e) => {
              const next = e.target.value;
              const parsed = next.trim() === "" ? null : Number(next.replace(",", "."));
              updateForm("price", Number.isFinite(parsed) ? parsed : null);
            }}
          />
          <input
            className="filter-input"
            placeholder="Alt barkodlar (virgülle)"
            value={altInput}
            onChange={(e) => {
              const next = e.target.value;
              setAltInput(next);
              updateForm("alt_barcodes", formatAlt(next));
            }}
            onBlur={() => {
              const parsed = formatAlt(altInput);
              setAltInput(parsed.join(", "));
              updateForm("alt_barcodes", parsed);
            }}
          />
        </div>
        <label style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <input type="checkbox" checked={Boolean(editState.form.active)} onChange={(e) => updateForm("active", e.target.checked)} />
          Aktif
        </label>
        {formError ? (
          <p className="error" style={{ margin: 0 }}>
            {formError}
          </p>
        ) : null}
      </div>
    );
  };

  const cards = paginated.map((p) => {
    const statusTone = p.active ? "success" : "muted";
    const alt = p.alt_barcodes && p.alt_barcodes.length > 0 ? p.alt_barcodes.join(", ") : null;

    return (
      <div key={p.id} style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        <div style={cardStyles.row}>
          <div style={{ display: "flex", alignItems: "center", gap: 12, minWidth: 220 }}>
            <div style={cardStyles.avatar}>{getInitials(p.name)}</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
              <div style={{ fontWeight: 800 }}>{p.name}</div>
              <div style={{ color: "var(--text-subtle)", fontSize: 13 }}>
                {p.brand || "Marka yok"} · {p.category || "Kategori yok"}
              </div>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
                <SoftBadge tone="muted" label={`Barkod ${p.barcode}`} />
                {alt ? <SoftBadge tone="muted" label={`Alt: ${alt}`} /> : null}
              </div>
            </div>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
              <SoftBadge tone="info" label={`Tedarikçi: ${p.supplier || "-"}`} />
              <SoftBadge tone="muted" label={`Birim: ${p.unit || "-"}`} />
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
              <SoftBadge tone="info" label={`Kategori: ${p.category || "-"}`} />
              <SoftBadge tone="muted" label={`Marka: ${p.brand || "-"}`} />
            </div>
          </div>

          <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 8 }}>
            <SoftBadge tone={statusTone} label={p.active ? "Aktif" : "Pasif"} />
            <div style={{ fontWeight: 800, fontSize: 18 }}>{formatPrice(p.price)} ₺</div>
            {canEdit ? (
              <div style={{ display: "flex", gap: 8 }}>
                <CardActionButton tone={p.active ? "muted" : "success"} onClick={() => toggleActive(p)} disabled={saving}
                  label={p.active ? "Pasifleştir" : "Aktifleştir"}
                />
                <CardActionButton tone="info" onClick={() => openEdit(p)} disabled={saving} label="Düzenle" />
                <CardActionButton
                  tone="danger"
                  onClick={() => {
                    if (!window.confirm("Bu ürün silinsin mi?")) return;
                    void deleteProduct(p.id);
                  }}
                  disabled={deletingId === p.id}
                  label={deletingId === p.id ? "Siliniyor..." : "Sil"}
                />
              </div>
            ) : null}
          </div>
        </div>
        {editState?.mode === "edit" && editState.id === p.id ? renderEditPanel("Ürünü Düzenle") : null}
      </div>
    );
  });

  return (
    <CardListShell
      title="Ürün Listesi"
      description="Şube müdürü kendi firmasına ait ürünleri kart görünümünde filtreleyebilir."
      stats={[
        { label: "Toplam", value: products.length },
        { label: "Filtrelenen", value: filtered.length },
        lastSync ? { label: "Son senkron", value: new Date(lastSync).toLocaleString("tr-TR") } : null,
      ].filter(Boolean) as { label: string; value: string | number }[]}
      actions={
        <>
          <button className="ghost" onClick={resetFilters} type="button">
            Filtreleri sıfırla
          </button>
          <button className="primary" onClick={handleSync} type="button" disabled={loading}>
            {loading ? "Senkronize ediliyor..." : "Ürünleri senkronize et"}
          </button>
          {canEdit ? (
            <button className="primary" onClick={openCreate} type="button">
              Yeni Ürün
            </button>
          ) : null}
        </>
      }
      filterContent={filterContent}
      pills={activeFilters.map((label) => ({ label, tone: "muted" }))}
      footer={renderPagination()}
    >
      {loading ? <p>Yükleniyor...</p> : null}
      {pageError ? <p className="error">{pageError}</p> : null}

      {!loading && !pageError && paginated.length === 0 ? <p className="muted">Kayıt bulunamadı.</p> : null}

      {!loading && !pageError ? cards : null}

      {editState?.mode === "create" ? renderEditPanel("Yeni Ürün") : null}
    </CardListShell>
  );
}
