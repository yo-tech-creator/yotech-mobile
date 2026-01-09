"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import type { ChangeEvent } from "react";
import { read, utils, write } from "xlsx";
import { normaliseBoolean } from "@/lib/xlsx/normalisers";
import { productsTemplateExample } from "@/components/tenants/templates";

const PRODUCT_SHEET = "Products";

const PRODUCT_HEADERS = [
  "tenant_code",
  "barcode",
  "name",
  "brand",
  "category",
  "supplier",
  "unit",
  "price",
  "alt_barcodes",
  "active",
] as const;

type ProductRow = {
  tenant_code?: string | number | null;
  barcode?: string | number | null;
  name?: string | null;
  brand?: string | null;
  category?: string | null;
  supplier?: string | null;
  unit?: string | null;
  price?: number | string | null;
  alt_barcodes?: string | null;
  active?: boolean | string | number | null;
};

type ProductDefinition = {
  tenant_code: string;
  barcode: string;
  name: string;
  brand: string | null;
  category: string | null;
  supplier: string | null;
  unit: string | null;
  price: number | null;
  alt_barcodes: string[] | null;
  active: boolean;
};

type ProductsImportPayload = {
  tenantCode: string;
  products: ProductDefinition[];
};

type ImportState =
  | { status: "idle" }
  | { status: "parsing" }
  | { status: "parsed"; payload: ProductsImportPayload }
  | { status: "error"; message: string }
  | { status: "importing"; payload: ProductsImportPayload }
  | { status: "success"; tenantCode: string; productCount: number };

function isEmptyRow(row: Record<string, unknown>): boolean {
  return Object.values(row).every((value) => value === null || value === undefined || value === "");
}

function splitAltBarcodes(raw: string | null | undefined): string[] {
  if (!raw) return [];
  return raw
    .split(",")
    .map((c) => c.trim())
    .filter((c) => c.length > 0);
}

async function parseWorkbook(file: File): Promise<ProductsImportPayload> {
  const buffer = await file.arrayBuffer();
  const workbook = read(buffer, { type: "array" });

  const productSheet = workbook.Sheets[PRODUCT_SHEET];
  if (!productSheet) {
    throw new Error(`${PRODUCT_SHEET} sayfası bulunamadı. Şablondaki sekme adını değiştirmeyin.`);
  }

  const rows = utils.sheet_to_json<ProductRow>(productSheet, {
    header: [...PRODUCT_HEADERS],
    range: 1,
    defval: null,
  });

  const tenantCodes = new Set<string>();
  const barcodes = new Set<string>();
  const altCodes = new Set<string>();
  const products: ProductDefinition[] = [];

  rows.forEach((row, index) => {
    if (isEmptyRow(row)) return;

    const rowNumber = index + 2;
    const tenantCodeRaw = row.tenant_code;
    const barcodeRaw = row.barcode;
    const nameRaw = row.name;

    if (!tenantCodeRaw || !barcodeRaw || !nameRaw) {
      throw new Error(`${rowNumber}. satırda tenant_code, barcode ve name zorunlu`);
    }

    const tenantCode = String(tenantCodeRaw).trim();
    const barcode = String(barcodeRaw).trim();
    const name = String(nameRaw).trim();

    if (!tenantCode || !barcode || !name) {
      throw new Error(`${rowNumber}. satırda boş değer bırakılamaz`);
    }

    tenantCodes.add(tenantCode);

    if (barcodes.has(barcode) || altCodes.has(barcode)) {
      throw new Error(`Tekrarlanan barkod bulundu: ${barcode}`);
    }
    barcodes.add(barcode);

    const altList = splitAltBarcodes(row.alt_barcodes);
    if (altList.length > 10) {
      throw new Error(`${barcode} için alt_barcodes en fazla 10 değer içerebilir`);
    }

    const localAlt = new Set<string>();
    altList.forEach((code) => {
      if (code === barcode) {
        throw new Error(`${barcode} alt_barcodes ana barkod ile aynı olamaz`);
      }
      if (barcodes.has(code) || altCodes.has(code) || localAlt.has(code)) {
        throw new Error(`${barcode} alt_barcodes değeri tekrar ediyor veya başka ürünle çakışıyor: ${code}`);
      }
      localAlt.add(code);
      altCodes.add(code);
    });

    const price = row.price === null || row.price === undefined || row.price === ""
      ? null
      : Number(row.price);

    if (price !== null && Number.isNaN(price)) {
      throw new Error(`${barcode} fiyat değeri numerik olmalı`);
    }

    const active = normaliseBoolean(row.active ?? true);
    if (active === null) {
      throw new Error(`${barcode} için active true/false olmalıdır`);
    }

    products.push({
      tenant_code: tenantCode,
      barcode,
      name,
      brand: row.brand?.trim() || null,
      category: row.category?.trim() || null,
      supplier: row.supplier?.trim() || null,
      unit: row.unit?.trim() || "adet",
      price,
      alt_barcodes: altList.length > 0 ? altList : null,
      active,
    });
  });

  if (products.length === 0) {
    throw new Error(`${PRODUCT_SHEET} sayfasında en az bir ürün satırı olmalı`);
  }

  if (tenantCodes.size === 0) {
    throw new Error(`${PRODUCT_SHEET} sayfasında tenant_code eksik`);
  }

  if (tenantCodes.size > 1) {
    throw new Error(`${PRODUCT_SHEET} sayfasında birden fazla tenant_code bulundu: ${Array.from(tenantCodes).join(", ")}`);
  }

  const [tenantCode] = Array.from(tenantCodes);

  return { tenantCode, products };
}

