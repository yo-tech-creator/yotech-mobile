"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { createBrowserClient } from "@supabase/ssr";
import { 
  ArrowLeft,
  Plus, 
  Trash2, 
  GripVertical, 
  AlertTriangle,
  Type,
  List,
  ToggleLeft,
  Star,
  Hash,
  MessageSquare,
  ClipboardList,
  MapPin,
  Building2,
  Users,
  Filter
} from "lucide-react";
import type { 
  TargetScope, 
  CreateSurveyForm, 
  SurveyQuestionType,
  CreateSurveyQuestion,
  Branch, 
  Region,
  User
} from "@/types/announcements";
import "./create-page.css";

const QUESTION_TYPES: { value: SurveyQuestionType; label: string; icon: React.ReactNode; description: string }[] = [
  { value: "text", label: "Kısa Metin", icon: <Type size={16} />, description: "Kısa metin yanıtı" },
  { value: "textarea", label: "Uzun Metin", icon: <MessageSquare size={16} />, description: "Uzun metin yanıtı" },
  { value: "single_choice", label: "Tek Seçim", icon: <List size={16} />, description: "Birden fazla seçenek, tek cevap" },
  { value: "multiple_choice", label: "Çoklu Seçim", icon: <List size={16} />, description: "Birden fazla seçenek seçilebilir" },
  { value: "rating", label: "Puanlama", icon: <Star size={16} />, description: "1-5 arası yıldız puanı" },
  { value: "number", label: "Sayı", icon: <Hash size={16} />, description: "Sayısal değer" },
  { value: "yes_no", label: "Evet/Hayır", icon: <ToggleLeft size={16} />, description: "İki seçenekli cevap" },
];

const createEmptyQuestion = (sortOrder: number): CreateSurveyQuestion => ({
  question_text: "",
  question_type: "text",
  options: null,
  required: true,
  sort_order: sortOrder,
});

