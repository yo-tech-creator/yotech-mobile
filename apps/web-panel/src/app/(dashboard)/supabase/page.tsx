import { Metadata } from "next";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";
import { AlertCircle, Shield, Database, Activity, RefreshCcw } from "lucide-react";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Supabase Yönetimi",
};

type RlsPolicy = {
  table: string;
  policy: string;
  command: string;
  check: string | null;
  using: string | null;
};

type EdgeFunction = {
  name: string;
  version: string;
  deployedAt: string;
};

type RpcResult<T> = { items: T[]; error?: string };

async function getRlsPolicies(): Promise<RpcResult<RlsPolicy>> {
  try {
    const supabase = getSupabaseAdminClient();
    const { data, error } = await supabase.rpc("list_rls_policies");
    if (error) throw error;
    return { items: (data ?? []) as RlsPolicy[] };
  } catch (error) {
    console.error("RLS fetch error", error);
    return { items: [], error: error instanceof Error ? error.message : String(error) };
  }
}

async function getEdgeFunctions(): Promise<RpcResult<EdgeFunction>> {
  try {
    const supabase = getSupabaseAdminClient();
    const { data, error } = await supabase.rpc("list_edge_functions");
    if (error) throw error;
    return { items: (data ?? []) as EdgeFunction[] };
  } catch (error) {
    console.error("Edge functions fetch error", error);
    return { items: [], error: error instanceof Error ? error.message : String(error) };
  }
}

export default async function SupabasePage() {
  const [policiesResult, edgeFunctionsResult] = await Promise.all([
    getRlsPolicies(),
    getEdgeFunctions(),
  ]);

  const policies = policiesResult.items;
  const policiesError = policiesResult.error;
  const edgeFunctions = edgeFunctionsResult.items;
  const edgeError = edgeFunctionsResult.error;

  return (
    <div className="page-layout">
      <header className="page-header" style={{ marginBottom: "1rem" }}>
        <div>
          <h2>Supabase Yönetimi</h2>
          <p>RLS politikaları, Edge Functions ve kritik durumu tek bakışta görün.</p>
        </div>
        <Link href="/observability" className="button ghost" style={{ display: "inline-flex", gap: 8 }}>
          <Activity size={16} />
          Gözetim Panosu
        </Link>
      </header>

      <section
        className="card"
        style={{ display: "grid", gap: "16px", gridTemplateColumns: "repeat(auto-fit, minmax(260px, 1fr))" }}
      >
        <article className="card" style={{ margin: 0 }}>
          <div className="card-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <h3>Edge Functions</h3>
            <Database size={16} color="#6b7280" />
          </div>
          <div className="card-body" style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {edgeError ? (
              <p className="alert alert-error">Edge functions RPC hatası: {edgeError}</p>
            ) : edgeFunctions.length === 0 ? (
              <p className="time-stamp">Henüz kayıt bulunmuyor.</p>
            ) : (
              edgeFunctions.map((fn) => (
                <div key={fn.name} className="list-item" style={{ alignItems: "center" }}>
                  <div>
                    <strong>{fn.name}</strong>
                    <div className="time-stamp">v{fn.version}</div>
                  </div>
                  <span className="badge">{new Date(fn.deployedAt).toLocaleDateString()}</span>
                </div>
              ))
            )}
          </div>
        </article>

        <article className="card" style={{ margin: 0 }}>
          <div className="card-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <h3>RLS Politikaları</h3>
            <Shield size={16} color="#6b7280" />
          </div>
          <div
            className="card-body"
            style={{ display: "flex", flexDirection: "column", gap: 8, maxHeight: 360, overflowY: "auto" }}
          >
            {policiesError ? (
              <p className="alert alert-error">RLS RPC hatası: {policiesError}</p>
            ) : policies.length === 0 ? (
              <p className="time-stamp">Politika kaydı bulunamadı.</p>
            ) : (
              policies.map((policy) => (
                <div key={`${policy.table}-${policy.policy}`} className="list-item" style={{ alignItems: "flex-start" }}>
                  <div>
                    <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                      <span className="badge">{policy.command}</span>
                      <strong>{policy.policy}</strong>
                    </div>
                    {(policy.using || policy.check) ? (
                      <div className="time-stamp" style={{ marginTop: 4 }}>
                        {policy.using ? <div>USING: {policy.using}</div> : null}
                        {policy.check ? <div>CHECK: {policy.check}</div> : null}
                      </div>
                    ) : null}
                  </div>
                  <span className="time-stamp">{policy.table}</span>
                </div>
              ))
            )}
          </div>
        </article>
      </section>

      <section className="card">
        <div className="card-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div>
            <h3>Hızlı Kontroller</h3>
            <p className="time-stamp">Önemli başlıklar için kısayol.</p>
          </div>
          <RefreshCcw size={16} color="#6b7280" />
        </div>
        <div className="card-body" style={{ display: "grid", gap: "12px", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))" }}>
          <Link href="/observability" className="list-item" style={{ alignItems: "center" }}>
            <Activity size={16} />
            <div style={{ marginLeft: 8 }}>Log ve Alarmlar</div>
          </Link>
          <Link href="/modules" className="list-item" style={{ alignItems: "center" }}>
            <Database size={16} />
            <div style={{ marginLeft: 8 }}>Modül Bağlantıları</div>
          </Link>
          <Link href="/tenants" className="list-item" style={{ alignItems: "center" }}>
            <AlertCircle size={16} />
            <div style={{ marginLeft: 8 }}>Yetki/RLS İncele</div>
          </Link>
        </div>
      </section>

      <p className="time-stamp">
        RLS ve Edge Function verileri Supabase RPC (list_rls_policies, list_edge_functions) üzerinden okunur.
      </p>
    </div>
  );
}