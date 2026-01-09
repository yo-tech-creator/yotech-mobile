export const branchTemplateExample = {
  Branches: [
    {
      tenant_code: "ORNEK",
      branch_code: "ORK-0001",
      branch_name: "Ornek Market Ankara 1",
      region_code: "ANKARA-MERKEZ",
      city: "Ankara",
      is_active: true,
    },
  ],
  BranchModules: [
    { branch_code: "ORK-0001", module_code: "shift_management", is_enabled: true },
    { branch_code: "ORK-0001", module_code: "puantaj", is_enabled: false },
  ],
};

export const regionTemplateExample = {
  Regions: [
    {
      tenant_code: "ORNEK",
      region_code: "ANKARA-MERKEZ",
      region_name: "Ankara Merkez Bölgesi",
      is_active: true,
    },
  ],
};

export const staffTemplateExample = {
  Personnel: [
    {
      tenant_code: "FILEMARKET",
      sicil_no: "FM-1001",
      first_name: "Ayşe",
      last_name: "Yılmaz",
      email: "ayse.yilmaz@filemarket.com",
      phone: "+90 555 555 5511",
      branch_code: "ANK-0001",
      is_active: true,
    },
    {
      tenant_code: "FILEMARKET",
      sicil_no: "FM-2001",
      first_name: "Fatih",
      last_name: "Demir",
      email: "fatih.demir@filemarket.com",
      phone: "+90 555 555 5522",
      branch_code: "",
      is_active: true,
    },
  ],
  RoleAssignments: [
    { sicil_no: "FM-1001", role: "sube_muduru", scope_type: "branch", scope_code: "ANK-0001" },
    { sicil_no: "FM-1001", role: "firma_admin", scope_type: "tenant", scope_code: "FILEMARKET" },
    { sicil_no: "FM-2001", role: "bolge_muduru", scope_type: "region", scope_code: "ANKARA-MERKEZ" },
  ],
};

export const productsTemplateExample = {
  Products: [
    {
      tenant_code: "FILEMARKET",
      barcode: "8690000000000",
      name: "Chocolate Bar 50g",
      brand: "SweetCo",
      category: "Snacks",
      supplier: "SweetCo TR",
      unit: "adet",
      price: 12.5,
      alt_barcodes: "8690000000001,8690000000002",
      active: true,
    },
  ],
};

export const tenantTemplateExample = {
  Tenant: [
    {
      tenant_code: "ORNEK",
      tenant_name: "Örnek Firma",
      active: true,
      logo_url: "https://cdn.example.com/logos/filemarket.png",
      sap_integration_active: false,
      sap_api_url: "",
      sap_api_key: "",
      module_skt: true,
      module_tasks: true,
      module_attendance: true,
      module_shifts: true,
      module_forms: true,
      module_malfunctions: true,
      module_transfers: true,
      module_performance: true,
      module_payroll: true,
    },
  ],
  Modules: [
    { module_code: "tasks", is_enabled: true, enabled_by_email: "grandadmin@filemarket.com" },
    { module_code: "attendance", is_enabled: false, enabled_by_email: "" },
  ],
};
