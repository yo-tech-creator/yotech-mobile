"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import type { ChangeEvent } from "react";
import { read, utils, write } from "xlsx";
import { normaliseBoolean, normaliseNumber } from "@/lib/xlsx/normalisers";
import { branchTemplateExample } from "@/components/tenants/templates";

const BRANCH_SHEET_NAME = "Branches";
const BRANCH_MODULE_SHEET_NAME = "BranchModules";

const BRANCH_HEADERS = [
  "tenant_code",
  "branch_code",
  "branch_name",
  "region_code",
  "city",
  "district",
  "address",
  "latitude",
  "longitude",
  "geofence_radius",
  "is_active",
];

const BRANCH_MODULE_HEADERS = ["branch_code", "module_code", "is_enabled"] as const;

type BranchRow = {
  tenant_code?: string | number | null;
  branch_code?: string | number | null;
  branch_name?: string | null;
  region_code?: string | number | null;
  city?: string | null;
  district?: string | null;
  address?: string | null;
  latitude?: number | string | null;
  longitude?: number | string | null;
  geofence_radius?: number | string | null;
  is_active?: boolean | string | number | null;
};

type BranchModuleRow = {
  branch_code?: string | number | null;
  module_code?: string | null;
  is_enabled?: boolean | string | number | null;
};

type BranchDefinition = {
  branch_code: string;
  branch_name: string;
  region_code: string | null;
  city: string | null;
  district: string | null;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  geofence_radius: number | null;
  is_active: boolean;
};

type BranchModuleDefinition = {
  branch_code: string;
  module_code: string;
  is_enabled: boolean;
};

type BranchImportPayload = {
  tenantCode: string;
  branches: BranchDefinition[];
  branchModules: BranchModuleDefinition[];
};

type ImportState =
  | { status: "idle" }
  | { status: "parsing" }
  | { status: "parsed"; payload: BranchImportPayload }
  | { status: "error"; message: string }
  | { status: "importing"; payload: BranchImportPayload }
  | { status: "success"; tenantCode: string; branchCount: number; enabledModules: number };

function isEmptyRow(row: Record<string, unknown>): boolean {
  return Object.values(row).every((value) => value === null || value === undefined || value === "");
}

