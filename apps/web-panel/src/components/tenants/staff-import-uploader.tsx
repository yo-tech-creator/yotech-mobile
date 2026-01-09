"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import type { ChangeEvent } from "react";
import { read, utils, write } from "xlsx";
import { normaliseBoolean } from "@/lib/xlsx/normalisers";
import { staffTemplateExample } from "@/components/tenants/templates";

const PERSONNEL_SHEET = "Personnel";
const ROLE_SHEET = "RoleAssignments";

const PERSONNEL_HEADERS = [
  "tenant_code",
  "sicil_no",
  "first_name",
  "last_name",
  "email",
  "phone",
  "branch_code",
  "is_active",
] as const;

const ROLE_HEADERS = ["sicil_no", "role", "scope_type", "scope_code"] as const;

type PersonnelRow = {
  tenant_code?: string | number | null;
  sicil_no?: string | number | null;
  first_name?: string | null;
  last_name?: string | null;
  email?: string | null;
  phone?: string | null;
  branch_code?: string | number | null;
  is_active?: boolean | string | number | null;
};

type RoleRow = {
  sicil_no?: string | number | null;
  role?: string | null;
  scope_type?: string | null;
  scope_code?: string | number | null;
};

type PersonnelDefinition = {
  tenant_code: string;
  sicil_no: string;
  first_name: string;
  last_name: string;
  email: string | null;
  phone: string | null;
  branch_code: string | null;
  is_active: boolean;
};

type RoleAssignment = {
  sicil_no: string;
  role: string;
  scope_type: "tenant" | "branch" | "region";
  scope_code: string;
};

type StaffImportPayload = {
  tenantCode: string;
  personnel: PersonnelDefinition[];
  roleAssignments: RoleAssignment[];
};

type ImportState =
  | { status: "idle" }
  | { status: "parsing" }
  | { status: "parsed"; payload: StaffImportPayload }
  | { status: "error"; message: string }
  | { status: "importing"; payload: StaffImportPayload }
  | { status: "success"; tenantCode: string; personnelCount: number };

function isEmptyRow(row: Record<string, unknown>): boolean {
  return Object.values(row).every((value) => value === null || value === undefined || value === "");
}

