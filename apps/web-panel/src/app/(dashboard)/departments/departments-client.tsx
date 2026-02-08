"use client";

import { useState, useEffect, useCallback, CSSProperties } from "react";
import { createBrowserClient } from "@supabase/ssr";
import {
  Building2,
  Search,
  Plus,
  Edit2,
  Trash2,
  Users,
  Loader2,
  AlertCircle,
  X,
  UserPlus,
  UserMinus,
  RefreshCw,
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
  flexWrap: "wrap",
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
  background: "linear-gradient(135deg, #8b5cf6, #6366f1)",
  display: "grid",
  placeItems: "center",
  color: "#fff",
  boxShadow: "0 8px 20px -10px rgba(139, 92, 246, 0.5)",
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

const HEADER_ACTIONS: CSSProperties = {
  display: "flex",
  gap: "12px",
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

const ADD_BTN: CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  gap: "8px",
  padding: "10px 20px",
  borderRadius: 12,
  border: "none",
  background: "linear-gradient(135deg, #8b5cf6, #6366f1)",
  color: "#fff",
  fontWeight: 600,
  fontSize: "0.9rem",
  cursor: "pointer",
  transition: "transform 0.2s ease, box-shadow 0.2s ease",
};

const SEARCH_CONTAINER: CSSProperties = {
  position: "relative",
  maxWidth: 400,
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

const CARD_GRID: CSSProperties = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fill, minmax(320px, 1fr))",
  gap: "20px",
};

const DEPARTMENT_CARD: CSSProperties = {
  background: "var(--surface-strong)",
  borderRadius: 18,
  border: "1px solid var(--surface-strong-border)",
  boxShadow: "0 8px 24px rgba(0,0,0,0.08)",
  overflow: "hidden",
  transition: "transform 0.2s ease, box-shadow 0.2s ease",
};

const CARD_HEADER: CSSProperties = {
  padding: "20px",
  borderBottom: "1px solid var(--surface-strong-border)",
  display: "flex",
  alignItems: "flex-start",
  gap: "14px",
};

const CARD_ICON: CSSProperties = {
  width: 44,
  height: 44,
  borderRadius: 12,
  background: "rgba(139, 92, 246, 0.12)",
  display: "grid",
  placeItems: "center",
  color: "#8b5cf6",
  flexShrink: 0,
};

const CARD_TITLE: CSSProperties = {
  margin: 0,
  fontSize: "1.1rem",
  fontWeight: 600,
  color: "var(--text-strong)",
};

const CARD_DESC: CSSProperties = {
  margin: "4px 0 0",
  fontSize: "0.9rem",
  color: "var(--muted)",
};

const CARD_BODY: CSSProperties = {
  padding: "16px 20px",
};

const USER_COUNT_BADGE: CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  gap: "6px",
  padding: "6px 12px",
  borderRadius: 20,
  background: "rgba(59, 130, 246, 0.12)",
  color: "#2563eb",
  fontSize: "0.85rem",
  fontWeight: 600,
};

const CARD_ACTIONS: CSSProperties = {
  display: "flex",
  gap: "8px",
  padding: "12px 20px",
  borderTop: "1px solid var(--surface-strong-border)",
  background: "var(--table-row-alt)",
};

