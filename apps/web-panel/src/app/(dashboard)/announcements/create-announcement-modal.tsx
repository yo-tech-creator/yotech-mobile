"use client";

import { useState, useEffect } from "react";
import { createBrowserClient } from "@supabase/ssr";
import { X, Building2, Users, MapPin, AlertTriangle } from "lucide-react";
import type { TargetScope, CreateAnnouncementForm, Branch, Region } from "@/types/announcements";

interface Props {
  onClose: () => void;
  onSuccess: () => void;
  userRole: string | null;
}

const TARGET_SCOPE_OPTIONS: { value: TargetScope; label: string; description: string; roles: string[] }[] = [
  {
    value: "all_branches",
    label: "Tüm Şubeler",
    description: "Tüm şubelerdeki kullanıcılara gönderilir",
    roles: ["firma_admin"],
  },
  {
    value: "selected_branches",
    label: "Seçili Şubeler",
    description: "Belirli şubelere gönderilir",
    roles: ["firma_admin", "bolge_muduru"],
  },
  {
    value: "my_branches",
    label: "Bölgemdeki Şubeler",
    description: "Bölgenizdeki tüm şubelere gönderilir",
    roles: ["bolge_muduru"],
  },
  {
    value: "my_branch",
    label: "Sadece Şubem",
    description: "Sadece kendi şubenize gönderilir",
    roles: ["sube_muduru"],
  },
  {
    value: "region_managers_only",
    label: "Sadece Bölge Müdürleri",
    description: "Sadece bölge müdürlerine gönderilir",
    roles: ["firma_admin"],
  },
];

const PRIORITY_OPTIONS = [
  { value: 1, label: "Düşük", color: "#94a3b8" },
  { value: 2, label: "Normal", color: "#3b82f6" },
  { value: 3, label: "Yüksek", color: "#f59e0b" },
  { value: 4, label: "Acil", color: "#dc2626" },
];

