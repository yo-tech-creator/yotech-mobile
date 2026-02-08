"use client";

import { useState, useEffect } from "react";
import { createBrowserClient } from "@supabase/ssr";
import { 
  X, 
  Plus, 
  Trash2, 
  GripVertical, 
  AlertTriangle,
  Type,
  List,
  ToggleLeft,
  Star,
  Hash,
  MessageSquare
} from "lucide-react";
import type { 
  TargetScope, 
  CreateSurveyForm, 
  SurveyQuestionType,
  CreateSurveyQuestion,
  Branch, 
  Region 
} from "@/types/announcements";

interface Props {
  onClose: () => void;
  onSuccess: () => void;
  userRole: string | null;
}

const QUESTION_TYPES: { value: SurveyQuestionType; label: string; icon: React.ReactNode; description: string }[] = [
  { value: "text", label: "Kısa Metin", icon: <Type size={16} />, description: "Kısa metin yanıtı" },
  { value: "textarea", label: "Uzun Metin", icon: <MessageSquare size={16} />, description: "Uzun metin yanıtı" },
  { value: "single_choice", label: "Tek Seçim", icon: <List size={16} />, description: "Birden fazla seçenek, tek cevap" },
  { value: "multiple_choice", label: "Çoklu Seçim", icon: <List size={16} />, description: "Birden fazla seçenek seçilebilir" },
  { value: "rating", label: "Puanlama", icon: <Star size={16} />, description: "1-5 arası yıldız puanı" },
  { value: "number", label: "Sayı", icon: <Hash size={16} />, description: "Sayısal değer" },
  { value: "yes_no", label: "Evet/Hayır", icon: <ToggleLeft size={16} />, description: "İki seçenekli cevap" },
];

const TARGET_SCOPE_OPTIONS: { value: TargetScope; label: string; roles: string[] }[] = [
  { value: "all_branches", label: "Tüm Şubeler", roles: ["firma_admin"] },
  { value: "selected_branches", label: "Seçili Şubeler", roles: ["firma_admin", "bolge_muduru"] },
  { value: "my_branches", label: "Bölgemdeki Şubeler", roles: ["bolge_muduru"] },
  { value: "my_branch", label: "Sadece Şubem", roles: ["sube_muduru"] },
];

const createEmptyQuestion = (sortOrder: number): CreateSurveyQuestion => ({
  question_text: "",
  question_type: "text",
  options: null,
  required: true,
  sort_order: sortOrder,
});

