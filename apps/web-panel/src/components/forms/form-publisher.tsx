
"use client";

import { useEffect, useMemo, useState, type CSSProperties } from "react";
import { useRouter } from "next/navigation";
import { read, utils, writeFileXLSX } from "xlsx";

export type TenantOption = { id: string; name: string; code?: string | null };
export type AllowedRole = "grand_admin" | "firma_admin" | "bolge_muduru" | "sube_muduru";

type ParsedRow = {
  question: string;
  hasBinaryChoice: boolean;
  allowComment: boolean;
  score: number;
  rowNumber: number;
};

export type PublishedForm = {
  tenant_id: string | null;
  form_id: string;
  form_version_id: string;
  code: string;
  title: string;
  description: string | null;
  version: number;
  sections: Array<{ title?: string; items?: any[] }>;
  published_at?: string | null;
  tenant?: string | null;
  visible_roles?: string[] | null;
};

type Props = {
  role: AllowedRole;
  tenants: TenantOption[];
  initialTenantId?: string | null;
  initialForm?: PublishedForm | null;
};

function normalizeBoolean(value: unknown, fallback: boolean): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (["1", "true", "evet", "yes", "y"].includes(normalized)) return true;
    if (["0", "false", "hayir", "no", "n"].includes(normalized)) return false;
  }
  return fallback;
}