const ACTION_BTN = (color: string): CSSProperties => ({
  display: "inline-flex",
  alignItems: "center",
  gap: "6px",
  padding: "8px 14px",
  borderRadius: 10,
  border: "none",
  background: `${color}20`,
  color: color,
  fontWeight: 600,
  fontSize: "0.85rem",
  cursor: "pointer",
  transition: "all 0.2s ease",
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

// Modal Styles
const MODAL_OVERLAY: CSSProperties = {
  position: "fixed",
  inset: 0,
  background: "rgba(0,0,0,0.5)",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  zIndex: 1000,
  padding: "20px",
};

const MODAL_CONTENT: CSSProperties = {
  background: "var(--surface-strong)",
  borderRadius: 20,
  width: "100%",
  maxWidth: 500,
  maxHeight: "90vh",
  overflow: "auto",
  boxShadow: "0 20px 60px rgba(0,0,0,0.3)",
};

const MODAL_HEADER: CSSProperties = {
  padding: "20px 24px",
  borderBottom: "1px solid var(--surface-strong-border)",
  display: "flex",
  alignItems: "center",
  justifyContent: "space-between",
};

const MODAL_TITLE: CSSProperties = {
  margin: 0,
  fontSize: "1.25rem",
  fontWeight: 700,
  color: "var(--text-strong)",
};

const MODAL_CLOSE: CSSProperties = {
  width: 36,
  height: 36,
  borderRadius: 10,
  border: "none",
  background: "var(--pill-bg)",
  display: "grid",
  placeItems: "center",
  cursor: "pointer",
  color: "var(--muted)",
};

const MODAL_BODY: CSSProperties = {
  padding: "24px",
};

const FORM_GROUP: CSSProperties = {
  marginBottom: 20,
};

const FORM_LABEL: CSSProperties = {
  display: "block",
  marginBottom: 8,
  fontWeight: 600,
  fontSize: "0.9rem",
  color: "var(--text-strong)",
};

const FORM_INPUT: CSSProperties = {
  width: "100%",
  padding: "12px 16px",
  borderRadius: 12,
  border: "1px solid var(--surface-strong-border)",
  background: "var(--surface)",
  fontSize: "0.95rem",
  color: "var(--text-strong)",
  outline: "none",
};

const FORM_TEXTAREA: CSSProperties = {
  ...FORM_INPUT,
  minHeight: 100,
  resize: "vertical" as const,
};

const MODAL_ACTIONS: CSSProperties = {
  display: "flex",
  gap: "12px",
  justifyContent: "flex-end",
  padding: "16px 24px",
  borderTop: "1px solid var(--surface-strong-border)",
};

const CANCEL_BTN: CSSProperties = {
  padding: "10px 20px",
  borderRadius: 12,
  border: "1px solid var(--surface-strong-border)",
  background: "transparent",
  color: "var(--text)",
  fontWeight: 600,
  fontSize: "0.9rem",
  cursor: "pointer",
};

const SUBMIT_BTN: CSSProperties = {
  padding: "10px 24px",
  borderRadius: 12,
  border: "none",
  background: "linear-gradient(135deg, #8b5cf6, #6366f1)",
  color: "#fff",
  fontWeight: 600,
  fontSize: "0.9rem",
  cursor: "pointer",
};

const USER_LIST: CSSProperties = {
  display: "flex",
  flexDirection: "column",
  gap: "8px",
  maxHeight: 300,
  overflowY: "auto",
};

const USER_ITEM: CSSProperties = {
  display: "flex",
  alignItems: "center",
  justifyContent: "space-between",
  padding: "12px 14px",
  borderRadius: 12,
  background: "var(--surface)",
  border: "1px solid var(--surface-strong-border)",
};

const USER_INFO: CSSProperties = {
  display: "flex",
  flexDirection: "column",
};

const USER_NAME: CSSProperties = {
  fontWeight: 600,
  fontSize: "0.95rem",
  color: "var(--text-strong)",
};

const USER_ROLE: CSSProperties = {
  fontSize: "0.8rem",
  color: "var(--muted)",
};

// Types
interface Department {
  id: string;
  tenant_id: string;
  name: string;
  description: string | null;
  created_at: string;
  updated_at: string;
  user_count?: number;
}

interface DepartmentUser {
  id: string;
  first_name: string | null;
  last_name: string | null;
  role: string;
  department_id: string | null;
}

type ModalType = "create" | "edit" | "delete" | "users" | null;

export function DepartmentsClient() {
  const [departments, setDepartments] = useState<Department[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [modalType, setModalType] = useState<ModalType>(null);
  const [selectedDepartment, setSelectedDepartment] = useState<Department | null>(null);
  const [formName, setFormName] = useState("");
  const [formDescription, setFormDescription] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [departmentUsers, setDepartmentUsers] = useState<DepartmentUser[]>([]);
  const [availableUsers, setAvailableUsers] = useState<DepartmentUser[]>([]);
  const [loadingUsers, setLoadingUsers] = useState(false);
  const [userSearchQuery, setUserSearchQuery] = useState("");
  const [tenantId, setTenantId] = useState<string | null>(null);

  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  const loadDepartments = useCallback(async (showLoading = true) => {
    try {
      if (showLoading) setLoading(true);
      setError(null);

      // Get current user's tenant
      const { data: userData } = await supabase.auth.getUser();
      if (!userData?.user) throw new Error("Oturum bulunamadı");

      const { data: profile } = await supabase
        .from("users")
        .select("tenant_id")
        .eq("id", userData.user.id)
        .single();

      if (!profile?.tenant_id) throw new Error("Firma bilgisi bulunamadı");
      setTenantId(profile.tenant_id);

      // Get departments with user count
      const { data: depts, error: fetchError } = await supabase
        .from("departments")
        .select("*")
        .eq("tenant_id", profile.tenant_id)
        .order("name");

      if (fetchError) throw fetchError;

      // Get user counts for each department
      const departmentsWithCounts = await Promise.all(
        (depts || []).map(async (dept) => {
          const { count } = await supabase
            .from("users")
            .select("*", { count: "exact", head: true })
            .eq("department_id", dept.id);
          return { ...dept, user_count: count || 0 };
        })
      );

      setDepartments(departmentsWithCounts);
    } catch (err) {
      console.error("Error loading departments:", err);
      setError(err instanceof Error ? err.message : "Departmanlar yüklenirken bir hata oluştu");
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadDepartments(true);
  }, [loadDepartments]);

  const openCreateModal = () => {
    setFormName("");
    setFormDescription("");
    setSelectedDepartment(null);
    setModalType("create");
  };

  const openEditModal = (dept: Department) => {
    setFormName(dept.name);
    setFormDescription(dept.description || "");
    setSelectedDepartment(dept);
    setModalType("edit");
  };

  const openDeleteModal = (dept: Department) => {
    setSelectedDepartment(dept);
    setModalType("delete");
  };

  const openUsersModal = async (dept: Department) => {
    setSelectedDepartment(dept);
    setModalType("users");
    setLoadingUsers(true);

    try {
      // Get users in this department (with tenant_id filter for RLS compatibility)
      const { data: deptUsers, error: deptUsersError } = await supabase
        .from("users")
        .select("id, first_name, last_name, role, department_id")
        .eq("tenant_id", tenantId)
        .eq("department_id", dept.id)
        .order("first_name");

      if (deptUsersError) {
        console.error("Error loading department users:", deptUsersError);
      }
      setDepartmentUsers(deptUsers || []);

      // Get available users (same tenant, no department)
      const { data: available, error: availableError } = await supabase
        .from("users")
        .select("id, first_name, last_name, role, department_id")
        .eq("tenant_id", tenantId)
        .is("department_id", null)
        .order("first_name");

      if (availableError) {
        console.error("Error loading available users:", availableError);
      }
      setAvailableUsers(available || []);
    } catch (err) {
      console.error("Error loading users:", err);
    } finally {
      setLoadingUsers(false);
    }
  };

  const closeModal = () => {
    setModalType(null);
    setSelectedDepartment(null);
    setFormName("");
    setFormDescription("");
    setDepartmentUsers([]);
    setAvailableUsers([]);
    setUserSearchQuery("");
  };

  const handleCreateDepartment = async () => {
    if (!formName.trim() || !tenantId) return;
    setSubmitting(true);

    try {
      const { error: insertError } = await supabase
        .from("departments")
        .insert({
          tenant_id: tenantId,
          name: formName.trim(),
          description: formDescription.trim() || null,
        });

      if (insertError) throw insertError;
      closeModal();
      await loadDepartments(false);
    } catch (err) {
      console.error("Error creating department:", err);
      alert("Departman oluşturulurken bir hata oluştu");
    } finally {
      setSubmitting(false);
    }
  };

  const handleEditDepartment = async () => {
    if (!formName.trim() || !selectedDepartment) return;
    setSubmitting(true);

    try {
      const { error: updateError } = await supabase
        .from("departments")
        .update({
          name: formName.trim(),
          description: formDescription.trim() || null,
        })
        .eq("id", selectedDepartment.id);

      if (updateError) throw updateError;
      closeModal();
      await loadDepartments(false);
    } catch (err) {
      console.error("Error updating department:", err);
      alert("Departman güncellenirken bir hata oluştu");
    } finally {
      setSubmitting(false);
    }
  };

  const handleDeleteDepartment = async () => {
    if (!selectedDepartment) return;
    setSubmitting(true);

    try {
      // Remove users from department first
      await supabase
        .from("users")
        .update({ department_id: null })
        .eq("department_id", selectedDepartment.id);

      const { error: deleteError } = await supabase
        .from("departments")
        .delete()
        .eq("id", selectedDepartment.id);

      if (deleteError) throw deleteError;
      closeModal();
      await loadDepartments(false);
    } catch (err) {
      console.error("Error deleting department:", err);
      alert("Departman silinirken bir hata oluştu");
    } finally {
      setSubmitting(false);
    }
  };

  const assignUser = async (userId: string) => {
    if (!selectedDepartment) return;

    try {
      const { error: updateError } = await supabase
        .from("users")
        .update({ department_id: selectedDepartment.id })
        .eq("id", userId);

      if (updateError) throw updateError;

      // Refresh user lists
      const userToMove = availableUsers.find((u) => u.id === userId);
      if (userToMove) {
        setAvailableUsers((prev) => prev.filter((u) => u.id !== userId));
        setDepartmentUsers((prev) => [...prev, { ...userToMove, department_id: selectedDepartment.id }]);
      }
      
      // Update department user_count in main list
      setDepartments((prev) =>
        prev.map((d) =>
          d.id === selectedDepartment.id
            ? { ...d, user_count: (d.user_count || 0) + 1 }
            : d
        )
      );
    } catch (err) {
      console.error("Error assigning user:", err);
      alert("Kullanıcı atanırken bir hata oluştu");
    }
  };

  const removeUser = async (userId: string) => {
    if (!selectedDepartment) return;
    
    try {
      const { error: updateError } = await supabase
        .from("users")
        .update({ department_id: null })
        .eq("id", userId);

      if (updateError) throw updateError;

      // Refresh user lists
      const userToMove = departmentUsers.find((u) => u.id === userId);
      if (userToMove) {
        setDepartmentUsers((prev) => prev.filter((u) => u.id !== userId));
        setAvailableUsers((prev) => [...prev, { ...userToMove, department_id: null }]);
      }
      
      // Update department user_count in main list
      setDepartments((prev) =>
        prev.map((d) =>
          d.id === selectedDepartment.id
            ? { ...d, user_count: Math.max(0, (d.user_count || 0) - 1) }
            : d
        )
      );
    } catch (err) {
      console.error("Error removing user:", err);
      alert("Kullanıcı çıkarılırken bir hata oluştu");
    }
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

  const filteredDepartments = departments.filter((dept) => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      dept.name.toLowerCase().includes(query) ||
      dept.description?.toLowerCase().includes(query)
    );
  });

  if (loading) {
    return (
      <div style={PAGE_CONTAINER}>
        <div style={LOADING_CONTAINER}>
          <Loader2 size={40} style={{ animation: "spin 1s linear infinite", color: "var(--muted)" }} />
          <p style={{ color: "var(--muted)" }}>Departmanlar yükleniyor...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={PAGE_CONTAINER}>
        <div style={EMPTY_STATE}>
          <div style={EMPTY_ICON}>
            <AlertCircle size={28} />
          </div>
          <h3 style={{ margin: "0 0 8px", color: "var(--text-strong)" }}>Hata</h3>
          <p style={{ margin: 0, color: "var(--muted)" }}>{error}</p>
          <button
            style={{ ...ADD_BTN, marginTop: 16 }}
            onClick={() => loadDepartments(true)}
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
            <Building2 size={28} />
          </div>
          <div>
            <h1 style={HEADER_TITLE}>Departmanlar</h1>
            <p style={HEADER_DESC}>Departmanları yönetin ve personel atayın</p>
          </div>
        </div>
        <div style={HEADER_ACTIONS}>
          <button
            style={REFRESH_BTN}
            onClick={() => loadDepartments(false)}
            title="Yenile"
          >
            <RefreshCw size={18} />
          </button>
          <button style={ADD_BTN} onClick={openCreateModal}>
            <Plus size={18} />
            Yeni Departman
          </button>
        </div>
      </div>

      {/* Search */}
      <div style={SEARCH_CONTAINER}>
        <Search size={18} style={SEARCH_ICON_STYLE} />
        <input
          type="text"
          placeholder="Departman ara..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          style={SEARCH_INPUT}
        />
      </div>

      {/* Department Grid */}
      {filteredDepartments.length === 0 ? (
        <div style={EMPTY_STATE}>
          <div style={EMPTY_ICON}>
            <Building2 size={28} />
          </div>
          <h3 style={{ margin: "0 0 8px", color: "var(--text-strong)" }}>
            {searchQuery ? "Departman Bulunamadı" : "Henüz Departman Yok"}
          </h3>
          <p style={{ margin: 0, color: "var(--muted)" }}>
            {searchQuery
              ? "Arama kriterlerinize uygun departman bulunamadı"
              : "Yeni departman eklemek için yukarıdaki butona tıklayın"}
          </p>
        </div>
      ) : (
        <div style={CARD_GRID}>
          {filteredDepartments.map((dept) => (
            <div key={dept.id} style={DEPARTMENT_CARD}>
              <div style={CARD_HEADER}>
                <div style={CARD_ICON}>
                  <Building2 size={22} />
                </div>
                <div style={{ flex: 1 }}>
                  <h3 style={CARD_TITLE}>{dept.name}</h3>
                  {dept.description && (
                    <p style={CARD_DESC}>{dept.description}</p>
                  )}
                </div>
              </div>
              <div style={CARD_BODY}>
                <div style={USER_COUNT_BADGE}>
                  <Users size={14} />
                  {dept.user_count} Personel
                </div>
              </div>
              <div style={CARD_ACTIONS}>
                <button
                  style={ACTION_BTN("#3b82f6")}
                  onClick={() => openUsersModal(dept)}
                >
                  <Users size={16} />
                  Personel
                </button>
                <button
                  style={ACTION_BTN("#8b5cf6")}
                  onClick={() => openEditModal(dept)}
                >
                  <Edit2 size={16} />
                  Düzenle
                </button>
                <button
                  style={ACTION_BTN("#ef4444")}
                  onClick={() => openDeleteModal(dept)}
                >
                  <Trash2 size={16} />
                  Sil
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Create/Edit Modal */}
      {(modalType === "create" || modalType === "edit") && (
        <div style={MODAL_OVERLAY} onClick={closeModal}>
          <div style={MODAL_CONTENT} onClick={(e) => e.stopPropagation()}>
            <div style={MODAL_HEADER}>
              <h2 style={MODAL_TITLE}>
                {modalType === "create" ? "Yeni Departman" : "Departmanı Düzenle"}
              </h2>
              <button style={MODAL_CLOSE} onClick={closeModal}>
                <X size={18} />
              </button>
            </div>
            <div style={MODAL_BODY}>
              <div style={FORM_GROUP}>
                <label style={FORM_LABEL}>Departman Adı *</label>
                <input
                  type="text"
                  placeholder="Örn: Satın Alma"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  style={FORM_INPUT}
                  autoFocus
                />
              </div>
              <div style={FORM_GROUP}>
                <label style={FORM_LABEL}>Açıklama</label>
                <textarea
                  placeholder="Departman hakkında kısa açıklama"
                  value={formDescription}
                  onChange={(e) => setFormDescription(e.target.value)}
                  style={FORM_TEXTAREA}
                />
              </div>
            </div>
            <div style={MODAL_ACTIONS}>
              <button style={CANCEL_BTN} onClick={closeModal} disabled={submitting}>
                İptal
              </button>
              <button
                style={{ ...SUBMIT_BTN, opacity: submitting || !formName.trim() ? 0.6 : 1 }}
                onClick={modalType === "create" ? handleCreateDepartment : handleEditDepartment}
                disabled={submitting || !formName.trim()}
              >
                {submitting ? (
                  <Loader2 size={18} style={{ animation: "spin 1s linear infinite" }} />
                ) : modalType === "create" ? (
                  "Oluştur"
                ) : (
                  "Kaydet"
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {modalType === "delete" && selectedDepartment && (
        <div style={MODAL_OVERLAY} onClick={closeModal}>
          <div style={MODAL_CONTENT} onClick={(e) => e.stopPropagation()}>
            <div style={MODAL_HEADER}>
              <h2 style={MODAL_TITLE}>Departmanı Sil</h2>
              <button style={MODAL_CLOSE} onClick={closeModal}>
                <X size={18} />
              </button>
            </div>
            <div style={MODAL_BODY}>
              <p style={{ margin: 0, color: "var(--text)" }}>
                <strong>{selectedDepartment.name}</strong> departmanını silmek istediğinize emin misiniz?
              </p>
              {selectedDepartment.user_count && selectedDepartment.user_count > 0 && (
                <p style={{ margin: "12px 0 0", color: "var(--muted)", fontSize: "0.9rem" }}>
                  Bu departmanda {selectedDepartment.user_count} personel bulunuyor. Silme işleminde personeller departmansız kalacak.
                </p>
              )}
            </div>
            <div style={MODAL_ACTIONS}>
              <button style={CANCEL_BTN} onClick={closeModal} disabled={submitting}>
                İptal
              </button>
              <button
                style={{ ...SUBMIT_BTN, background: "linear-gradient(135deg, #ef4444, #dc2626)", opacity: submitting ? 0.6 : 1 }}
                onClick={handleDeleteDepartment}
                disabled={submitting}
              >
                {submitting ? (
                  <Loader2 size={18} style={{ animation: "spin 1s linear infinite" }} />
                ) : (
                  "Sil"
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Users Modal */}
      {modalType === "users" && selectedDepartment && (
        <div style={MODAL_OVERLAY} onClick={closeModal}>
          <div style={{ ...MODAL_CONTENT, maxWidth: 600 }} onClick={(e) => e.stopPropagation()}>
            <div style={MODAL_HEADER}>
              <h2 style={MODAL_TITLE}>{selectedDepartment.name} - Personel</h2>
              <button style={MODAL_CLOSE} onClick={closeModal}>
                <X size={18} />
              </button>
            </div>
            <div style={MODAL_BODY}>
              {loadingUsers ? (
                <div style={{ textAlign: "center", padding: "40px" }}>
                  <Loader2 size={32} style={{ animation: "spin 1s linear infinite", color: "var(--muted)" }} />
                </div>
              ) : (
                <>
                  {/* Current Users */}
                  <div style={{ marginBottom: 24 }}>
                    <h4 style={{ margin: "0 0 12px", color: "var(--text-strong)", fontSize: "0.95rem" }}>
                      Mevcut Personel ({departmentUsers.length})
                    </h4>
                    {departmentUsers.length === 0 ? (
                      <p style={{ color: "var(--muted)", fontSize: "0.9rem" }}>
                        Bu departmanda personel yok
                      </p>
                    ) : (
                      <div style={USER_LIST}>
                        {departmentUsers.map((user) => (
                          <div key={user.id} style={USER_ITEM}>
                            <div style={USER_INFO}>
                              <span style={USER_NAME}>
                                {user.first_name} {user.last_name}
                              </span>
                              <span style={USER_ROLE}>{formatRoleLabel(user.role)}</span>
                            </div>
                            <button
                              style={ACTION_BTN("#ef4444")}
                              onClick={() => removeUser(user.id)}
                            >
                              <UserMinus size={16} />
                              Çıkar
                            </button>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Available Users */}
                  <div>
                    <h4 style={{ margin: "0 0 12px", color: "var(--text-strong)", fontSize: "0.95rem" }}>
                      Atanabilir Personel ({availableUsers.length})
                    </h4>
                    {/* Search Input */}
                    <div style={{ position: "relative", marginBottom: 12 }}>
                      <Search size={16} style={{ position: "absolute", left: 12, top: "50%", transform: "translateY(-50%)", color: "var(--muted)" }} />
                      <input
                        type="text"
                        placeholder="İsim ile ara..."
                        value={userSearchQuery}
                        onChange={(e) => setUserSearchQuery(e.target.value)}
                        style={{
                          width: "100%",
                          padding: "10px 12px 10px 38px",
                          borderRadius: 10,
                          border: "1px solid var(--surface-strong-border)",
                          background: "var(--surface)",
                          fontSize: "0.9rem",
                          color: "var(--text-strong)",
                          outline: "none",
                        }}
                      />
                    </div>
                    {availableUsers.length === 0 ? (
                      <p style={{ color: "var(--muted)", fontSize: "0.9rem" }}>
                        Atanabilir personel yok
                      </p>
                    ) : (
                      <div style={USER_LIST}>
                        {availableUsers
                          .filter((user) => {
                            if (!userSearchQuery.trim()) return true;
                            const fullName = `${user.first_name || ""} ${user.last_name || ""}`.toLowerCase();
                            return fullName.includes(userSearchQuery.toLowerCase());
                          })
                          .map((user) => (
                          <div key={user.id} style={USER_ITEM}>
                            <div style={USER_INFO}>
                              <span style={USER_NAME}>
                                {user.first_name} {user.last_name}
                              </span>
                              <span style={USER_ROLE}>{formatRoleLabel(user.role)}</span>
                            </div>
                            <button
                              style={ACTION_BTN("#22c55e")}
                              onClick={() => assignUser(user.id)}
                            >
                              <UserPlus size={16} />
                              Ata
                            </button>
                          </div>
                        ))}
                        {availableUsers.filter((user) => {
                          if (!userSearchQuery.trim()) return true;
                          const fullName = `${user.first_name || ""} ${user.last_name || ""}`.toLowerCase();
                          return fullName.includes(userSearchQuery.toLowerCase());
                        }).length === 0 && (
                          <p style={{ color: "var(--muted)", fontSize: "0.9rem", textAlign: "center", padding: "16px" }}>
                            &quot;{userSearchQuery}&quot; ile eşleşen personel bulunamadı
                          </p>
                        )}
                      </div>
                    )}
                  </div>
                </>
              )}
            </div>
            <div style={MODAL_ACTIONS}>
              <button style={CANCEL_BTN} onClick={closeModal}>
                Kapat
              </button>
            </div>
          </div>
        </div>
      )}

      <style>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}
