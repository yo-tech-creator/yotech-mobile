"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import type { ChangeEvent } from "react";
import { read, utils, write } from "xlsx";
import { normaliseBoolean } from "@/lib/xlsx/normalisers";
import { regionTemplateExample } from "@/components/tenants/templates";

const REGION_SHEET_NAME = "Regions";

const REGION_HEADERS = ["tenant_code", "region_code", "region_name", "is_active"] as const;

type RegionRow = {
  tenant_code?: string | number | null;
  region_code?: string | number | null;
  region_name?: string | null;
  is_active?: boolean | string | number | null;
};

type RegionDefinition = {
  tenant_code: string;
  region_code: string;
  region_name: string;
  is_active: boolean;
};

type RegionImportPayload = {
  tenantCode: string;
  regions: RegionDefinition[];
};

type ImportState =
  | { status: "idle" }
  | { status: "parsing" }
  | { status: "parsed"; payload: RegionImportPayload }
  | { status: "error"; message: string }
  | { status: "importing"; payload: RegionImportPayload }
  | { status: "success"; tenantCode: string; regionCount: number };

function isEmptyRow(row: Record<string, unknown>): boolean {
  return Object.values(row).every((value) => value === null || value === undefined || value === "");
}

async function parseWorkbook(file: File): Promise<RegionImportPayload> {
  const buffer = await file.arrayBuffer();
  const workbook = read(buffer, { type: "array" });

  const regionSheet = workbook.Sheets[REGION_SHEET_NAME];
  if (!regionSheet) {
    throw new Error(
      `${REGION_SHEET_NAME} sayfası bulunamadı. Lütfen "Şablon indir" ile gelen tenant-regions-template.xlsx dosyasını ve içindeki Regions sekmesini kullanın.`,
    );
  }

  const rows = utils.sheet_to_json<RegionRow>(regionSheet, {
    header: [...REGION_HEADERS],
    range: 1,
    defval: null,
  });

  const tenantCodes = new Set<string>();
  const regionCodes = new Set<string>();
  const regions: RegionDefinition[] = [];

  rows.forEach((row, index) => {
    if (isEmptyRow(row)) {
      return;
    }

          <div className="tenant-preview-wrapper">
            <div className="tenant-preview">
              <div>
                <strong>Bölgeler ({preview.regions.length})</strong>
                <ul>
                  {preview.regions.map((r) => (
                    <li key={r.code}>
                      {r.code} — {r.name} {r.active ? "(Aktif)" : "(Pasif)"}
                    </li>
                  ))}
                </ul>
              </div>
              {preview.regionManagers.length > 0 ? (
                <div>
                  <strong>Yönetici Atamaları</strong>
                  <ul>
                    {preview.regionManagers.map((r, idx) => (
                      <li key={`${r.region_code}-${idx}`}>
                        {r.region_code} → {r.manager_sicil}
                      </li>
                    ))}
                  </ul>
                </div>
              ) : null}
            </div>
          </div>
    tenantCodes.add(tenantCode);

    const activeValue = normaliseBoolean(row.is_active ?? true);
    if (activeValue === null) {
      throw new Error(`${REGION_SHEET_NAME} sayfasındaki ${regionCode} satırında is_active true/false olmalıdır`);
    }

    regions.push({
      tenant_code: tenantCode,
      region_code: regionCode,
      region_name: regionName,
      is_active: activeValue,
    });
  });

  if (regions.length === 0) {
    throw new Error(`${REGION_SHEET_NAME} sayfasında en az bir bölge satırı bulunmalıdır`);
  }

  if (tenantCodes.size === 0) {
    throw new Error(`${REGION_SHEET_NAME} sayfasında tenant_code belirtilmelidir`);
  }

  if (tenantCodes.size > 1) {
    throw new Error(`${REGION_SHEET_NAME} sayfasında birden fazla tenant_code bulundu: ${Array.from(tenantCodes).join(", ")}`);
  }

  const [tenantCode] = Array.from(tenantCodes);

  return {
    tenantCode,
    regions,
  };
}

function buildTemplateWorkbook(tenantCodeOverride?: string) {
  const workbook = utils.book_new();

  const regionExample = regionTemplateExample.Regions[0];
  const tenantCode = tenantCodeOverride ? String(tenantCodeOverride).trim() : regionExample?.tenant_code ?? "";

  const regionSheet = utils.aoa_to_sheet([
    [...REGION_HEADERS],
    [tenantCode, regionExample?.region_code ?? "", regionExample?.region_name ?? "", regionExample?.is_active ? "TRUE" : "FALSE"],
  ]);

  utils.book_append_sheet(workbook, regionSheet, REGION_SHEET_NAME);

  return workbook;
}

