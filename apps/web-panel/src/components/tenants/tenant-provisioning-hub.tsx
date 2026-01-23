"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Download, FileSpreadsheet, Layers3, Package } from "lucide-react";
import { utils, write } from "xlsx";
import { TenantImportUploader } from "@/components/tenants/tenant-import-uploader";
import { BranchImportUploader } from "@/components/tenants/branch-import-uploader";
import { RegionImportUploader } from "@/components/tenants/region-import-uploader";
import { StaffImportUploader } from "@/components/tenants/staff-import-uploader";
import { ProductImportUploader } from "@/components/tenants/product-import-uploader";
import { branchTemplateExample, productsTemplateExample, staffTemplateExample } from "@/components/tenants/templates";

type TabKey = "tenant" | "branches" | "products" | "staff";

type Props = {
  initialFocus?: string;
  tenantId?: string;
};

type TabDefinition = {
  key: TabKey;
  label: string;
  description: string;
};

const tabs: TabDefinition[] = [
  {
    key: "tenant",
    label: "Firma Kurulumu",
    description: "Tenant ve modül yetkilerini Excel ile içe aktarın.",
  },
  {
    key: "branches",
    label: "Şube Yapısı",
    description: "Şube detaylarını ve modül aktivasyonlarını hazırlayın.",
  },
  {
    key: "products",
    label: "Ürün Kataloğu",
    description: "Barkod ve alt barkod kurallarıyla ürün kataloğunu yükleyin.",
  },
  {
    key: "staff",
    label: "Personel & Yetkiler",
    description: "Kullanıcı profilleri ve rol kapsamlarını içe aktarın.",
  },
];

