"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import type { ChangeEvent } from "react";
import { read, utils, write } from "xlsx";
import { normaliseBoolean } from "@/lib/xlsx/normalisers";
import { tenantTemplateExample } from "@/components/tenants/templates";

const TENANT_SHEET_NAME = "Tenant";
const MODULES_SHEET_NAME = "Modules";

const TENANT_HEADERS = [
  "tenant_code",
  "tenant_name",
  "is_active",
  "logo_url",
  "sap_integration_active",
  "sap_api_url",
  "sap_api_key",
  "module_skt",
  "module_tasks",
  "module_attendance",
  "module_shifts",
  "module_forms",
  "module_malfunctions",
  "module_transfers",
  "module_performance",
  "module_payroll",
] as const;

const MODULE_HEADERS = ["module_code", "is_enabled", "enabled_by_email"] as const;

const TENANT_FIELD_HELP = [
  { key: "tenant_code", text: "Benzersiz firma kodu (zorunlu, büyük harf)." },
  { key: "tenant_name", text: "Firma adı (zorunlu)." },
  { key: "is_active", text: "TRUE: firma aktif, FALSE: pasif." },
  { key: "logo_url", text: "Opsiyonel logo görseli URL'si." },
  { key: "sap_integration_active", text: "TRUE: SAP entegrasyonu açık, FALSE: kapalı." },
  { key: "sap_api_url", text: "SAP entegrasyonu için base URL (opsiyonel)." },
  { key: "sap_api_key", text: "SAP erişim anahtarı (opsiyonel)." },
  { key: "module_*", text: "TRUE: modül firma genelinde açık; FALSE: tamamen kapalı (şube bazında da kullanılamaz)." },
];

const MODULE_FIELD_HELP = [
  { key: "module_code", text: "Sistemde tanımlı modül kodu (örn. tasks, attendance)." },
  { key: "is_enabled", text: "TRUE: bu firmada modül aktif, FALSE: pasif." },
  {
    key: "enabled_by_email",
    text: "Modülü yetkilendiren kullanıcı e-postası (opsiyonel). Boşsa oturumdaki kullanıcı atanır.",
  },
];

type TenantRow = {
  tenant_code?: string;
  tenant_name?: string;
  is_active?: boolean | string | number;
  logo_url?: string | null;
  sap_integration_active?: boolean | string | number | null;
  sap_api_url?: string | null;
  sap_api_key?: string | null;
  module_skt?: boolean | string | number | null;
  module_tasks?: boolean | string | number | null;
  module_attendance?: boolean | string | number | null;
  module_shifts?: boolean | string | number | null;
  module_forms?: boolean | string | number | null;
  module_malfunctions?: boolean | string | number | null;
  module_transfers?: boolean | string | number | null;
  module_performance?: boolean | string | number | null;
  module_payroll?: boolean | string | number | null;
};

type ModuleRow = {
  module_code?: string;
  is_enabled?: boolean | string | number;
  enabled_by_email?: string | null;
};

type TenantImportPayload = {
  tenant: {
    code: string;
    name: string;
    is_active: boolean;
    currency: string;
    language: string;
    country: string | null;
    city: string | null;
    logo_url: string | null;
    sap_customer_id: string | null;
    sap_api_key: string | null;
    sap_api_url: string | null;
    sap_integration_active: boolean;
    module_flags: Record<string, boolean>;
  };
  modules: {
    module_code: string;
    is_enabled: boolean;
    enabled_by_email: string | null;
  }[];
};
type AvailableModule = {
  module_code: string;
  name?: string | null;
};

type ImportState =
  | { status: "idle" }
  | { status: "parsing" }
  | { status: "parsed"; payload: TenantImportPayload }
  | { status: "error"; message: string }
  | { status: "importing"; payload: TenantImportPayload }
  | { status: "success"; tenantCode: string };

