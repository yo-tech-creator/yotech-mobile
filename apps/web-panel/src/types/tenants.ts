export type TenantSummary = {
  id: string;
  code: string;
  name: string;
  is_active: boolean;
  total_users: number;
  active_modules: number;
};

export type TenantModule = {
  module_code: string;
  module_name: string;
  module_icon: string | null;
  module_description: string | null;
  is_core: boolean;
  is_enabled: boolean;
  enabled_at: string | null;
};