function downloadWorkbook(filename: string, workbook: ReturnType<typeof utils.book_new>) {
  const buffer = write(workbook, { type: "array", bookType: "xlsx" });
  const blob = new Blob([buffer], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

function BranchTemplateCard({ tenantId }: { tenantId?: string }) {
  const workbook = useMemo(() => {
    const wb = utils.book_new();
    const tenantCode = tenantId?.trim();
    const branchSheet = utils.aoa_to_sheet([
      ["tenant_code", "branch_code", "branch_name", "region_code", "city", "is_active"],
      ...branchTemplateExample.Branches.map((row) => [
        tenantCode ?? row.tenant_code,
        row.branch_code,
        row.branch_name,
        row.region_code,
        row.city,
        row.is_active ? "TRUE" : "FALSE",
      ]),
    ]);
    const moduleSheet = utils.aoa_to_sheet([
      ["branch_code", "module_code", "is_enabled"],
      ...branchTemplateExample.BranchModules.map((row) => [row.branch_code, row.module_code, row.is_enabled ? "TRUE" : "FALSE"]),
    ]);
    utils.book_append_sheet(wb, branchSheet, "Branches");
    utils.book_append_sheet(wb, moduleSheet, "BranchModules");
    return wb;
  }, [tenantId]);

  return (
    <div className="card">
      <header className="provisioning-card__header">
        <div>
          <h3>Şube Şablonu</h3>
          <p>Şube kayıtlarını, bölge kodlarını ve şube bazında aktif modülleri tanımlayın.</p>
        </div>
        <Download
          size={18}
          className="provisioning-card__download"
          onClick={() => downloadWorkbook("tenant-branches-template.xlsx", workbook)}
        />
      </header>
      <ul className="provisioning-checklist">
        <li>Branches sayfasında her satır bir şubeyi temsil eder.</li>
        <li>tenant_code alanı yeni oluşturulan firma kodu ile eşleşmelidir.</li>
        <li>Şube yüklemeden önce bölgeleri Region şablonu ile oluşturun veya region_code alanını boş bırakın.</li>
        <li>BranchModules sayfası şube bazlı modül açılışını tanımlar.</li>
        <li>{tenantId ? `Bu işlem ${tenantId} tenant kimliği için hazırlanıyor.` : "Şablona tenant ID notunu eklemeyi unutmayın."}</li>
      </ul>
      <p className="provisioning-note">Şablonu doldurduktan sonra aynı sekmeden yükleyerek şubeleri otomatik oluşturabilirsiniz.</p>
    </div>
  );
}

function StaffTemplateCard({ tenantId }: { tenantId?: string }) {
  const workbook = useMemo(() => {
    const wb = utils.book_new();
    const personnelSheet = utils.aoa_to_sheet([
      ["tenant_code", "sicil_no", "first_name", "last_name", "email", "phone", "branch_code", "is_active"],
      ...staffTemplateExample.Personnel.map((row) => [
        row.tenant_code,
        row.sicil_no,
        row.first_name,
        row.last_name,
        row.email,
        row.phone,
        row.branch_code,
        row.is_active ? "TRUE" : "FALSE",
      ]),
    ]);
    const rolesSheet = utils.aoa_to_sheet([
      ["sicil_no", "role", "scope_type", "scope_code"],
      ...staffTemplateExample.RoleAssignments.map((row) => [row.sicil_no, row.role, row.scope_type, row.scope_code]),
    ]);
    utils.book_append_sheet(wb, personnelSheet, "Personnel");
    utils.book_append_sheet(wb, rolesSheet, "RoleAssignments");
    return wb;
  }, []);

  return (
    <div className="card">
      <header className="provisioning-card__header">
        <div>
          <h3>Personel ve Yetki Şablonu</h3>
          <p>Kullanıcı kayıtlarını ve rol kapsamlarını tek dosyada yönetin.</p>
        </div>
        <Download
          size={18}
          className="provisioning-card__download"
          onClick={() => downloadWorkbook("tenant-staff-template.xlsx", workbook)}
        />
      </header>
      <ul className="provisioning-checklist">
        <li>Personnel sayfasında kullanıcıya ait temel bilgiler yer alır.</li>
        <li>RoleAssignments sayfası hangi rolün hangi kapsamda verileceğini tanımlar.</li>
        <li>Sicil numaraları benzersiz olmalı ve Supabase kullanıcıları ile eşleşmelidir.</li>
        <li>{tenantId ? `${tenantId} tenant kimliği için şablon hazırlıyorsunuz.` : "Tenant kodunu satırlara eklemeyi unutmayın."}</li>
      </ul>
      <p className="provisioning-note">
        Personel import API akışı hazırlanıyor. Şablonu doldurarak veri yapınızı önceden planlayabilirsiniz.
      </p>
    </div>
  );
}

function ProductTemplateCard({ tenantId }: { tenantId?: string }) {
  const workbook = useMemo(() => {
    const wb = utils.book_new();
    const tenantCode = tenantId?.trim() || productsTemplateExample.Products[0].tenant_code;
    const productSheet = utils.aoa_to_sheet([
      ["tenant_code", "barcode", "name", "brand", "category", "supplier", "unit", "price", "alt_barcodes", "active"],
      ...productsTemplateExample.Products.map((row) => [
        tenantCode,
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
    utils.book_append_sheet(wb, productSheet, "Products");
    return wb;
  }, [tenantId]);

  return (
    <div className="card">
      <header className="provisioning-card__header">
        <div>
          <h3>Ürün Şablonu</h3>
          <p>Firma kataloglarını barkod/alt barkod kurallarıyla hazırlayın.</p>
        </div>
        <Download
          size={18}
          className="provisioning-card__download"
          onClick={() => downloadWorkbook("tenant-products-template.xlsx", workbook)}
        />
      </header>
      <ul className="provisioning-checklist">
        <li>tenant_code tüm satırlarda hedef firma kodu ile eşleşmeli.</li>
        <li>barcode benzersiz olmalı; alt_barcodes en fazla 10 değer, ana barkodla aynı olamaz.</li>
        <li>brand/category/supplier/unit opsiyonel; unit boşsa adet kabul edilir.</li>
        <li>price opsiyonel numerik; active true/false ile ürün durumu belirlenir.</li>
        <li>{tenantId ? `${tenantId} için şablon oluşturuldu.` : "Tenant kodunu doldurmayı unutmayın."}</li>
      </ul>
      <p className="provisioning-note">Şablonu doldurup Ürün İçe Aktarma sekmesinden yükleyebilirsiniz.</p>
    </div>
  );
}

export function TenantProvisioningHub({ initialFocus, tenantId }: Props) {
  const router = useRouter();
  const resolvedFocus = (initialFocus as TabKey) ?? "tenant";
  const [activeTab, setActiveTab] = useState<TabKey>(tabs.find((tab) => tab.key === resolvedFocus)?.key ?? "tenant");

  const handleTabChange = (next: TabKey) => {
    setActiveTab(next);
    const search = new URLSearchParams();
    search.set("focus", next);
    if (tenantId) {
      search.set("tenantId", tenantId);
    }
    router.replace(`/tenants/import?${search.toString()}`);
  };

  const description = tabs.find((tab) => tab.key === activeTab)?.description ?? "";

  return (
    <div className="tenant-provisioning">
      <header className="page-header">
        <h2>Tenant Kurulum Merkezi</h2>
        <p>
          Yeni bir firmayı canlıya almadan önce gerekli tüm veri setlerini hazırlayın. Her sekme farklı bir Excel şablonu
          sağlar ve Supabase seed süreçlerine temel oluşturur.
        </p>
      </header>

      <nav className="provisioning-tabs" aria-label="İçe aktarma seçenekleri">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            type="button"
            className={activeTab === tab.key ? "provisioning-tab active" : "provisioning-tab"}
            onClick={() => handleTabChange(tab.key)}
          >
            <FileSpreadsheet size={18} />
            <span>
              <strong>{tab.label}</strong>
              <small>{tab.description}</small>
            </span>
          </button>
        ))}
      </nav>

      <section className="provisioning-content">
        {activeTab === "tenant" ? (
          <div className="card">
            <header className="provisioning-card__header">
              <div>
                <h3>Firma ve Modül Kurulumu</h3>
                <p>{description}</p>
              </div>
              <Layers3 size={18} className="provisioning-card__icon" />
            </header>
            <TenantImportUploader showHeader={false} tenantHint={tenantId} />
          </div>
        ) : null}

        {activeTab === "branches" ? (
          <>
            <RegionImportUploader tenantHint={tenantId} />
            <BranchImportUploader tenantHint={tenantId} />
            <BranchTemplateCard tenantId={tenantId} />
          </>
        ) : null}

        {activeTab === "products" ? (
          <>
            <div className="card">
              <header className="provisioning-card__header">
                <div>
                  <h3>Ürün Kataloğu</h3>
                  <p>{description}</p>
                </div>
                <Package size={18} className="provisioning-card__icon" />
              </header>
              <ProductImportUploader showHeader={false} tenantHint={tenantId} />
            </div>
            <ProductTemplateCard tenantId={tenantId} />
          </>
        ) : null}

        {activeTab === "staff" ? (
          <>
            <StaffImportUploader tenantHint={tenantId} />
            <StaffTemplateCard tenantId={tenantId} />
          </>
        ) : null}
      </section>
    </div>
  );
}
