"use client";

import { useState, useEffect, useCallback, CSSProperties } from "react";
import { createBrowserClient } from "@supabase/ssr";
import {
  Inbox,
  Search,
  Clock,
  CheckCircle,
  XCircle,
  AlertCircle,
  Loader2,
  ChevronDown,
  ChevronUp,
  Play,
  Check,
  X,
  Building2,
  User,
  Calendar,
  Wrench,
  Package,
  CalendarDays,
  HelpCircle,
  RefreshCw,
  Hand,
  ArrowRightLeft,
  UserCheck,
} from "lucide-react";

// Styles
const PAGE_CONTAINER: CSSProperties = {
  display: "flex",
  flexDirection: "column",
  gap: "24px",
};

const HEADER_STYLE: CSSProperties = {
  display: "flex",
  alignItems: "center",
  justifyContent: "space-between",
  gap: "16px",
};

const HEADER_LEFT: CSSProperties = {
  display: "flex",
  alignItems: "center",
  gap: "16px",
};

const HEADER_ICON: CSSProperties = {
  width: 56,
  height: 56,
  borderRadius: 16,
  background: "linear-gradient(135deg, #4f46e5, #0ea5e9)",
  display: "grid",
  placeItems: "center",
  color: "#fff",
  boxShadow: "0 8px 20px -10px rgba(79, 70, 229, 0.5)",
};

const HEADER_TITLE: CSSProperties = {
  margin: 0,
  fontSize: "1.75rem",
  fontWeight: 700,
  color: "var(--text-strong)",
};

const HEADER_DESC: CSSProperties = {
  margin: 0,
  fontSize: "0.95rem",
  color: "var(--muted)",
};

const REFRESH_BTN: CSSProperties = {
  width: 40,
  height: 40,
  borderRadius: 10,
  border: "1px solid var(--surface-strong-border)",
  background: "var(--surface-strong)",
  display: "grid",
  placeItems: "center",
  cursor: "pointer",
  color: "var(--muted)",
  transition: "all 0.2s ease",
};

const TABS_CONTAINER: CSSProperties = {
  display: "flex",
  gap: "4px",
  padding: "6px",
  borderRadius: 14,
  background: "var(--surface-strong)",
  border: "1px solid var(--surface-strong-border)",
  boxShadow: "0 4px 12px rgba(0,0,0,0.06)",
  width: "fit-content",
};

const TAB_BUTTON = (isActive: boolean): CSSProperties => ({
  padding: "10px 18px",
  borderRadius: 10,
  border: "none",
  background: isActive ? "linear-gradient(135deg, #4f46e5, #0ea5e9)" : "transparent",
  color: isActive ? "#fff" : "var(--text)",
  fontWeight: 600,
  fontSize: "0.9rem",
  cursor: "pointer",
  transition: "all 0.2s ease",
  display: "flex",
  alignItems: "center",
  gap: "6px",
});

const FILTERS_CONTAINER: CSSProperties = {
  display: "flex",
  flexWrap: "wrap",
  gap: "12px",
  alignItems: "center",
};

const SEARCH_INPUT_WRAPPER: CSSProperties = {
  position: "relative",
  flex: "1 1 280px",
  maxWidth: 380,
};

const SEARCH_ICON_STYLE: CSSProperties = {
  position: "absolute",
  left: 14,
  top: "50%",
  transform: "translateY(-50%)",
  color: "var(--muted)",
  pointerEvents: "none",
};

const SEARCH_INPUT: CSSProperties = {
  width: "100%",
  padding: "12px 14px 12px 44px",
  borderRadius: 12,
  border: "1px solid var(--surface-strong-border)",
  background: "var(--surface-strong)",
  fontSize: "0.95rem",
  color: "var(--text-strong)",
  outline: "none",
};

const SELECT_STYLE: CSSProperties = {
  padding: "12px 14px",
  borderRadius: 12,
  border: "1px solid var(--surface-strong-border)",
  background: "var(--surface-strong)",
  fontSize: "0.95rem",
  color: "var(--text-strong)",
  cursor: "pointer",
  outline: "none",
  minWidth: 160,
};