function slugify(input: string): string {
  return input
    .normalize("NFKD")
    .replace(/[^a-zA-Z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .toUpperCase();
}

function flattenFormItems(form: PublishedForm): ParsedRow[] {
  const list: ParsedRow[] = [];
  form.sections?.forEach((section) => {
    (section.items ?? []).forEach((item) => {
      const metadata = (item?.metadata as Record<string, any> | undefined) ?? {};
      const allowComment =
        typeof metadata.allowComment === "boolean"
          ? metadata.allowComment
          : typeof metadata.allow_comment === "boolean"
            ? metadata.allow_comment
            : false;
      const hasBinaryChoice =
        typeof metadata.hasBinaryChoice === "boolean"
          ? metadata.hasBinaryChoice
          : typeof metadata.has_binary_choice === "boolean"
            ? metadata.has_binary_choice
            : (item?.negativePoints ?? item?.negative_points ?? 0) > 0;
      const scoreRaw = Number(metadata.score ?? metadata.Score ?? item?.positivePoints ?? item?.positive_points ?? 1);
      const score = Number.isFinite(scoreRaw) && scoreRaw > 0 ? Number(scoreRaw) : 1;
      const question = (item?.label ?? item?.question ?? "").toString().trim();
      if (!question) return;
      list.push({
        question,
        hasBinaryChoice,
        allowComment,
        score,
        rowNumber: list.length + 1,
      });
    });
  });
  return list;
}

export function FormPublisher({ role, tenants, initialTenantId, initialForm }: Props) {
  const router = useRouter();
  const gridStyle: CSSProperties = {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))",
    gap: "16px",
    alignItems: "start",
  };

  const fieldStyle: CSSProperties = {
    display: "flex",
    flexDirection: "column",
    gap: "6px",
    fontWeight: 600,
  };

  const inputStyle: CSSProperties = {
    border: "1px solid var(--card-border)",
    borderRadius: "12px",
    padding: "12px 14px",
    fontWeight: 500,
    background: "var(--card-bg)",
    color: "var(--text)",
    width: "100%",
    minHeight: 44,
  };

  const textAreaStyle: CSSProperties = {
    ...inputStyle,
    minHeight: 64,
    resize: "vertical",
  };

  const roleHierarchy: AllowedRole[] = ["grand_admin", "firma_admin", "bolge_muduru", "sube_muduru"];

  function upperRoles(current: AllowedRole): string[] {
    const idx = roleHierarchy.indexOf(current);
    return idx >= 0 ? roleHierarchy.slice(0, idx + 1) : [];
  }

  function lowerRoles(current: AllowedRole): string[] {
    const idx = roleHierarchy.indexOf(current);
    const below = idx >= 0 ? roleHierarchy.slice(idx + 1) : [];
    // personel her zaman en alttaki sınıf
    return Array.from(new Set([...below, "personel"]));
  }

  function defaultVisibleRoles(current: AllowedRole): string[] {
    const auto = upperRoles(current);
    const selectable = lowerRoles(current);
    return Array.from(new Set([...auto, ...selectable]));
  }

  function normalizeVisibleRoles(current: AllowedRole, roles?: string[] | null): string[] {
    const base = Array.isArray(roles) && roles.length > 0 ? roles.filter(Boolean) : defaultVisibleRoles(current);
    const mustInclude = upperRoles(current);
    return Array.from(new Set([...base, ...mustInclude]));
  }

  const roleOptions = [
    { value: "grand_admin", label: "Grand Admin" },
    { value: "firma_admin", label: "Firma Admini" },
    { value: "bolge_muduru", label: "Bölge Müdürü" },
    { value: "sube_muduru", label: "Şube Müdürü" },
    { value: "personel", label: "Personel" },
  ];

  const [tenantId, setTenantId] = useState<string>(initialTenantId ?? tenants[0]?.id ?? "");
  const [tenantScope, setTenantScope] = useState<"all" | "single">("all");
  const [title, setTitle] = useState<string>("Yeni Form");
  const [code, setCode] = useState<string>("");
  const [description, setDescription] = useState<string>("");
  const [visibleRoles, setVisibleRoles] = useState<string[]>(defaultVisibleRoles(role));
  const [rows, setRows] = useState<ParsedRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const tenantOptions = useMemo(() => tenants, [tenants]);
  const selectableRoles = useMemo(() => lowerRoles(role), [role]);
  const autoRoles = useMemo(() => upperRoles(role), [role]);

  function loadExistingForm(form: PublishedForm) {
    const flattened = flattenFormItems(form);
    setTenantScope(form.tenant_id ? "single" : "all");
    setTenantId(form.tenant_id || tenantId || "");
    setTitle(form.title || "");
    setCode(form.code || "");
    setDescription(form.description || "");
    setVisibleRoles(normalizeVisibleRoles(role as AllowedRole, form.visible_roles ?? undefined));
    setRows(flattened);
    setMessage(`Form yüklendi (${form.title} v${form.version}). Düzenleyip yeniden yayınlayın.`);
    setError(null);
  }

  useEffect(() => {
    if (initialForm) {
      loadExistingForm(initialForm);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialForm?.form_version_id]);

  function addEmptyRow() {
    setRows((prev) => [
      ...prev,
      {
        question: "",
        hasBinaryChoice: true,
        allowComment: false,
        score: 1,
        rowNumber: prev.length + 1,
      },
    ]);
  }

  function updateRow(index: number, patch: Partial<ParsedRow>) {
    setRows((prev) =>
      prev.map((row, i) =>
        i === index
          ? {
              ...row,
              ...patch,
              rowNumber: row.rowNumber,
            }
          : row,
      ),
    );
  }

  function removeRow(index: number) {
    setRows((prev) => prev.filter((_, i) => i !== index).map((row, i) => ({ ...row, rowNumber: i + 1 })));
  }

  function handleTemplateDownload() {
    const workbook = utils.book_new();
    const sheet = utils.aoa_to_sheet([
      ["Form Sorusu", "Olumlu/Olumsuz", "Puan", "Aciklama"],
      ["Magaza giris temizligi", "TRUE", 1, "FALSE"],
      ["Personel teshir duzeni", "TRUE", 1, "TRUE"],
    ]);
    utils.book_append_sheet(workbook, sheet, "Form");
    writeFileXLSX(workbook, "form_sablon.xlsx");
  }

  async function handleFileChange(file: File | null) {
    if (!file) return;
    setError(null);
    setMessage(null);
    try {
      const buffer = await file.arrayBuffer();
      const workbook = read(buffer, { type: "array" });
      const firstSheet = workbook.SheetNames[0];
      const sheet = workbook.Sheets[firstSheet];
      const json = utils.sheet_to_json(sheet, {
        header: ["question", "hasBinaryChoice", "score", "allowComment"],
        range: 1,
        defval: "",
      }) as Array<{ question?: unknown; hasBinaryChoice?: unknown; score?: unknown; allowComment?: unknown }>;

      const parsed: ParsedRow[] = json
        .map((row, index) => {
          const question = (row.question ?? "").toString().trim();
          if (!question) return null;
          const rawScore = Number(row.score);
          const score = Number.isFinite(rawScore) && rawScore > 0 ? Number(rawScore) : 1;
          return {
            question,
            hasBinaryChoice: normalizeBoolean(row.hasBinaryChoice, true),
            allowComment: normalizeBoolean(row.allowComment, false),
            score,
            rowNumber: index + 2,
          };
        })
        .filter(Boolean) as ParsedRow[];

      setRows(parsed);
      if (parsed.length === 0) {
        setError("Geçerli soru bulunamadı. İlk satır başlık olmalı, sonrakiler dolu olmalı.");
      }
    } catch (err) {
      console.error("excel parse error", err);
      setError("Excel okunamadı. XLSX şablonunu kullanın.");
    }
  }

  async function handlePublish() {
    if (tenantScope === "single" && !tenantId) {
      setError("Firma seçmelisiniz.");
      return;
    }
    if (rows.length === 0) {
      setError("Yüklü soru yok. Önce şablonu doldurup yükleyin.");
      return;
    }

    setLoading(true);
    setError(null);
    setMessage(null);

    const selectableSet = new Set(selectableRoles);
    const autoSet = new Set(autoRoles);
    const selected = visibleRoles.filter((r) => selectableSet.has(r) || autoSet.has(r));
    const merged = Array.from(new Set([...selected, ...autoRoles]));

    const payload = {
      tenantId: tenantScope === "all" ? "__ALL__" : tenantId,
      title: title.trim() || "Yeni Form",
      code: slugify(code.trim() || title),
      description: description.trim(),
      visibleRoles: merged,
      items: rows,
    };

    const response = await fetch("/api/forms/publish", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    const result = await response.json().catch(() => null);

    if (!response.ok) {
      setError(result?.message || "Form yayınlanamadı");
      setLoading(false);
      return;
    }

    setMessage(`Form yayınlandı (versiyon ${result?.version ?? "?"})`);
    setLoading(false);
  }

  async function handleDelete() {
    if (!initialForm?.form_version_id) {
      setError("Silinecek form bulunamadı.");
      return;
    }

    const confirmed = window.confirm("Formu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.");
    if (!confirmed) return;

    setDeleting(true);
    setError(null);
    setMessage(null);

    const response = await fetch("/api/forms/delete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ formVersionId: initialForm.form_version_id }),
    });

    const result = await response.json().catch(() => null);

    if (!response.ok) {
      setError(result?.message || "Form silinemedi");
      setDeleting(false);
      return;
    }

    setMessage("Form silindi.");
    setRows([]);
    setTitle("Yeni Form");
    setCode("");
    setDescription("");
    setDeleting(false);
    router.push("/forms/published");
  }

  return (
    <div className="card" style={{ display: "flex", flexDirection: "column", gap: "18px" }}>
      <div style={gridStyle}>
        {role === "grand_admin" ? (
          <div style={{ ...fieldStyle, gap: "10px" }}>
            <span>Firma</span>
            <div style={{ display: "flex", gap: "12px", flexWrap: "wrap" }}>
              <label style={{ display: "flex", alignItems: "center", gap: 6 }}>
                <input
                  type="radio"
                  name="tenantScope"
                  value="all"
                  checked={tenantScope === "all"}
                  onChange={() => {
                    setTenantScope("all");
                    setTenantId("__ALL__");
                  }}
                />
                <span>Tüm firmalar</span>
              </label>
              <label style={{ display: "flex", alignItems: "center", gap: 6 }}>
                <input
                  type="radio"
                  name="tenantScope"
                  value="single"
                  checked={tenantScope === "single"}
                  onChange={() => {
                    setTenantScope("single");
                    setTenantId(tenantOptions[0]?.id ?? "");
                  }}
                />
                <span>Tek firma seç</span>
              </label>
            </div>
            {tenantScope === "single" ? (
              <select
                style={{ ...inputStyle, appearance: "none", backgroundImage: "linear-gradient(135deg, #1e293b, #0f172a)" }}
                value={tenantId || ""}
                onChange={(e) => setTenantId(e.target.value)}
                disabled={tenantOptions.length === 0}
              >
                {tenantOptions.map((tenant) => (
                  <option key={tenant.id} value={tenant.id}>
                    {tenant.name} {tenant.code ? `(${tenant.code})` : ""}
                  </option>
                ))}
                {tenantOptions.length === 0 && <option value="" disabled>Tanımlı firma yok</option>}
              </select>
            ) : null}
          </div>
        ) : (
          <div style={fieldStyle}>
            <span>Firma</span>
            <div
              className="pill"
              style={{
                padding: "12px 14px",
                borderRadius: "12px",
                border: "1px solid var(--card-border)",
                background: "var(--card-bg)",
                minHeight: 44,
                display: "flex",
                alignItems: "center",
              }}
            >
              {tenantOptions[0]?.name ?? ""}
            </div>
          </div>
        )}

        <label style={fieldStyle}>
          <span>Form Başlığı</span>
          <input
            style={inputStyle}
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Örn. Mağaza Genel Kontrol"
          />
        </label>

        <label style={fieldStyle}>
          <span>Form Kodu (opsiyonel)</span>
          <input
            style={inputStyle}
            value={code}
            onChange={(e) => setCode(e.target.value)}
            onBlur={(e) => setCode(slugify(e.target.value || title))}
            placeholder="MAĞAZA_KONTROL"
          />
        </label>

        <label style={{ ...fieldStyle, gridColumn: "1 / -1" }}>
          <span>Açıklama</span>
          <textarea
            style={textAreaStyle}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={2}
            placeholder="Form açıklaması"
          />
        </label>

        <div style={{ ...fieldStyle, gridColumn: "1 / -1", gap: "10px" }}>
          <span>Kimler görebilir?</span>
          {selectableRoles.length === 0 ? (
            <div className="muted">Bu rol için alt sınıf seçimi yok. Form otomatik olarak üst rollere ve personele görünür.</div>
          ) : (
            <>
              <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
                {roleOptions
                  .filter((opt) => selectableRoles.includes(opt.value))
                  .map((opt) => {
                    const checked = visibleRoles.includes(opt.value);
                    return (
                      <label
                        key={opt.value}
                        style={{
                          display: "flex",
                          alignItems: "center",
                          gap: 8,
                          padding: "6px 10px",
                          border: "1px solid var(--card-border)",
                          borderRadius: 10,
                          background: checked ? "var(--card-bg-strong)" : "var(--card-bg)",
                        }}
                      >
                        <input
                          type="checkbox"
                          checked={checked}
                          onChange={(e) => {
                            const isChecked = e.target.checked;
                            setVisibleRoles((prev) => {
                              if (isChecked) {
                                return Array.from(new Set([...prev, opt.value]));
                              }
                              return prev.filter((r) => r !== opt.value);
                            });
                          }}
                        />
                        <span>{opt.label}</span>
                      </label>
                    );
                  })}
              </div>
              <div className="muted">Seçili alt roller + otomatik üst roller formu görebilir.</div>
            </>
          )}
        </div>
      </div>

      <div className="upload-row">
        <div>
          <div className="muted">Excel şablonu: A soru, B olumlu/olumsuz (TRUE/FALSE), C puan (sayı), D açıklama (TRUE/FALSE)</div>
          <div className="muted">İlk satır başlık olmalı. 1000 satıra kadar desteklenir. Puan boş veya geçersizse 1 kabul edilir.</div>
        </div>
        <div className="button-row" style={{ gap: "10px" }}>
          <label
            className="button button--primary"
            style={{ cursor: "pointer", paddingInline: 18, boxShadow: "0 12px 24px -12px rgba(37, 99, 235, 0.55)" }}
          >
            Excel yükle
            <input type="file" accept=".xlsx" style={{ display: "none" }} onChange={(e) => handleFileChange(e.target.files?.[0] ?? null)} />
          </label>
          <button type="button" className="button" onClick={handleTemplateDownload}>
            Şablonu indir
          </button>
        </div>
      </div>

      {rows.length > 0 && (
        <div className="table-wrapper">
          <div className="table-header">Önizleme / Düzenleme ({rows.length} satır)</div>
          <table className="table">
            <thead>
              <tr>
                <th>#</th>
                <th>Soru</th>
                <th>Olumlu/Olumsuz</th>
                <th>Puan</th>
                <th>Açıklama</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.rowNumber}>
                  <td>{row.rowNumber}</td>
                  <td>
                    <input
                      style={{ width: "100%" }}
                      value={row.question}
                      onChange={(e) => updateRow(row.rowNumber - 1, { question: e.target.value })}
                      placeholder="Soru"
                    />
                  </td>
                  <td style={{ textAlign: "center" }}>
                    <input
                      type="checkbox"
                      checked={row.hasBinaryChoice}
                      onChange={(e) => updateRow(row.rowNumber - 1, { hasBinaryChoice: e.target.checked })}
                    />
                  </td>
                  <td style={{ width: 120 }}>
                    <input
                      type="number"
                      min={0}
                      step={0.5}
                      value={row.score}
                      onChange={(e) => {
                        const next = Number(e.target.value);
                        updateRow(row.rowNumber - 1, { score: Number.isFinite(next) && next > 0 ? next : 1 });
                      }}
                      style={{ width: "100%" }}
                    />
                  </td>
                  <td style={{ textAlign: "center" }}>
                    <input
                      type="checkbox"
                      checked={row.allowComment}
                      onChange={(e) => updateRow(row.rowNumber - 1, { allowComment: e.target.checked })}
                    />
                  </td>
                  <td>
                    <button type="button" className="button" onClick={() => removeRow(row.rowNumber - 1)}>
                      Sil
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div style={{ marginTop: 12 }}>
            <button type="button" className="button" onClick={addEmptyRow}>
              Yeni madde ekle
            </button>
          </div>
        </div>
      )}

      {error && <div className="alert alert--error">{error}</div>}
      {message && <div className="alert alert--success">{message}</div>}

      <div className="action-row">
        <button type="button" className="button button--primary" onClick={handlePublish} disabled={loading}>
          {loading ? "Yükleniyor..." : "Formu Yayınla"}
        </button>
        {initialForm ? (
          <button type="button" className="button" onClick={handleDelete} disabled={deleting || loading}>
            {deleting ? "Siliniyor..." : "Formu Sil"}
          </button>
        ) : null}
      </div>
    </div>
  );
}
