export type Database = {
  public: {
    Tables: {
      users: {
        Row: {
          id: string;
          role: string | null;
          tenant_id: string | null;
          first_name: string | null;
          last_name: string | null;
          email: string | null;
          phone: string | null;
          branch_id: string | null;
          employee_code: string | null;
          position: string | null;
          active?: boolean | null;
        };
        Insert: {
          id: string;
          role?: string | null;
          tenant_id?: string | null;
          first_name?: string | null;
          last_name?: string | null;
          email?: string | null;
          phone?: string | null;
          branch_id?: string | null;
          employee_code?: string | null;
          position?: string | null;
          active?: boolean | null;
        };
        Update: {
          id?: string;
          role?: string | null;
          tenant_id?: string | null;
          first_name?: string | null;
          last_name?: string | null;
          email?: string | null;
          phone?: string | null;
          branch_id?: string | null;
          employee_code?: string | null;
          position?: string | null;
          active?: boolean | null;
        };
        Relationships: [];
      };
      tenants: {
        Row: {
          id: string;
          code: string;
          name: string;
          active: boolean;
        };
        Insert: {
          id: string;
          code: string;
          name: string;
          active?: boolean;
        };
        Update: {
          id?: string;
          code?: string;
          name?: string;
          active?: boolean;
        };
        Relationships: [];
      };
      modules: {
        Row: {
          code: string;
          name: string;
          icon: string | null;
          description: string | null;
          is_core: boolean;
          active: boolean;
          display_order: number | null;
        };
        Insert: {
          code: string;
          name: string;
          icon?: string | null;
          description?: string | null;
          is_core?: boolean;
          active?: boolean;
          display_order?: number | null;
        };
        Update: {
          code?: string;
          name?: string;
          icon?: string | null;
          description?: string | null;
          is_core?: boolean;
          active?: boolean;
          display_order?: number | null;
        };
        Relationships: [];
      };
      tenant_modules: {
        Row: {
          tenant_id: string;
          module_code: string;
          is_enabled: boolean;
          enabled_at: string | null;
          enabled_by: string | null;
        };
        Insert: {
          tenant_id: string;
          module_code: string;
          is_enabled?: boolean;
          enabled_at?: string | null;
          enabled_by?: string | null;
        };
        Update: {
          tenant_id?: string;
          module_code?: string;
          is_enabled?: boolean;
          enabled_at?: string | null;
          enabled_by?: string | null;
        };
        Relationships: [];
      };
      branches: {
        Row: {
          id: string;
          tenant_id: string;
          region_id: string | null;
          name: string;
          code: string;
          address: string | null;
          city: string | null;
          district: string | null;
          latitude: number | null;
          longitude: number | null;
          geofence_radius: number | null;
          manager_id: string | null;
          active: boolean | null;
          created_at: string | null;
          updated_at: string | null;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          region_id?: string | null;
          name: string;
          code: string;
          address?: string | null;
          city?: string | null;
          district?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          geofence_radius?: number | null;
          manager_id?: string | null;
          active?: boolean | null;
          created_at?: string | null;
          updated_at?: string | null;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          region_id?: string | null;
          name?: string;
          code?: string;
          address?: string | null;
          city?: string | null;
          district?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          geofence_radius?: number | null;
          manager_id?: string | null;
          active?: boolean | null;
          created_at?: string | null;
          updated_at?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "branches_tenant_id_fkey";
            columns: ["tenant_id"];
            referencedRelation: "tenants";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "branches_region_id_fkey";
            columns: ["region_id"];
            referencedRelation: "regions";
            referencedColumns: ["id"];
          },
        ];
      };
      products: {
        Row: {
          id: string;
          tenant_id: string;
          barcode: string;
          name: string;
          brand: string | null;
          category: string | null;
          supplier: string | null;
          unit: string | null;
          price: number | null;
          active: boolean | null;
          alt_barcodes: string[] | null;
          created_at: string | null;
          updated_at: string | null;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          barcode: string;
          name: string;
          brand?: string | null;
          category?: string | null;
          supplier?: string | null;
          unit?: string | null;
          price?: number | null;
          active?: boolean | null;
          alt_barcodes?: string[] | null;
          created_at?: string | null;
          updated_at?: string | null;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          barcode?: string;
          name?: string;
          brand?: string | null;
          category?: string | null;
          supplier?: string | null;
          unit?: string | null;
          price?: number | null;
          active?: boolean | null;
          alt_barcodes?: string[] | null;
          created_at?: string | null;
          updated_at?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "products_tenant_id_fkey";
            columns: ["tenant_id"];
            referencedRelation: "tenants";
            referencedColumns: ["id"];
          },
        ];
      };
      regions: {
        Row: {
          id: string;
          tenant_id: string;
          name: string;
          code: string;
          manager_id: string | null;
          active: boolean | null;
          created_at: string | null;
          updated_at: string | null;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          name: string;
          code: string;
          manager_id?: string | null;
          active?: boolean | null;
          created_at?: string | null;
          updated_at?: string | null;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          name?: string;
          code?: string;
          manager_id?: string | null;
          active?: boolean | null;
          created_at?: string | null;
          updated_at?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "regions_tenant_id_fkey";
            columns: ["tenant_id"];
            referencedRelation: "tenants";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Views: Record<string, never>;
    Functions: {
      get_user_email_by_sicil: {
        Args: {
          p_sicil_no: string;
        };
        Returns:
          | {
              email: string | null;
              active: boolean | null;
            }[]
          | null;
      };
      get_all_tenants: {
        Args: Record<string, never>;
        Returns:
          | {
              id: string;
              code: string;
              name: string;
              active: boolean;
              total_users: number;
              active_modules: number;
            }[]
          | null;
      };
      get_tenant_modules: {
        Args: {
          p_tenant_id: string;
        };
        Returns:
          | {
              module_code: string;
              module_name: string;
              module_icon: string | null;
              module_description: string | null;
              is_core: boolean;
              is_enabled: boolean;
              enabled_at: string | null;
            }[]
          | null;
      };
      toggle_tenant_module: {
        Args: {
          p_tenant_id: string;
          p_module_code: string;
          p_is_enabled: boolean;
        };
        Returns:
          | {
              success: boolean;
              tenant_id?: string;
              module_code?: string;
              is_enabled?: boolean;
              error?: string;
            }
          | null;
      };
      add_personel: {
        Args: {
          p_employee_code: string;
          p_password: string;
          p_tenant_id: string;
        };
        Returns:
          | {
              success: boolean;
              user_id?: string;
              email?: string;
              error?: string;
            }
          | null;
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
  auth: {
    Tables: {
      users: {
        Row: {
          id: string;
          email: string | null;
          email_confirmed_at: string | null;
        };
        Insert: {
          id: string;
          email?: string | null;
          email_confirmed_at?: string | null;
        };
        Update: {
          id?: string;
          email?: string | null;
          email_confirmed_at?: string | null;
        };
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