const CARD_GRID: CSSProperties = {
  display: "flex",
  flexDirection: "column",
  gap: "16px",
};

const REQUEST_CARD: CSSProperties = {
  background: "var(--surface-strong)",
  borderRadius: 18,
  border: "1px solid var(--surface-strong-border)",
  boxShadow: "0 8px 24px rgba(0,0,0,0.08)",
  overflow: "hidden",
  transition: "transform 0.2s ease, box-shadow 0.2s ease",
};

const CARD_HEADER: CSSProperties = {
  padding: "20px",
  display: "flex",
  alignItems: "flex-start",
  gap: "16px",
  cursor: "pointer",
};

const CATEGORY_ICON_BOX = (bgColor: string): CSSProperties => ({
  width: 48,
  height: 48,
  borderRadius: 14,
  background: bgColor,
  display: "grid",
  placeItems: "center",
  flexShrink: 0,
});

const CARD_CONTENT: CSSProperties = {
  flex: 1,
  minWidth: 0,
};

const CARD_TITLE_ROW: CSSProperties = {
  display: "flex",
  alignItems: "center",
  gap: "12px",
  flexWrap: "wrap",
  marginBottom: 10,
};

const CARD_TITLE: CSSProperties = {
  margin: 0,
  fontSize: "1.1rem",
  fontWeight: 600,
  color: "var(--text-strong)",
};

const STATUS_BADGE = (bgColor: string, textColor: string): CSSProperties => ({
  display: "inline-flex",
  alignItems: "center",
  gap: "6px",
  padding: "5px 12px",
  borderRadius: 20,
  background: bgColor,
  color: textColor,
  fontSize: "0.8rem",
  fontWeight: 600,
});

const CARD_META: CSSProperties = {
  display: "flex",
  flexWrap: "wrap",
  alignItems: "center",
  gap: "16px",
  color: "var(--muted)",
  fontSize: "0.9rem",
};

const META_ITEM: CSSProperties = {
  display: "flex",
  alignItems: "center",
  gap: "6px",
};

const CATEGORY_TAG = (bgColor: string, textColor: string): CSSProperties => ({
  display: "inline-flex",
  alignItems: "center",
  padding: "4px 10px",
  borderRadius: 8,
  background: bgColor,
  color: textColor,
  fontSize: "0.8rem",
  fontWeight: 600,
});

const EXPAND_ICON: CSSProperties = {
  color: "var(--muted)",
  flexShrink: 0,
  marginLeft: "auto",
};

const CARD_EXPANDED: CSSProperties = {
  borderTop: "1px solid var(--surface-strong-border)",
  background: "var(--table-row-alt)",
  padding: "20px",
};

const SECTION_TITLE: CSSProperties = {
  fontSize: "0.75rem",
  fontWeight: 700,
  color: "var(--muted)",
  textTransform: "uppercase",
  letterSpacing: "0.05em",
  marginBottom: 8,
};

const DESCRIPTION_BOX: CSSProperties = {
  background: "var(--surface-strong)",
  padding: "14px",
  borderRadius: 12,
  border: "1px solid var(--surface-strong-border)",
  color: "var(--text-strong)",
  whiteSpace: "pre-wrap" as const,
  marginBottom: 16,
};

const INFO_GRID: CSSProperties = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
  gap: "12px",
  marginBottom: 16,
};

const INFO_CARD: CSSProperties = {
  background: "var(--surface-strong)",
  padding: "14px",
  borderRadius: 12,
  border: "1px solid var(--surface-strong-border)",
};

const INFO_LABEL: CSSProperties = {
  fontSize: "0.75rem",
  fontWeight: 700,
  color: "var(--muted)",
  textTransform: "uppercase",
  letterSpacing: "0.05em",
  marginBottom: 4,
};

const INFO_VALUE: CSSProperties = {
  fontSize: "0.95rem",
  fontWeight: 600,
  color: "var(--text-strong)",
};

const INFO_VALUE_SUB: CSSProperties = {
  fontSize: "0.85rem",
  color: "var(--muted)",
  marginLeft: 6,
};

const ACTIONS_CONTAINER: CSSProperties = {
  paddingTop: 16,
  borderTop: "1px solid var(--surface-strong-border)",
  marginTop: 8,
};

