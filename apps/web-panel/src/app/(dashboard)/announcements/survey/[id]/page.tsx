"use client";

import { useState, useEffect, use } from "react";
import { useRouter } from "next/navigation";
import { createBrowserClient } from "@supabase/ssr";
import { 
  ArrowLeft,
  BarChart3, 
  Users,
  CheckCircle,
  Star,
  Loader2,
  Download,
  ChevronDown,
  ChevronUp,
  MessageSquare,
  Hash,
  ToggleLeft,
  List,
  User,
  Building2,
  Calendar,
  Type
} from "lucide-react";
import "./survey-results.css";

interface SurveyAnswer {
  user_id: string;
  user_name: string;
  branch_name: string | null;
  answer_text: string | null;
  answer_options: string[] | null;
  answer_rating: number | null;
  answer_boolean: boolean | null;
  submitted_at: string;
}

interface QuestionSummary {
  average?: number;
  count_1?: number;
  count_2?: number;
  count_3?: number;
  count_4?: number;
  count_5?: number;
  yes?: number;
  no?: number;
  [key: string]: number | undefined;
}

interface SurveyQuestion {
  question_id: string;
  question_text: string;
  question_type: string;
  options: string[] | null;
  answers: SurveyAnswer[] | null;
  summary: QuestionSummary | null;
}

interface SurveyResultsData {
  success: boolean;
  error?: string;
  announcement_id: string;
  total_responses: number;
  questions: SurveyQuestion[] | null;
}

interface AnnouncementInfo {
  id: string;
  title: string;
  content: string;
  published_at: string;
  expires_at: string | null;
  publisher?: {
    first_name: string;
    last_name: string;
  };
}