async function parseWorkbook(file: File): Promise<StaffImportPayload> {
  const buffer = await file.arrayBuffer();
  const workbook = read(buffer, { type: "array" });

  const personnelSheet = workbook.Sheets[PERSONNEL_SHEET];
  if (!personnelSheet) {
    throw new Error(`${PERSONNEL_SHEET} sayfası bulunamadı. Şablondaki sekme adını değiştirmeyin.`);
  }

  const personnelRows = utils.sheet_to_json<PersonnelRow>(personnelSheet, {
    header: [...PERSONNEL_HEADERS],
    range: 1,
    defval: null,
  });

  const roleSheet = workbook.Sheets[ROLE_SHEET];
  const roleRows = roleSheet
    ? utils.sheet_to_json<RoleRow>(roleSheet, { header: [...ROLE_HEADERS], range: 1, defval: null })
    : [];

  const tenantCodes = new Set<string>();
  const sicilCodes = new Set<string>();
  const personnel: PersonnelDefinition[] = [];

  personnelRows.forEach((row, index) => {
    if (isEmptyRow(row)) {
      return;
    }
    const rowNumber = index + 2;
    const tenantCodeRaw = row.tenant_code;
    const sicilRaw = row.sicil_no;
    const firstNameRaw = row.first_name;
    const lastNameRaw = row.last_name;

    if (!tenantCodeRaw || !sicilRaw || !firstNameRaw || !lastNameRaw) {
      throw new Error(
        `${PERSONNEL_SHEET} sayfasındaki ${rowNumber}. satırda tenant_code, sicil_no, first_name ve last_name zorunlu`,
      );
    }

    const tenantCode = String(tenantCodeRaw).trim();
    const sicil = String(sicilRaw).trim().toUpperCase();
    const firstName = String(firstNameRaw).trim();
    const lastName = String(lastNameRaw).trim();

    if (!tenantCode || !sicil || !firstName || !lastName) {
      throw new Error(`${PERSONNEL_SHEET} sayfasındaki ${rowNumber}. satırda boş değer bırakılamaz`);
    }

    if (sicilCodes.has(sicil)) {
      throw new Error(`${PERSONNEL_SHEET} sayfasında tekrarlanan sicil_no bulundu: ${sicil}`);
    }

    sicilCodes.add(sicil);
    tenantCodes.add(tenantCode);

    const email = row.email ? String(row.email).trim() : null;
    const phone = row.phone ? String(row.phone).trim() : null;
    const branchCode = row.branch_code ? String(row.branch_code).trim().toUpperCase() : null;
    const isActive = normaliseBoolean(row.is_active ?? true);
    if (isActive === null) {
      throw new Error(`${sicil} satırında is_active true/false olmalıdır`);
    }

    personnel.push({
      tenant_code: tenantCode,
      sicil_no: sicil,
      first_name: firstName,
      last_name: lastName,
      email: email && email.length > 0 ? email : null,
      phone: phone && phone.length > 0 ? phone : null,
      branch_code: branchCode && branchCode.length > 0 ? branchCode : null,
      is_active: isActive,
    });
  });

  if (personnel.length === 0) {
    throw new Error(`${PERSONNEL_SHEET} sayfasında en az bir personel satırı olmalı`);
  }

  if (tenantCodes.size === 0) {
    throw new Error(`${PERSONNEL_SHEET} sayfasında tenant_code eksik`);
  }

  if (tenantCodes.size > 1) {
    throw new Error(`${PERSONNEL_SHEET} sayfasında birden fazla tenant_code bulundu: ${Array.from(tenantCodes).join(", ")}`);
  }

  const [tenantCode] = Array.from(tenantCodes);

  const roleAssignments: RoleAssignment[] = [];

  roleRows.forEach((row, index) => {
    if (isEmptyRow(row)) {
      return;
    }
    const rowNumber = index + 2;
    const sicilRaw = row.sicil_no;
    const roleRaw = row.role;
    const scopeTypeRaw = row.scope_type;
    const scopeCodeRaw = row.scope_code;

    if (!sicilRaw || !roleRaw || !scopeTypeRaw || !scopeCodeRaw) {
      throw new Error(`${ROLE_SHEET} sayfasındaki ${rowNumber}. satırda sicil_no, role, scope_type, scope_code zorunlu`);
    }

    const sicil = String(sicilRaw).trim().toUpperCase();
    const role = String(roleRaw).trim().toLowerCase();
    const scopeType = String(scopeTypeRaw).trim().toLowerCase();
    const scopeCode = String(scopeCodeRaw).trim().toUpperCase();

    if (scopeType !== "tenant" && scopeType !== "branch" && scopeType !== "region") {
      throw new Error(`${ROLE_SHEET} satır ${rowNumber}: scope_type tenant/branch/region olmalı`);
    }

    roleAssignments.push({ sicil_no: sicil, role, scope_type: scopeType as "tenant" | "branch" | "region", scope_code: scopeCode });
  });

  return {
    tenantCode,
    personnel,
    roleAssignments,
  };
}

function buildTemplateWorkbook(tenantCodeOverride?: string) {
  const workbook = utils.book_new();
  const tenantCode = tenantCodeOverride ? tenantCodeOverride.trim() : staffTemplateExample.Personnel[0].tenant_code;

  const personnelSheet = utils.aoa_to_sheet([
    [...PERSONNEL_HEADERS],
    ...staffTemplateExample.Personnel.map((row) => [
      tenantCode ?? "",
      row.sicil_no,
      row.first_name,
      row.last_name,
      row.email,
      row.phone,
      row.branch_code,
      row.is_active ? "TRUE" : "FALSE",
    ]),
  ]);

  const roleSheet = utils.aoa_to_sheet([
    [...ROLE_HEADERS],
    ...staffTemplateExample.RoleAssignments.map((row) => [row.sicil_no, row.role, row.scope_type, row.scope_code]),
  ]);

  utils.book_append_sheet(workbook, personnelSheet, PERSONNEL_SHEET);
  utils.book_append_sheet(workbook, roleSheet, ROLE_SHEET);

  return workbook;
}

