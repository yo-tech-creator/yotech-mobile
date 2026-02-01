"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { createBrowserClient } from "@supabase/ssr";
import { ArrowLeft, MapPin, AlertTriangle, Megaphone, Building2, Users, Filter } from "lucide-react";
import type { TargetScope, CreateAnnouncementForm, Branch, Region, User } from "@/types/announcements";
import "./create-page.css";

const PRIORITY_OPTIONS = [
  { value: 1, label: "Düşük", color: "#94a3b8" },
  { value: 2, label: "Normal", color: "#3b82f6" },
  { value: 3, label: "Yüksek", color: "#f59e0b" },
  { value: 4, label: "Acil", color: "#dc2626" },
];

export default function CreateAnnouncementPage() {
  const router = useRouter();
  const [form, setForm] = useState<CreateAnnouncementForm>({
    title: "",
    content: "",
    summary: "",
    type: "announcement",
    target_scope: "all_branches",
    target_branches: [],
    target_regions: [],
    target_users: [],
    target_roles: [],
    include_region_managers: false,
    managers_only: false,
    priority: 2,
    pinned: false,
    expires_at: null,
  });
  
  const [branches, setBranches] = useState<Branch[]>([]);
  const [regions, setRegions] = useState<Region[]>([]);
  const [personnel, setPersonnel] = useState<User[]>([]);
  const [showBranchFilter, setShowBranchFilter] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [userRole, setUserRole] = useState<string | null>(null);
  const [managedRegionIds, setManagedRegionIds] = useState<string[]>([]);
  const [userBranchId, setUserBranchId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedRegionId, setSelectedRegionId] = useState<string | null>(null);

  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);

      // Use API route to get all lookup data (bypasses RLS)
      const response = await fetch("/api/announcements/lookup");
      if (!response.ok) {
        throw new Error("Failed to load data");
      }
      
      const data = await response.json();
      console.log("Lookup data:", data);
      
      const role = data.role || null;
      setUserRole(role);
      setManagedRegionIds(data.managed_region_ids || []);
      setUserBranchId(data.branch_id || null);
      setBranches(data.branches || []);
      setRegions(data.regions || []);
      setPersonnel(data.personnel || []);
      
      // Set default target scope based on role
      const normalizedRole = role?.toLowerCase().replace(/\s+/g, "_") || "";
      if (normalizedRole.includes("firma") || normalizedRole.includes("admin")) {
        setForm(prev => ({ ...prev, target_scope: "all_branches" }));
      } else if (normalizedRole.includes("bolge") || normalizedRole.includes("bölge")) {
        setForm(prev => ({ ...prev, target_scope: "my_branches" }));
      } else if (normalizedRole.includes("sube") || normalizedRole.includes("şube")) {
        setForm(prev => ({ ...prev, target_scope: "all_personnel" }));
      }
    } catch (err) {
      console.error("Error loading data:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!form.title.trim()) {
      setError("Başlık zorunludur");
      return;
    }
    
    if (!form.content.trim()) {
      setError("İçerik zorunludur");
      return;
    }

    // Validation based on target scope
    if (form.target_scope === "selected_regions" && form.target_regions.length === 0) {
      setError("En az bir bölge seçmelisiniz");
      return;
    }

    if (form.target_scope === "selected_branches" && form.target_branches.length === 0) {
      setError("En az bir şube seçmelisiniz");
      return;
    }

    if (form.target_scope === "selected_personnel" && form.target_users.length === 0) {
      setError("En az bir personel seçmelisiniz");
      return;
    }

    try {
      setSaving(true);
      setError(null);

      // Calculate target branches based on scope
      let targetBranches: string[] | null = null;
      
      if (form.target_scope === "selected_regions") {
        if (showBranchFilter && form.target_branches.length > 0) {
          targetBranches = form.target_branches;
        } else {
          targetBranches = branches
            .filter(b => form.target_regions.includes(b.region_id || ""))
            .map(b => b.id);
        }
      } else if (form.target_scope === "selected_branches") {
        targetBranches = form.target_branches;
      }

      // Call API route instead of RPC
      const response = await fetch("/api/announcements", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: form.title,
          content: form.content,
          summary: form.summary || null,
          target_scope: form.target_scope === "selected_regions" ? "selected_branches" : form.target_scope,
          target_branches: targetBranches,
          target_users: form.target_scope === "selected_personnel" ? form.target_users : null,
          include_region_managers: form.include_region_managers,
          managers_only: form.managers_only,
          priority: form.priority,
          pinned: form.pinned,
          expires_at: form.expires_at,
        }),
      });

      const result = await response.json();
      
      if (!response.ok) {
        throw new Error(result.error || "Duyuru oluşturulurken bir hata oluştu");
      }
      
      router.push("/announcements");
    } catch (err: unknown) {
      console.error("Error creating announcement:", err);
      const error = err as { message?: string };
      setError(error.message || "Duyuru oluşturulurken bir hata oluştu");
    } finally {
      setSaving(false);
    }
  };

  const handleRegionToggle = (regionId: string) => {
    setForm(prev => ({
      ...prev,
      target_regions: prev.target_regions.includes(regionId)
        ? prev.target_regions.filter(id => id !== regionId)
        : [...prev.target_regions, regionId],
      target_branches: prev.target_regions.includes(regionId)
        ? prev.target_branches.filter(id => {
            const branch = branches.find(b => b.id === id);
            return branch?.region_id !== regionId;
          })
        : prev.target_branches
    }));
  };

  const handleBranchToggle = (branchId: string) => {
    setForm(prev => ({
      ...prev,
      target_branches: prev.target_branches.includes(branchId)
        ? prev.target_branches.filter(id => id !== branchId)
        : [...prev.target_branches, branchId],
    }));
  };

  const handlePersonnelToggle = (userId: string) => {
    setForm(prev => ({
      ...prev,
      target_users: prev.target_users.includes(userId)
        ? prev.target_users.filter(id => id !== userId)
        : [...prev.target_users, userId],
    }));
  };

  const selectAllBranchesInRegions = () => {
    const regionBranches = branches
      .filter(b => form.target_regions.includes(b.region_id || ""))
      .map(b => b.id);
    setForm(prev => ({ ...prev, target_branches: regionBranches }));
  };

  const filteredBranches = branches.filter(b => 
    form.target_regions.includes(b.region_id || "")
  );

  // Bölge seçimine göre şubeleri filtrele (firma admin için)
  const branchesInSelectedRegion = selectedRegionId 
    ? branches.filter(b => b.region_id === selectedRegionId)
    : branches;

  const getTargetScopeOptions = () => {
    console.log("userRole:", userRole);
    const role = userRole?.toLowerCase().replace(/\s+/g, "_") || "";
    
    if (role.includes("firma") || role.includes("admin") || role === "grand_admin") {
      return [
        { value: "all_branches", label: "Tüm Şubeler", description: "Tüm bölgelerdeki tüm şubelere gönderilir" },
        { value: "selected_regions", label: "Bölge Seç", description: "Seçtiğiniz bölgelerdeki şubelere gönderilir" },
        { value: "selected_branches", label: "Şube Seç", description: "Önce bölge seçin, sonra şubeleri belirleyin" },
      ];
    } else if (role.includes("bolge") || role.includes("bölge")) {
      return [
        { value: "my_branches", label: "Tüm Şubelerim", description: "Bölgenizdeki tüm şubelere gönderilir" },
        { value: "selected_branches", label: "Şube Seç", description: "Seçtiğiniz şubelere gönderilir" },
      ];
    } else if (role.includes("sube") || role.includes("şube")) {
      return [
        { value: "all_personnel", label: "Tüm Personeller", description: "Şubenizdeki tüm personele gönderilir" },
        { value: "selected_personnel", label: "Personel Seç", description: "Seçtiğiniz personellere gönderilir" },
      ];
    }
    // Default fallback for any role
    if (userRole) {
      return [
        { value: "all_branches", label: "Tüm Şubeler", description: "Tüm bölgelerdeki tüm şubelere gönderilir" },
        { value: "selected_regions", label: "Bölge Seç", description: "Seçtiğiniz bölgelerdeki şubelere gönderilir" },
      ];
    }
    return [];
  };

  if (loading) {
    return (
      <div className="create-page">
        <div className="loading-container">
          <div className="spinner" />
          <p>Yükleniyor...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="create-page">
      <div className="page-header">
        <button className="back-btn" onClick={() => router.push("/announcements")}>
          <ArrowLeft size={20} />
          Geri
        </button>
        <div className="header-title">
          <Megaphone size={24} />
          <h1>Yeni Duyuru</h1>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="create-form">
        {error && (
          <div className="alert alert-error">
            <AlertTriangle size={18} />
            {error}
          </div>
        )}

        <div className="form-card">
          <h2>Temel Bilgiler</h2>
          
          <div className="form-group">
            <label>Başlık *</label>
            <input
              type="text"
              value={form.title}
              onChange={(e) => setForm(prev => ({ ...prev, title: e.target.value }))}
              placeholder="Duyuru başlığı"
              maxLength={200}
            />
          </div>

          <div className="form-group">
            <label>Özet (opsiyonel)</label>
            <input
              type="text"
              value={form.summary || ""}
              onChange={(e) => setForm(prev => ({ ...prev, summary: e.target.value }))}
              placeholder="Kısa özet (liste görünümünde gösterilir)"
              maxLength={300}
            />
          </div>

          <div className="form-group">
            <label>İçerik *</label>
            <textarea
              value={form.content}
              onChange={(e) => setForm(prev => ({ ...prev, content: e.target.value }))}
              placeholder="Duyuru içeriği..."
              rows={8}
            />
          </div>
        </div>

        <div className="form-card">
          <h2>Hedef Kitle</h2>
          
          <div className="scope-options">
            {getTargetScopeOptions().map((opt) => (
              <label key={opt.value} className="scope-option">
                <input
                  type="radio"
                  name="target_scope"
                  value={opt.value}
                  checked={form.target_scope === opt.value}
                  onChange={() => {
                    setForm(prev => ({ 
                      ...prev, 
                      target_scope: opt.value as TargetScope,
                      target_regions: [],
                      target_branches: [],
                      target_users: []
                    }));
                    setShowBranchFilter(false);
                  }}
                />
                <div className="scope-content">
                  <span className="scope-label">{opt.label}</span>
                  <span className="scope-desc">{opt.description}</span>
                </div>
              </label>
            ))}
          </div>

          {/* FIRMA ADMIN: Bölge Seçimi */}
          {userRole === "firma_admin" && form.target_scope === "selected_regions" && (
            <div className="selection-section">
              <div className="section-header">
                <label>
                  <MapPin size={16} />
                  Bölge Seçimi ({form.target_regions.length} bölge seçili)
                </label>
                <button
                  type="button"
                  className="select-all-btn"
                  onClick={() => {
                    if (form.target_regions.length === regions.length) {
                      setForm(prev => ({ ...prev, target_regions: [], target_branches: [] }));
                    } else {
                      setForm(prev => ({ ...prev, target_regions: regions.map(r => r.id) }));
                    }
                  }}
                >
                  {form.target_regions.length === regions.length ? "Tümünü Kaldır" : "Tümünü Seç"}
                </button>
              </div>
              <div className="items-grid">
                {regions.map((region) => {
                  const branchCount = branches.filter(b => b.region_id === region.id).length;
                  return (
                    <label key={region.id} className="item-checkbox">
                      <input
                        type="checkbox"
                        checked={form.target_regions.includes(region.id)}
                        onChange={() => handleRegionToggle(region.id)}
                      />
                      <MapPin size={14} />
                      <span>{region.name}</span>
                      <span className="item-count">({branchCount} şube)</span>
                    </label>
                  );
                })}
              </div>

              {/* Şube Filtresi Toggle */}
              {form.target_regions.length > 0 && (
                <div className="filter-toggle">
                  <label className="toggle-checkbox">
                    <input
                      type="checkbox"
                      checked={showBranchFilter}
                      onChange={(e) => {
                        setShowBranchFilter(e.target.checked);
                        if (!e.target.checked) {
                          setForm(prev => ({ ...prev, target_branches: [] }));
                        }
                      }}
                    />
                    <Filter size={14} />
                    <span>Şube Filtrele (opsiyonel)</span>
                  </label>
                  <span className="filter-hint">
                    {showBranchFilter 
                      ? `${form.target_branches.length} şube seçili`
                      : "Seçili bölgelerdeki tüm şubelere gönderilecek"
                    }
                  </span>
                </div>
              )}

              {/* Şube Seçimi (Opsiyonel Filtre) */}
              {showBranchFilter && form.target_regions.length > 0 && (
                <div className="sub-selection">
                  <div className="section-header">
                    <label>
                      <Building2 size={16} />
                      Şube Filtresi ({form.target_branches.length} şube seçili)
                    </label>
                    <button
                      type="button"
                      className="select-all-btn"
                      onClick={selectAllBranchesInRegions}
                    >
                      Tümünü Seç
                    </button>
                  </div>
                  <div className="items-grid">
                    {filteredBranches.map((branch) => {
                      const region = regions.find(r => r.id === branch.region_id);
                      return (
                        <label key={branch.id} className="item-checkbox">
                          <input
                            type="checkbox"
                            checked={form.target_branches.includes(branch.id)}
                            onChange={() => handleBranchToggle(branch.id)}
                          />
                          <Building2 size={14} />
                          <span>{branch.name}</span>
                          {region && <span className="item-region">({region.name})</span>}
                        </label>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* FİRMA ADMİN: Şube Seçimi (Önce Bölge Seç) */}
          {(userRole === "firma_admin" || userRole === "grand_admin") && form.target_scope === "selected_branches" && (
            <div className="selection-section">
              {/* Bölge Dropdown */}
              <div className="form-group">
                <label>
                  <MapPin size={16} />
                  Önce Bölge Seçin
                </label>
                <select
                  value={selectedRegionId || ""}
                  onChange={(e) => {
                    setSelectedRegionId(e.target.value || null);
                    setForm(prev => ({ ...prev, target_branches: [] }));
                  }}
                  className="region-select"
                >
                  <option value="">-- Bölge Seçin --</option>
                  {regions.map((region) => {
                    const branchCount = branches.filter(b => b.region_id === region.id).length;
                    return (
                      <option key={region.id} value={region.id}>
                        {region.name} ({branchCount} şube)
                      </option>
                    );
                  })}
                </select>
              </div>

              {/* Şube Seçimi */}
              {selectedRegionId && (
                <>
                  <div className="section-header">
                    <label>
                      <Building2 size={16} />
                      Şube Seçimi ({form.target_branches.length} şube seçili)
                    </label>
                    <button
                      type="button"
                      className="select-all-btn"
                      onClick={() => {
                        if (form.target_branches.length === branchesInSelectedRegion.length) {
                          setForm(prev => ({ ...prev, target_branches: [] }));
                        } else {
                          setForm(prev => ({ ...prev, target_branches: branchesInSelectedRegion.map(b => b.id) }));
                        }
                      }}
                    >
                      {form.target_branches.length === branchesInSelectedRegion.length ? "Tümünü Kaldır" : "Tümünü Seç"}
                    </button>
                  </div>
                  <div className="items-grid">
                    {branchesInSelectedRegion.map((branch) => (
                      <label key={branch.id} className="item-checkbox">
                        <input
                          type="checkbox"
                          checked={form.target_branches.includes(branch.id)}
                          onChange={() => handleBranchToggle(branch.id)}
                        />
                        <Building2 size={14} />
                        <span>{branch.name}</span>
                      </label>
                    ))}
                  </div>
                </>
              )}
            </div>
          )}

          {/* BÖLGE MÜDÜRÜ: Şube Seçimi */}
          {userRole === "bolge_muduru" && form.target_scope === "selected_branches" && (
            <div className="selection-section">
              <div className="section-header">
                <label>
                  <Building2 size={16} />
                  Şube Seçimi ({form.target_branches.length} şube seçili)
                </label>
                <button
                  type="button"
                  className="select-all-btn"
                  onClick={() => {
                    if (form.target_branches.length === branches.length) {
                      setForm(prev => ({ ...prev, target_branches: [] }));
                    } else {
                      setForm(prev => ({ ...prev, target_branches: branches.map(b => b.id) }));
                    }
                  }}
                >
                  {form.target_branches.length === branches.length ? "Tümünü Kaldır" : "Tümünü Seç"}
                </button>
              </div>
              <div className="items-grid">
                {branches.map((branch) => (
                  <label key={branch.id} className="item-checkbox">
                    <input
                      type="checkbox"
                      checked={form.target_branches.includes(branch.id)}
                      onChange={() => handleBranchToggle(branch.id)}
                    />
                    <Building2 size={14} />
                    <span>{branch.name}</span>
                  </label>
                ))}
              </div>
            </div>
          )}

          {/* ŞUBE MÜDÜRÜ: Personel Seçimi */}
          {userRole === "sube_muduru" && form.target_scope === "selected_personnel" && (
            <div className="selection-section">
              <div className="section-header">
                <label>
                  <Users size={16} />
                  Personel Seçimi ({form.target_users.length} personel seçili)
                </label>
                <button
                  type="button"
                  className="select-all-btn"
                  onClick={() => {
                    if (form.target_users.length === personnel.length) {
                      setForm(prev => ({ ...prev, target_users: [] }));
                    } else {
                      setForm(prev => ({ ...prev, target_users: personnel.map(p => p.id) }));
                    }
                  }}
                >
                  {form.target_users.length === personnel.length ? "Tümünü Kaldır" : "Tümünü Seç"}
                </button>
              </div>
              {personnel.length === 0 ? (
                <p className="no-items">Şubenizde personel bulunmuyor</p>
              ) : (
                <div className="items-grid">
                  {personnel.map((person) => (
                    <label key={person.id} className="item-checkbox">
                      <input
                        type="checkbox"
                        checked={form.target_users.includes(person.id)}
                        onChange={() => handlePersonnelToggle(person.id)}
                      />
                      <Users size={14} />
                      <span>{person.first_name} {person.last_name}</span>
                    </label>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        <div className="form-card">
          <h2>Ek Ayarlar</h2>
          
          <div className="form-row">
            <div className="form-group">
              <label>Öncelik</label>
              <div className="priority-options">
                {PRIORITY_OPTIONS.map((opt) => (
                  <button
                    key={opt.value}
                    type="button"
                    className={`priority-btn ${form.priority === opt.value ? "active" : ""}`}
                    style={{ "--priority-color": opt.color } as React.CSSProperties}
                    onClick={() => setForm(prev => ({ ...prev, priority: opt.value }))}
                  >
                    {opt.label}
                  </button>
                ))}
              </div>
            </div>

            <div className="form-group">
              <label>Bitiş Tarihi (opsiyonel)</label>
              <input
                type="date"
                value={form.expires_at || ""}
                onChange={(e) => setForm(prev => ({ 
                  ...prev, 
                  expires_at: e.target.value || null 
                }))}
                min={new Date().toISOString().split("T")[0]}
              />
            </div>
          </div>

          <div className="checkbox-group">
            <label className="checkbox-item">
              <input
                type="checkbox"
                checked={form.pinned}
                onChange={(e) => setForm(prev => ({ ...prev, pinned: e.target.checked }))}
              />
              <span>Sabitle (listenin başında göster)</span>
            </label>
            
            {userRole !== "sube_muduru" && (
              <label className="checkbox-item">
                <input
                  type="checkbox"
                  checked={form.managers_only}
                  onChange={(e) => setForm(prev => ({ ...prev, managers_only: e.target.checked }))}
                />
                <span>Sadece müdürlere göster</span>
              </label>
            )}
          </div>
        </div>

        <div className="form-actions">
          <button type="button" className="btn btn-secondary" onClick={() => router.push("/announcements")}>
            İptal
          </button>
          <button type="submit" className="btn btn-primary" disabled={saving}>
            {saving ? "Yayınlanıyor..." : "Duyuruyu Yayınla"}
          </button>
        </div>
      </form>
    </div>
  );
}