export default function SurveyResultsPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: surveyId } = use(params);
  const router = useRouter();
  const [results, setResults] = useState<SurveyResultsData | null>(null);
  const [announcement, setAnnouncement] = useState<AnnouncementInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [expandedQuestions, setExpandedQuestions] = useState<Set<string>>(new Set());
  const [viewMode, setViewMode] = useState<"summary" | "individual">("summary");

  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  useEffect(() => {
    loadData();
  }, [surveyId]);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);

      // Load announcement info
      const { data: announcementData, error: announcementError } = await supabase
        .from("announcements")
        .select(`
          id,
          title,
          content,
          published_at,
          expires_at,
          publisher:published_by(first_name, last_name)
        `)
        .eq("id", surveyId)
        .single();

      if (announcementError) throw announcementError;
      setAnnouncement(announcementData as unknown as AnnouncementInfo);

      // Load survey results
      const { data, error: fetchError } = await supabase.rpc("get_survey_results", {
        p_announcement_id: surveyId,
      });

      if (fetchError) throw fetchError;
      
      const resultData = data as SurveyResultsData;
      if (!resultData.success) {
        throw new Error(resultData.error || "Sonuçlar yüklenemedi");
      }
      
      setResults(resultData);
    } catch (err: unknown) {
      console.error("Error loading survey results:", err);
      const error = err as { message?: string };
      setError(error.message || "Anket sonuçları yüklenirken bir hata oluştu");
    } finally {
      setLoading(false);
    }
  };

  const toggleQuestion = (questionId: string) => {
    setExpandedQuestions(prev => {
      const next = new Set(prev);
      if (next.has(questionId)) {
        next.delete(questionId);
      } else {
        next.add(questionId);
      }
      return next;
    });
  };

  const expandAll = () => {
    if (results?.questions) {
      setExpandedQuestions(new Set(results.questions.map(q => q.question_id)));
    }
  };

  const collapseAll = () => {
    setExpandedQuestions(new Set());
  };

  const getQuestionIcon = (type: string) => {
    switch (type) {
      case "rating": return <Star size={18} />;
      case "single_choice": return <CheckCircle size={18} />;
      case "multiple_choice": return <List size={18} />;
      case "yes_no": return <ToggleLeft size={18} />;
      case "number": return <Hash size={18} />;
      case "textarea": return <MessageSquare size={18} />;
      default: return <Type size={18} />;
    }
  };

  const getQuestionTypeLabel = (type: string) => {
    switch (type) {
      case "rating": return "Puanlama";
      case "single_choice": return "Tekli Seçim";
      case "multiple_choice": return "Çoklu Seçim";
      case "yes_no": return "Evet/Hayır";
      case "number": return "Sayı";
      case "textarea": return "Uzun Metin";
      case "text": return "Kısa Metin";
      default: return type;
    }
  };

  const exportToCSV = () => {
    if (!results || !announcement) return;

    let csv = "Soru,Soru Tipi,Kullanıcı,Şube,Cevap,Tarih\n";
    
    results.questions?.forEach(q => {
      q.answers?.forEach(a => {
        let answer = "";
        if (a.answer_text) answer = a.answer_text;
        else if (a.answer_rating) answer = `${a.answer_rating} yıldız`;
        else if (a.answer_boolean !== null) answer = a.answer_boolean ? "Evet" : "Hayır";
        else if (a.answer_options) answer = a.answer_options.join(", ");
        
        csv += `"${q.question_text}","${getQuestionTypeLabel(q.question_type)}","${a.user_name}","${a.branch_name || "-"}","${answer}","${new Date(a.submitted_at).toLocaleString("tr-TR")}"\n`;
      });
    });

    const blob = new Blob(["\ufeff" + csv], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = `anket_sonuclari_${announcement.title.replace(/[^a-z0-9]/gi, "_")}.csv`;
    link.click();
  };

  // Render functions for different question types
  const renderRatingResult = (question: SurveyQuestion) => {
    const summary = question.summary;
    const avgRating = summary?.average || 0;
    const totalAnswers = question.answers?.length || 0;
    
    const distribution = [
      { star: 5, count: summary?.count_5 || 0 },
      { star: 4, count: summary?.count_4 || 0 },
      { star: 3, count: summary?.count_3 || 0 },
      { star: 2, count: summary?.count_2 || 0 },
      { star: 1, count: summary?.count_1 || 0 },
    ];

    return (
      <div className="result-content">
        <div className="rating-summary">
          <div className="rating-big">
            <span className="rating-number">{avgRating.toFixed(1)}</span>
            <div className="rating-stars">
              {[1, 2, 3, 4, 5].map((star) => (
                <Star 
                  key={star} 
                  size={24} 
                  fill={star <= Math.round(avgRating) ? "#fbbf24" : "none"}
                  color={star <= Math.round(avgRating) ? "#fbbf24" : "#cbd5e1"}
                />
              ))}
            </div>
            <span className="rating-count">{totalAnswers} değerlendirme</span>
          </div>
          <div className="rating-bars">
            {distribution.map(({ star, count }) => {
              const percent = totalAnswers > 0 ? (count / totalAnswers) * 100 : 0;
              return (
                <div key={star} className="rating-bar-row">
                  <span className="bar-label">{star}★</span>
                  <div className="bar-track">
                    <div className="bar-fill rating-fill" style={{ width: `${percent}%` }} />
                  </div>
                  <span className="bar-count">{count}</span>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    );
  };

  const renderChoiceResult = (question: SurveyQuestion) => {
    const summary = question.summary || {};
    const options = question.options || [];
    const totalAnswers = question.answers?.length || 0;
    
    // Calculate percentages
    const optionStats = options.map(opt => {
      const count = summary[opt] || 0;
      const percent = totalAnswers > 0 ? (count / totalAnswers) * 100 : 0;
      return { option: opt, count, percent };
    }).sort((a, b) => b.count - a.count);

    const maxCount = Math.max(...optionStats.map(o => o.count), 1);

    return (
      <div className="result-content">
        <div className="choice-summary">
          <div className="choice-stats">
            {optionStats.map(({ option, count, percent }, index) => (
              <div key={`${option}-${index}`} className="choice-bar-row">
                <div className="choice-label">
                  <span className="choice-text">{option}</span>
                  <span className="choice-percent">{percent.toFixed(0)}%</span>
                </div>
                <div className="bar-track">
                  <div 
                    className="bar-fill choice-fill" 
                    style={{ width: `${(count / maxCount) * 100}%` }} 
                  />
                </div>
                <span className="bar-count">{count} kişi</span>
              </div>
            ))}
          </div>
          <div className="total-responses">
            <Users size={16} />
            <span>Toplam {totalAnswers} yanıt</span>
          </div>
        </div>
      </div>
    );
  };

  const renderYesNoResult = (question: SurveyQuestion) => {
    const summary = question.summary;
    const yesCount = summary?.yes || 0;
    const noCount = summary?.no || 0;
    const total = yesCount + noCount;
    
    const yesPercent = total > 0 ? (yesCount / total) * 100 : 0;
    const noPercent = total > 0 ? (noCount / total) * 100 : 0;

    return (
      <div className="result-content">
        <div className="yesno-summary">
          <div className="yesno-chart">
            <div className="yesno-bar yes-bar" style={{ width: `${yesPercent}%` }}>
              {yesPercent > 10 && <span>Evet {yesPercent.toFixed(0)}%</span>}
            </div>
            <div className="yesno-bar no-bar" style={{ width: `${noPercent}%` }}>
              {noPercent > 10 && <span>Hayır {noPercent.toFixed(0)}%</span>}
            </div>
          </div>
          <div className="yesno-stats">
            <div className="yesno-stat yes">
              <CheckCircle size={18} />
              <span>Evet: {yesCount} kişi ({yesPercent.toFixed(0)}%)</span>
            </div>
            <div className="yesno-stat no">
              <span className="x-icon">✕</span>
              <span>Hayır: {noCount} kişi ({noPercent.toFixed(0)}%)</span>
            </div>
          </div>
        </div>
      </div>
    );
  };

  const renderTextResult = (question: SurveyQuestion) => {
    const answers = question.answers || [];
    
    return (
      <div className="result-content">
        <div className="text-responses">
          <div className="responses-header">
            <MessageSquare size={16} />
            <span>{answers.length} yanıt</span>
          </div>
          {answers.length === 0 ? (
            <p className="no-responses">Henüz yanıt yok</p>
          ) : (
            <div className="responses-list">
              {answers.map((answer, idx) => (
                <div key={idx} className="response-item">
                  <div className="response-header">
                    <div className="response-user">
                      <User size={14} />
                      <span>{answer.user_name}</span>
                    </div>
                    {answer.branch_name && (
                      <div className="response-branch">
                        <Building2 size={14} />
                        <span>{answer.branch_name}</span>
                      </div>
                    )}
                    <div className="response-date">
                      <Calendar size={14} />
                      <span>{new Date(answer.submitted_at).toLocaleString("tr-TR")}</span>
                    </div>
                  </div>
                  <div className="response-text">
                    {answer.answer_text || "-"}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    );
  };

  const renderNumberResult = (question: SurveyQuestion) => {
    const answers = question.answers || [];
    const numbers = answers
      .map(a => parseFloat(a.answer_text || "0"))
      .filter(n => !isNaN(n));
    
    const avg = numbers.length > 0 ? numbers.reduce((a, b) => a + b, 0) / numbers.length : 0;
    const min = numbers.length > 0 ? Math.min(...numbers) : 0;
    const max = numbers.length > 0 ? Math.max(...numbers) : 0;

    return (
      <div className="result-content">
        <div className="number-summary">
          <div className="number-stats">
            <div className="number-stat">
              <span className="stat-label">Ortalama</span>
              <span className="stat-value">{avg.toFixed(1)}</span>
            </div>
            <div className="number-stat">
              <span className="stat-label">Minimum</span>
              <span className="stat-value">{min}</span>
            </div>
            <div className="number-stat">
              <span className="stat-label">Maksimum</span>
              <span className="stat-value">{max}</span>
            </div>
            <div className="number-stat">
              <span className="stat-label">Yanıt Sayısı</span>
              <span className="stat-value">{numbers.length}</span>
            </div>
          </div>
        </div>
      </div>
    );
  };

  const renderQuestionResult = (question: SurveyQuestion) => {
    switch (question.question_type) {
      case "rating":
        return renderRatingResult(question);
      case "single_choice":
      case "multiple_choice":
        return renderChoiceResult(question);
      case "yes_no":
        return renderYesNoResult(question);
      case "number":
        return renderNumberResult(question);
      default:
        return renderTextResult(question);
    }
  };

  const renderIndividualResponses = (question: SurveyQuestion) => {
    const answers = question.answers || [];
    
    return (
      <div className="individual-responses">
        {answers.length === 0 ? (
          <p className="no-responses">Henüz yanıt yok</p>
        ) : (
          <div className="responses-table">
            <div className="table-header">
              <span>Kullanıcı</span>
              <span>Şube</span>
              <span>Cevap</span>
              <span>Tarih</span>
            </div>
            {answers.map((answer, idx) => {
              let displayAnswer = "-";
              if (answer.answer_text) displayAnswer = answer.answer_text;
              else if (answer.answer_rating) displayAnswer = `${"★".repeat(answer.answer_rating)}${"☆".repeat(5 - answer.answer_rating)}`;
              else if (answer.answer_boolean !== null) displayAnswer = answer.answer_boolean ? "Evet ✓" : "Hayır ✕";
              else if (answer.answer_options) displayAnswer = answer.answer_options.join(", ");
              
              return (
                <div key={idx} className="table-row">
                  <span className="cell-user">{answer.user_name}</span>
                  <span className="cell-branch">{answer.branch_name || "-"}</span>
                  <span className="cell-answer">{displayAnswer}</span>
                  <span className="cell-date">{new Date(answer.submitted_at).toLocaleDateString("tr-TR")}</span>
                </div>
              );
            })}
          </div>
        )}
      </div>
    );
  };

  if (loading) {
    return (
      <div className="survey-results-page">
        <div className="loading-container">
          <Loader2 className="spinner" size={40} />
          <p>Anket sonuçları yükleniyor...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="survey-results-page">
        <div className="error-container">
          <p>{error}</p>
          <button className="btn btn-primary" onClick={loadData}>
            Tekrar Dene
          </button>
          <button className="btn btn-secondary" onClick={() => router.push("/announcements")}>
            Geri Dön
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="survey-results-page">
      {/* Header */}
      <div className="page-header">
        <div className="header-left">
          <button className="back-btn" onClick={() => router.push("/announcements")}>
            <ArrowLeft size={20} />
            Geri
          </button>
          <div className="header-info">
            <div className="header-title">
              <BarChart3 size={24} />
              <h1>Anket Sonuçları</h1>
            </div>
            {announcement && (
              <p className="survey-title">{announcement.title}</p>
            )}
          </div>
        </div>
        <div className="header-actions">
          <button className="btn btn-secondary" onClick={exportToCSV}>
            <Download size={16} />
            CSV İndir
          </button>
        </div>
      </div>

      {/* Stats Overview */}
      <div className="stats-overview">
        <div className="stat-card">
          <div className="stat-icon">
            <Users size={24} />
          </div>
          <div className="stat-content">
            <span className="stat-value">{results?.total_responses || 0}</span>
            <span className="stat-label">Toplam Katılımcı</span>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon">
            <BarChart3 size={24} />
          </div>
          <div className="stat-content">
            <span className="stat-value">{results?.questions?.length || 0}</span>
            <span className="stat-label">Soru Sayısı</span>
          </div>
        </div>
        {announcement && (
          <div className="stat-card">
            <div className="stat-icon">
              <Calendar size={24} />
            </div>
            <div className="stat-content">
              <span className="stat-value">{new Date(announcement.published_at).toLocaleDateString("tr-TR")}</span>
              <span className="stat-label">Yayınlanma Tarihi</span>
            </div>
          </div>
        )}
      </div>

      {/* View Mode Toggle */}
      <div className="view-controls">
        <div className="view-toggle">
          <button 
            className={`toggle-btn ${viewMode === "summary" ? "active" : ""}`}
            onClick={() => setViewMode("summary")}
          >
            <BarChart3 size={16} />
            Özet Görünüm
          </button>
          <button 
            className={`toggle-btn ${viewMode === "individual" ? "active" : ""}`}
            onClick={() => setViewMode("individual")}
          >
            <Users size={16} />
            Bireysel Yanıtlar
          </button>
        </div>
        <div className="expand-controls">
          <button className="text-btn" onClick={expandAll}>Tümünü Aç</button>
          <button className="text-btn" onClick={collapseAll}>Tümünü Kapat</button>
        </div>
      </div>

      {/* Questions */}
      <div className="questions-list">
        {results?.questions?.map((question, index) => {
          const isExpanded = expandedQuestions.has(question.question_id);
          const answerCount = question.answers?.length || 0;
          
          return (
            <div key={question.question_id} className={`question-card ${isExpanded ? "expanded" : ""}`}>
              <div className="question-header" onClick={() => toggleQuestion(question.question_id)}>
                <div className="question-info">
                  <span className="question-number">{index + 1}</span>
                  <div className="question-type-badge">
                    {getQuestionIcon(question.question_type)}
                    <span>{getQuestionTypeLabel(question.question_type)}</span>
                  </div>
                  <h3 className="question-text">{question.question_text}</h3>
                </div>
                <div className="question-meta">
                  <span className="answer-count">
                    <Users size={14} />
                    {answerCount} yanıt
                  </span>
                  <span className="expand-icon">
                    {isExpanded ? <ChevronUp size={20} /> : <ChevronDown size={20} />}
                  </span>
                </div>
              </div>
              
              {isExpanded && (
                <div className="question-content">
                  {viewMode === "summary" ? (
                    renderQuestionResult(question)
                  ) : (
                    renderIndividualResponses(question)
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {(!results?.questions || results.questions.length === 0) && (
        <div className="empty-state">
          <BarChart3 size={48} />
          <h3>Henüz soru yok</h3>
          <p>Bu ankette henüz soru bulunmuyor.</p>
        </div>
      )}
    </div>
  );
}