type Props = {
  showHeader?: boolean;
  tenantHint?: string;
};

export function StaffImportUploader({ showHeader = true, tenantHint }: Props) {
  const [state, setState] = useState<ImportState>({ status: "idle" });
  const [selectedFileName, setSelectedFileName] = useState<string | null>(null);
  const [progress, setProgress] = useState<number>(0);
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

    if (!file) {
      setState({ status: "idle" });
      return;
    }

    setState({ status: "parsing" });

    try {
      const payload = await parseWorkbook(file);
      setState({ status: "parsed", payload });
    } catch (error) {
      console.error("Staff import parse error", error);
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
    link.download = "tenant-staff-template.xlsx";
    link.click();
    URL.revokeObjectURL(url);
  };

  const handleImport = async () => {
    if (state.status !== "parsed") {
      return;
    }

    setState({ status: "importing", payload: state.payload });
    startProgress();

    const response = await fetch("/api/tenants/import/staff", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(state.payload),
    });

    if (!response.ok) {
      const body = await response.json().catch(() => ({ message: "Bilinmeyen hata" }));
      stopProgress(0);
      setState({ status: "error", message: body.message ?? "Personel içe aktarılırken hata oluştu" });
      return;
    }

    const result = (await response.json()) as { tenantCode: string; personnelCount: number };
    setState({ status: "success", tenantCode: result.tenantCode, personnelCount: result.personnelCount });
    setSelectedFileName(null);
    stopProgress(100);
    setTimeout(() => stopProgress(0), 400);
  };

  return (
    <div className="tenant-import">
      {showHeader ? (
        <header className="page-header">
          <h3>Personel İçe Aktarma</h3>
          <p>Personel ve rol atamalarını Excel ile yükleyin. Sicil numarası benzersiz olmalıdır.</p>
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
            {state.tenantCode} kodlu firmaya {state.personnelCount} personel eklendi.
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
        <h3>Personel şablonu rehberi</h3>
        <ul>
          <li>Personnel.tenant_code: Hedef firma kodu; tüm satırlarda aynı olmalı.</li>
          <li>Personnel.sicil_no: Benzersiz personel/sicil kodu; girişte kullanılır.</li>
          <li>Personnel.first_name/last_name: Zorunlu ad/soyad.</li>
          <li>Personnel.email/phone: Opsiyonel; doluysa auth maili güncellenir.</li>
          <li>Personnel.branch_code: Opsiyonel; şube kodu Branches sayfası ile eşleşir.</li>
          <li>Personnel.is_active: true aktif kullanıcı; false pasif açılır.</li>
          <li>RoleAssignments: scope_type tenant/branch/region olabilir; scope_code ilgili firma/şube/bölge kodu olmalı.</li>
          <li>Bölge müdürü eklemek için role = bolge_muduru, scope_type = region, scope_code = bölge kodu satırı ekleyin.</li>
        </ul>
      </div>

      {preview ? (
        <div className="card">
          <h3>Önizleme</h3>
          <div className="tenant-preview-wrapper">
            <div className="tenant-preview">
              <div>
                <strong>Personel ({preview.personnel.length})</strong>
                <ul>
                  {preview.personnel.map((p) => (
                    <li key={p.sicil_no}>
                      {p.sicil_no} — {p.first_name} {p.last_name} {p.is_active ? "(Aktif)" : "(Pasif)"}
                      {p.branch_code ? ` · Şube: ${p.branch_code}` : ""}
                    </li>
                  ))}
                </ul>
              </div>
              {preview.roleAssignments.length > 0 ? (
                <div>
                  <strong>Rol Atamaları</strong>
                  <ul>
                    {preview.roleAssignments.map((r, idx) => (
                      <li key={`${r.sicil_no}-${idx}`}>
                        {r.sicil_no} → {r.role} ({r.scope_type}: {r.scope_code})
                      </li>
                    ))}
                  </ul>
                </div>
              ) : null}
            </div>
          </div>
          <button type="button" className="primary" onClick={handleImport} disabled={state.status === "importing"}>
            {state.status === "importing" ? "İçe aktarılıyor..." : "Personelleri oluştur"}
          </button>
        </div>
      ) : null}
    </div>
  );
}
