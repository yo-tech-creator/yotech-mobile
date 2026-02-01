"use client";

import { useState, useEffect } from "react";
import { createBrowserClient } from "@supabase/ssr";
import { 
  X, 
  BarChart3, 
  Users,
  CheckCircle,
  Star,
  Loader2,
  Download
} from "lucide-react";
import type { SurveyResults, SurveyQuestionResult } from "@/types/announcements";

interface Props {
  surveyId: string;
  onClose: () => void;
}

export function SurveyResultsModal({ surveyId, onClose }: Props) {
  const [results, setResults] = useState<SurveyResults | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  useEffect(() => {
    loadResults();
  }, [surveyId]);

  const loadResults = async () => {
    try {
      setLoading(true);
      setError(null);

      const { data, error: fetchError } = await supabase.rpc("get_survey_results", {
        p_announcement_id: surveyId,
      });

      if (fetchError) throw fetchError;
      
      setResults(data as SurveyResults);
    } catch (err: unknown) {
      console.error("Error loading survey results:", err);
      const error = err as { message?: string };
      setError(error.message || "Anket sonuçları yüklenirken bir hata oluştu");
    } finally {
      setLoading(false);
    }
  };

  const renderQuestionResult = (question: SurveyQuestionResult) => {
    switch (question.question_type) {
      case "rating":
        return renderRatingResult(question);
      case "single_choice":
      case "multiple_choice":
        return renderChoiceResult(question);
      case "yes_no":
        return renderBooleanResult(question);
      case "number":
        return renderNumberResult(question);
      default:
        return renderTextResult(question);
    }
  };

  const renderRatingResult = (question: SurveyQuestionResult) => {
    const avgRating = question.statistics?.average_rating || 0;
    const ratings = question.statistics?.rating_distribution || {};
    
    return (
      <div className="result-content rating">
        <div className="avg-rating">
          <div className="rating-value">{avgRating.toFixed(1)}</div>
          <div className="rating-stars">
            {[1, 2, 3, 4, 5].map((star) => (
              <Star 
                key={star} 
                size={20} 
                fill={star <= Math.round(avgRating) ? "#fbbf24" : "none"}
                color={star <= Math.round(avgRating) ? "#fbbf24" : "#cbd5e1"}
              />
            ))}
          </div>
          <div className="rating-count">{question.answer_count} değerlendirme</div>
        </div>
        <div className="rating-bars">
          {[5, 4, 3, 2, 1].map((star) => {
            const count = ratings[star.toString()] || 0;
            const percent = question.answer_count > 0 ? (count / question.answer_count) * 100 : 0;
            return (
              <div key={star} className="rating-bar">
                <span className="bar-label">{star}★</span>
                <div className="bar-track">
                  <div className="bar-fill" style={{ width: `${percent}%` }} />
                </div>
                <span className="bar-count">{count}</span>
              </div>
            );
          })}
        </div>
      </div>
    );
  };

  const renderChoiceResult = (question: SurveyQuestionResult) => {
    const distribution = question.statistics?.choice_distribution || {};
    const options = Object.keys(distribution);
    const maxCount = Math.max(...Object.values(distribution), 1);

    return (
      <div className="result-content choice">
        {options.length === 0 ? (
          <p className="no-data">Henüz yanıt yok</p>
        ) : (
          <div className="choice-bars">
            {options.map((option) => {
              const count = distribution[option] || 0;
              const percent = question.answer_count > 0 
                ? ((count / question.answer_count) * 100).toFixed(0) 
                : 0;
              const barWidth = (count / maxCount) * 100;
              
              return (
                <div key={option} className="choice-bar">
                  <div className="choice-label">{option}</div>
                  <div className="choice-bar-container">
                    <div className="choice-bar-track">
                      <div 
                        className="choice-bar-fill" 
                        style={{ width: `${barWidth}%` }} 
                      />
                    </div>
                    <span className="choice-stats">{count} ({percent}%)</span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    );
  };

  const renderBooleanResult = (question: SurveyQuestionResult) => {
    const trueCount = question.statistics?.true_count || 0;
    const falseCount = question.statistics?.false_count || 0;
    const total = trueCount + falseCount;
    const truePercent = total > 0 ? ((trueCount / total) * 100).toFixed(0) : 0;
    const falsePercent = total > 0 ? ((falseCount / total) * 100).toFixed(0) : 0;

    return (
      <div className="result-content boolean">
        <div className="boolean-bars">
          <div className="boolean-option yes">
            <CheckCircle size={18} />
            <span>Evet</span>
            <div className="boolean-bar-track">
              <div 
                className="boolean-bar-fill yes" 
                style={{ width: `${truePercent}%` }} 
              />
            </div>
            <span className="boolean-stat">{trueCount} ({truePercent}%)</span>
          </div>
          <div className="boolean-option no">
            <X size={18} />
            <span>Hayır</span>
            <div className="boolean-bar-track">
              <div 
                className="boolean-bar-fill no" 
                style={{ width: `${falsePercent}%` }} 
              />
            </div>
            <span className="boolean-stat">{falseCount} ({falsePercent}%)</span>
          </div>
        </div>
      </div>
    );
  };

  const renderNumberResult = (question: SurveyQuestionResult) => {
    const stats = question.statistics || {};

    return (
      <div className="result-content number">
        <div className="number-stats">
          <div className="stat-box">
            <span className="stat-value">{stats.min_number ?? "-"}</span>
            <span className="stat-label">Minimum</span>
          </div>
          <div className="stat-box">
            <span className="stat-value">{stats.max_number ?? "-"}</span>
            <span className="stat-label">Maksimum</span>
          </div>
          <div className="stat-box highlight">
            <span className="stat-value">{stats.average_number?.toFixed(1) ?? "-"}</span>
            <span className="stat-label">Ortalama</span>
          </div>
        </div>
      </div>
    );
  };

  const renderTextResult = (question: SurveyQuestionResult) => {
    const responses = question.text_responses || [];

    return (
      <div className="result-content text">
        {responses.length === 0 ? (
          <p className="no-data">Henüz yanıt yok</p>
        ) : (
          <div className="text-responses">
            {responses.slice(0, 10).map((response, idx) => (
              <div key={idx} className="text-response">
                "{response}"
              </div>
            ))}
            {responses.length > 10 && (
              <p className="more-responses">+{responses.length - 10} daha fazla yanıt</p>
            )}
          </div>
        )}
      </div>
    );
  };

  const exportToCSV = () => {
    if (!results) return;

    let csv = "Soru,Tip,Yanıt Sayısı,Detay\n";
    
    results.questions.forEach((q) => {
      let detail = "";
      if (q.question_type === "rating") {
        detail = `Ortalama: ${q.statistics?.average_rating?.toFixed(1) || "-"}`;
      } else if (["single_choice", "multiple_choice"].includes(q.question_type)) {
        const dist = q.statistics?.choice_distribution || {};
        detail = Object.entries(dist).map(([k, v]) => `${k}: ${v}`).join("; ");
      } else if (q.question_type === "yes_no") {
        detail = `Evet: ${q.statistics?.true_count || 0}, Hayır: ${q.statistics?.false_count || 0}`;
      } else if (q.question_type === "number") {
        detail = `Min: ${q.statistics?.min_number ?? "-"}, Max: ${q.statistics?.max_number ?? "-"}, Ort: ${q.statistics?.average_number?.toFixed(1) ?? "-"}`;
      } else {
        detail = (q.text_responses || []).join("; ");
      }
      
      csv += `"${q.question_text}","${q.question_type}",${q.answer_count},"${detail}"\n`;
    });

    const blob = new Blob(["\ufeff" + csv], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = `anket_sonuclari_${results.announcement.title.replace(/[^a-z0-9]/gi, "_")}.csv`;
    link.click();
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content large" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div className="header-title">
            <BarChart3 size={24} />
            <div>
              <h2>Anket Sonuçları</h2>
              {results && <span className="survey-title">{results.announcement.title}</span>}
            </div>
          </div>
          <div className="header-actions">
            {results && (
              <button className="btn btn-secondary" onClick={exportToCSV}>
                <Download size={16} />
                CSV İndir
              </button>
            )}
            <button className="close-btn" onClick={onClose}>
              <X size={20} />
            </button>
          </div>
        </div>

        <div className="modal-body">
          {loading ? (
            <div className="loading">
              <Loader2 className="spinner" size={32} />
              <p>Sonuçlar yükleniyor...</p>
            </div>
          ) : error ? (
            <div className="error">
              <p>{error}</p>
              <button className="btn btn-primary" onClick={loadResults}>
                Tekrar Dene
              </button>
            </div>
          ) : results ? (
            <>
              {/* Summary Stats */}
              <div className="summary-stats">
                <div className="stat-card">
                  <Users size={24} />
                  <div className="stat-info">
                    <span className="stat-value">{results.total_responses}</span>
                    <span className="stat-label">Toplam Yanıt</span>
                  </div>
                </div>
                <div className="stat-card">
                  <CheckCircle size={24} />
                  <div className="stat-info">
                    <span className="stat-value">{results.questions.length}</span>
                    <span className="stat-label">Soru Sayısı</span>
                  </div>
                </div>
              </div>

              {/* Questions */}
              <div className="questions-results">
                {results.questions.map((question, idx) => (
                  <div key={question.question_id} className="question-result-card">
                    <div className="question-header">
                      <span className="question-number">{idx + 1}</span>
                      <div className="question-info">
                        <h4>{question.question_text}</h4>
                        <span className="question-meta">
                          {getQuestionTypeLabel(question.question_type)} • {question.answer_count} yanıt
                          {question.required && <span className="required-badge">Zorunlu</span>}
                        </span>
                      </div>
                    </div>
                    {renderQuestionResult(question)}
                  </div>
                ))}
              </div>
            </>
          ) : null}
        </div>

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
            max-width: 900px;
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

          .header-title {
            display: flex;
            align-items: center;
            gap: 12px;
          }

          .header-title h2 {
            margin: 0;
            font-size: 18px;
          }

          .survey-title {
            font-size: 13px;
            color: #64748b;
          }

          .header-actions {
            display: flex;
            align-items: center;
            gap: 12px;
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

          .loading, .error {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 60px 20px;
            text-align: center;
            color: #64748b;
          }

          .spinner {
            animation: spin 1s linear infinite;
          }

          @keyframes spin {
            to { transform: rotate(360deg); }
          }

          .summary-stats {
            display: flex;
            gap: 16px;
            margin-bottom: 24px;
          }

          .stat-card {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 16px 20px;
            background: #f8fafc;
            border-radius: 10px;
            flex: 1;
            color: #3b82f6;
          }

          .stat-info {
            display: flex;
            flex-direction: column;
          }

          .stat-info .stat-value {
            font-size: 24px;
            font-weight: 600;
            color: #1e293b;
          }

          .stat-info .stat-label {
            font-size: 13px;
            color: #64748b;
          }

          .questions-results {
            display: flex;
            flex-direction: column;
            gap: 20px;
          }

          .question-result-card {
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            overflow: hidden;
          }

          .question-header {
            display: flex;
            align-items: flex-start;
            gap: 12px;
            padding: 16px;
            background: #f8fafc;
            border-bottom: 1px solid #e2e8f0;
          }

          .question-number {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 28px;
            height: 28px;
            background: #3b82f6;
            color: white;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
          }

          .question-info h4 {
            margin: 0 0 4px;
            font-size: 15px;
            font-weight: 500;
          }

          .question-meta {
            font-size: 12px;
            color: #64748b;
          }

          .required-badge {
            display: inline-block;
            margin-left: 8px;
            padding: 2px 6px;
            background: #fee2e2;
            color: #dc2626;
            border-radius: 4px;
            font-size: 10px;
          }

          .result-content {
            padding: 20px;
          }

          .no-data {
            color: #94a3b8;
            font-style: italic;
            text-align: center;
          }

          /* Rating styles */
          .result-content.rating {
            display: flex;
            gap: 32px;
          }

          .avg-rating {
            text-align: center;
          }

          .rating-value {
            font-size: 48px;
            font-weight: 700;
            color: #1e293b;
            line-height: 1;
          }

          .rating-stars {
            display: flex;
            justify-content: center;
            gap: 4px;
            margin: 8px 0;
          }

          .rating-count {
            font-size: 12px;
            color: #64748b;
          }

          .rating-bars {
            flex: 1;
            display: flex;
            flex-direction: column;
            gap: 6px;
          }

          .rating-bar {
            display: flex;
            align-items: center;
            gap: 8px;
          }

          .bar-label {
            width: 30px;
            font-size: 13px;
            color: #64748b;
          }

          .bar-track {
            flex: 1;
            height: 12px;
            background: #f1f5f9;
            border-radius: 6px;
            overflow: hidden;
          }

          .bar-fill {
            height: 100%;
            background: #fbbf24;
            border-radius: 6px;
          }

          .bar-count {
            width: 30px;
            font-size: 13px;
            color: #64748b;
            text-align: right;
          }

          /* Choice styles */
          .choice-bars {
            display: flex;
            flex-direction: column;
            gap: 12px;
          }

          .choice-bar {
            display: flex;
            flex-direction: column;
            gap: 4px;
          }

          .choice-label {
            font-size: 14px;
            color: #334155;
          }

          .choice-bar-container {
            display: flex;
            align-items: center;
            gap: 12px;
          }

          .choice-bar-track {
            flex: 1;
            height: 24px;
            background: #f1f5f9;
            border-radius: 6px;
            overflow: hidden;
          }

          .choice-bar-fill {
            height: 100%;
            background: linear-gradient(90deg, #3b82f6 0%, #60a5fa 100%);
            border-radius: 6px;
          }

          .choice-stats {
            font-size: 13px;
            color: #64748b;
            min-width: 80px;
            text-align: right;
          }

          /* Boolean styles */
          .boolean-bars {
            display: flex;
            flex-direction: column;
            gap: 12px;
          }

          .boolean-option {
            display: flex;
            align-items: center;
            gap: 12px;
          }

          .boolean-option.yes {
            color: #16a34a;
          }

          .boolean-option.no {
            color: #dc2626;
          }

          .boolean-option span:first-of-type {
            width: 50px;
          }

          .boolean-bar-track {
            flex: 1;
            height: 24px;
            background: #f1f5f9;
            border-radius: 6px;
            overflow: hidden;
          }

          .boolean-bar-fill.yes {
            height: 100%;
            background: #22c55e;
            border-radius: 6px;
          }

          .boolean-bar-fill.no {
            height: 100%;
            background: #ef4444;
            border-radius: 6px;
          }

          .boolean-stat {
            font-size: 13px;
            color: #64748b !important;
            min-width: 80px;
            text-align: right;
          }

          /* Number styles */
          .number-stats {
            display: flex;
            gap: 16px;
          }

          .stat-box {
            flex: 1;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 20px;
            background: #f8fafc;
            border-radius: 10px;
          }

          .stat-box.highlight {
            background: #eff6ff;
          }

          .stat-box .stat-value {
            font-size: 28px;
            font-weight: 600;
            color: #1e293b;
          }

          .stat-box .stat-label {
            font-size: 12px;
            color: #64748b;
            margin-top: 4px;
          }

          /* Text styles */
          .text-responses {
            display: flex;
            flex-direction: column;
            gap: 8px;
          }

          .text-response {
            padding: 10px 14px;
            background: #f8fafc;
            border-radius: 8px;
            font-size: 14px;
            font-style: italic;
            color: #475569;
          }

          .more-responses {
            text-align: center;
            font-size: 13px;
            color: #64748b;
            margin-top: 8px;
          }

          .btn {
            display: flex;
            align-items: center;
            gap: 6px;
            padding: 8px 16px;
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

          .btn-primary:hover {
            background: #2563eb;
          }

          .btn-secondary {
            background: #f1f5f9;
            color: #334155;
          }

          .btn-secondary:hover {
            background: #e2e8f0;
          }
        `}</style>
      </div>
    </div>
  );
}

function getQuestionTypeLabel(type: string): string {
  const labels: Record<string, string> = {
    text: "Metin",
    textarea: "Uzun Metin",
    single_choice: "Tek Seçim",
    multiple_choice: "Çoklu Seçim",
    rating: "Puanlama",
    number: "Sayı",
    boolean: "Evet/Hayır",
  };
  return labels[type] || type;
}
