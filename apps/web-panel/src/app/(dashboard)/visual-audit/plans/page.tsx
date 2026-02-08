"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { ArrowLeft, Edit2, Trash2, Copy, Clock, Calendar, Building2, Layers, CheckCircle, Loader2, X, Save, AlertCircle } from "lucide-react";
import { toast } from "sonner";
import { getPlans, getSections, getBranches, updatePlan, deletePlan, copyPlan, Plan } from "../actions";
import "../visual-audit.css";

// Helper function to get Turkey timezone date string (YYYY-MM-DD)
function getTurkeyDateString(date?: Date): string {
  const d = date || new Date();
  return d.toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
}

interface Section {
  id: string;
  name: string;
  color: string;
  is_active: boolean;
}

interface Branch {
  id: string;
  name: string;
}

const dayNames = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"];
const dayNamesFull = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"];

export default function PlansPage() {
  const [plans, setPlans] = useState<Plan[]>([]);
  const [sections, setSections] = useState<Section[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [loading, setLoading] = useState(true);
  
  // Modal states
  const [showForm, setShowForm] = useState(false);
  const [editingPlan, setEditingPlan] = useState<Plan | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState<Plan | null>(null);
  const [showCopyModal, setShowCopyModal] = useState<Plan | null>(null);
  const [saving, setSaving] = useState(false);
  
  // Form state
  const [form, setForm] = useState({
    name: "",
    section_ids: [] as string[],
    branch_ids: [] as string[],
    scheduled_hour: 9,
    deadline_minutes: 60,
    min_photos: 1,
    notes: "",
    recurrence: "daily" as "daily" | "weekly",
    recurrence_days: [] as number[],
    start_date: getTurkeyDateString(),
    end_date: getTurkeyDateString(new Date(Date.now() + 14 * 24 * 60 * 60 * 1000)),
  });
  
  // Copy form state
  const [copyForm, setCopyForm] = useState({
    name: "",
    start_date: getTurkeyDateString(),
    end_date: "",
  });
  
  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [plansData, sectionsData, branchesData] = await Promise.all([
        getPlans(),
        getSections(),
        getBranches(),
      ]);
      setPlans(plansData);
      setSections(sectionsData);
      setBranches(branchesData);
    } catch (error) {
      console.error("Error fetching data:", error);
      toast.error("Veriler yüklenirken hata oluştu");
    } finally {
      setLoading(false);
    }
  }, []);
  
  useEffect(() => {
    fetchData();
  }, [fetchData]);
  
  const resetForm = () => {
    setForm({
      name: "",
      section_ids: [],
      branch_ids: [],
      scheduled_hour: 9,
      deadline_minutes: 60,
      min_photos: 1,
      notes: "",
      recurrence: "daily",
      recurrence_days: [],
      start_date: getTurkeyDateString(),
      end_date: getTurkeyDateString(new Date(Date.now() + 14 * 24 * 60 * 60 * 1000)),
    });
    setEditingPlan(null);
    setShowForm(false);
  };
  
  const openEditForm = (plan: Plan) => {
    setEditingPlan(plan);
    setForm({
      name: plan.name,
      section_ids: plan.section_ids,
      branch_ids: plan.branch_ids,
      scheduled_hour: plan.scheduled_hour,
      deadline_minutes: plan.deadline_minutes,
      min_photos: plan.min_photos,
      notes: plan.notes || "",
      recurrence: plan.recurrence,
      recurrence_days: plan.recurrence_days,
      start_date: plan.start_date,
      end_date: plan.end_date,
    });
    setShowForm(true);
  };
  
  const openCopyModal = (plan: Plan) => {
    const duration = new Date(plan.end_date).getTime() - new Date(plan.start_date).getTime();
    const startDate = getTurkeyDateString();
    const endDate = getTurkeyDateString(new Date(Date.now() + duration));
    
    setCopyForm({
      name: plan.name + " (Kopya)",
      start_date: startDate,
      end_date: endDate,
    });
    setShowCopyModal(plan);
  };
  
  const toggleSection = (id: string) => {
    setForm(prev => ({
      ...prev,
      section_ids: prev.section_ids.includes(id)
        ? prev.section_ids.filter(s => s !== id)
        : [...prev.section_ids, id],
    }));
  };
  
  const toggleBranch = (id: string) => {
    setForm(prev => ({
      ...prev,
      branch_ids: prev.branch_ids.includes(id)
        ? prev.branch_ids.filter(b => b !== id)
        : [...prev.branch_ids, id],
    }));
  };
  
  const toggleDay = (day: number) => {
    setForm(prev => ({
      ...prev,
      recurrence_days: prev.recurrence_days.includes(day)
        ? prev.recurrence_days.filter(d => d !== day)
        : [...prev.recurrence_days, day].sort(),
    }));
  };
  
  const handleSubmit = async () => {
    if (form.section_ids.length === 0) {
      toast.error("En az bir bölüm seçmelisiniz");
      return;
    }
    
    if (form.recurrence === "weekly" && form.recurrence_days.length === 0) {
      toast.error("Haftanın en az bir gününü seçmelisiniz");
      return;
    }
    
    if (!editingPlan) {
      toast.error("Düzenlenecek plan bulunamadı");
      return;
    }
    
    if (!form.name.trim()) {
      // Auto-generate name
      const sectionNames = sections
        .filter(s => form.section_ids.includes(s.id))
        .map(s => s.name)
        .join(" + ");
      const timeStr = `${String(form.scheduled_hour).padStart(2, "0")}:00`;
      const daysStr = form.recurrence === "daily" 
        ? "Her Gün" 
        : form.recurrence_days.map(d => dayNames[d]).join("/");
      form.name = `${sectionNames} - ${daysStr} ${timeStr}`;
    }
    
    setSaving(true);
    try {
      // Update existing plan
      const result = await updatePlan(editingPlan.id, {
        name: form.name,
        section_ids: form.section_ids,
        branch_ids: form.branch_ids,
        scheduled_hour: form.scheduled_hour,
        deadline_minutes: form.deadline_minutes,
        min_photos: form.min_photos,
        notes: form.notes,
        recurrence: form.recurrence,
        recurrence_days: form.recurrence_days,
        end_date: form.end_date,
      });
      
      if (!result.success) {
        throw new Error(result.error);
      }
      
      toast.success(`Plan güncellendi. ${result.data.tasks_created} görev oluşturuldu, ${result.data.tasks_deleted} silindi, ${result.data.tasks_updated} güncellendi.`);
      
      resetForm();
      fetchData();
    } catch (error) {
      console.error("Error saving plan:", error);
      toast.error(error instanceof Error ? error.message : "Plan kaydedilemedi");
    } finally {
      setSaving(false);
    }
  };
  
  const handleDelete = async (plan: Plan) => {
    setSaving(true);
    try {
      const result = await deletePlan(plan.id);
      if (!result.success) {
        throw new Error(result.error);
      }
      
      toast.success(`Plan silindi. ${result.data.tasks_deleted} bekleyen görev silindi.`);
      setShowDeleteConfirm(null);
      fetchData();
    } catch (error) {
      console.error("Error deleting plan:", error);
      toast.error(error instanceof Error ? error.message : "Plan silinemedi");
    } finally {
      setSaving(false);
    }
  };
  
  const handleCopy = async () => {
    if (!showCopyModal) return;
    
    setSaving(true);
    try {
      const result = await copyPlan(
        showCopyModal.id,
        copyForm.name,
        copyForm.start_date,
        copyForm.end_date || undefined
      );
      
      if (!result.success) {
        throw new Error(result.error);
      }
      
      toast.success(`Plan kopyalandı. ${result.data.tasks_created} görev oluşturuldu.`);
      setShowCopyModal(null);
      fetchData();
    } catch (error) {
      console.error("Error copying plan:", error);
      toast.error(error instanceof Error ? error.message : "Plan kopyalanamadı");
    } finally {
      setSaving(false);
    }
  };
  
  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString("tr-TR", {
      day: "numeric",
      month: "short",
      year: "numeric",
    });
  };
  
  const getRecurrenceText = (plan: Plan) => {
    if (plan.recurrence === "daily") {
      return "Her Gün";
    }
    return plan.recurrence_days.map(d => dayNames[d]).join(", ");
  };
  
  const getPlanProgress = (plan: Plan) => {
    if (plan.total_tasks === 0) return 0;
    return Math.round((plan.completed_tasks / plan.total_tasks) * 100);
  };

  if (loading) {
    return (
      <div className="va-container">
        <div className="va-loading">
          <Loader2 className="va-spinner" size={32} />
          <span>Yükleniyor...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="va-container">
      {/* Header */}
      <div className="va-header">
        <div className="va-header-left">
          <Link href="/visual-audit" className="va-back-link">
            <ArrowLeft size={20} />
          </Link>
          <div>
            <h1>Görev Planları</h1>
            <p className="va-subtitle">Tekrar eden görevleri yönetin</p>
          </div>
        </div>
      </div>
      
      {/* Plans Grid */}
      {plans.length === 0 ? (
        <div className="va-empty-state">
          <Calendar size={48} />
          <h3>Henüz plan yok</h3>
          <p>Ana sayfadan tekrarlı görev oluşturduğunuzda planlar burada görünecek</p>
        </div>
      ) : (
        <div className="va-plans-grid">
          {plans.map(plan => (
            <div key={plan.id} className={`va-plan-card ${!plan.is_active ? "inactive" : ""}`}>
              <div className="va-plan-header">
                <h3 className="va-plan-name">{plan.name}</h3>
                <div className="va-plan-actions">
                  <button className="va-icon-btn" onClick={() => openCopyModal(plan)} title="Kopyala">
                    <Copy size={16} />
                  </button>
                  <button className="va-icon-btn" onClick={() => openEditForm(plan)} title="Düzenle">
                    <Edit2 size={16} />
                  </button>
                  <button className="va-icon-btn danger" onClick={() => setShowDeleteConfirm(plan)} title="Sil">
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
              
              <div className="va-plan-meta">
                <div className="va-plan-meta-item">
                  <Layers size={14} />
                  <span>{plan.section_names?.join(", ") || `${plan.section_ids.length} bölüm`}</span>
                </div>
                <div className="va-plan-meta-item">
                  <Building2 size={14} />
                  <span>{plan.branch_names?.length ? plan.branch_names.join(", ") : `${plan.branch_ids.length} şube`}</span>
                </div>
                <div className="va-plan-meta-item">
                  <Clock size={14} />
                  <span>{String(plan.scheduled_hour).padStart(2, "0")}:00</span>
                </div>
                <div className="va-plan-meta-item">
                  <Calendar size={14} />
                  <span>{getRecurrenceText(plan)}</span>
                </div>
              </div>
              
              <div className="va-plan-dates">
                <span>{formatDate(plan.start_date)}</span>
                <span>→</span>
                <span>{formatDate(plan.end_date)}</span>
              </div>
              
              <div className="va-plan-progress">
                <div className="va-plan-progress-bar">
                  <div 
                    className="va-plan-progress-fill" 
                    style={{ width: `${getPlanProgress(plan)}%` }}
                  />
                </div>
                <div className="va-plan-progress-stats">
                  <span className="completed">
                    <CheckCircle size={12} />
                    {plan.completed_tasks}
                  </span>
                  <span className="pending">
                    <Clock size={12} />
                    {plan.pending_tasks}
                  </span>
                  <span className="total">{plan.total_tasks} toplam</span>
                </div>
              </div>
              
              {!plan.is_active && (
                <div className="va-plan-badge inactive">Pasif</div>
              )}
            </div>
          ))}
        </div>
      )}
      
      {/* Form Modal */}
      {showForm && editingPlan && (
        <div className="va-modal-overlay" onClick={() => !saving && resetForm()}>
          <div className="va-modal va-modal-lg" onClick={e => e.stopPropagation()}>
            <div className="va-modal-header">
              <h2>Planı Düzenle</h2>
              <button className="va-close-btn" onClick={() => !saving && resetForm()} disabled={saving}>
                <X size={20} />
              </button>
            </div>
            
            <div className="va-modal-body">
              {/* Plan Name */}
              <div className="va-form-group">
                <label>Plan Adı <span className="va-hint">(Boş bırakılırsa otomatik oluşturulur)</span></label>
                <input
                  type="text"
                  value={form.name}
                  onChange={e => setForm({ ...form, name: e.target.value })}
                  placeholder="Örn: Depo Kontrolü - Hafta İçi 09:00"
                  className="va-input"
                />
              </div>
              
              {/* Sections */}
              <div className="va-form-group">
                <label>Bölümler *</label>
                <div className="va-chip-list">
                  {sections.map(s => (
                    <button
                      key={s.id}
                      className={`va-chip ${form.section_ids.includes(s.id) ? "active" : ""}`}
                      style={{ borderColor: s.color, background: form.section_ids.includes(s.id) ? s.color : undefined }}
                      onClick={() => toggleSection(s.id)}
                    >
                      {s.name}
                    </button>
                  ))}
                  {sections.length === 0 && (
                    <p className="va-empty-text">Önce Ayarlar&apos;dan bölüm ekleyin</p>
                  )}
                </div>
              </div>
              
              {/* Branches */}
              <div className="va-form-group">
                <label>Şubeler <span className="va-hint">(Boş = Tüm şubeler)</span></label>
                <div className="va-chip-list va-chip-list-scroll">
                  {branches.map(b => (
                    <button
                      key={b.id}
                      className={`va-chip ${form.branch_ids.includes(b.id) ? "active" : ""}`}
                      onClick={() => toggleBranch(b.id)}
                    >
                      {b.name}
                    </button>
                  ))}
                </div>
              </div>
              
              {/* Time Options */}
              <div className="va-form-row">
                <div className="va-form-group">
                  <label>Görev Saati</label>
                  <select
                    value={form.scheduled_hour}
                    onChange={e => setForm({ ...form, scheduled_hour: parseInt(e.target.value) })}
                    className="va-select"
                  >
                    {Array.from({ length: 17 }, (_, i) => i + 6).map(hour => (
                      <option key={hour} value={hour}>
                        {String(hour).padStart(2, "0")}:00
                      </option>
                    ))}
                  </select>
                </div>
                <div className="va-form-group">
                  <label>Süre Limiti</label>
                  <select
                    value={form.deadline_minutes}
                    onChange={e => setForm({ ...form, deadline_minutes: parseInt(e.target.value) })}
                    className="va-select"
                  >
                    <option value={30}>30 dakika</option>
                    <option value={60}>1 saat</option>
                    <option value={120}>2 saat</option>
                    <option value={240}>4 saat</option>
                    <option value={480}>8 saat</option>
                  </select>
                </div>
                <div className="va-form-group">
                  <label>Min. Fotoğraf</label>
                  <select
                    value={form.min_photos}
                    onChange={e => setForm({ ...form, min_photos: parseInt(e.target.value) })}
                    className="va-select"
                  >
                    <option value={1}>1 fotoğraf</option>
                    <option value={2}>2 fotoğraf</option>
                    <option value={3}>3 fotoğraf</option>
                    <option value={5}>5 fotoğraf</option>
                  </select>
                </div>
              </div>
              
              {/* Recurrence */}
              <div className="va-form-group">
                <label>Tekrar Tipi</label>
                <div className="va-recurrence-options">
                  <button
                    type="button"
                    className={`va-chip ${form.recurrence === "daily" ? "active" : ""}`}
                    onClick={() => setForm({ ...form, recurrence: "daily", recurrence_days: [] })}
                  >
                    Her Gün
                  </button>
                  <button
                    type="button"
                    className={`va-chip ${form.recurrence === "weekly" ? "active" : ""}`}
                    onClick={() => setForm({ ...form, recurrence: "weekly" })}
                  >
                    Haftanın Günleri
                  </button>
                </div>
              </div>
              
              {/* Day Selection for Weekly */}
              {form.recurrence === "weekly" && (
                <div className="va-form-group">
                  <label>Günler *</label>
                  <div className="va-day-selector">
                    {dayNamesFull.map((name, index) => (
                      <button
                        key={index}
                        type="button"
                        className={`va-day-btn ${form.recurrence_days.includes(index) ? "active" : ""}`}
                        onClick={() => toggleDay(index)}
                      >
                        {name}
                      </button>
                    ))}
                  </div>
                </div>
              )}
              
              {/* Date Range */}
              <div className="va-form-row">
                <div className="va-form-group">
                  <label>Başlangıç Tarihi</label>
                  <input
                    type="date"
                    value={form.start_date}
                    onChange={e => setForm({ ...form, start_date: e.target.value })}
                    className="va-input"
                    disabled={!!editingPlan}
                  />
                </div>
                <div className="va-form-group">
                  <label>Bitiş Tarihi</label>
                  <input
                    type="date"
                    value={form.end_date}
                    onChange={e => setForm({ ...form, end_date: e.target.value })}
                    min={form.start_date}
                    className="va-input"
                  />
                </div>
              </div>
              
              {/* Notes */}
              <div className="va-form-group">
                <label>Not <span className="va-hint">(Opsiyonel)</span></label>
                <input
                  type="text"
                  value={form.notes}
                  onChange={e => setForm({ ...form, notes: e.target.value })}
                  placeholder="Personele iletilecek not..."
                  className="va-input"
                />
              </div>
            </div>
            
            <div className="va-modal-footer">
              <button className="va-btn va-btn-secondary" onClick={() => !saving && resetForm()} disabled={saving}>
                İptal
              </button>
              <button className="va-btn va-btn-primary" onClick={handleSubmit} disabled={saving}>
                {saving ? <Loader2 className="va-spinner" size={18} /> : <Save size={18} />}
                Güncelle
              </button>
            </div>
          </div>
        </div>
      )}
      
      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div className="va-modal-overlay" onClick={() => !saving && setShowDeleteConfirm(null)}>
          <div className="va-modal va-modal-sm" onClick={e => e.stopPropagation()}>
            <div className="va-modal-header">
              <h2>Planı Sil</h2>
              <button className="va-close-btn" onClick={() => !saving && setShowDeleteConfirm(null)} disabled={saving}>
                <X size={20} />
              </button>
            </div>
            
            <div className="va-modal-body">
              <div className="va-delete-warning">
                <AlertCircle size={48} />
                <p><strong>{showDeleteConfirm.name}</strong> planını silmek istediğinize emin misiniz?</p>
                <p className="va-hint">Bu işlem geri alınamaz. {showDeleteConfirm.pending_tasks} bekleyen görev silinecek, tamamlananlar korunacaktır.</p>
              </div>
            </div>
            
            <div className="va-modal-footer">
              <button className="va-btn va-btn-secondary" onClick={() => setShowDeleteConfirm(null)} disabled={saving}>
                İptal
              </button>
              <button className="va-btn va-btn-danger" onClick={() => handleDelete(showDeleteConfirm)} disabled={saving}>
                {saving ? <Loader2 className="va-spinner" size={18} /> : <Trash2 size={18} />}
                Sil
              </button>
            </div>
          </div>
        </div>
      )}
      
      {/* Copy Modal */}
      {showCopyModal && (
        <div className="va-modal-overlay" onClick={() => !saving && setShowCopyModal(null)}>
          <div className="va-modal va-modal-sm" onClick={e => e.stopPropagation()}>
            <div className="va-modal-header">
              <h2>Planı Kopyala</h2>
              <button className="va-close-btn" onClick={() => !saving && setShowCopyModal(null)} disabled={saving}>
                <X size={20} />
              </button>
            </div>
            
            <div className="va-modal-body">
              <div className="va-form-group">
                <label>Yeni Plan Adı</label>
                <input
                  type="text"
                  value={copyForm.name}
                  onChange={e => setCopyForm({ ...copyForm, name: e.target.value })}
                  className="va-input"
                />
              </div>
              
              <div className="va-form-row">
                <div className="va-form-group">
                  <label>Başlangıç Tarihi</label>
                  <input
                    type="date"
                    value={copyForm.start_date}
                    onChange={e => setCopyForm({ ...copyForm, start_date: e.target.value })}
                    className="va-input"
                  />
                </div>
                <div className="va-form-group">
                  <label>Bitiş Tarihi <span className="va-hint">(Boş = aynı süre)</span></label>
                  <input
                    type="date"
                    value={copyForm.end_date}
                    onChange={e => setCopyForm({ ...copyForm, end_date: e.target.value })}
                    min={copyForm.start_date}
                    className="va-input"
                  />
                </div>
              </div>
            </div>
            
            <div className="va-modal-footer">
              <button className="va-btn va-btn-secondary" onClick={() => setShowCopyModal(null)} disabled={saving}>
                İptal
              </button>
              <button className="va-btn va-btn-primary" onClick={handleCopy} disabled={saving}>
                {saving ? <Loader2 className="va-spinner" size={18} /> : <Copy size={18} />}
                Kopyala
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
