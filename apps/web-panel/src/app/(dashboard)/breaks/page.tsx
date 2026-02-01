"use client";

import { useEffect, useState, useMemo } from "react";
import "./breaks.css";

interface BreakSession {
  id: string;
  user_id: string;
  branch_id?: string;
  started_at: string;
  ended_at: string | null;
  duration_seconds: number | null;
  user_name?: string;
}

interface Branch {
  id: string;
  name: string;
}

interface GroupedBreaks {
  userName: string;
  userId: string;
  breaks: BreakSession[];
  totalSeconds: number;
  isActive: boolean;
}

const formatTime = (isoString: string) => {
  const date = new Date(isoString);
  return date.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });
};

const formatDuration = (seconds: number) => {
  const hours = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  if (hours > 0) {
    return `${hours}s ${mins}dk`;
  }
  return `${mins}dk`;
};

const formatDate = (date: Date) => {
  return date.toLocaleDateString("tr-TR", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });
};

const formatIsoDate = (date: Date) => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
};

export default function BreaksPage() {
  const [selectedDate, setSelectedDate] = useState<Date>(new Date());
  const [activeTab, setActiveTab] = useState<"my" | "team">("my");
  const [myBreaks, setMyBreaks] = useState<BreakSession[]>([]);
  const [teamBreaks, setTeamBreaks] = useState<BreakSession[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [userRole, setUserRole] = useState<string | null>(null);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [selectedBranchId, setSelectedBranchId] = useState<string | null>(null);

  const isManager = userRole === "sube_muduru" || userRole === "bolge_muduru" || userRole === "firma_admin";
  const isBolgeMuduru = userRole === "bolge_muduru";

  useEffect(() => {
    const fetchBreaks = async () => {
      setLoading(true);
      setError(null);
      
      try {
        const dateParam = formatIsoDate(selectedDate);
        
        // Fetch my breaks
        const myRes = await fetch(`/api/breaks?date=${dateParam}`);
        const myData = await myRes.json();
        
        if (!myRes.ok) {
          console.error("API Error:", myData);
          throw new Error(myData.error || "Molalar yüklenemedi");
        }
        
        setMyBreaks(myData.breaks || []);
        setUserRole(myData.role);

        // Store branches for bolge_muduru
        if (myData.branches && myData.branches.length > 0) {
          setBranches(myData.branches);
        }

        // Fetch team breaks if manager
        if (myData.role === "sube_muduru" || myData.role === "bolge_muduru" || myData.role === "firma_admin") {
          let teamUrl = `/api/breaks?date=${dateParam}&team=true`;
          // Add branch filter for bolge_muduru
          if (myData.role === "bolge_muduru" && selectedBranchId) {
            teamUrl += `&branchId=${selectedBranchId}`;
          }
          const teamRes = await fetch(teamUrl);
          if (teamRes.ok) {
            const teamData = await teamRes.json();
            setTeamBreaks(teamData.breaks || []);
          } else {
            const teamError = await teamRes.json();
            console.error("Team breaks error:", teamError);
          }
        }
      } catch (err) {
        console.error("Fetch error:", err);
        setError((err as Error).message);
      } finally {
        setLoading(false);
      }
    };

    fetchBreaks();
  }, [selectedDate, selectedBranchId]);

  const goToPrevDay = () => {
    setSelectedDate((prev) => {
      const next = new Date(prev);
      next.setDate(next.getDate() - 1);
      return next;
    });
  };

  const goToNextDay = () => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const selected = new Date(selectedDate);
    selected.setHours(0, 0, 0, 0);
    
    if (selected >= today) return;
    
    setSelectedDate((prev) => {
      const next = new Date(prev);
      next.setDate(next.getDate() + 1);
      return next;
    });
  };

  const isToday = useMemo(() => {
    const today = new Date();
    return (
      selectedDate.getFullYear() === today.getFullYear() &&
      selectedDate.getMonth() === today.getMonth() &&
      selectedDate.getDate() === today.getDate()
    );
  }, [selectedDate]);

  // Calculate summary for my breaks
  const myTotalSeconds = useMemo(() => {
    return myBreaks.reduce((sum, b) => {
      if (b.duration_seconds) return sum + b.duration_seconds;
      if (!b.ended_at) {
        // Active break
        const now = new Date();
        const started = new Date(b.started_at);
        return sum + Math.floor((now.getTime() - started.getTime()) / 1000);
      }
      return sum;
    }, 0);
  }, [myBreaks]);

  // Group team breaks by user
  const groupedTeamBreaks: GroupedBreaks[] = useMemo(() => {
    const groups = new Map<string, GroupedBreaks>();
    
    teamBreaks.forEach((b) => {
      const key = b.user_id;
      if (!groups.has(key)) {
        groups.set(key, {
          userName: b.user_name || b.user_id.slice(0, 8),
          userId: b.user_id,
          breaks: [],
          totalSeconds: 0,
          isActive: false,
        });
      }
      const group = groups.get(key)!;
      group.breaks.push(b);
      
      if (b.duration_seconds) {
        group.totalSeconds += b.duration_seconds;
      } else if (!b.ended_at) {
        group.isActive = true;
        const now = new Date();
        const started = new Date(b.started_at);
        group.totalSeconds += Math.floor((now.getTime() - started.getTime()) / 1000);
      }
    });
    
    return Array.from(groups.values()).sort((a, b) => {
      // Active users first
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      return b.totalSeconds - a.totalSeconds;
    });
  }, [teamBreaks]);

  // Team summary
  const teamSummary = useMemo(() => {
    const uniqueUsers = new Set(teamBreaks.map((b) => b.user_id)).size;
    const totalBreaks = teamBreaks.length;
    const activeCount = teamBreaks.filter((b) => !b.ended_at).length;
    const totalSeconds = groupedTeamBreaks.reduce((sum, g) => sum + g.totalSeconds, 0);
    return { uniqueUsers, totalBreaks, activeCount, totalSeconds };
  }, [teamBreaks, groupedTeamBreaks]);

  return (
    <div className="breaks-page">
      <header className="breaks-header">
        <div className="breaks-header__info">
          <h1>Mola Takibi</h1>
          <p>Günlük mola geçmişi ve ekip molaları</p>
        </div>
      </header>

      {/* Tabs */}
      <div className="breaks-tabs">
        <button
          className={`breaks-tab ${activeTab === "my" ? "breaks-tab--active" : ""}`}
          onClick={() => setActiveTab("my")}
        >
          <span className="breaks-tab__icon">👤</span>
          Molalarım
        </button>
        <button
          className={`breaks-tab ${activeTab === "team" ? "breaks-tab--active" : ""} ${!isManager ? "breaks-tab--disabled" : ""}`}
          onClick={() => isManager && setActiveTab("team")}
          disabled={!isManager}
        >
          <span className="breaks-tab__icon">{isManager ? "👥" : "🔒"}</span>
          Ekip Molaları
        </button>
      </div>

      {/* Date Selector */}
      <div className="breaks-date-selector">
        <button className="breaks-date-nav" onClick={goToPrevDay}>
          ‹
        </button>
        <div className="breaks-date-display">
          <span className="breaks-date-label">{isToday ? "Bugün" : ""}</span>
          <span className="breaks-date-value">{formatDate(selectedDate)}</span>
        </div>
        <button
          className="breaks-date-nav"
          onClick={goToNextDay}
          disabled={isToday}
        >
          ›
        </button>
      </div>

      {loading && (
        <div className="breaks-loading">
          <div className="breaks-spinner"></div>
          <span>Yükleniyor...</span>
        </div>
      )}

      {error && (
        <div className="breaks-error">
          <span>⚠️</span> {error}
        </div>
      )}

      {!loading && !error && (
        <>
          {activeTab === "my" && (
            <div className="breaks-content">
              {/* Summary Card */}
              <div className="breaks-summary">
                <div className="breaks-summary__item">
                  <span className="breaks-summary__icon">⏱️</span>
                  <div className="breaks-summary__info">
                    <span className="breaks-summary__label">Toplam Süre</span>
                    <span className="breaks-summary__value">{formatDuration(myTotalSeconds)}</span>
                  </div>
                </div>
                <div className="breaks-summary__item">
                  <span className="breaks-summary__icon">☕</span>
                  <div className="breaks-summary__info">
                    <span className="breaks-summary__label">Mola Sayısı</span>
                    <span className="breaks-summary__value">{myBreaks.length}</span>
                  </div>
                </div>
              </div>

              {/* Break List */}
              {myBreaks.length === 0 ? (
                <div className="breaks-empty">
                  <span className="breaks-empty__icon">☕</span>
                  <p>Bu tarihte mola kaydı yok</p>
                </div>
              ) : (
                <div className="breaks-list">
                  {myBreaks.map((b) => (
                    <div
                      key={b.id}
                      className={`breaks-card ${!b.ended_at ? "breaks-card--active" : ""}`}
                    >
                      <div className="breaks-card__icon">
                        {b.ended_at ? "☕" : "🟢"}
                      </div>
                      <div className="breaks-card__content">
                        <span className="breaks-card__time">
                          {formatTime(b.started_at)} - {b.ended_at ? formatTime(b.ended_at) : "Devam ediyor"}
                        </span>
                        {b.duration_seconds && (
                          <span className="breaks-card__duration">
                            {formatDuration(b.duration_seconds)}
                          </span>
                        )}
                      </div>
                      {!b.ended_at && (
                        <span className="breaks-card__badge">Aktif</span>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {activeTab === "team" && isManager && (
            <div className="breaks-content">
              {/* Branch Filter for Bölge Müdürü */}
              {isBolgeMuduru && branches.length > 0 && (
                <div className="breaks-branch-filter">
                  <label htmlFor="branch-select">Şube:</label>
                  <select
                    id="branch-select"
                    value={selectedBranchId || ""}
                    onChange={(e) => setSelectedBranchId(e.target.value || null)}
                    className="breaks-branch-select"
                  >
                    <option value="">Tüm Şubeler</option>
                    {branches.map((b) => (
                      <option key={b.id} value={b.id}>
                        {b.name}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              {/* Team Summary */}
              <div className="breaks-team-summary">
                <div className="breaks-team-summary__item">
                  <span className="breaks-team-summary__icon">👥</span>
                  <span className="breaks-team-summary__value">{teamSummary.uniqueUsers}</span>
                  <span className="breaks-team-summary__label">Kişi</span>
                </div>
                <div className="breaks-team-summary__item">
                  <span className="breaks-team-summary__icon">☕</span>
                  <span className="breaks-team-summary__value">{teamSummary.totalBreaks}</span>
                  <span className="breaks-team-summary__label">Mola</span>
                </div>
                <div className="breaks-team-summary__item">
                  <span className="breaks-team-summary__icon">⏱️</span>
                  <span className="breaks-team-summary__value">{formatDuration(teamSummary.totalSeconds)}</span>
                  <span className="breaks-team-summary__label">Toplam</span>
                </div>
              </div>

              {teamSummary.activeCount > 0 && (
                <div className="breaks-active-alert">
                  <span>🔴</span> {teamSummary.activeCount} kişi şu an molada
                </div>
              )}

              {/* Grouped Team Breaks */}
              {groupedTeamBreaks.length === 0 ? (
                <div className="breaks-empty">
                  <span className="breaks-empty__icon">👥</span>
                  <p>Bu tarihte ekip mola kaydı yok</p>
                </div>
              ) : (
                <div className="breaks-team-list">
                  {groupedTeamBreaks.map((group) => (
                    <details key={group.userId} className="breaks-person-card" open={group.isActive}>
                      <summary className="breaks-person-header">
                        <div className="breaks-person-avatar">
                          {group.userName.charAt(0).toUpperCase()}
                        </div>
                        <div className="breaks-person-info">
                          <span className="breaks-person-name">
                            {group.userName}
                            {group.isActive && <span className="breaks-person-badge">Molada</span>}
                          </span>
                          <span className="breaks-person-stats">
                            {group.breaks.length} mola • {formatDuration(group.totalSeconds)}
                          </span>
                        </div>
                      </summary>
                      <div className="breaks-person-breaks">
                        {group.breaks.map((b) => (
                          <div key={b.id} className="breaks-person-break">
                            <span className={`breaks-person-break__dot ${!b.ended_at ? "breaks-person-break__dot--active" : ""}`}></span>
                            <span className="breaks-person-break__time">
                              {formatTime(b.started_at)} - {b.ended_at ? formatTime(b.ended_at) : "Devam"}
                            </span>
                            {b.duration_seconds && (
                              <span className="breaks-person-break__duration">
                                {formatDuration(b.duration_seconds)}
                              </span>
                            )}
                          </div>
                        ))}
                      </div>
                    </details>
                  ))}
                </div>
              )}
            </div>
          )}

          {activeTab === "team" && !isManager && (
            <div className="breaks-no-permission">
              <span className="breaks-no-permission__icon">🔒</span>
              <h3>Erişim Yetkiniz Yok</h3>
              <p>Ekip molalarını görüntülemek için şube müdürü veya üstü yetki gerekir.</p>
            </div>
          )}
        </>
      )}
    </div>
  );
}
