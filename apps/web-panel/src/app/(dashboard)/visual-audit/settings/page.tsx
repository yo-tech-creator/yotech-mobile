"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { ArrowLeft, Plus, Pencil, Trash2, Check, X, Loader2, ToggleLeft, ToggleRight } from "lucide-react";
import { toast } from "sonner";
import { getSections, createSection, updateSection, deleteSection, toggleSectionActive } from "../actions";
import "../visual-audit.css";

interface Section {
  id: string;
  name: string;
  color: string;
  is_active: boolean;
}

const COLORS = [
  "#ef4444", "#f97316", "#f59e0b", "#eab308", 
  "#84cc16", "#22c55e", "#10b981", "#14b8a6",
  "#06b6d4", "#0ea5e9", "#3b82f6", "#6366f1",
  "#8b5cf6", "#a855f7", "#d946ef", "#ec4899",
];

export default function VisualAuditSettingsPage() {
  const [sections, setSections] = useState<Section[]>([]);
  const [loading, setLoading] = useState(true);
  
  // New section form
  const [showNewForm, setShowNewForm] = useState(false);
  const [newName, setNewName] = useState("");
  const [newColor, setNewColor] = useState(COLORS[0]);
  const [creating, setCreating] = useState(false);
  
  // Edit section
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [editColor, setEditColor] = useState("");
  const [saving, setSaving] = useState(false);

  const fetchSections = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getSections(true); // Tüm bölümleri getir (aktif ve pasif)
      setSections(data);
    } catch (error) {
      console.error("Error fetching sections:", error);
      toast.error("Bölümler yüklenemedi");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchSections();
  }, [fetchSections]);

  const handleCreate = async () => {
    if (!newName.trim()) {
      toast.error("Bölüm adı gerekli");
      return;
    }

    setCreating(true);
    try {
      const result = await createSection(newName.trim(), newColor);
      if (!result.success) throw new Error(result.error);
      
      toast.success("Bölüm eklendi");
      setNewName("");
      setNewColor(COLORS[0]);
      setShowNewForm(false);
      fetchSections();
    } catch (error) {
      const msg = error instanceof Error ? error.message : "Bölüm eklenemedi";
      toast.error(msg);
    } finally {
      setCreating(false);
    }
  };

  const startEdit = (section: Section) => {
    setEditingId(section.id);
    setEditName(section.name);
    setEditColor(section.color);
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditName("");
    setEditColor("");
  };

  const handleUpdate = async () => {
    if (!editingId || !editName.trim()) return;

    setSaving(true);
    try {
      const result = await updateSection(editingId, editName.trim(), editColor);
      if (!result.success) throw new Error(result.error);
      
      toast.success("Bölüm güncellendi");
      cancelEdit();
      fetchSections();
    } catch (error) {
      const msg = error instanceof Error ? error.message : "Bölüm güncellenemedi";
      toast.error(msg);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`"${name}" bölümünü kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.`)) return;

    try {
      const result = await deleteSection(id);
      if (!result.success) throw new Error(result.error);
      
      toast.success("Bölüm silindi");
      fetchSections();
    } catch (error) {
      const msg = error instanceof Error ? error.message : "Bölüm silinemedi";
      toast.error(msg);
    }
  };

  const handleToggleActive = async (id: string, currentlyActive: boolean) => {
    try {
      const result = await toggleSectionActive(id, !currentlyActive);
      if (!result.success) throw new Error(result.error);
      
      toast.success(currentlyActive ? "Bölüm pasif yapıldı" : "Bölüm aktif yapıldı");
      fetchSections();
    } catch (error) {
      const msg = error instanceof Error ? error.message : "İşlem başarısız";
      toast.error(msg);
    }
  };

  return (
    <div className="va-page">
      {/* Header */}
      <div className="va-page-header">
        <div className="va-header-content">
          <h1>Görsel Denetim Ayarları</h1>
          <p>Denetim bölümlerini yönetin</p>
        </div>
        <Link href="/visual-audit" className="va-btn-ghost">
          <ArrowLeft size={18} />
          Geri
        </Link>
      </div>

      {/* Sections */}
      <div className="va-settings-card">
        <div className="va-settings-header">
          <h3>Bölümler</h3>
          <p>Fotoğraf çekilecek alanları tanımlayın (Mutfak, Depo, Vitrin vb.)</p>
        </div>

        {loading ? (
          <div className="va-loading">
            <Loader2 size={32} className="va-spinner" />
            <span>Yükleniyor...</span>
          </div>
        ) : (
          <div className="va-section-list">
            {sections.length === 0 && !showNewForm && (
              <div className="va-empty-inline">Henüz bölüm eklenmedi</div>
            )}
            {sections.map(section => (
              <div key={section.id} className="va-section-item">
                {editingId === section.id ? (
                  // Edit mode
                  <div className="va-section-edit">
                    <input
                      type="text"
                      value={editName}
                      onChange={e => setEditName(e.target.value)}
                      className="va-input"
                      placeholder="Bölüm adı"
                    />
                    <div className="va-color-picker">
                      {COLORS.map(c => (
                        <button
                          key={c}
                          className={`va-color-btn ${editColor === c ? "active" : ""}`}
                          style={{ background: c }}
                          onClick={() => setEditColor(c)}
                        />
                      ))}
                    </div>
                    <div className="va-section-actions">
                      <button className="va-icon-btn success" onClick={handleUpdate} disabled={saving}>
                        <Check size={18} />
                      </button>
                      <button className="va-icon-btn muted" onClick={cancelEdit}>
                        <X size={18} />
                      </button>
                    </div>
                  </div>
                ) : (
                  // View mode
                  <>
                    <div className="va-section-info">
                      <span className="va-section-color" style={{ background: section.color, opacity: section.is_active ? 1 : 0.4 }} />
                      <span className={`va-section-name ${!section.is_active ? "va-section-inactive" : ""}`}>
                        {section.name}
                        {!section.is_active && <span className="va-inactive-badge">Pasif</span>}
                      </span>
                    </div>
                    <div className="va-section-actions">
                      <button 
                        className={`va-icon-btn ${section.is_active ? "success" : "muted"}`}
                        onClick={() => handleToggleActive(section.id, section.is_active)}
                        title={section.is_active ? "Pasif yap" : "Aktif yap"}
                      >
                        {section.is_active ? <ToggleRight size={18} /> : <ToggleLeft size={18} />}
                      </button>
                      <button className="va-icon-btn" onClick={() => startEdit(section)}>
                        <Pencil size={16} />
                      </button>
                      <button className="va-icon-btn danger" onClick={() => handleDelete(section.id, section.name)}>
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </>
                )}
              </div>
            ))}

            {/* New section form */}
            {showNewForm && (
              <div className="va-section-item va-section-new">
                <input
                  type="text"
                  value={newName}
                  onChange={e => setNewName(e.target.value)}
                  className="va-input"
                  placeholder="Yeni bölüm adı..."
                  autoFocus
                />
                <div className="va-color-picker">
                  {COLORS.map(c => (
                    <button
                      key={c}
                      className={`va-color-btn ${newColor === c ? "active" : ""}`}
                      style={{ background: c }}
                      onClick={() => setNewColor(c)}
                    />
                  ))}
                </div>
                <div className="va-section-actions">
                  <button className="va-icon-btn success" onClick={handleCreate} disabled={creating}>
                    <Check size={18} />
                  </button>
                  <button className="va-icon-btn muted" onClick={() => setShowNewForm(false)}>
                    <X size={18} />
                  </button>
                </div>
              </div>
            )}
          </div>
        )}

        {!showNewForm && (
          <div className="va-settings-footer">
            <button className="va-btn-primary" onClick={() => setShowNewForm(true)}>
              <Plus size={18} />
              Yeni Bölüm Ekle
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