async function parseWorkbook(file: File): Promise<BranchImportPayload> {
  const buffer = await file.arrayBuffer();
  const workbook = read(buffer, { type: "array" });

  const branchSheet = workbook.Sheets[BRANCH_SHEET_NAME];
  if (!branchSheet) {
    throw new Error(`${BRANCH_SHEET_NAME} sayfası bulunamadı`);
  }

  const branchRows = utils.sheet_to_json<BranchRow>(branchSheet, {
    header: [...BRANCH_HEADERS],
    range: 1,
    defval: null,
  });

  const tenantCodes = new Set<string>();
  const branchCodes = new Set<string>();
  const branches: BranchDefinition[] = [];

  branchRows.forEach((row, index) => {
    if (isEmptyRow(row)) {
      return;
    }

    const rowNumber = index + 2;
    const tenantCodeRaw = row.tenant_code;
    const branchCodeRaw = row.branch_code;
    const branchNameRaw = row.branch_name;

    if (!tenantCodeRaw || !branchCodeRaw || !branchNameRaw) {
      throw new Error(
        `Branches sayfasındaki ${rowNumber}. satırda tenant_code, branch_code ve branch_name alanları doldurulmalıdır`,
      );
    }

    const tenantCode = String(tenantCodeRaw).trim();
    const branchCode = String(branchCodeRaw).trim().toUpperCase();
    const branchName = String(branchNameRaw).trim();

    if (!tenantCode || !branchCode || !branchName) {
      throw new Error(`Branches sayfasındaki ${rowNumber}. satırda boş değer bırakılamaz`);
    }

    if (branchCodes.has(branchCode)) {
      throw new Error(`Branches sayfasında tekrarlanan şube kodu bulundu: ${branchCode}`);
    }

    branchCodes.add(branchCode);
    tenantCodes.add(tenantCode);

    const regionCode = row.region_code ? String(row.region_code).trim().toUpperCase() : null;
    const city = row.city ? String(row.city).trim() : null;
    const district = row.district ? String(row.district).trim() : null;
    const address = row.address ? String(row.address).trim() : null;
    const latitude = normaliseNumber(row.latitude);
    const longitude = normaliseNumber(row.longitude);
    const radiusValue = normaliseNumber(row.geofence_radius);
    const geofenceRadius = radiusValue !== null ? Math.round(radiusValue) : null;

    if (geofenceRadius !== null && geofenceRadius <= 0) {
      throw new Error(`Branches sayfasındaki ${branchCode} satırında geofence_radius 0'dan büyük olmalıdır`);
    }

    const activeValue = normaliseBoolean(row.is_active ?? true);
    if (activeValue === null) {
      throw new Error(`Branches sayfasındaki ${branchCode} satırında is_active alanı evet/hayır veya true/false olmalıdır`);
    }

    branches.push({
      branch_code: branchCode,
      branch_name: branchName,
      region_code: regionCode && regionCode.length > 0 ? regionCode : null,
      city: city && city.length > 0 ? city : null,
      district: district && district.length > 0 ? district : null,
      address: address && address.length > 0 ? address : null,
      latitude: latitude,
      longitude: longitude,
      geofence_radius: geofenceRadius,
      is_active: activeValue,
    });
  });

  if (branches.length === 0) {
    throw new Error(`${BRANCH_SHEET_NAME} sayfasında en az bir şube satırı bulunmalıdır`);
  }

  if (tenantCodes.size === 0) {
    throw new Error(`${BRANCH_SHEET_NAME} sayfasında tenant_code belirtilmelidir`);
  }

  if (tenantCodes.size > 1) {
    throw new Error(`Branches sayfasında birden fazla tenant_code bulundu: ${Array.from(tenantCodes).join(", ")}`);
  }

  const [tenantCode] = Array.from(tenantCodes);

  const moduleSheet = workbook.Sheets[BRANCH_MODULE_SHEET_NAME];
  const branchModules: BranchModuleDefinition[] = [];

  if (moduleSheet) {
    const moduleRows = utils.sheet_to_json<BranchModuleRow>(moduleSheet, {
      header: [...BRANCH_MODULE_HEADERS],
      range: 1,
      defval: null,
    });

    moduleRows.forEach((row, index) => {
      if (isEmptyRow(row)) {
        return;
      }

      const rowNumber = index + 2;
      const branchCodeRaw = row.branch_code;
      const moduleCodeRaw = row.module_code;

      if (!branchCodeRaw || !moduleCodeRaw) {
        throw new Error(
          `BranchModules sayfasındaki ${rowNumber}. satırda branch_code ve module_code alanları doldurulmalıdır`,
        );
      }

      const branchCode = String(branchCodeRaw).trim().toUpperCase();
      const moduleCode = String(moduleCodeRaw).trim().toLowerCase();

      if (!branchCodes.has(branchCode)) {
        throw new Error(`BranchModules sayfasındaki ${branchCode} kodu Branches sayfasında tanımlı değil`);
      }

      const isEnabled = normaliseBoolean(row.is_enabled ?? true);
      if (isEnabled === null) {
        throw new Error(
          `BranchModules sayfasındaki ${moduleCode} kaydında is_enabled alanı evet/hayır veya true/false olmalıdır`,
        );
      }

      branchModules.push({
        branch_code: branchCode,
        module_code: moduleCode,
        is_enabled: isEnabled,
      });
    });
  }

  return {
    tenantCode,
    branches,
    branchModules,
  };
}

function buildTemplateWorkbook(tenantCodeOverride?: string) {
  const workbook = utils.book_new();

  const branchExample = branchTemplateExample.Branches[0];
  const tenantCode = tenantCodeOverride ? String(tenantCodeOverride).trim() : branchExample?.tenant_code ?? "";

  const branchSheet = utils.aoa_to_sheet([
    [...BRANCH_HEADERS],
    [
      tenantCode,
      branchExample?.branch_code ?? "",
      branchExample?.branch_name ?? "",
      branchExample?.region_code ?? "",
      branchExample?.city ?? "",
      "",
      "",
      "",
      "",
      "",
      branchExample?.is_active ? "TRUE" : "FALSE",
    ],
  ]);

  const moduleSheet = utils.aoa_to_sheet([
    [...BRANCH_MODULE_HEADERS],
    ...branchTemplateExample.BranchModules.map((row) => [row.branch_code, row.module_code, row.is_enabled ? "TRUE" : "FALSE"]),
  ]);

  utils.book_append_sheet(workbook, branchSheet, BRANCH_SHEET_NAME);
  utils.book_append_sheet(workbook, moduleSheet, BRANCH_MODULE_SHEET_NAME);

  return workbook;
}

type Props = {
  showHeader?: boolean;
  tenantHint?: string;
};