const ACTIONS_ROW: CSSProperties = {
  display: "flex",
  flexWrap: "wrap",
  gap: "10px",
};

const ACTION_BUTTON = (bgColor: string): CSSProperties => ({
  display: "inline-flex",
  alignItems: "center",
  gap: "8px",
  padding: "10px 18px",
  borderRadius: 12,
  border: "none",
  background: bgColor,
  color: "#fff",
  fontWeight: 600,
  fontSize: "0.9rem",
  cursor: "pointer",
  transition: "transform 0.2s ease, box-shadow 0.2s ease",
});

const EMPTY_STATE: CSSProperties = {
  display: "flex",
  flexDirection: "column",
  alignItems: "center",
  justifyContent: "center",
  padding: "60px 20px",
  background: "var(--surface-strong)",
  borderRadius: 18,
  border: "2px dashed var(--surface-strong-border)",
  textAlign: "center",
};

const EMPTY_ICON: CSSProperties = {
  width: 64,
  height: 64,
  borderRadius: 16,
  background: "var(--pill-bg)",
  display: "grid",
  placeItems: "center",
  marginBottom: 16,
  color: "var(--muted)",
};

const LOADING_CONTAINER: CSSProperties = {
  display: "flex",
  flexDirection: "column",
  alignItems: "center",
  justifyContent: "center",
  padding: "80px 20px",
  gap: 16,
};

// Request status types
type RequestStatus = "pending" | "in_progress" | "resolved" | "cancelled" | "rejected" | "failed";
type RequestCategory = "malfunction" | "equipment" | "leave" | "other";
type TabType = "all" | "pending" | "in_progress" | "resolved" | "rejected";

interface BranchRequest {
  id: string;
  branch_id: string;
  category: RequestCategory;
  title: string;
  description: string | null;
  status: RequestStatus;
  payload: Record<string, string | number | boolean | null> | null;
  target_department: string | null;
  target_department_id: string | null;
  target_user_id: string | null;
  assigned_to: string | null;
  assigned_at: string | null;
  created_by: string;
  resolved_by: string | null;
  resolved_at: string | null;
  created_at: string;
  updated_at: string;
  branch?: { name: string };
  creator?: { first_name: string; last_name: string; role: string };
  target_user?: { first_name: string; last_name: string; role: string };
  resolver?: { first_name: string; last_name: string };
  assigned_user?: { first_name: string; last_name: string; role: string };
}

const statusConfig: Record<RequestStatus, { label: string; bg: string; color: string }> = {
  pending: { label: "Bekliyor", bg: "rgba(251, 191, 36, 0.15)", color: "#b45309" },
  in_progress: { label: "İşlemde", bg: "rgba(59, 130, 246, 0.15)", color: "#1d4ed8" },
  resolved: { label: "Çözüldü", bg: "rgba(34, 197, 94, 0.15)", color: "#15803d" },
  cancelled: { label: "İptal", bg: "rgba(107, 114, 128, 0.15)", color: "#4b5563" },
  rejected: { label: "Reddedildi", bg: "rgba(239, 68, 68, 0.15)", color: "#b91c1c" },
  failed: { label: "Tamamlanamadı", bg: "rgba(249, 115, 22, 0.15)", color: "#c2410c" },
};

const categoryConfig: Record<RequestCategory, { label: string; icon: typeof Wrench; bg: string; color: string }> = {
  malfunction: { label: "Arıza", icon: Wrench, bg: "rgba(239, 68, 68, 0.12)", color: "#dc2626" },
  equipment: { label: "Ekipman", icon: Package, bg: "rgba(59, 130, 246, 0.12)", color: "#2563eb" },
  leave: { label: "İzin", icon: CalendarDays, bg: "rgba(34, 197, 94, 0.12)", color: "#16a34a" },
  other: { label: "Diğer", icon: HelpCircle, bg: "rgba(139, 92, 246, 0.12)", color: "#7c3aed" },
};