async function parseWorkbook(file: File): Promise<TenantImportPayload> {
  const buffer = await file.arrayBuffer();
  const excelWorkbook = read(buffer, { type: "array" });

  const tenantSheet = excelWorkbook.Sheets[TENANT_SHEET_NAME];
  if (!tenantSheet) {
    throw new Error(`${TENANT_SHEET_NAME} sayfası bulunamadı`);
  }

  const tenantRows = utils.sheet_to_json<TenantRow>(tenantSheet, {
    header: [...TENANT_HEADERS],
    range: 1,
    defval: null,
  });
  const tenant = tenantRows[0];

  if (!tenant || !tenant.tenant_code || !tenant.tenant_name) {
    throw new Error("Tenant sayfasında tenant_code ve tenant_name zorunlu alanlardır");
  }

  const activeValue = normaliseBoolean(tenant.is_active ?? true);
  if (activeValue === null) {
    throw new Error("Tenant sayfasındaki is_active sütunu evet/hayır veya true/false olmalıdır");
  }

  const sapActiveValue = normaliseBoolean(tenant.sap_integration_active ?? false);
  if (sapActiveValue === null) {
    throw new Error("sap_integration_active sütunu evet/hayır veya true/false olmalıdır");
  }

  const moduleFlag = (value: TenantRow[keyof TenantRow], key: string) => {
    const parsed = normaliseBoolean(value ?? true);
    if (parsed === null) {
      throw new Error(`${key} sütunu evet/hayır veya true/false olmalıdır`);
    }
    return parsed;
  };

  const modulesSheet = excelWorkbook.Sheets[MODULES_SHEET_NAME];
  if (!modulesSheet) {
    throw new Error(`${MODULES_SHEET_NAME} sayfası bulunamadı`);
  }

  const moduleRows = utils.sheet_to_json<ModuleRow>(modulesSheet, {
    header: [...MODULE_HEADERS],
    range: 1,
    defval: null,
  });
  const modules = moduleRows
    .filter((row) => !!row.module_code)
    .map((row) => {
      const isEnabled = normaliseBoolean(row.is_enabled ?? true);
      if (isEnabled === null) {
        throw new Error(
          `${MODULES_SHEET_NAME} sayfasındaki ${row.module_code ?? "(boş)"} satırında is_enabled alanı evet/hayır veya true/false olmalıdır`,
        );
      }
      return {
        module_code: String(row.module_code).trim().toLowerCase(),
        is_enabled: isEnabled,
        enabled_by_email: row.enabled_by_email ? String(row.enabled_by_email).trim() : null,
      };
    });

  if (modules.length === 0) {
    throw new Error(`${MODULES_SHEET_NAME} sayfasında en az bir modül bulunmalıdır`);
  }

  return {
    tenant: {
      code: String(tenant.tenant_code).trim().toUpperCase(),
      name: String(tenant.tenant_name).trim(),
      is_active: activeValue,
      currency: "TRY",
      language: "tr",
      country: null,
      city: null,
      logo_url: tenant.logo_url ? String(tenant.logo_url).trim() : null,
      sap_customer_id: null,
      sap_integration_active: sapActiveValue,
      sap_api_url: tenant.sap_api_url ? String(tenant.sap_api_url).trim() : null,
      sap_api_key: tenant.sap_api_key ? String(tenant.sap_api_key).trim() : null,
      module_flags: {
        module_skt: moduleFlag(tenant.module_skt, "module_skt"),
        module_tasks: moduleFlag(tenant.module_tasks, "module_tasks"),
        module_attendance: moduleFlag(tenant.module_attendance, "module_attendance"),
        module_shifts: moduleFlag(tenant.module_shifts, "module_shifts"),
        module_forms: moduleFlag(tenant.module_forms, "module_forms"),
        module_malfunctions: moduleFlag(tenant.module_malfunctions, "module_malfunctions"),
        module_transfers: moduleFlag(tenant.module_transfers, "module_transfers"),
        module_performance: moduleFlag(tenant.module_performance, "module_performance"),
        module_payroll: moduleFlag(tenant.module_payroll, "module_payroll"),
      },
    },
    modules,
  };
}