export function BranchImportUploader({ showHeader = true, tenantHint }: Props) {
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

  const enabledModuleCount = useMemo(() => {
    if (!preview) {
      return 0;
    }
    return preview.branchModules.filter((module) => module.is_enabled).length;
  }, [preview]);

  const modulesByBranch = useMemo(() => {
    if (!preview) {
      return new Map<string, string[]>();
    }
    const map = new Map<string, string[]>();
    preview.branchModules.forEach((module) => {
      if (!module.is_enabled) {
        return;
      }
      const current = map.get(module.branch_code) ?? [];
      current.push(module.module_code);
      map.set(module.branch_code, current);
    });
    return map;
  }, [preview]);

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
      console.error("Branch import parse error", error);
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
    link.download = "tenant-branches-template.xlsx";
    link.click();
    URL.revokeObjectURL(url);
  };

  const handleImport = async () => {
    if (state.status !== "parsed") {
      return;
    }

    setState({ status: "importing", payload: state.payload });
    startProgress();

    const response = await fetch("/api/tenants/import/branches", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(state.payload),
    });

    if (!response.ok) {
      const body = await response.json().catch(() => ({ message: "Bilinmeyen hata" }));
      stopProgress(0);
      setState({ status: "error", message: body.message ?? "Şubeler içe aktarılırken hata oluştu" });
      return;
    }

    const result = (await response.json()) as { tenantCode: string; branchCount: number; enabledModules: number };
    setState({
      status: "success",
      tenantCode: result.tenantCode,
      branchCount: result.branchCount,
      enabledModules: result.enabledModules,
    });
    setSelectedFileName(null);
    stopProgress(100);
    setTimeout(() => stopProgress(0), 400);
  };

  return (
    <div className="tenant-import">
      {showHeader ? (
        <header className="page-header">
          <h3>Şube İçe Aktarma</h3>
          <p>
            Branches şablonunu doldurup yükleyerek şubeleri otomatik oluşturun. BranchModules sayfası, şube bazlı açık
            olması gereken modülleri işaretler.
          </p>
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
            {state.tenantCode} kodlu firmaya {state.branchCount} şube eklendi. {state.enabledModules} modül etkinleştirildi.
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
        <h3>Şube şablonu rehberi</h3>
        <ul>
          <li>
            Branches.tenant_code: Hedef firma kodu; tüm satırlarda aynı olmalı ve yeni oluşturduğunuz tenant kodu ile
            eşleşmeli.
          </li>
          <li>Branches.branch_code: Şube için benzersiz kod (büyük harf önerilir).</li>
          <li>Branches.branch_name: Panelde görünen şube adı.</li>
          <li>Branches.region_code: Opsiyonel; Supabase regions tablosundaki kod ile eşleşir.</li>
          <li>Branches.city/district/address: Opsiyonel serbest metin; raporlama ve adres bilgisi için.</li>
          <li>
            Branches.latitude/longitude: Opsiyonel; geofence_radius (metre) ile birlikte konum doğrulama için kullanılır.
            Radius pozitif olmalı.
          </li>
          <li>
            Branches.is_active: true ise şube aktif ve listelerde görünür; false ise pasif açılır, ileride aktifleştirilebilir.
          </li>
          <li>
            BranchModules.module_code: Supabase modules tablosundaki module_code değerlerinden biri. Şube kodu ile eşleştirin.
          </li>
          <li>
            BranchModules.is_enabled: true modülü şube bazında açar; false mevcut durumu değiştirmez veya kapalı bırakır.
            Modül satırı eklemezseniz şube tenant varsayılanlarını kullanır.
          </li>
        </ul>
      </div>

      {preview ? (
        <div className="card">
          <h3>Önizleme</h3>
          <div className="tenant-preview-wrapper">
            <div className="tenant-preview">
              <div>
                <strong>Şubeler ({preview.branches.length})</strong>
                <ul>
                  {preview.branches.map((branch) => {
                    const modules = modulesByBranch.get(branch.branch_code) ?? [];
                    return (
                      <li key={branch.branch_code}>
                        <span>
                          {branch.branch_code} — {branch.branch_name} {branch.is_active ? "(Aktif)" : "(Pasif)"}
                        </span>
                        <div>
                          {branch.region_code ? `Bölge: ${branch.region_code}` : ""}
                          {branch.region_code && branch.city ? " · " : ""}
                          {branch.city ? `Şehir: ${branch.city}` : ""}
                        </div>
                        {modules.length > 0 ? <div>Modüller: {modules.join(", ")}</div> : null}
                      </li>
                    );
                  })}
                </ul>
              </div>
              <div>
                <strong>Modül Özeti</strong>
                <p>Toplam {enabledModuleCount} modül şube bazında etkinleştirilecek.</p>
                <p>BranchModules sayfasında pasif işaretlenen modüller mevcut durumu değiştirmez.</p>
              </div>
            </div>
          </div>
          <button type="button" className="primary" onClick={handleImport} disabled={state.status === "importing"}>
            {state.status === "importing" ? "İçe aktarılıyor..." : "Şubeleri oluştur"}
          </button>
        </div>
      ) : null}
    </div>
  );
}