export function RequestsClient() {
  const [requests, setRequests] = useState<BranchRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<TabType>("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<RequestCategory | "all">("all");
  const [expandedRequestId, setExpandedRequestId] = useState<string | null>(null);
  const [updatingRequestId, setUpdatingRequestId] = useState<string | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [currentUserRole, setCurrentUserRole] = useState<string | null>(null);
  const [currentUserDepartmentId, setCurrentUserDepartmentId] = useState<string | null>(null);
  const [claimingRequestId, setClaimingRequestId] = useState<string | null>(null);

  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  const loadRequests = useCallback(async (showLoading = true) => {
    try {
      if (showLoading) setLoading(true);
      setError(null);

      const { data: userData } = await supabase.auth.getUser();
      if (userData?.user) {
        setCurrentUserId(userData.user.id);
        const { data: profile } = await supabase
          .from("users")
          .select("role, department_id")
          .eq("id", userData.user.id)
          .single();
        setCurrentUserRole(profile?.role || null);
        setCurrentUserDepartmentId(profile?.department_id || null);
      }

      const { data, error: fetchError } = await supabase
        .from("branch_requests")
        .select(`
          *,
          branch:branches(name),
          creator:users!branch_requests_created_by_fkey(first_name, last_name, role),
          target_user:users!branch_requests_target_user_id_fkey(first_name, last_name, role),
          resolver:users!branch_requests_resolved_by_fkey(first_name, last_name),
          assigned_user:users!branch_requests_assigned_to_fkey(first_name, last_name, role)
        `)
        .order("created_at", { ascending: false });

      if (fetchError) throw fetchError;
      setRequests(data || []);
    } catch (err) {
      console.error("Error loading requests:", err);
      setError("Talepler yüklenirken bir hata oluştu");
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadRequests(true);
    const interval = setInterval(() => loadRequests(false), 30000);
    return () => clearInterval(interval);
  }, [loadRequests]);

  const updateRequestStatus = async (requestId: string, newStatus: RequestStatus) => {
    setUpdatingRequestId(requestId);
    try {
      const updates: Record<string, unknown> = { status: newStatus };
      if (["resolved", "failed", "rejected"].includes(newStatus)) {
        updates.resolved_by = currentUserId;
        updates.resolved_at = new Date().toISOString();
      }

      const { error: updateError } = await supabase
        .from("branch_requests")
        .update(updates)
        .eq("id", requestId);

      if (updateError) throw updateError;
      await loadRequests(false);
    } catch (err) {
      console.error("Error updating request status:", err);
      alert("Durum güncellenirken bir hata oluştu");
    } finally {
      setUpdatingRequestId(null);
    }
  };

  const canManageWorkflow = (request: BranchRequest): boolean => {
    if (!currentUserId || !currentUserRole) return false;
    // Kullanıcılar kendi taleplerini yönetemez
    if (request.created_by === currentUserId) return false;
    // Hedef kullanıcı ise yönetebilir
    if (request.target_user_id === currentUserId) return true;
    // Yönetici rolleri
    return ["firma_admin", "bolge_muduru", "sube_muduru"].includes(currentUserRole);
  };

  // Talebi işleme alabilir mi kontrolü (claim)
  // Sadece departman üyeleri işleme alabilir
  const canClaimRequest = (request: BranchRequest): boolean => {
    if (!currentUserId) return false;
    if (request.created_by === currentUserId) return false;
    if (request.assigned_to) return false;
    if (request.status !== "pending") return false;
    
    // Kullanıcı bir departmana ait olmalı
    if (!currentUserDepartmentId) return false;
    
    // Departmana atanmış talep ise, sadece aynı departmandaki kullanıcılar alabilir
    if (request.target_department_id) {
      if (currentUserDepartmentId !== request.target_department_id) {
        return false;
      }
    } else {
      // Departmana atanmamışsa, target_user_id ile eşleşmeli veya target_user_id olmamalı
      if (request.target_user_id && request.target_user_id !== currentUserId) {
        return false;
      }
    }
    
    return true;
  };

  // Talebi işleme al (claim)
  const claimRequest = async (requestId: string) => {
    setClaimingRequestId(requestId);
    try {
      const { error: claimError } = await supabase.rpc("claim_request", {
        p_request_id: requestId,
      });

      if (claimError) throw claimError;
      await loadRequests(false);
    } catch (err) {
      console.error("Error claiming request:", err);
      alert("Talep işleme alınırken bir hata oluştu");
    } finally {
      setClaimingRequestId(null);
    }
  };

  const filteredRequests = requests.filter((request) => {
    if (activeTab !== "all") {
      if (activeTab === "rejected" && !["rejected", "failed", "cancelled"].includes(request.status)) return false;
      else if (activeTab !== "rejected" && request.status !== activeTab) return false;
    }
    if (categoryFilter !== "all" && request.category !== categoryFilter) return false;
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      return (
        request.title.toLowerCase().includes(query) ||
        request.description?.toLowerCase().includes(query) ||
        request.branch?.name?.toLowerCase().includes(query) ||
        `${request.creator?.first_name} ${request.creator?.last_name}`.toLowerCase().includes(query)
      );
    }
    return true;
  });

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString("tr-TR", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  const formatRoleLabel = (role: string) => {
    const roleLabels: Record<string, string> = {
      firma_admin: "Firma Yöneticisi",
      bolge_muduru: "Bölge Müdürü",
      sube_muduru: "Şube Müdürü",
      personel: "Personel",
    };
    return roleLabels[role] || role;
  };

  const getStatusIcon = (status: RequestStatus) => {
    switch (status) {
      case "pending": return <Clock size={14} />;
      case "in_progress": return <Loader2 size={14} style={{ animation: "spin 1s linear infinite" }} />;
      case "resolved": return <CheckCircle size={14} />;
      case "cancelled": return <XCircle size={14} />;
      case "rejected": return <X size={14} />;
      case "failed": return <AlertCircle size={14} />;
    }
  };

  const tabCounts = {
    all: requests.length,
    pending: requests.filter((r) => r.status === "pending").length,
    in_progress: requests.filter((r) => r.status === "in_progress").length,
    resolved: requests.filter((r) => r.status === "resolved").length,
    rejected: requests.filter((r) => ["rejected", "failed", "cancelled"].includes(r.status)).length,
  };

  if (loading) {
    return (
      <div style={PAGE_CONTAINER}>
        <div style={LOADING_CONTAINER}>
          <Loader2 size={40} style={{ color: "#4f46e5", animation: "spin 1s linear infinite" }} />
          <p style={{ color: "var(--muted)", margin: 0 }}>Talepler yükleniyor...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={PAGE_CONTAINER}>
        <div style={LOADING_CONTAINER}>
          <AlertCircle size={40} style={{ color: "#dc2626" }} />
          <p style={{ color: "var(--text-strong)", margin: 0, fontWeight: 600 }}>{error}</p>
          <button
            onClick={() => loadRequests(true)}
            style={ACTION_BUTTON("linear-gradient(135deg, #4f46e5, #0ea5e9)")}
          >
            Tekrar Dene
          </button>
        </div>
      </div>
    );
  }

  return (
    <div style={PAGE_CONTAINER}>
      {/* Header */}
      <div style={HEADER_STYLE}>
        <div style={HEADER_LEFT}>
          <div style={HEADER_ICON}>
            <Inbox size={28} />
          </div>
          <div>
            <h1 style={HEADER_TITLE}>Talepler</h1>
            <p style={HEADER_DESC}>Şube talepleri, arıza bildirimleri ve izin istekleri</p>
          </div>
        </div>
        <button
          onClick={() => loadRequests(true)}
          style={REFRESH_BTN}
          title="Yenile"
        >
          <RefreshCw size={18} />
        </button>
      </div>

      {/* Tabs */}
      <div style={TABS_CONTAINER}>
        {[
          { key: "all" as TabType, label: "Tümü" },
          { key: "pending" as TabType, label: "Bekleyen" },
          { key: "in_progress" as TabType, label: "İşlemde" },
          { key: "resolved" as TabType, label: "Çözülen" },
          { key: "rejected" as TabType, label: "Reddedilen" },
        ].map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            style={TAB_BUTTON(activeTab === tab.key)}
          >
            {tab.label}
            <span style={{ opacity: 0.7, fontSize: "0.8rem" }}>({tabCounts[tab.key]})</span>
          </button>
        ))}
      </div>

      {/* Filters */}
      <div style={FILTERS_CONTAINER}>
        <div style={SEARCH_INPUT_WRAPPER}>
          <Search size={18} style={SEARCH_ICON_STYLE} />
          <input
            type="text"
            placeholder="Talep ara..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={SEARCH_INPUT}
          />
        </div>

        <select
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value as RequestCategory | "all")}
          style={SELECT_STYLE}
        >
          <option value="all">Tüm Kategoriler</option>
          {Object.entries(categoryConfig).map(([key, { label }]) => (
            <option key={key} value={key}>{label}</option>
          ))}
        </select>
      </div>

      {/* Request List */}
      <div style={CARD_GRID}>
        {filteredRequests.length === 0 ? (
          <div style={EMPTY_STATE}>
            <div style={EMPTY_ICON}>
              <Inbox size={32} />
            </div>
            <h3 style={{ margin: 0, fontSize: "1.1rem", fontWeight: 600, color: "var(--text-strong)" }}>
              Talep bulunamadı
            </h3>
            <p style={{ margin: "8px 0 0", color: "var(--muted)" }}>
              Filtreleri değiştirmeyi deneyin
            </p>
          </div>
        ) : (
          filteredRequests.map((request) => {
            const status = statusConfig[request.status];
            const category = categoryConfig[request.category];
            const CategoryIcon = category.icon;
            const isExpanded = expandedRequestId === request.id;
            const isUpdating = updatingRequestId === request.id;
            const isClaiming = claimingRequestId === request.id;
            const canManage = canManageWorkflow(request);
            const canClaim = canClaimRequest(request);

            return (
              <div key={request.id} style={REQUEST_CARD}>
                {/* Card Header */}
                <div
                  style={CARD_HEADER}
                  onClick={() => setExpandedRequestId(isExpanded ? null : request.id)}
                >
                  <div style={CATEGORY_ICON_BOX(category.bg)}>
                    <CategoryIcon size={22} style={{ color: category.color }} />
                  </div>

                  <div style={CARD_CONTENT}>
                    <div style={CARD_TITLE_ROW}>
                      <h3 style={CARD_TITLE}>{request.title}</h3>
                      <span style={STATUS_BADGE(status.bg, status.color)}>
                        {getStatusIcon(request.status)}
                        {status.label}
                      </span>
                    </div>
                    <div style={CARD_META}>
                      <span style={META_ITEM}>
                        <Building2 size={16} />
                        {request.branch?.name || "Bilinmeyen Şube"}
                      </span>
                      <span style={META_ITEM}>
                        <User size={16} />
                        {request.creator ? `${request.creator.first_name} ${request.creator.last_name}` : "Bilinmeyen"}
                      </span>
                      <span style={META_ITEM}>
                        <Calendar size={16} />
                        {formatDate(request.created_at)}
                      </span>
                      <span style={CATEGORY_TAG(category.bg, category.color)}>
                        {category.label}
                      </span>
                      {request.assigned_user && (
                        <span style={{ 
                          ...META_ITEM, 
                          background: "rgba(34, 197, 94, 0.12)", 
                          padding: "4px 10px", 
                          borderRadius: 8,
                          color: "#16a34a",
                          fontWeight: 600,
                          fontSize: "0.8rem"
                        }}>
                          <UserCheck size={14} />
                          {request.assigned_user.first_name} {request.assigned_user.last_name}
                        </span>
                      )}
                      {!request.assigned_to && request.status === "pending" && (
                        <span style={{ 
                          ...META_ITEM, 
                          background: "rgba(251, 191, 36, 0.15)", 
                          padding: "4px 10px", 
                          borderRadius: 8,
                          color: "#b45309",
                          fontWeight: 600,
                          fontSize: "0.8rem"
                        }}>
                          <Hand size={14} />
                          İşleme alınmadı
                        </span>
                      )}
                    </div>
                  </div>

                  <div style={EXPAND_ICON}>
                    {isExpanded ? <ChevronUp size={20} /> : <ChevronDown size={20} />}
                  </div>
                </div>

                {/* Expanded Content */}
                {isExpanded && (
                  <div style={CARD_EXPANDED}>
                    {/* Description */}
                    {request.description && (
                      <div style={{ marginBottom: 16 }}>
                        <div style={SECTION_TITLE}>Açıklama</div>
                        <div style={DESCRIPTION_BOX}>{request.description}</div>
                      </div>
                    )}

                    {/* Info Grid */}
                    <div style={INFO_GRID}>
                      {request.branch && (
                        <div style={INFO_CARD}>
                          <div style={INFO_LABEL}>Şube</div>
                          <div style={INFO_VALUE}>{request.branch.name}</div>
                        </div>
                      )}
                      {request.target_department && (
                        <div style={INFO_CARD}>
                          <div style={INFO_LABEL}>Hedef Birim</div>
                          <div style={INFO_VALUE}>{request.target_department}</div>
                        </div>
                      )}
                      {request.target_user && (
                        <div style={INFO_CARD}>
                          <div style={INFO_LABEL}>Hedef Yetkili</div>
                          <div style={INFO_VALUE}>
                            {request.target_user.first_name} {request.target_user.last_name}
                            <span style={INFO_VALUE_SUB}>({formatRoleLabel(request.target_user.role)})</span>
                          </div>
                        </div>
                      )}
                      {request.creator && (
                        <div style={INFO_CARD}>
                          <div style={INFO_LABEL}>Talep Eden</div>
                          <div style={INFO_VALUE}>
                            {request.creator.first_name} {request.creator.last_name}
                            <span style={INFO_VALUE_SUB}>({formatRoleLabel(request.creator.role)})</span>
                          </div>
                        </div>
                      )}
                      {request.assigned_user && (
                        <div style={{ ...INFO_CARD, background: "rgba(34, 197, 94, 0.08)", borderColor: "rgba(34, 197, 94, 0.3)" }}>
                          <div style={INFO_LABEL}>İşleme Alan</div>
                          <div style={{ ...INFO_VALUE, color: "#16a34a" }}>
                            {request.assigned_user.first_name} {request.assigned_user.last_name}
                            <span style={INFO_VALUE_SUB}>({formatRoleLabel(request.assigned_user.role)})</span>
                            {request.assigned_at && <span style={INFO_VALUE_SUB}> - {formatDate(request.assigned_at)}</span>}
                          </div>
                        </div>
                      )}
                      {request.resolver && (
                        <div style={INFO_CARD}>
                          <div style={INFO_LABEL}>Sonuçlandıran</div>
                          <div style={INFO_VALUE}>
                            {request.resolver.first_name} {request.resolver.last_name}
                            {request.resolved_at && <span style={INFO_VALUE_SUB}>{formatDate(request.resolved_at)}</span>}
                          </div>
                        </div>
                      )}
                    </div>

                    {/* Payload Info */}
                    {request.payload && Object.keys(request.payload).length > 0 && (
                      <div style={INFO_CARD}>
                        <div style={SECTION_TITLE}>Ek Bilgiler</div>
                        <div style={{ display: "flex", flexDirection: "column", gap: 6, fontSize: "0.9rem" }}>
                          {request.category === "malfunction" && request.payload.malfunction_type_label && (
                            <p style={{ margin: 0 }}><span style={{ color: "var(--muted)" }}>Arıza Türü:</span> <span style={{ color: "var(--text-strong)", fontWeight: 500 }}>{`${request.payload.malfunction_type_label}`}</span></p>
                          )}
                          {request.category === "equipment" && request.payload.equipment_type_label && (
                            <p style={{ margin: 0 }}><span style={{ color: "var(--muted)" }}>Ekipman Türü:</span> <span style={{ color: "var(--text-strong)", fontWeight: 500 }}>{`${request.payload.equipment_type_label}`}</span></p>
                          )}
                          {request.category === "leave" && (
                            <>
                              {request.payload.leave_type_label && (
                                <p style={{ margin: 0 }}><span style={{ color: "var(--muted)" }}>İzin Türü:</span> <span style={{ color: "var(--text-strong)", fontWeight: 500 }}>{`${request.payload.leave_type_label}`}</span></p>
                              )}
                              {request.payload.start_date && request.payload.end_date && (
                                <p style={{ margin: 0 }}>
                                  <span style={{ color: "var(--muted)" }}>Tarih:</span>{" "}
                                  <span style={{ color: "var(--text-strong)", fontWeight: 500 }}>
                                    {new Date(String(request.payload.start_date)).toLocaleDateString("tr-TR")} -{" "}
                                    {new Date(String(request.payload.end_date)).toLocaleDateString("tr-TR")}
                                  </span>
                                </p>
                              )}
                            </>
                          )}
                        </div>
                      </div>
                    )}

                    {/* Claim Action - Atanmamış talepler için */}
                    {canClaim && (
                      <div style={{ ...ACTIONS_CONTAINER, borderTop: "none", paddingTop: 0, marginTop: 0 }}>
                        <div style={{ 
                          padding: "16px", 
                          background: "rgba(251, 191, 36, 0.1)", 
                          borderRadius: 12,
                          border: "1px solid rgba(251, 191, 36, 0.3)",
                          marginBottom: 16
                        }}>
                          <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
                            <Hand size={18} style={{ color: "#b45309" }} />
                            <span style={{ fontWeight: 600, color: "#b45309" }}>Talebi Üstlen</span>
                          </div>
                          <p style={{ margin: 0, fontSize: "0.85rem", color: "var(--muted)", marginBottom: 12 }}>
                            Bu talep henüz kimseye atanmamış. Talebi işleme alarak üstlenebilirsiniz.
                          </p>
                          <button
                            onClick={(e) => { e.stopPropagation(); claimRequest(request.id); }}
                            disabled={isClaiming}
                            style={{ ...ACTION_BUTTON("#f59e0b"), opacity: isClaiming ? 0.6 : 1 }}
                          >
                            {isClaiming ? <Loader2 size={16} style={{ animation: "spin 1s linear infinite" }} /> : <Hand size={16} />}
                            Talebi İşleme Al
                          </button>
                        </div>
                      </div>
                    )}

                    {/* Workflow Actions */}
                    {canManage && (
                      <div style={ACTIONS_CONTAINER}>
                        <div style={SECTION_TITLE}>Talep Yönetimi</div>
                        <div style={ACTIONS_ROW}>
                          {request.status === "pending" && (
                            <>
                              <button
                                onClick={(e) => { e.stopPropagation(); updateRequestStatus(request.id, "in_progress"); }}
                                disabled={isUpdating}
                                style={{ ...ACTION_BUTTON("#2563eb"), opacity: isUpdating ? 0.6 : 1 }}
                              >
                                {isUpdating ? <Loader2 size={16} style={{ animation: "spin 1s linear infinite" }} /> : <Play size={16} />}
                                İşleme Al
                              </button>
                              <button
                                onClick={(e) => { e.stopPropagation(); updateRequestStatus(request.id, "rejected"); }}
                                disabled={isUpdating}
                                style={{ ...ACTION_BUTTON("#dc2626"), opacity: isUpdating ? 0.6 : 1 }}
                              >
                                {isUpdating ? <Loader2 size={16} style={{ animation: "spin 1s linear infinite" }} /> : <X size={16} />}
                                Reddet
                              </button>
                            </>
                          )}
                          {request.status === "in_progress" && (
                            <>
                              <button
                                onClick={(e) => { e.stopPropagation(); updateRequestStatus(request.id, "resolved"); }}
                                disabled={isUpdating}
                                style={{ ...ACTION_BUTTON("#16a34a"), opacity: isUpdating ? 0.6 : 1 }}
                              >
                                {isUpdating ? <Loader2 size={16} style={{ animation: "spin 1s linear infinite" }} /> : <Check size={16} />}
                                Tamamlandı
                              </button>
                              <button
                                onClick={(e) => { e.stopPropagation(); updateRequestStatus(request.id, "failed"); }}
                                disabled={isUpdating}
                                style={{ ...ACTION_BUTTON("#ea580c"), opacity: isUpdating ? 0.6 : 1 }}
                              >
                                {isUpdating ? <Loader2 size={16} style={{ animation: "spin 1s linear infinite" }} /> : <AlertCircle size={16} />}
                                Tamamlanamadı
                              </button>
                            </>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>

      <style>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}