type Props = {
  showHeader?: boolean;
  tenantHint?: string;
};

export function RegionImportUploader({ showHeader = true, tenantHint }: Props) {
  const [state, setState] = useState<ImportState>({ status: "idle" });
  const [selectedFileName, setSelectedFileName] = useState<string | null>(null);
  const [progress, setProgress] = useState<number>(0);
  const progressTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  const preview = useMemo(() => {
    if (state.status === "parsed" || state.status === "importing") {
      return state.payload;
    }
    return null;
  }, [state]);

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

  const handleFileChange = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    setSelectedFileName(file?.name ?? null);

    if (!file) {
      setState({ status: "idle" });
      return;
    }

    setState({ status: "parsing" });

    try {
      const payload = await parseWorkbook(file);
      setState({ status: "parsed", payload });
    } catch (error) {
      console.error("Region import parse error", error);
      setState({
        status: "error",
        message: error instanceof Error ? error.message : "Dosya okunamadı",
      });
    }
  };

  const handleDownloadTemplate = () => {
    const workbook = buildTemplateWorkbook(tenantHint ?? undefined);
    const buffer = write(workbook, { type: "array", bookType: "xlsx" });
    const blob = new Blob([buffer], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "tenant-regions-template.xlsx";
    link.click();
    URL.revokeObjectURL(url);
  };

  const handleImport = async () => {
    if (state.status !== "parsed") {
      return;
    }

    setState({ status: "importing", payload: state.payload });
    startProgress();

    const response = await fetch("/api/tenants/import/regions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(state.payload),
    });

    if (!response.ok) {
      const body = await response.json().catch(() => ({ message: "Bilinmeyen hata" }));
      stopProgress(0);
      setState({ status: "error", message: body.message ?? "Bölgeler içe aktarılırken hata oluştu" });
      return;
    }

    const result = (await response.json()) as { tenantCode: string; regionCount: number };
    setState({ status: "success", tenantCode: result.tenantCode, regionCount: result.regionCount });
    setSelectedFileName(null);
    stopProgress(100);
    setTimeout(() => stopProgress(0), 400);
  };

  return (
    <div className="tenant-import">
      {showHeader ? (
        <header className="page-header">
          <h3>Bölge İçe Aktarma</h3>
          <p>Regions şablonunu doldurup yükleyerek şube bölgelerini oluşturun. Şube importundan önce tamamlayın.</p>
        </header>
      ) : null}

      <div className="card">
        <div className="tenant-import__actions">
          <button type="button" className="download" onClick={handleDownloadTemplate}>
            Şablon indir
          </button>
          <label className="upload">
            Excel dosyası seç
            <input type="file" accept=".xlsx,.xls" onChange={handleFileChange} />
          </label>
        </div>
        {tenantHint ? <p>Hedef firma: {tenantHint}</p> : null}
        {selectedFileName ? <p>Seçilen dosya: {selectedFileName}</p> : null}
        {state.status === "parsing" ? <p>Dosya okunuyor...</p> : null}
        {state.status === "error" ? <p className="alert alert-error">{state.message}</p> : null}
        {state.status === "success" ? (
          <p className="alert alert-success">
            {state.tenantCode} kodlu firmaya {state.regionCount} bölge eklendi.
          </p>
        ) : null}
        {progress > 0 ? (
          <div className="progress">
            <div className="progress__bar" style={{ width: `${progress}%` }} />
            <span className="progress__label">%{Math.round(progress)}</span>
          </div>
        ) : null}
      </div>

      <div className="card">
        <h3>Bölge şablonu rehberi</h3>
        <ul>
          <li>Regions.tenant_code: Hedef firma kodu; tüm satırlarda aynı olmalı.</li>
          <li>Regions.region_code: Benzersiz bölge kodu (büyük harf önerilir); şubelerde bu kodla referans verilir.</li>
          <li>Regions.region_name: Panelde gösterilecek bölge adı, zorunlu.</li>
          <li>Regions.is_active: true aktif bölge oluşturur; false pasif açar, sonra aktifleştirilebilir.</li>
        </ul>
      </div>

      {preview ? (
        <div className="card">
          <h3>Önizleme</h3>
          <div className="tenant-preview">
            <div>
              <strong>Bölgeler ({preview.regions.length})</strong>
              <ul>
                {preview.regions.map((region) => (
                  <li key={region.region_code}>
                    <span>
                      {region.region_code} — {region.region_name} {region.is_active ? "(Aktif)" : "(Pasif)"}
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
          <button type="button" className="primary" onClick={handleImport} disabled={state.status === "importing"}>
            {state.status === "importing" ? "İçe aktarılıyor..." : "Bölgeleri oluştur"}
          </button>
        </div>
      ) : null}
    </div>
  );
}