function buildTemplateWorkbook(
  modulesOverride?: Array<{ module_code: string; is_enabled?: boolean; enabled_by_email?: string | null }>,
) {
  const workbook = utils.book_new();
  const tenantExample = tenantTemplateExample[TENANT_SHEET_NAME][0];
  const modulesExample = (modulesOverride !== undefined ? modulesOverride : tenantTemplateExample[MODULES_SHEET_NAME]).map((row) => ({
    module_code: row.module_code,
    is_enabled: row.is_enabled ?? true,
    enabled_by_email: row.enabled_by_email ?? "",
  }));

  const tenantSheet = utils.aoa_to_sheet([
    [...TENANT_HEADERS],
    [
      tenantExample?.tenant_code ?? "",
      tenantExample?.tenant_name ?? "",
      tenantExample?.is_active ? "TRUE" : "FALSE",
      tenantExample?.logo_url ?? "",
      tenantExample?.sap_integration_active ? "TRUE" : "FALSE",
      tenantExample?.sap_api_url ?? "",
      tenantExample?.sap_api_key ?? "",
      tenantExample?.module_skt ? "TRUE" : "FALSE",
      tenantExample?.module_tasks ? "TRUE" : "FALSE",
      tenantExample?.module_attendance ? "TRUE" : "FALSE",
      tenantExample?.module_shifts ? "TRUE" : "FALSE",
      tenantExample?.module_forms ? "TRUE" : "FALSE",
      tenantExample?.module_malfunctions ? "TRUE" : "FALSE",
      tenantExample?.module_transfers ? "TRUE" : "FALSE",
      tenantExample?.module_performance ? "TRUE" : "FALSE",
      tenantExample?.module_payroll ? "TRUE" : "FALSE",
    ],
  ]);

  const modulesSheet = utils.aoa_to_sheet([
    [...MODULE_HEADERS],
    ...modulesExample.map((row) => [row.module_code, row.is_enabled ? "TRUE" : "FALSE", row.enabled_by_email ?? ""]),
  ]);

  utils.book_append_sheet(workbook, tenantSheet, TENANT_SHEET_NAME);
  utils.book_append_sheet(workbook, modulesSheet, MODULES_SHEET_NAME);

  return workbook;
}

type Props = {
  showHeader?: boolean;
  tenantHint?: string;
};