function buildTemplateWorkbook(tenantCodeOverride?: string) {
  const workbook = utils.book_new();
  const tenantCode = tenantCodeOverride ? tenantCodeOverride.trim() : productsTemplateExample.Products[0].tenant_code;

  const productSheet = utils.aoa_to_sheet([
    [...PRODUCT_HEADERS],
    ...productsTemplateExample.Products.map((row) => [
      tenantCode ?? "",
      row.barcode,
      row.name,
      row.brand,
      row.category,
      row.supplier,
      row.unit,
      row.price,
      row.alt_barcodes,
      row.active ? "TRUE" : "FALSE",
    ]),
  ]);

  utils.book_append_sheet(workbook, productSheet, PRODUCT_SHEET);
  return workbook;
}

type Props = {
  showHeader?: boolean;
  tenantHint?: string;
};

export function ProductImportUploader({ showHeader = true, tenantHint }: Props) {
  const [state, setState] = useState<ImportState>({ status: "idle" });
  const [selectedFileName, setSelectedFileName] = useState<string | null>(null);
  const [progress, setProgress] = useState<number>(0);
  const [feedback, setFeedback] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const progressTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  const stopProgress = (value = 0) => {
    if (progressTimer.current) {
      clearInterval(progressTimer.current);
      progressTimer.current = null;
    }
    setProgress(value);
  };

  const startProgress = () => {
    stopProgress(10);
    progressTimer.current = setInterval(() => {
      setProgress((prev) => (prev >= 90 ? 90 : prev + 7));
    }, 350);
  };

  useEffect(() => () => stopProgress(0), []);

  const preview = useMemo(() => {
    if (state.status === "parsed" || state.status === "importing") {
      return state.payload;
    }
    return null;
  }, [state]);

  const handleFileChange = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    setSelectedFileName(file?.name ?? null);

    // Aynı dosyayı tekrar seçebilmek için input'u temizliyoruz.
    if (event.target) {
      event.target.value = "";
    }

    setFeedback(null);

    if (!file) {
      setState({ status: "idle" });
      return;
    }

    setState({ status: "parsing" });

    try {
      const payload = await parseWorkbook(file);
      setState({ status: "parsed", payload });
    } catch (error) {
      console.error("Product import parse error", error);
      setState({ status: "error", message: error instanceof Error ? error.message : "Dosya okunamadı" });
    }
  };

  const handleDownloadTemplate = () => {
    const workbook = buildTemplateWorkbook(tenantHint ?? undefined);
    const buffer = write(workbook, { type: "array", bookType: "xlsx" });
    const blob = new Blob([buffer], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "tenant-products-template.xlsx";
    link.click();
    URL.revokeObjectURL(url);
  };

  const handleImport = async () => {
    if (state.status !== "parsed") return;

    setState({ status: "importing", payload: state.payload });
    startProgress();

    const response = await fetch("/api/tenants/import/products", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(state.payload),
    });

    if (!response.ok) {
      const body = await response.json().catch(() => ({ message: "Bilinmeyen hata" }));
      stopProgress(0);
      setFeedback({ type: "error", message: body.message ?? "Ürünler içe aktarılırken hata oluştu" });
      setState({ status: "idle" });
      setSelectedFileName(null);
      if (fileInputRef.current) fileInputRef.current.value = "";
      return;
    }

    const result = (await response.json()) as { tenantCode: string; productCount: number };
    setFeedback({ type: "success", message: `${result.tenantCode} kodlu firmaya ${result.productCount} ürün eklendi.` });
    setState({ status: "idle" });
    setSelectedFileName(null);
    if (fileInputRef.current) fileInputRef.current.value = "";
    stopProgress(100);
    setTimeout(() => stopProgress(0), 400);
  };

  return (
    <div className="tenant-import">
      {showHeader ? (
        <header className="page-header">
          <h3>Ürün İçe Aktarma</h3>
          <p>Ürün kataloglarını barkod ve alt barkod kurallarıyla tek seferde ekleyin.</p>
        </header>
      ) : null}

      <div className="card">
        <div className="tenant-import__actions">
          <button type="button" className="download" onClick={handleDownloadTemplate}>
            Şablon indir
          </button>
          <label className="upload">
            Excel dosyası seç
            <input ref={fileInputRef} type="file" accept=".xlsx,.xls" onChange={handleFileChange} />
          </label>
        </div>
        {tenantHint ? <p>Hedef firma: {tenantHint}</p> : null}
        {selectedFileName ? <p>Seçilen dosya: {selectedFileName}</p> : null}
        {state.status === "parsing" ? <p>Dosya okunuyor...</p> : null}
        {feedback ? (
          <p className={`alert alert-${feedback.type === "success" ? "success" : "error"}`}>{feedback.message}</p>
        ) : null}
        {progress > 0 ? (
          <div className="progress">
            <div className="progress__bar" style={{ width: `${progress}%` }} />
            <span className="progress__label">%{Math.round(progress)}</span>
          </div>
        ) : null}
      </div>

      <div className="card">
        <h3>Ürün şablonu rehberi</h3>
        <ul>
          <li>tenant_code: Hedef firma kodu; tüm satırlarda aynı olmalı.</li>
          <li>barcode: Zorunlu ve aynı firmada benzersiz.</li>
          <li>alt_barcodes: Virgülle ayrılmış en fazla 10 değer; ana barkodla aynı olamaz.</li>
          <li>brand/category/supplier/unit: Opsiyonel; unit boşsa "adet" kabul edilir.</li>
          <li>price: Opsiyonel numerik değer.</li>
          <li>active: true aktif, false pasif ürün oluşturur.</li>
        </ul>
      </div>

      {preview ? (
        <div className="card">
          <h3>Önizleme</h3>
          <div className="tenant-preview-wrapper">
            <div className="tenant-preview">
              <div>
                <strong>Ürünler ({preview.products.length})</strong>
                <ul>
                  {preview.products.map((p) => (
                    <li key={p.barcode}>
                      {p.barcode} — {p.name}
                      {p.brand ? ` · Marka: ${p.brand}` : ""}
                      {p.category ? ` · Kategori: ${p.category}` : ""}
                      {p.price !== null && !Number.isNaN(p.price) ? ` · Fiyat: ${p.price}` : ""}
                      {p.active ? " (Aktif)" : " (Pasif)"}
                      {p.alt_barcodes && p.alt_barcodes.length > 0 ? ` · Alt barkodlar: ${p.alt_barcodes.join(", ")}` : ""}
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
          <button type="button" className="primary" onClick={handleImport} disabled={state.status === "importing"}>
            {state.status === "importing" ? "İçe aktarılıyor..." : "Ürünleri oluştur"}
          </button>
        </div>
      ) : null}
    </div>
  );
}
