"use client";

import { useEffect, useMemo, useState } from "react";
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

export default function ProductsPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [filters, setFilters] = useState<Filters>(emptyFilters);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pageSize, setPageSize] = useState<number>(10);
  const [page, setPage] = useState<number>(1);

  useEffect(() => {
    let mounted = true;

    async function load() {
      try {
        const res = await fetch("/api/products");
        if (!res.ok) {
          throw new Error("Ürünler alınamadı");
        }
        const body = (await res.json()) as { products: Product[] };
        if (mounted) {
          setProducts(body.products ?? []);
        }
      } catch (err) {
        if (mounted) {
          setError((err as Error).message);
        }
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    }

    void load();
    return () => {
      mounted = false;
    };
  }, []);

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

  const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize));
  const currentPage = Math.min(page, totalPages);
  const start = (currentPage - 1) * pageSize;
  const paginated = filtered.slice(start, start + pageSize);

  const renderPagination = () => (
    <div
      style={{
        display: "flex",
        flexWrap: "wrap",
        gap: "10px",
        alignItems: "center",
        justifyContent: "flex-end",
        marginTop: "8px",
        fontSize: 13,
      }}
    >
      <span style={{ whiteSpace: "nowrap" }}>
        Gösterilen {paginated.length} / {filtered.length}
      </span>
      <div style={{ display: "flex", gap: "6px", alignItems: "center", flexWrap: "wrap" }}>
        <label style={{ display: "flex", alignItems: "center", gap: 6, whiteSpace: "nowrap" }}>
          <span>Sayfa başına</span>
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
            {[10, 100, 500].map((n) => (
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
        <span style={{ minWidth: 80, textAlign: "center" }}>
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

  return (
    <div className="page">
      <header className="page-header">
        <h2>Ürün Listesi</h2>
        <p>Şube müdürü kendi firmasına ait ürünleri görüntüler; başlıklar üzerinden filtreleyebilir.</p>
      </header>

      <div className="card table-card">
        <div className="table-toolbar">
          <div className="toolbar-stat">Toplam: {products.length}</div>
          <div className="toolbar-stat">Filtrelenen: {filtered.length}</div>
          <button className="ghost" onClick={resetFilters} type="button">
            Filtreleri sıfırla
          </button>
          <div className="toolbar-spacer" />
          {renderPagination()}
        </div>

        {loading ? <p>Yükleniyor...</p> : null}
        {error ? <p className="error">{error}</p> : null}

        {!loading && !error ? (
          <div className="table-wrapper">
            <table className="products-table">
              <thead>
                <tr>
                  <th>Barkod</th>
                  <th>Ürün Adı</th>
                  <th>Marka</th>
                  <th>Kategori</th>
                  <th>Tedarikçi</th>
                  <th>Birim</th>
                  <th>Fiyat</th>
                  <th>Durum</th>
                </tr>
                <tr className="filter-row">
                  <th>
                    <input
                      className="filter-input"
                      placeholder="Barkod / Alt barkod"
                      value={filters.barcode}
                      onChange={(e) => handleFilterChange("barcode", e.target.value)}
                    />
                  </th>
                  <th>
                    <input
                      className="filter-input"
                      placeholder="Ürün adı"
                      value={filters.name}
                      onChange={(e) => handleFilterChange("name", e.target.value)}
                    />
                  </th>
                  <th>
                    <input
                      className="filter-input"
                      placeholder="Marka"
                      value={filters.brand}
                      onChange={(e) => handleFilterChange("brand", e.target.value)}
                    />
                  </th>
                  <th>
                    <input
                      className="filter-input"
                      placeholder="Kategori"
                      value={filters.category}
                      onChange={(e) => handleFilterChange("category", e.target.value)}
                    />
                  </th>
                  <th>
                    <input
                      className="filter-input"
                      placeholder="Tedarikçi"
                      value={filters.supplier}
                      onChange={(e) => handleFilterChange("supplier", e.target.value)}
                    />
                  </th>
                  <th>
                    <input
                      className="filter-input"
                      placeholder="Birim"
                      value={filters.unit}
                      onChange={(e) => handleFilterChange("unit", e.target.value)}
                    />
                  </th>
                  <th>
                    <div className="price-filter">
                      <input
                        className="filter-input"
                        placeholder="Min"
                        value={filters.minPrice}
                        onChange={(e) => handleFilterChange("minPrice", e.target.value)}
                        inputMode="decimal"
                      />
                      <input
                        className="filter-input"
                        placeholder="Max"
                        value={filters.maxPrice}
                        onChange={(e) => handleFilterChange("maxPrice", e.target.value)}
                        inputMode="decimal"
                      />
                    </div>
                  </th>
                  <th>
                    <select
                      className="filter-input"
                      value={filters.status}
                      onChange={(e) => handleFilterChange("status", e.target.value as Filters["status"])}
                    >
                      <option value="all">Tümü</option>
                      <option value="active">Aktif</option>
                      <option value="inactive">Pasif</option>
                    </select>
                  </th>
                </tr>
              </thead>
              <tbody>
                {paginated.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="empty">
                      Kayıt bulunamadı.
                    </td>
                  </tr>
                ) : (
                  paginated.map((p) => (
                    <tr key={p.id}>
                      <td>
                        <div className="cell-main">{p.barcode}</div>
                        {p.alt_barcodes && p.alt_barcodes.length > 0 ? (
                          <div className="cell-sub">Alt: {p.alt_barcodes.join(", ")}</div>
                        ) : null}
                      </td>
                      <td>{p.name}</td>
                      <td>{p.brand || "-"}</td>
                      <td>{p.category || "-"}</td>
                      <td>{p.supplier || "-"}</td>
                      <td>{p.unit || "-"}</td>
                      <td>{typeof p.price === "number" ? p.price.toLocaleString("tr-TR", { minimumFractionDigits: 2 }) : "-"}</td>
                      <td>
                        <span className={p.active ? "status-chip success" : "status-chip muted"}>
                          {p.active ? "Aktif" : "Pasif"}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
            {renderPagination()}
          </div>
        ) : null}

        {!loading && !error ? (
          <div className="table-footer">
            <div className="pager compact">
              <label className="pager-label">Gösterim</label>
              <select
                className="filter-input page-size"
                value={pageSize}
                onChange={(e) => {
                  const next = Number(e.target.value);
                  setPageSize(next);
                  setPage(1);
                }}
              >
                {[10, 100, 1000].map((n) => (
                  <option key={n} value={n}>
                    {n}
                  </option>
                ))}
              </select>
              <button className="ghost" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={currentPage === 1} type="button">
                ←
              </button>
              <button
                className="ghost"
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
                type="button"
              >
                →
              </button>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}