export function TenantImportUploader({ showHeader = true, tenantHint }: Props) {
  const [state, setState] = useState<ImportState>({ status: "idle" });
  const [selectedFileName, setSelectedFileName] = useState<string | null>(null);
  const [availableModules, setAvailableModules] = useState<AvailableModule[]>([]);
  const [modulesLoadError, setModulesLoadError] = useState<string | null>(null);
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

  useEffect(() => {
    let isCancelled = false;

    async function loadModules() {
      try {
        const response = await fetch("/api/modules/list");
        const data = (await response.json()) as AvailableModule[] | { message?: string };
        if (isCancelled) return;
        if (Array.isArray(data) && data.length > 0) {
          setAvailableModules(data);
          setModulesLoadError(null);
        } else {
          setAvailableModules([]);
          setModulesLoadError("Modül listesi alınamadı, şablon varsayılan örnekle indirilecek.");
        }
      } catch (error) {
        console.error("modules list fetch error", error);
        if (isCancelled) return;
        setModulesLoadError("Modül listesi alınamadı, şablon varsayılan örnekle indirilecek.");
        setAvailableModules([]);
      }
    }

    loadModules();

    return () => {
      isCancelled = true;
    };
  }, []);

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
      console.error("Tenant import parse error", error);
      setState({
        status: "error",
        message: error instanceof Error ? error.message : "Dosya okunamadı",
      });
    }
  };

  const handleDownloadTemplate = async () => {
    const moduleRows = availableModules.map((m) => ({ module_code: m.module_code, is_enabled: true, enabled_by_email: "" }));

    const workbook = buildTemplateWorkbook(moduleRows);
    const buffer = write(workbook, { type: "array", bookType: "xlsx" });
    const blob = new Blob([buffer], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "tenant-import-template.xlsx";
    link.click();
    URL.revokeObjectURL(url);
  };

  const handleImport = async () => {
    if (state.status !== "parsed") {
      return;
    }

    setState({ status: "importing", payload: state.payload });
    startProgress();

    const response = await fetch("/api/tenants/import", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(state.payload),
    });

    if (!response.ok) {
      const body = await response.json().catch(() => ({ message: "Bilinmeyen hata" }));
      stopProgress(0);
      setState({ status: "error", message: body.message ?? "Firma import edilirken hata oluştu" });
      return;
    }

    const result = (await response.json()) as { tenantCode: string };
    setState({ status: "success", tenantCode: result.tenantCode });
    setSelectedFileName(null);
    stopProgress(100);
    setTimeout(() => stopProgress(0), 400);
  };

  return (
    <div className="tenant-import">
      {showHeader ? (
        <header className="page-header">
          <h2>Yeni Firma İçe Aktarma</h2>
          <p>Şablonu indirip doldurduktan sonra yükleyin. Dosya kontrolünden sonra firma ve modüller otomatik oluşturulur.</p>
        </header>
      ) : null}

      <div className="card">
        <h3>Şablon açıklamaları</h3>
        <p>TRUE/FALSE alanları için açık/kapalı seçimi yapın. Boole dışı değerler reddedilir.</p>
        {availableModules.length > 0 ? (
          <p>Şu anda sistemde kayıtlı modül kodları: {availableModules.map((m) => m.module_code).join(", ")}</p>
        ) : modulesLoadError ? (
          <p className="alert alert-error">{modulesLoadError}</p>
        ) : (
          <p>Modül listesi yükleniyor...</p>
        )}
        {availableModules.length === 0 ? (
          <p>Modules sayfasını indirilen şablonda doğru kodlarla kendin doldurmalısın; yanlış kodla import hata verir.</p>
        ) : null}
        <div className="tenant-import__help">
          <div>
            <strong>Tenant sayfası</strong>
            <ul>
              {TENANT_FIELD_HELP.map((item) => (
                <li key={item.key}>
                  <span>{item.key}:</span> {item.text}
                </li>
              ))}
            </ul>
          </div>
          <div>
            <strong>Modules sayfası</strong>
            <ul>
              {MODULE_FIELD_HELP.map((item) => (
                <li key={item.key}>
                  <span>{item.key}:</span> {item.text}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>

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
          <p className="alert alert-success">{state.tenantCode} kodlu firma oluşturuldu.</p>
        ) : null}
        {progress > 0 ? (
          <div className="progress">
            <div className="progress__bar" style={{ width: `${progress}%` }} />
            <span className="progress__label">%{Math.round(progress)}</span>
          </div>
        ) : null}
      </div>

      {preview ? (
        <div className="card">
          <h3>Önizleme</h3>
          <div className="tenant-preview-wrapper">
            <div className="tenant-preview">
              <div>
                <strong>Firma</strong>
                <p>Kod: {preview.tenant.code}</p>
                <p>Ad: {preview.tenant.name}</p>
                <p>Aktif: {preview.tenant.is_active ? "Evet" : "Hayır"}</p>
                {preview.tenant.logo_url ? <p>Logo: {preview.tenant.logo_url}</p> : null}
                <p>SAP Entegrasyonu: {preview.tenant.sap_integration_active ? "Açık" : "Kapalı"}</p>
                {preview.tenant.sap_api_url ? <p>SAP API URL: {preview.tenant.sap_api_url}</p> : null}
                {preview.tenant.sap_api_key ? <p>SAP API Key: (gizli)</p> : null}
                <p>Modül bayrakları:</p>
                <ul>
                  {Object.entries(preview.tenant.module_flags).map(([key, val]) => (
                    <li key={key}>
                      {key}: {val ? "Açık" : "Kapalı"}
                    </li>
                  ))}
                </ul>
              </div>
              <div>
                <strong>Modüller</strong>
                <ul>
                  {preview.modules.map((module) => (
                    <li key={module.module_code}>
                      {module.module_code} — {module.is_enabled ? "Aktif" : "Pasif"}
                      {module.enabled_by_email ? ` (by ${module.enabled_by_email})` : ""}
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
          <button
            type="button"
            className="primary"
            onClick={handleImport}
            disabled={state.status === "importing"}
          >
            {state.status === "importing" ? "İçe aktarılıyor..." : "Firmayı oluştur"}
          </button>
        </div>
      ) : null}
    </div>
  );
}
