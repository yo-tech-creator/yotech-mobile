"use client";

import { useEffect, useMemo, useState } from "react";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import type { Database } from "@/lib/types/database";
import type { TenantModule, TenantSummary } from "@/types/tenants";

type Props = {
  tenants: TenantSummary[];
};

type ToggleResponse = NonNullable<Database["public"]["Functions"]["toggle_tenant_module"]["Returns"]>;

export function ModulePermissionsManager({ tenants }: Props) {
  const supabase = useMemo(() => getSupabaseBrowserClient(), []);
  const [selectedTenantId, setSelectedTenantId] = useState<string | null>(tenants[0]?.id ?? null);
  const [modules, setModules] = useState<TenantModule[]>([]);
  const [loadingModules, setLoadingModules] = useState(false);
  const [savingModule, setSavingModule] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!selectedTenantId) {
      setModules([]);
      return;
    }

    let isCancelled = false;

    async function loadModules(tenantId: string) {
      setLoadingModules(true);
      setError(null);

      const { data, error: rpcError } = await supabase.rpc<
        "get_tenant_modules",
        Database["public"]["Functions"]["get_tenant_modules"]["Args"]
      >("get_tenant_modules", { p_tenant_id: tenantId });

      if (isCancelled) {
        return;
      }

      if (rpcError) {
        console.error("get_tenant_modules rpc error", rpcError);
        setError("Modüller getirilirken hata oluştu");
        setModules([]);
      } else {
        setModules((data ?? []) as TenantModule[]);
      }

      setLoadingModules(false);
    }

    loadModules(selectedTenantId);

    return () => {
      isCancelled = true;
    };
  }, [selectedTenantId, supabase]);

  const handleToggle = async (tenantId: string, module: TenantModule) => {
    if (module.is_core && module.is_enabled) {
      setSuccessMessage("Temel modüller devre dışı bırakılamaz");
      return;
    }

    setSavingModule(module.module_code);
    setError(null);
    setSuccessMessage(null);

    const nextState = !module.is_enabled;

    const { data, error: rpcError } = await supabase.rpc<
      "toggle_tenant_module",
      Database["public"]["Functions"]["toggle_tenant_module"]["Args"]
    >("toggle_tenant_module", {
      p_tenant_id: tenantId,
      p_module_code: module.module_code,
      p_is_enabled: nextState,
    });

    const result = data as ToggleResponse | null;

    if (rpcError || !result?.success) {
      console.error("toggle_tenant_module error", rpcError ?? result);
      setError(result?.error ?? "Modül durumunu güncellerken hata oluştu");
    } else {
      setModules((prev) =>
        prev.map((item) =>
          item.module_code === module.module_code ? { ...item, is_enabled: nextState } : item,
        ),
      );
      setSuccessMessage(`${module.module_name} modülü ${nextState ? "aktif" : "pasif"} edildi`);
    }

    setSavingModule(null);
  };

  return (
    <div className="module-permissions">
      <div className="module-permissions__sidebar">
        <h3>Firmalar</h3>
        <ul>
          {tenants.map((tenant) => {
            const isActive = tenant.id === selectedTenantId;
            return (
              <li key={tenant.id}>
                <button
                  type="button"
                  className={isActive ? "active" : undefined}
                  onClick={() => setSelectedTenantId(tenant.id)}
                >
                  <span>{tenant.name}</span>
                  <small>
                    {tenant.total_users} kullanıcı · {tenant.active_modules} aktif modül
                  </small>
                </button>
              </li>
            );
          })}
        </ul>
      </div>
      <div className="module-permissions__content">
        <header className="page-header">
          <h2>Modül İzinleri</h2>
          <p>
            Seçilen firma için aktif modülleri yönetin. Değişiklikler Supabase fonksiyonları ile anında
            kaydedilir.
          </p>
        </header>

        {error ? <div className="alert alert-error">{error}</div> : null}
        {successMessage ? <div className="alert alert-success">{successMessage}</div> : null}

        {loadingModules ? (
          <div className="card">
            <p>Modüller yükleniyor...</p>
          </div>
        ) : modules.length === 0 ? (
          <div className="card">
            <p>Bu firmaya ait modül kaydı bulunamadı.</p>
          </div>
        ) : (
          <ul className="module-permissions__list">
            {modules.map((module) => (
              <li key={module.module_code} className="card">
                <div className="module-permissions__item">
                  <div>
                    <strong>{module.module_name}</strong>
                    <p>{module.module_description ?? "Açıklama eklenmedi."}</p>
                    <span className="badge">{module.is_core ? "Temel" : "Opsiyonel"}</span>
                  </div>
                  <div>
                    <button
                      type="button"
                      className={module.is_enabled ? "toggle active" : "toggle"}
                      onClick={() =>
                        selectedTenantId && handleToggle(selectedTenantId, module)
                      }
                      disabled={savingModule === module.module_code}
                    >
                      {savingModule === module.module_code
                        ? "Kaydediliyor..."
                        : module.is_enabled
                        ? "Devre Dışı Bırak"
                        : "Aktifleştir"}
                    </button>
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