export default function CreateSurveyPage() {
  const router = useRouter();
  const [form, setForm] = useState<CreateSurveyForm>({
    title: "",
    content: "",
    summary: "",
    type: "survey",
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
    questions: [createEmptyQuestion(1)],
  });
  
  const [branches, setBranches] = useState<Branch[]>([]);
  const [regions, setRegions] = useState<Region[]>([]);
  const [personnel, setPersonnel] = useState<User[]>([]);
  const [showBranchFilter, setShowBranchFilter] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [step, setStep] = useState<1 | 2>(1);
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
      setStep(1);
      return;
    }
    
    if (!form.content.trim()) {
      setError("Açıklama zorunludur");
      setStep(1);
      return;
    }

    // Validation based on target scope
    if (form.target_scope === "selected_regions" && form.target_regions.length === 0) {
      setError("En az bir bölge seçmelisiniz");
      setStep(1);
      return;
    }

    if (form.target_scope === "selected_branches" && form.target_branches.length === 0) {
      setError("En az bir şube seçmelisiniz");
      setStep(1);
      return;
    }

    if (form.target_scope === "selected_personnel" && form.target_users.length === 0) {
      setError("En az bir personel seçmelisiniz");
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

    // Check for duplicate options within each choice question
    const duplicateOptionQuestion = form.questions.find((q) => {
      if (!["single_choice", "multiple_choice"].includes(q.question_type) || !q.options) {
        return false;
      }
      const trimmedOptions = q.options.map(opt => opt.trim().toLowerCase()).filter(opt => opt);
      const uniqueOptions = new Set(trimmedOptions);
      return uniqueOptions.size !== trimmedOptions.length;
    });
    if (duplicateOptionQuestion) {
      const confirmDuplicate = confirm(
        `"${duplicateOptionQuestion.question_text}" sorusunda aynı seçenek birden fazla kez kullanılmış. Yine de devam etmek istiyor musunuz?`
      );
      if (!confirmDuplicate) {
        setStep(2);
        return;
      }
    }

    try {
      setSaving(true);
      setError(null);

      const mapQuestionType = (type: string): string => {
        if (type === 'boolean') return 'yes_no';
        return type;
      };

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

      // Map web panel scope values to database enum values
      // Database supports: all_branches, selected_branches, my_branches, my_branch, region_managers_only
      let finalScope: string = form.target_scope;
      
      switch (form.target_scope) {
        case "selected_regions":
          finalScope = "selected_branches";
          break;
        case "all_personnel":
        case "selected_personnel":
          // Personnel scopes map to my_branch for store managers
          finalScope = "my_branch";
          break;
        case "all_branches":
        case "selected_branches":
        case "my_branches":
        case "my_branch":
        case "region_managers_only":
          // These are valid database values
          finalScope = form.target_scope;
          break;
        default:
          finalScope = "all_branches";
      }

      console.log("Creating survey with scope:", finalScope, "branches:", targetBranches);

      const { data, error: createError } = await supabase.rpc("create_survey", {
        p_title: form.title,
        p_content: form.content,
        p_summary: form.summary || null,
        p_target_scope: finalScope,
        p_target_branches: targetBranches,
        p_target_regions: form.target_scope === "selected_regions" ? form.target_regions : null,
        p_include_region_managers: form.include_region_managers,
        p_managers_only: form.managers_only,
        p_expires_at: form.expires_at,
        p_questions: form.questions.map((q) => ({
          question_text: q.question_text,
          question_type: mapQuestionType(q.question_type),
          options: q.options || null,
          required: q.required,
          sort_order: q.sort_order,
        })),
      });

      if (createError) {
        console.error("Supabase RPC error:", createError);
        throw createError;
      }
      
      // Check if the response indicates an error
      if (data && typeof data === 'object' && 'success' in data) {
        if (!data.success) {
          throw new Error((data as { error?: string }).error || "Anket oluşturulamadı");
        }
      }
      
      router.push("/announcements");
    } catch (err: unknown) {
      console.error("Error creating survey:", err);
      
      // Better error handling
      let errorMessage = "Anket oluşturulurken bir hata oluştu";
      
      if (err instanceof Error) {
        errorMessage = err.message;
      } else if (typeof err === 'object' && err !== null) {
        const errObj = err as Record<string, unknown>;
        if (errObj.message) {
          errorMessage = String(errObj.message);
        } else if (errObj.error) {
          errorMessage = String(errObj.error);
        } else if (errObj.details) {
          errorMessage = String(errObj.details);
        } else {
          // Log the full error for debugging
          console.error("Full error object:", JSON.stringify(err, null, 2));
        }
      }
      
      setError(errorMessage);
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
    <div className="create-page" style={{ width: '100%', maxWidth: '100%', padding: '24px' }}>
      <div className="page-header" style={{ width: '100%' }}>
        <button className="back-btn" onClick={() => router.push("/announcements")}>
          <ArrowLeft size={20} />
          Geri
        </button>
        <div className="header-title" style={{ flex: 1 }}>
          <ClipboardList size={24} />
          <h1>Yeni Anket</h1>
        </div>
        <div className="steps">
          <span className={`step ${step === 1 ? "active" : ""}`}>1. Genel Bilgiler</span>
          <span className="step-divider">→</span>
          <span className={`step ${step === 2 ? "active" : ""}`}>2. Sorular</span>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="create-form" style={{ width: '100%' }}>
        {error && (
          <div className="alert alert-error">
            <AlertTriangle size={18} />
            {error}
          </div>
        )}

        {step === 1 && (
          <>
            <div className="form-card" style={{ width: '100%' }}>
              <h2>Temel Bilgiler</h2>
              
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
            </div>

            <div className="form-card" style={{ width: '100%' }}>
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

            <div className="form-card" style={{ width: '100%' }}>
              <h2>Ek Ayarlar</h2>
              
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
                {userRole !== "sube_muduru" && (
                  <label className="checkbox-item">
                    <input
                      type="checkbox"
                      checked={form.managers_only}
                      onChange={(e) => setForm((prev) => ({ ...prev, managers_only: e.target.checked }))}
                    />
                    <span>Sadece müdürlere göster</span>
                  </label>
                )}
              </div>
            </div>
          </>
        )}

        {step === 2 && (
          <div className="form-card questions-card" style={{ width: '100%' }}>
            <div className="questions-header">
              <h2>Sorular ({form.questions.length})</h2>
              <button type="button" className="btn btn-secondary btn-sm" onClick={addQuestion}>
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
                              <Trash2 size={14} />
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

        <div className="form-actions" style={{ width: '100%' }}>
          {step === 2 && (
            <button type="button" className="btn btn-secondary" onClick={() => setStep(1)}>
              ← Geri
            </button>
          )}
          <div className="actions-right">
            <button type="button" className="btn btn-secondary" onClick={() => router.push("/announcements")}>
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
                {saving ? "Yayınlanıyor..." : "Anketi Yayınla"}
              </button>
            )}
          </div>
        </div>
      </form>
    </div>
  );
}