export function CreateAnnouncementModal({ onClose, onSuccess, userRole }: Props) {
  const [form, setForm] = useState<CreateAnnouncementForm>({
    title: "",
    content: "",
    summary: "",
    type: "announcement",
    target_scope: userRole === "sube_muduru" ? "my_branch" : "all_branches",
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
  const [selectedRegions, setSelectedRegions] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  useEffect(() => {
    loadBranchesAndRegions();
  }, []);

  const loadBranchesAndRegions = async () => {
    try {
      const [branchesRes, regionsRes] = await Promise.all([
        supabase.from("branches").select("id, name, region_id").eq("is_active", true).order("name"),
        supabase.from("regions").select("id, name").order("name"),
      ]);

      if (branchesRes.data) setBranches(branchesRes.data);
      if (regionsRes.data) setRegions(regionsRes.data);
    } catch (err) {
      console.error("Error loading branches:", err);
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

    try {
      setSaving(true);
      setError(null);

      // Call API route instead of RPC
      const response = await fetch("/api/announcements", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: form.title,
          content: form.content,
          summary: form.summary || null,
          target_scope: form.target_scope,
          target_branches: form.target_branches.length > 0 ? form.target_branches : null,
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
      
      onSuccess();
    } catch (err: unknown) {
      console.error("Error creating announcement:", err);
      const error = err as { message?: string };
      setError(error.message || "Duyuru oluşturulurken bir hata oluştu");
    } finally {
      setSaving(false);
    }
  };

  const availableScopes = TARGET_SCOPE_OPTIONS.filter(
    (opt) => !userRole || opt.roles.includes(userRole)
  );

  const handleBranchToggle = (branchId: string) => {
    setForm((prev) => ({
      ...prev,
      target_branches: prev.target_branches.includes(branchId)
        ? prev.target_branches.filter((id) => id !== branchId)
        : [...prev.target_branches, branchId],
    }));
  };

  const handleSelectAllBranches = () => {
    if (form.target_branches.length === branches.length) {
      setForm((prev) => ({ ...prev, target_branches: [] }));
    } else {
      setForm((prev) => ({ ...prev, target_branches: branches.map((b) => b.id) }));
    }
  };

  const handleRegionSelect = (regionId: string) => {
    const regionBranches = branches.filter((b) => b.region_id === regionId);
    const regionBranchIds = regionBranches.map((b) => b.id);
    
    const allSelected = regionBranchIds.every((id) => form.target_branches.includes(id));
    
    if (allSelected) {
      // Deselect all from this region
      setSelectedRegions((prev) => prev.filter((id) => id !== regionId));
      setForm((prev) => ({
        ...prev,
        target_branches: prev.target_branches.filter((id) => !regionBranchIds.includes(id)),
      }));
    } else {
      // Select all from this region
      setSelectedRegions((prev) => [...new Set([...prev, regionId])]);
      setForm((prev) => ({
        ...prev,
        target_branches: [...new Set([...prev.target_branches, ...regionBranchIds])],
      }));
    }
  };

  // Seçili bölgelerdeki şubeler
  const filteredBranches = userRole === "firma_admin" && selectedRegions.length > 0
    ? branches.filter(b => selectedRegions.includes(b.region_id || ""))
    : branches;

  // Bölgesiz şubeler
  const branchesWithoutRegion = branches.filter(b => !b.region_id);

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Yeni Duyuru</h2>
          <button className="close-btn" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            {error && (
              <div className="alert alert-error">
                <AlertTriangle size={18} />
                {error}
              </div>
            )}

            {/* Title */}
            <div className="form-group">
              <label>Başlık *</label>
              <input
                type="text"
                value={form.title}
                onChange={(e) => setForm((prev) => ({ ...prev, title: e.target.value }))}
                placeholder="Duyuru başlığı"
                maxLength={200}
              />
            </div>

            {/* Summary */}
            <div className="form-group">
              <label>Özet (opsiyonel)</label>
              <input
                type="text"
                value={form.summary || ""}
                onChange={(e) => setForm((prev) => ({ ...prev, summary: e.target.value }))}
                placeholder="Kısa özet (liste görünümünde gösterilir)"
                maxLength={300}
              />
            </div>

            {/* Content */}
            <div className="form-group">
              <label>İçerik *</label>
              <textarea
                value={form.content}
                onChange={(e) => setForm((prev) => ({ ...prev, content: e.target.value }))}
                placeholder="Duyuru içeriği..."
                rows={6}
              />
            </div>

            {/* Target Scope */}
            <div className="form-group">
              <label>Hedef Kitle</label>
              <div className="scope-options">
                {availableScopes.map((opt) => (
                  <label key={opt.value} className="scope-option">
                    <input
                      type="radio"
                      name="target_scope"
                      value={opt.value}
                      checked={form.target_scope === opt.value}
                      onChange={() => setForm((prev) => ({ ...prev, target_scope: opt.value }))}
                    />
                    <div className="scope-content">
                      <span className="scope-label">{opt.label}</span>
                      <span className="scope-desc">{opt.description}</span>
                    </div>
                  </label>
                ))}
              </div>
            </div>

            {/* Branch Selection */}
            {form.target_scope === "selected_branches" && (
              <div className="form-group">
                {/* Firma Admin için önce bölge seçimi */}
                {userRole === "firma_admin" && (
                  <>
                    <div className="branch-header">
                      <label>1. Bölge Seçimi ({selectedRegions.length} bölge seçili)</label>
                    </div>
                    <div className="regions-selection">
                      {regions.map((region) => {
                        const regionBranchCount = branches.filter(b => b.region_id === region.id).length;
                        const isSelected = selectedRegions.includes(region.id);
                        return (
                          <label key={region.id} className="region-checkbox-item">
                            <input
                              type="checkbox"
                              checked={isSelected}
                              onChange={() => handleRegionSelect(region.id)}
                            />
                            <MapPin size={14} />
                            <span>{region.name} ({regionBranchCount} şube)</span>
                          </label>
                        );
                      })}
                      {branchesWithoutRegion.length > 0 && (
                        <label className="region-checkbox-item no-region">
                          <input
                            type="checkbox"
                            checked={branchesWithoutRegion.every(b => form.target_branches.includes(b.id))}
                            onChange={() => {
                              const ids = branchesWithoutRegion.map(b => b.id);
                              const allSelected = ids.every(id => form.target_branches.includes(id));
                              setForm(prev => ({
                                ...prev,
                                target_branches: allSelected 
                                  ? prev.target_branches.filter(id => !ids.includes(id))
                                  : [...new Set([...prev.target_branches, ...ids])]
                              }));
                            }}
                          />
                          <span>Bölgesiz Şubeler ({branchesWithoutRegion.length})</span>
                        </label>
                      )}
                    </div>
                  </>
                )}

                {/* Şube Seçimi */}
                {(userRole !== "firma_admin" || selectedRegions.length > 0 || branchesWithoutRegion.some(b => form.target_branches.includes(b.id))) && (
                  <>
                    <div className="branch-header" style={{ marginTop: userRole === "firma_admin" ? "16px" : "0" }}>
                      <label>{userRole === "firma_admin" ? "2. Şube Seçimi" : "Şubeler"} ({form.target_branches.length} seçili)</label>
                      {filteredBranches.length > 0 && (
                        <button 
                          type="button" 
                          className="select-all-btn"
                          onClick={() => {
                            const targetBranches = filteredBranches.map(b => b.id);
                            const allSelected = targetBranches.every(id => form.target_branches.includes(id));
                            setForm(prev => ({
                              ...prev,
                              target_branches: allSelected 
                                ? prev.target_branches.filter(id => !targetBranches.includes(id))
                                : [...new Set([...prev.target_branches, ...targetBranches])]
                            }));
                          }}
                        >
                          {filteredBranches.every(b => form.target_branches.includes(b.id)) ? "Tümünü Kaldır" : "Tümünü Seç"}
                        </button>
                      )}
                    </div>
                    
                    <div className="regions-container">
                      {selectedRegions.length === 0 && userRole === "firma_admin" ? (
                        <p className="no-selection-hint">Şubeleri görmek için yukarıdan bölge seçin</p>
                      ) : (
                        (userRole === "firma_admin" ? selectedRegions : regions.map(r => r.id)).map((regionId) => {
                          const region = regions.find(r => r.id === regionId);
                          if (!region) return null;
                          
                          const regionBranches = branches.filter((b) => b.region_id === region.id);
                          const selectedCount = regionBranches.filter((b) => 
                            form.target_branches.includes(b.id)
                          ).length;

                          return (
                            <div key={region.id} className="region-group">
                              <div 
                                className="region-header"
                                onClick={() => handleRegionSelect(region.id)}
                              >
                                <MapPin size={16} />
                                <span>{region.name}</span>
                                <span className="count">{selectedCount}/{regionBranches.length}</span>
                              </div>
                              <div className="branch-list">
                                {regionBranches.map((branch) => (
                                  <label key={branch.id} className="branch-item">
                                    <input
                                      type="checkbox"
                                      checked={form.target_branches.includes(branch.id)}
                                      onChange={() => handleBranchToggle(branch.id)}
                                    />
                                    <span>{branch.name}</span>
                                  </label>
                                ))}
                              </div>
                            </div>
                          );
                        })
                      )}
                    </div>
                  </>
                )}
              </div>
            )}

            {/* Additional Options */}
            <div className="form-row">
              {/* Priority */}
              <div className="form-group">
                <label>Öncelik</label>
                <div className="priority-options">
                  {PRIORITY_OPTIONS.map((opt) => (
                    <button
                      key={opt.value}
                      type="button"
                      className={`priority-btn ${form.priority === opt.value ? "active" : ""}`}
                      style={{ "--priority-color": opt.color } as React.CSSProperties}
                      onClick={() => setForm((prev) => ({ ...prev, priority: opt.value }))}
                    >
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Expires At */}
              <div className="form-group">
                <label>Bitiş Tarihi (opsiyonel)</label>
                <input
                  type="date"
                  value={form.expires_at || ""}
                  onChange={(e) => setForm((prev) => ({ 
                    ...prev, 
                    expires_at: e.target.value || null 
                  }))}
                  min={new Date().toISOString().split("T")[0]}
                />
              </div>
            </div>

            {/* Checkboxes */}
            <div className="checkbox-group">
              <label className="checkbox-item">
                <input
                  type="checkbox"
                  checked={form.pinned}
                  onChange={(e) => setForm((prev) => ({ ...prev, pinned: e.target.checked }))}
                />
                <span>Sabitle (listenin başında göster)</span>
              </label>
              
              {form.target_scope !== "region_managers_only" && (
                <label className="checkbox-item">
                  <input
                    type="checkbox"
                    checked={form.managers_only}
                    onChange={(e) => setForm((prev) => ({ ...prev, managers_only: e.target.checked }))}
                  />
                  <span>Sadece müdürlere göster</span>
                </label>
              )}

              {userRole === "firma_admin" && form.target_scope !== "region_managers_only" && (
                <label className="checkbox-item">
                  <input
                    type="checkbox"
                    checked={form.include_region_managers}
                    onChange={(e) => setForm((prev) => ({ 
                      ...prev, 
                      include_region_managers: e.target.checked 
                    }))}
                  />
                  <span>Bölge müdürlerini de dahil et</span>
                </label>
              )}
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" className="btn btn-secondary" onClick={onClose}>
              İptal
            </button>
            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? "Kaydediliyor..." : "Yayınla"}
            </button>
          </div>
        </form>

        <style jsx>{`
          .modal-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.5);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 1000;
            padding: 20px;
          }

          .modal-content {
            background: white;
            border-radius: 12px;
            width: 100%;
            max-width: 640px;
            max-height: 90vh;
            overflow: hidden;
            display: flex;
            flex-direction: column;
          }

          .modal-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 20px 24px;
            border-bottom: 1px solid #e2e8f0;
          }

          .modal-header h2 {
            margin: 0;
            font-size: 20px;
          }

          .close-btn {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 32px;
            height: 32px;
            border: none;
            background: transparent;
            cursor: pointer;
            border-radius: 6px;
            color: #64748b;
          }

          .close-btn:hover {
            background: #f1f5f9;
          }

          .modal-body {
            padding: 24px;
            overflow-y: auto;
            flex: 1;
          }

          .modal-footer {
            display: flex;
            justify-content: flex-end;
            gap: 12px;
            padding: 16px 24px;
            border-top: 1px solid #e2e8f0;
          }

          .form-group {
            margin-bottom: 20px;
          }

          .form-group label {
            display: block;
            font-weight: 500;
            margin-bottom: 8px;
            font-size: 14px;
          }

          .form-group input[type="text"],
          .form-group input[type="date"],
          .form-group textarea {
            width: 100%;
            padding: 10px 12px;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            font-size: 14px;
            transition: border-color 0.2s;
          }

          .form-group input:focus,
          .form-group textarea:focus {
            outline: none;
            border-color: #3b82f6;
          }

          .form-group textarea {
            resize: vertical;
            min-height: 120px;
          }

          .form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
          }

          .scope-options {
            display: flex;
            flex-direction: column;
            gap: 8px;
          }

          .scope-option {
            display: flex;
            align-items: flex-start;
            gap: 12px;
            padding: 12px;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.2s;
          }

          .scope-option:hover {
            background: #f8fafc;
          }

          .scope-option:has(input:checked) {
            background: #eff6ff;
            border-color: #3b82f6;
          }

          .scope-option input {
            margin-top: 2px;
          }

          .scope-content {
            display: flex;
            flex-direction: column;
          }

          .scope-label {
            font-weight: 500;
          }

          .scope-desc {
            font-size: 12px;
            color: #64748b;
          }

          .branch-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
          }

          .select-all-btn {
            padding: 4px 12px;
            font-size: 12px;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
            background: white;
            cursor: pointer;
          }

          .select-all-btn:hover {
            background: #f1f5f9;
          }

          .regions-container {
            max-height: 250px;
            overflow-y: auto;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            margin-top: 8px;
          }

          .region-group {
            border-bottom: 1px solid #e2e8f0;
          }

          .region-group:last-child {
            border-bottom: none;
          }

          .region-header {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 10px 12px;
            background: #f8fafc;
            font-weight: 500;
            cursor: pointer;
          }

          .region-header:hover {
            background: #f1f5f9;
          }

          .region-header .count {
            margin-left: auto;
            font-size: 12px;
            color: #64748b;
          }

          .branch-list {
            padding: 8px 12px 8px 32px;
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 4px;
          }

          .branch-item {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 4px;
            font-size: 13px;
            cursor: pointer;
          }

          .priority-options {
            display: flex;
            gap: 8px;
          }

          .priority-btn {
            flex: 1;
            padding: 8px 12px;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
            background: white;
            cursor: pointer;
            font-size: 13px;
            transition: all 0.2s;
          }

          .priority-btn:hover {
            background: #f8fafc;
          }

          .priority-btn.active {
            background: var(--priority-color);
            color: white;
            border-color: var(--priority-color);
          }

          .checkbox-group {
            display: flex;
            flex-direction: column;
            gap: 12px;
          }

          .checkbox-item {
            display: flex;
            align-items: center;
            gap: 8px;
            cursor: pointer;
          }

          .alert {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 16px;
          }

          .alert-error {
            background: #fef2f2;
            color: #dc2626;
            border: 1px solid #fecaca;
          }

          .btn {
            padding: 10px 20px;
            border-radius: 8px;
            font-weight: 500;
            cursor: pointer;
            border: none;
            transition: all 0.2s;
          }

          .btn-primary {
            background: #3b82f6;
            color: white;
          }

          .btn-primary:hover:not(:disabled) {
            background: #2563eb;
          }

          .btn-primary:disabled {
            opacity: 0.6;
            cursor: not-allowed;
          }

          .btn-secondary {
            background: #f1f5f9;
            color: #334155;
          }

          .btn-secondary:hover {
            background: #e2e8f0;
          }

          .regions-selection {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            padding: 12px;
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            max-height: 150px;
            overflow-y: auto;
          }

          .region-checkbox-item {
            display: flex;
            align-items: center;
            gap: 6px;
            padding: 6px 12px;
            background: white;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
            cursor: pointer;
            font-size: 13px;
            transition: all 0.2s;
          }

          .region-checkbox-item:hover {
            border-color: #3b82f6;
          }

          .region-checkbox-item:has(input:checked) {
            background: #eff6ff;
            border-color: #3b82f6;
          }

          .region-checkbox-item.no-region {
            background: #fef3c7;
            border-color: #fcd34d;
          }

          .no-selection-hint {
            text-align: center;
            padding: 24px;
            color: #64748b;
            font-size: 14px;
          }
        `}</style>
      </div>
    </div>
  );
}