export function CreateSurveyModal({ onClose, onSuccess, userRole }: Props) {
  const [form, setForm] = useState<CreateSurveyForm>({
    title: "",
    content: "",
    summary: "",
    type: "survey",
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
    questions: [createEmptyQuestion(1)],
  });
  
  const [branches, setBranches] = useState<Branch[]>([]);
  const [regions, setRegions] = useState<Region[]>([]);
  const [selectedRegions, setSelectedRegions] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [step, setStep] = useState<1 | 2>(1); // 1: Basic info, 2: Questions

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
    
    // Validate
    if (!form.title.trim()) {
      setError("Başlık zorunludur");
      setStep(1);
      return;
    }
    
    if (!form.content.trim()) {
      setError("Açıklama zorunludur");
      setStep(1);
      return;
    }

    if (form.questions.length === 0) {
      setError("En az bir soru eklenmelidir");
      setStep(2);
      return;
    }

    const invalidQuestion = form.questions.find((q) => !q.question_text.trim());
    if (invalidQuestion) {
      setError("Tüm soruların metni doldurulmalıdır");
      setStep(2);
      return;
    }

    const choiceQuestion = form.questions.find(
      (q) => ["single_choice", "multiple_choice"].includes(q.question_type) && 
             (!q.options || q.options.length < 2)
    );
    if (choiceQuestion) {
      setError("Seçenekli sorular en az 2 seçenek içermelidir");
      setStep(2);
      return;
    }

    try {
      setSaving(true);
      setError(null);

      // Map question types to database enum values
      const mapQuestionType = (type: string): string => {
        if (type === 'boolean') return 'yes_no';
        return type;
      };

      // Call RPC function to create survey
      const { data, error: createError } = await supabase.rpc("create_survey", {
        p_title: form.title,
        p_content: form.content,
        p_summary: form.summary || null,
        p_target_scope: form.target_scope,
        p_target_branches: form.target_branches.length > 0 ? form.target_branches : null,
        p_include_region_managers: form.include_region_managers,
        p_managers_only: form.managers_only,
        p_expires_at: form.expires_at,
        p_questions: form.questions.map((q) => ({
          question_text: q.question_text,
          question_type: mapQuestionType(q.question_type),
          options: q.options,
          required: q.required,
          sort_order: q.sort_order,
        })),
      });

      if (createError) throw createError;
      
      onSuccess();
    } catch (err: unknown) {
      console.error("Error creating survey:", err);
      const error = err as { message?: string };
      setError(error.message || "Anket oluşturulurken bir hata oluştu");
    } finally {
      setSaving(false);
    }
  };

  const addQuestion = () => {
    setForm((prev) => ({
      ...prev,
      questions: [...prev.questions, createEmptyQuestion(prev.questions.length + 1)],
    }));
  };

  const removeQuestion = (index: number) => {
    if (form.questions.length <= 1) return;
    setForm((prev) => ({
      ...prev,
      questions: prev.questions
        .filter((_, i) => i !== index)
        .map((q, i) => ({ ...q, sort_order: i + 1 })),
    }));
  };

  const updateQuestion = (index: number, updates: Partial<CreateSurveyQuestion>) => {
    setForm((prev) => ({
      ...prev,
      questions: prev.questions.map((q, i) => 
        i === index ? { ...q, ...updates } : q
      ),
    }));
  };

  const addOption = (questionIndex: number) => {
    const question = form.questions[questionIndex];
    const options = question.options || [];
    updateQuestion(questionIndex, { options: [...options, ""] });
  };

  const updateOption = (questionIndex: number, optionIndex: number, value: string) => {
    const question = form.questions[questionIndex];
    const options = [...(question.options || [])];
    options[optionIndex] = value;
    updateQuestion(questionIndex, { options });
  };

  const removeOption = (questionIndex: number, optionIndex: number) => {
    const question = form.questions[questionIndex];
    const options = (question.options || []).filter((_, i) => i !== optionIndex);
    updateQuestion(questionIndex, { options });
  };

  const handleBranchToggle = (branchId: string) => {
    setForm((prev) => ({
      ...prev,
      target_branches: prev.target_branches.includes(branchId)
        ? prev.target_branches.filter((id) => id !== branchId)
        : [...prev.target_branches, branchId],
    }));
  };

  // Bölge seçim fonksiyonu
  const handleRegionToggle = (regionId: string) => {
    const isSelected = selectedRegions.includes(regionId);
    const regionBranches = branches.filter(b => b.region_id === regionId).map(b => b.id);
    
    if (isSelected) {
      // Bölgeyi kaldır ve o bölgenin şubelerini kaldır
      setSelectedRegions(prev => prev.filter(id => id !== regionId));
      setForm(prev => ({
        ...prev,
        target_branches: prev.target_branches.filter(id => !regionBranches.includes(id))
      }));
    } else {
      // Bölgeyi ekle ve o bölgenin tüm şubelerini ekle
      setSelectedRegions(prev => [...prev, regionId]);
      setForm(prev => ({
        ...prev,
        target_branches: [...new Set([...prev.target_branches, ...regionBranches])]
      }));
    }
  };

  // Seçili bölgelerdeki şubeler
  const filteredBranches = userRole === "firma_admin" && selectedRegions.length > 0
    ? branches.filter(b => selectedRegions.includes(b.region_id || ""))
    : branches;

  const availableScopes = TARGET_SCOPE_OPTIONS.filter(
    (opt) => !userRole || opt.roles.includes(userRole)
  );

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content large" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Yeni Anket</h2>
          <div className="steps">
            <span className={`step ${step === 1 ? "active" : ""}`}>1. Genel Bilgiler</span>
            <span className="step-divider">→</span>
            <span className={`step ${step === 2 ? "active" : ""}`}>2. Sorular</span>
          </div>
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

            {step === 1 && (
              <>
                {/* Title */}
                <div className="form-group">
                  <label>Anket Başlığı *</label>
                  <input
                    type="text"
                    value={form.title}
                    onChange={(e) => setForm((prev) => ({ ...prev, title: e.target.value }))}
                    placeholder="Anket başlığı"
                    maxLength={200}
                  />
                </div>

                {/* Content/Description */}
                <div className="form-group">
                  <label>Açıklama *</label>
                  <textarea
                    value={form.content}
                    onChange={(e) => setForm((prev) => ({ ...prev, content: e.target.value }))}
                    placeholder="Anket hakkında kısa açıklama..."
                    rows={4}
                  />
                </div>

                {/* Target Scope */}
                <div className="form-group">
                  <label>Hedef Kitle</label>
                  <select
                    value={form.target_scope}
                    onChange={(e) => setForm((prev) => ({ 
                      ...prev, 
                      target_scope: e.target.value as TargetScope 
                    }))}
                  >
                    {availableScopes.map((opt) => (
                      <option key={opt.value} value={opt.value}>
                        {opt.label}
                      </option>
                    ))}
                  </select>
                </div>

                {/* Branch Selection */}
                {form.target_scope === "selected_branches" && (
                  <div className="form-group">
                    {/* Firma Admin için önce bölge seçimi */}
                    {userRole === "firma_admin" && (
                      <>
                        <label>Bölge Seçimi ({selectedRegions.length} bölge seçili)</label>
                        <div className="regions-grid">
                          {regions.map((region) => {
                            const regionBranchCount = branches.filter(b => b.region_id === region.id).length;
                            return (
                              <label key={region.id} className="region-checkbox">
                                <input
                                  type="checkbox"
                                  checked={selectedRegions.includes(region.id)}
                                  onChange={() => handleRegionToggle(region.id)}
                                />
                                <span>{region.name} ({regionBranchCount} şube)</span>
                              </label>
                            );
                          })}
                        </div>
                      </>
                    )}

                    {/* Şube Seçimi */}
                    {(userRole !== "firma_admin" || selectedRegions.length > 0) && (
                      <>
                        <label style={{ marginTop: userRole === "firma_admin" ? "16px" : "0" }}>
                          Şube Seçimi ({form.target_branches.length} şube seçili)
                          {userRole === "firma_admin" && selectedRegions.length > 0 && (
                            <button 
                              type="button" 
                              className="select-all-btn"
                              onClick={() => {
                                const allFiltered = filteredBranches.map(b => b.id);
                                const allSelected = allFiltered.every(id => form.target_branches.includes(id));
                                setForm(prev => ({
                                  ...prev,
                                  target_branches: allSelected 
                                    ? prev.target_branches.filter(id => !allFiltered.includes(id))
                                    : [...new Set([...prev.target_branches, ...allFiltered])]
                                }));
                              }}
                            >
                              {filteredBranches.every(b => form.target_branches.includes(b.id)) ? "Tümünü Kaldır" : "Tümünü Seç"}
                            </button>
                          )}
                        </label>
                        <div className="branches-grid">
                          {filteredBranches.length === 0 ? (
                            <p className="no-branches">
                              {userRole === "firma_admin" 
                                ? "Lütfen önce bölge seçin" 
                                : "Şube bulunamadı"}
                            </p>
                          ) : (
                            filteredBranches.map((branch) => (
                              <label key={branch.id} className="branch-checkbox">
                                <input
                                  type="checkbox"
                                  checked={form.target_branches.includes(branch.id)}
                                  onChange={() => handleBranchToggle(branch.id)}
                                />
                                <span>{branch.name}</span>
                              </label>
                            ))
                          )}
                        </div>
                      </>
                    )}
                  </div>
                )}

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

                {/* Checkboxes */}
                <div className="checkbox-group">
                  <label className="checkbox-item">
                    <input
                      type="checkbox"
                      checked={form.pinned}
                      onChange={(e) => setForm((prev) => ({ ...prev, pinned: e.target.checked }))}
                    />
                    <span>Sabitle</span>
                  </label>
                  <label className="checkbox-item">
                    <input
                      type="checkbox"
                      checked={form.managers_only}
                      onChange={(e) => setForm((prev) => ({ ...prev, managers_only: e.target.checked }))}
                    />
                    <span>Sadece müdürlere göster</span>
                  </label>
                </div>
              </>
            )}

            {step === 2 && (
              <div className="questions-section">
                <div className="questions-header">
                  <h3>Sorular ({form.questions.length})</h3>
                  <button type="button" className="btn btn-sm btn-secondary" onClick={addQuestion}>
                    <Plus size={16} />
                    Soru Ekle
                  </button>
                </div>

                <div className="questions-list">
                  {form.questions.map((question, qIndex) => (
                    <div key={qIndex} className="question-card">
                      <div className="question-header">
                        <div className="question-number">
                          <GripVertical size={16} className="drag-handle" />
                          <span>{qIndex + 1}</span>
                        </div>
                        <button
                          type="button"
                          className="remove-btn"
                          onClick={() => removeQuestion(qIndex)}
                          disabled={form.questions.length <= 1}
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>

                      <div className="question-body">
                        {/* Question Text */}
                        <div className="form-group">
                          <input
                            type="text"
                            value={question.question_text}
                            onChange={(e) => updateQuestion(qIndex, { question_text: e.target.value })}
                            placeholder="Soru metni..."
                            className="question-input"
                          />
                        </div>

                        {/* Question Type */}
                        <div className="question-type-row">
                          <select
                            value={question.question_type}
                            onChange={(e) => {
                              const newType = e.target.value as SurveyQuestionType;
                              const updates: Partial<CreateSurveyQuestion> = { question_type: newType };
                              
                              // Reset options for non-choice types
                              if (!["single_choice", "multiple_choice"].includes(newType)) {
                                updates.options = null;
                              } else if (!question.options) {
                                updates.options = ["", ""];
                              }
                              
                              updateQuestion(qIndex, updates);
                            }}
                          >
                            {QUESTION_TYPES.map((type) => (
                              <option key={type.value} value={type.value}>
                                {type.label} - {type.description}
                              </option>
                            ))}
                          </select>
                          
                          <label className="required-checkbox">
                            <input
                              type="checkbox"
                              checked={question.required}
                              onChange={(e) => updateQuestion(qIndex, { required: e.target.checked })}
                            />
                            <span>Zorunlu</span>
                          </label>
                        </div>

                        {/* Options for choice types */}
                        {["single_choice", "multiple_choice"].includes(question.question_type) && (
                          <div className="options-section">
                            <label className="options-label">Seçenekler</label>
                            {(question.options || []).map((option, oIndex) => (
                              <div key={oIndex} className="option-row">
                                <span className="option-number">{oIndex + 1}.</span>
                                <input
                                  type="text"
                                  value={option}
                                  onChange={(e) => updateOption(qIndex, oIndex, e.target.value)}
                                  placeholder={`Seçenek ${oIndex + 1}`}
                                />
                                <button
                                  type="button"
                                  className="remove-option-btn"
                                  onClick={() => removeOption(qIndex, oIndex)}
                                  disabled={(question.options?.length || 0) <= 2}
                                >
                                  <X size={14} />
                                </button>
                              </div>
                            ))}
                            <button
                              type="button"
                              className="add-option-btn"
                              onClick={() => addOption(qIndex)}
                            >
                              <Plus size={14} />
                              Seçenek Ekle
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          <div className="modal-footer">
            {step === 2 && (
              <button type="button" className="btn btn-secondary" onClick={() => setStep(1)}>
                ← Geri
              </button>
            )}
            <div className="footer-right">
              <button type="button" className="btn btn-secondary" onClick={onClose}>
                İptal
              </button>
              {step === 1 ? (
                <button 
                  type="button" 
                  className="btn btn-primary"
                  onClick={() => {
                    if (!form.title.trim()) {
                      setError("Başlık zorunludur");
                      return;
                    }
                    if (!form.content.trim()) {
                      setError("Açıklama zorunludur");
                      return;
                    }
                    setError(null);
                    setStep(2);
                  }}
                >
                  Devam →
                </button>
              ) : (
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? "Kaydediliyor..." : "Anketi Yayınla"}
                </button>
              )}
            </div>
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

          .modal-content.large {
            background: white;
            border-radius: 12px;
            width: 100%;
            max-width: 800px;
            max-height: 90vh;
            overflow: hidden;
            display: flex;
            flex-direction: column;
          }

          .modal-header {
            display: flex;
            align-items: center;
            padding: 20px 24px;
            border-bottom: 1px solid #e2e8f0;
            gap: 24px;
          }

          .modal-header h2 {
            margin: 0;
            font-size: 20px;
          }

          .steps {
            display: flex;
            align-items: center;
            gap: 12px;
            flex: 1;
          }

          .step {
            font-size: 13px;
            color: #94a3b8;
          }

          .step.active {
            color: #3b82f6;
            font-weight: 500;
          }

          .step-divider {
            color: #cbd5e1;
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
            margin-left: auto;
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
            justify-content: space-between;
            align-items: center;
            padding: 16px 24px;
            border-top: 1px solid #e2e8f0;
          }

          .footer-right {
            display: flex;
            gap: 12px;
            margin-left: auto;
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

          .form-group input,
          .form-group textarea,
          .form-group select {
            width: 100%;
            padding: 10px 12px;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            font-size: 14px;
          }

          .form-group select {
            cursor: pointer;
          }

          .branches-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 8px;
            max-height: 200px;
            overflow-y: auto;
            padding: 12px;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
          }

          .branch-checkbox {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 13px;
            cursor: pointer;
          }

          .checkbox-group {
            display: flex;
            gap: 24px;
          }

          .checkbox-item {
            display: flex;
            align-items: center;
            gap: 8px;
            cursor: pointer;
          }

          .questions-section {
            min-height: 300px;
          }

          .questions-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
          }

          .questions-header h3 {
            margin: 0;
            font-size: 16px;
          }

          .questions-list {
            display: flex;
            flex-direction: column;
            gap: 16px;
          }

          .question-card {
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            overflow: hidden;
          }

          .question-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 16px;
            background: #f8fafc;
            border-bottom: 1px solid #e2e8f0;
          }

          .question-number {
            display: flex;
            align-items: center;
            gap: 8px;
            font-weight: 600;
          }

          .drag-handle {
            color: #94a3b8;
            cursor: grab;
          }

          .remove-btn {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 28px;
            height: 28px;
            border: none;
            background: transparent;
            cursor: pointer;
            border-radius: 4px;
            color: #64748b;
          }

          .remove-btn:hover:not(:disabled) {
            background: #fef2f2;
            color: #dc2626;
          }

          .remove-btn:disabled {
            opacity: 0.3;
            cursor: not-allowed;
          }

          .question-body {
            padding: 16px;
          }

          .question-input {
            font-size: 15px !important;
            font-weight: 500;
          }

          .question-type-row {
            display: flex;
            gap: 16px;
            align-items: center;
          }

          .question-type-row select {
            flex: 1;
          }

          .required-checkbox {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 13px;
            cursor: pointer;
            white-space: nowrap;
          }

          .options-section {
            margin-top: 16px;
            padding: 12px;
            background: #f8fafc;
            border-radius: 8px;
          }

          .options-label {
            display: block;
            font-size: 12px;
            font-weight: 500;
            color: #64748b;
            margin-bottom: 8px;
          }

          .option-row {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-bottom: 8px;
          }

          .option-number {
            font-size: 12px;
            color: #94a3b8;
            width: 20px;
          }

          .option-row input {
            flex: 1;
            padding: 8px 12px;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
            font-size: 14px;
          }

          .remove-option-btn {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 24px;
            height: 24px;
            border: none;
            background: transparent;
            cursor: pointer;
            border-radius: 4px;
            color: #94a3b8;
          }

          .remove-option-btn:hover:not(:disabled) {
            background: #fef2f2;
            color: #dc2626;
          }

          .remove-option-btn:disabled {
            opacity: 0.3;
            cursor: not-allowed;
          }

          .add-option-btn {
            display: flex;
            align-items: center;
            gap: 4px;
            padding: 6px 12px;
            border: 1px dashed #cbd5e1;
            border-radius: 6px;
            background: transparent;
            cursor: pointer;
            font-size: 12px;
            color: #64748b;
          }

          .add-option-btn:hover {
            border-color: #3b82f6;
            color: #3b82f6;
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
            display: flex;
            align-items: center;
            gap: 6px;
            padding: 10px 20px;
            border-radius: 8px;
            font-weight: 500;
            cursor: pointer;
            border: none;
            transition: all 0.2s;
          }

          .btn-sm {
            padding: 8px 14px;
            font-size: 13px;
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

          .regions-grid {
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

          .region-checkbox {
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

          .region-checkbox:hover {
            border-color: #3b82f6;
          }

          .region-checkbox:has(input:checked) {
            background: #eff6ff;
            border-color: #3b82f6;
          }

          .branches-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 8px;
            padding: 12px;
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            max-height: 200px;
            overflow-y: auto;
          }

          .branch-checkbox {
            display: flex;
            align-items: center;
            gap: 6px;
            padding: 6px 10px;
            background: white;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
            cursor: pointer;
            font-size: 13px;
            transition: all 0.2s;
          }

          .branch-checkbox:hover {
            border-color: #3b82f6;
          }

          .branch-checkbox:has(input:checked) {
            background: #eff6ff;
            border-color: #3b82f6;
          }

          .no-branches {
            grid-column: 1 / -1;
            text-align: center;
            padding: 16px;
            color: #64748b;
            font-size: 14px;
          }

          .select-all-btn {
            margin-left: 8px;
            padding: 2px 8px;
            font-size: 11px;
            border: 1px solid #e2e8f0;
            border-radius: 4px;
            background: white;
            cursor: pointer;
            color: #64748b;
          }

          .select-all-btn:hover {
            background: #f1f5f9;
          }
        `}</style>
      </div>
    </div>
  );
}
