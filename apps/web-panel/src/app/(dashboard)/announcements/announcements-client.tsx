"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { createBrowserClient } from "@supabase/ssr";
import { 
  Bell, 
  BarChart3, 
  Eye, 
  Trash2, 
  Pin, 
  Calendar,
  Clock,
  Search,
  Building2,
  UserCheck,
  ChevronDown,
  ChevronUp,
  User,
  Loader2,
  History,
  ArrowUpDown,
  ArrowUp,
  ArrowDown,
  Filter,
  XCircle
} from "lucide-react";
import type { AnnouncementWithStats, Announcement } from "@/types/announcements";

type TabType = "all" | "announcements" | "surveys" | "history";
type SortOrder = "newest" | "oldest";
type HistoryTypeFilter = "all" | "surveys" | "announcements";

interface AnnouncementDetail extends Announcement {
  publisher?: {
    id: string;
    first_name: string;
    last_name: string;
    role: string;
  };
  read_count: number;
  reads?: {
    id: string;
    user: {
      first_name: string;
      last_name: string;
      role: string;
    };
    branch: {
      name: string;
    };
    read_at: string;
  }[];
}

export function AnnouncementsClient() {
  const router = useRouter();
  const [announcements, setAnnouncements] = useState<AnnouncementWithStats[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<TabType>("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [userRole, setUserRole] = useState<string | null>(null);
  
  // History tab filters
  const [historySortOrder, setHistorySortOrder] = useState<SortOrder>("newest");
  const [historyDateFrom, setHistoryDateFrom] = useState<string>("");
  const [historyDateTo, setHistoryDateTo] = useState<string>("");
  const [historyTypeFilter, setHistoryTypeFilter] = useState<HistoryTypeFilter>("all");
  
  // Expanded card state
  const [expandedAnnouncementId, setExpandedAnnouncementId] = useState<string | null>(null);
  const [expandedDetail, setExpandedDetail] = useState<AnnouncementDetail | null>(null);
  const [expandedLoading, setExpandedLoading] = useState(false);
  const [showReads, setShowReads] = useState(false);
  
  // Cache for loaded announcement details
  const [detailsCache, setDetailsCache] = useState<Record<string, AnnouncementDetail>>({});

  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  const loadAnnouncements = useCallback(async (showLoading = true) => {
    try {
      if (showLoading) setLoading(true);
      setError(null);

      // Get current user role
      const { data: userData } = await supabase.auth.getUser();
      if (userData?.user) {
        const { data: profile } = await supabase
          .from("users")
          .select("role")
          .eq("id", userData.user.id)
          .single();
        setUserRole(profile?.role || null);
      }

      // Get announcements from API (bypasses RLS)
      const response = await fetch("/api/announcements");
      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || "Duyurular yüklenemedi");
      }

      // Transform data
      const transformed = (result.announcements || []).map((item: Record<string, unknown>) => ({
        ...item,
        publisher: item.publisher ? {
          id: (item.publisher as Record<string, unknown>).id,
          name: `${(item.publisher as Record<string, unknown>).first_name || ''} ${(item.publisher as Record<string, unknown>).last_name || ''}`.trim(),
          role: (item.publisher as Record<string, unknown>).role,
        } : undefined,
        read_count: (item.read_count as number) || 0,
        response_count: (item.response_count as number) || 0,
        question_count: 0,
      })) as AnnouncementWithStats[];

      setAnnouncements(transformed);
    } catch (err) {
      console.error("Error loading announcements:", err);
      setError("Duyurular yüklenirken bir hata oluştu");
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadAnnouncements(true);
    
    // Refresh every 30 seconds to update read counts (without showing loading)
    const interval = setInterval(() => {
      loadAnnouncements(false);
    }, 30000);
    
    return () => clearInterval(interval);
  }, [loadAnnouncements]);

  const handleDelete = async (id: string) => {
    if (!confirm("Bu duyuruyu silmek istediğinize emin misiniz?")) return;

    // Store the item for potential rollback
    const deletedItem = announcements.find(a => a.id === id);
    
    // Optimistic update - remove from UI immediately
    setAnnouncements(prev => prev.filter(a => a.id !== id));
    
    // Also clear expanded state if this item was expanded
    if (expandedAnnouncementId === id) {
      setExpandedAnnouncementId(null);
      setExpandedDetail(null);
    }
    
    // Remove from cache
    setDetailsCache(prev => {
      const newCache = { ...prev };
      delete newCache[id];
      return newCache;
    });

    try {
      const response = await fetch(`/api/announcements/${id}`, {
        method: "DELETE",
      });
      
      const result = await response.json();
      
      if (!response.ok) {
        // Rollback on error - add item back
        if (deletedItem) {
          setAnnouncements(prev => sortAnnouncements([...prev, deletedItem]));
        }
        throw new Error(result.error || "Silme başarısız");
      }
    } catch (err) {
      console.error("Error deleting announcement:", err);
      alert("Silme işlemi başarısız oldu");
    }
  };

  // Sort announcements: pinned first (by pinned_at desc), then by priority, then by published_at
  const sortAnnouncements = useCallback((items: AnnouncementWithStats[]) => {
    return [...items].sort((a, b) => {
      // First by pinned status
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      
      // If both pinned, sort by pinned_at (most recent first)
      if (a.pinned && b.pinned) {
        const aTime = a.pinned_at ? new Date(a.pinned_at).getTime() : 0;
        const bTime = b.pinned_at ? new Date(b.pinned_at).getTime() : 0;
        if (bTime !== aTime) return bTime - aTime;
      }
      
      // Then by priority
      if ((b.priority || 0) !== (a.priority || 0)) {
        return (b.priority || 0) - (a.priority || 0);
      }
      
      // Finally by published_at
      const aPublished = new Date(a.published_at).getTime();
      const bPublished = new Date(b.published_at).getTime();
      return bPublished - aPublished;
    });
  }, []);

  // Expand/collapse announcement card
  const handleExpandAnnouncement = async (id: string) => {
    // If already expanded, collapse
    if (expandedAnnouncementId === id) {
      setExpandedAnnouncementId(null);
      setExpandedDetail(null);
      setShowReads(false);
      return;
    }

    // Expand the card
    setExpandedAnnouncementId(id);
    setShowReads(false);
    
    // Check if we have cached data
    if (detailsCache[id]) {
      setExpandedDetail(detailsCache[id]);
      // Mark as read in background
      fetch(`/api/announcements/${id}/read`, { method: "POST" }).catch(() => {});
      return;
    }

    // Load details if not cached
    setExpandedLoading(true);
    
    try {
      // Mark as read
      fetch(`/api/announcements/${id}/read`, { method: "POST" }).catch(() => {});

      // Load full details
      const response = await fetch(`/api/announcements/${id}`);
      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || "Duyuru bulunamadı");
      }

      const detail = result.announcement as AnnouncementDetail;
      setExpandedDetail(detail);
      
      // Cache the detail
      setDetailsCache(prev => ({ ...prev, [id]: detail }));
    } catch (err) {
      console.error("Error loading announcement details:", err);
    } finally {
      setExpandedLoading(false);
    }
  };

  // Helper functions for detail view
  const getPriorityLabel = (priority: number) => {
    const labels: Record<number, { label: string; color: string }> = {
      1: { label: "Düşük", color: "#94a3b8" },
      2: { label: "Normal", color: "#3b82f6" },
      3: { label: "Yüksek", color: "#f59e0b" },
      4: { label: "Acil", color: "#dc2626" },
    };
    return labels[priority] || labels[2];
  };

  const getRoleLabel = (role: string) => {
    const labels: Record<string, string> = {
      firma_admin: "Firma Admin",
      bolge_muduru: "Bölge Müdürü",
      sube_muduru: "Şube Müdürü",
      personel: "Personel",
    };
    return labels[role] || role;
  };

  const handleTogglePin = async (id: string, currentPinned: boolean) => {
    const newPinned = !currentPinned;
    const newPinnedAt = newPinned ? new Date().toISOString() : undefined;
    
    // Optimistic update - update UI immediately with proper sorting
    setAnnouncements(prev => {
      const updated = prev.map(a => 
        a.id === id ? { ...a, pinned: newPinned, pinned_at: newPinnedAt } : a
      );
      return sortAnnouncements(updated);
    });
    
    try {
      const response = await fetch(`/api/announcements/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pinned: newPinned }),
      });
      
      const result = await response.json();
      
      if (!response.ok) {
        // Revert on error
        setAnnouncements(prev => {
          const reverted = prev.map(a => 
            a.id === id ? { ...a, pinned: currentPinned, pinned_at: undefined } : a
          );
          return sortAnnouncements(reverted);
        });
        throw new Error(result.error || "Güncelleme başarısız");
      }
    } catch (err) {
      console.error("Error toggling pin:", err);
      alert("Sabitleme işlemi başarısız oldu");
    }
  };

  // Close survey/announcement (move to history)
  const handleCloseSurvey = async (id: string) => {
    if (!confirm("Bu anketi/duyuruyu kapatmak istediğinize emin misiniz? Geçmiş bölümüne taşınacak.")) return;

    // Set expires_at to now to move it to history
    const expiresAt = new Date().toISOString();
    
    // Optimistic update
    setAnnouncements(prev => prev.map(a => 
      a.id === id ? { ...a, expires_at: expiresAt } : a
    ));

    try {
      const response = await fetch(`/api/announcements/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ expires_at: expiresAt }),
      });
      
      const result = await response.json();
      
      if (!response.ok) {
        // Revert on error
        setAnnouncements(prev => prev.map(a => 
          a.id === id ? { ...a, expires_at: undefined } : a
        ));
        throw new Error(result.error || "Kapatma başarısız");
      }
    } catch (err) {
      console.error("Error closing survey:", err);
      alert("Anket kapatma işlemi başarısız oldu");
    }
  };

  // Filter announcements
  const filteredAnnouncements = announcements.filter((a) => {
    // Tab filter - history shows expired items
    if (activeTab === "history") {
      // Show expired announcements/surveys
      const isExpired = a.expires_at && new Date(a.expires_at) < new Date();
      if (!isExpired) return false;
      
      // Apply type filter for history
      if (historyTypeFilter === "surveys" && a.type !== "survey") return false;
      if (historyTypeFilter === "announcements" && a.type !== "announcement") return false;
      
      // Apply date range filter for history
      if (historyDateFrom) {
        const fromDate = new Date(historyDateFrom);
        fromDate.setHours(0, 0, 0, 0);
        if (new Date(a.published_at) < fromDate) return false;
      }
      if (historyDateTo) {
        const toDate = new Date(historyDateTo);
        toDate.setHours(23, 59, 59, 999);
        if (new Date(a.published_at) > toDate) return false;
      }
    } else {
      // Non-history tabs: exclude expired items
      const isExpired = a.expires_at && new Date(a.expires_at) < new Date();
      if (isExpired) return false;
      
      if (activeTab === "announcements" && a.type !== "announcement") return false;
      if (activeTab === "surveys" && a.type !== "survey") return false;
    }

    // Search filter
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      return (
        a.title.toLowerCase().includes(query) ||
        a.content.toLowerCase().includes(query)
      );
    }

    return true;
  });

  // Sort history items by date
  const sortedAnnouncements = activeTab === "history" 
    ? [...filteredAnnouncements].sort((a, b) => {
        const aTime = new Date(a.published_at).getTime();
        const bTime = new Date(b.published_at).getTime();
        return historySortOrder === "newest" ? bTime - aTime : aTime - bTime;
      })
    : filteredAnnouncements;

  // Count expired items for history tab
  const expiredCount = announcements.filter(a => a.expires_at && new Date(a.expires_at) < new Date()).length;

  const getTargetDescription = (a: AnnouncementWithStats) => {
    const parts: string[] = [];
    
    // Determine scope from target_branches array
    if (!a.target_branches || a.target_branches.length === 0) {
      parts.push("Tüm Şubeler");
    } else {
      parts.push(`${a.target_branches.length} Şube`);
    }

    // Check target_roles for manager filtering
    if (a.target_roles && a.target_roles.length > 0) {
      if (a.target_roles.includes("firma_admin") && 
          a.target_roles.includes("bolge_muduru") && 
          a.target_roles.includes("sube_muduru")) {
        parts.push("Sadece Müdürler");
      } else if (a.target_roles.includes("bolge_muduru")) {
        parts.push("+ Bölge Müdürleri");
      }
    }

    return parts.join(" • ");
  };

  if (loading) {
    return (
      <div className="page-container">
        <div className="loading-container">
          <div className="spinner" />
          <p>Yükleniyor...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="page-container">
      {/* Fixed Header Section */}
      <div className="fixed-header">
        {/* Title & Actions Row */}
        <div className="page-header">
          <div className="header-left">
            <h1>Duyurular & Anketler</h1>
            <p className="text-muted">
              Duyuru paylaşın veya anket oluşturun
            </p>
          </div>
          <div className="header-actions">
            <button 
              className="btn btn-secondary"
              onClick={() => router.push("/announcements/new")}
            >
              <Bell size={18} />
              Yeni Duyuru
            </button>
            <button 
              className="btn btn-primary"
              onClick={() => router.push("/announcements/new-survey")}
            >
              <BarChart3 size={18} />
              Yeni Anket
            </button>
          </div>
        </div>

        {error && (
          <div className="alert alert-error">
            {error}
            <button onClick={() => loadAnnouncements()} className="btn btn-sm">
              Tekrar Dene
            </button>
          </div>
        )}

        {/* Fixed Tabs & Filters Bar */}
        <div className="filters-bar">
          <div className="tabs">
            <button
              className={`tab ${activeTab === "all" ? "active" : ""}`}
              onClick={() => setActiveTab("all")}
            >
              Tümü
              <span className="badge">{announcements.filter(a => !a.expires_at || new Date(a.expires_at) >= new Date()).length}</span>
            </button>
            <button
              className={`tab ${activeTab === "announcements" ? "active" : ""}`}
              onClick={() => setActiveTab("announcements")}
            >
              <Bell size={16} />
              Duyurular
              <span className="badge">
                {announcements.filter((a) => a.type === "announcement" && (!a.expires_at || new Date(a.expires_at) >= new Date())).length}
              </span>
            </button>
            <button
              className={`tab ${activeTab === "surveys" ? "active" : ""}`}
              onClick={() => setActiveTab("surveys")}
            >
              <BarChart3 size={16} />
              Anketler
              <span className="badge">
                {announcements.filter((a) => a.type === "survey" && (!a.expires_at || new Date(a.expires_at) >= new Date())).length}
              </span>
            </button>
            <button
              className={`tab ${activeTab === "history" ? "active" : ""}`}
              onClick={() => setActiveTab("history")}
            >
              <History size={16} />
              Geçmiş
              <span className="badge">{expiredCount}</span>
            </button>
          </div>

          <div className="search-box">
            <Search size={18} />
            <input
              type="text"
              placeholder="Ara..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
        </div>

        {/* History Filters */}
        {activeTab === "history" && (
          <div className="history-filters">
            <div className="filter-group">
              <label>
                <Filter size={14} />
                Tip
              </label>
              <select
                value={historyTypeFilter}
                onChange={(e) => setHistoryTypeFilter(e.target.value as HistoryTypeFilter)}
                className="type-select"
              >
                <option value="all">Tümü</option>
                <option value="surveys">Anketler</option>
                <option value="announcements">Duyurular</option>
              </select>
            </div>
            <div className="filter-group">
              <label>
                <Calendar size={14} />
                Başlangıç
              </label>
              <input 
                type="date" 
                value={historyDateFrom}
                onChange={(e) => setHistoryDateFrom(e.target.value)}
              />
            </div>
            <div className="filter-group">
              <label>
                <Calendar size={14} />
                Bitiş
              </label>
              <input 
                type="date" 
                value={historyDateTo}
                onChange={(e) => setHistoryDateTo(e.target.value)}
              />
            </div>
            <div className="filter-group">
              <label>
                <ArrowUpDown size={14} />
                Sıralama
              </label>
              <button 
                className="sort-btn"
                onClick={() => setHistorySortOrder(prev => prev === "newest" ? "oldest" : "newest")}
              >
                {historySortOrder === "newest" ? (
                  <>
                    <ArrowDown size={14} />
                    En Yeni
                  </>
                ) : (
                  <>
                    <ArrowUp size={14} />
                    En Eski
                  </>
                )}
              </button>
            </div>
            {(historyDateFrom || historyDateTo || historyTypeFilter !== "all") && (
              <button 
                className="clear-filters-btn"
                onClick={() => {
                  setHistoryDateFrom("");
                  setHistoryDateTo("");
                  setHistoryTypeFilter("all");
                }}
              >
                Filtreleri Temizle
              </button>
            )}
          </div>
        )}
      </div>

      {/* Content Area - This is the only part that changes */}
      <div className="content-area">

      {/* Announcements List */}
      {sortedAnnouncements.length === 0 ? (
        <div className="empty-state">
          {activeTab === "history" ? (
            <>
              <History size={48} />
              <h3>Geçmiş kayıt bulunamadı</h3>
              <p>Süresi dolmuş duyuru veya anket bulunmuyor</p>
            </>
          ) : (
            <>
              <Bell size={48} />
              <h3>Henüz duyuru veya anket yok</h3>
              <p>Yeni bir duyuru veya anket oluşturarak başlayın</p>
            </>
          )}
        </div>
      ) : (
        <div className="announcements-grid">
          {sortedAnnouncements.map((a) => (
            <div 
              key={a.id} 
              className={`announcement-card ${a.pinned ? "pinned" : ""} ${a.type} priority-${a.priority} ${activeTab === "history" ? "expired" : ""}`}
            >
              {/* Card Header */}
              <div className="card-header">
                <div className="card-type">
                  {a.type === "survey" ? (
                    <span className="type-badge survey">
                      <BarChart3 size={14} />
                      Anket
                    </span>
                  ) : (
                    <span className="type-badge announcement">
                      <Bell size={14} />
                      Duyuru
                    </span>
                  )}
                  {a.priority === 4 && (
                    <span className="priority-badge urgent">
                      🔴 Acil
                    </span>
                  )}
                  {a.priority === 3 && (
                    <span className="priority-badge high">
                      🟠 Yüksek
                    </span>
                  )}
                  {a.pinned && (
                    <span className="pin-badge">
                      <Pin size={12} />
                      Sabitlendi
                    </span>
                  )}
                </div>
                <div className="card-actions">
                  {/* Close survey button - only for active surveys/announcements */}
                  {activeTab !== "history" && (
                    <button
                      className="icon-btn warning"
                      title="Kapat (Geçmişe Taşı)"
                      onClick={() => handleCloseSurvey(a.id)}
                    >
                      <XCircle size={16} />
                    </button>
                  )}
                  <button
                    className="icon-btn"
                    title={a.pinned ? "Sabitlemeyi Kaldır" : "Sabitle"}
                    onClick={() => handleTogglePin(a.id, a.pinned)}
                  >
                    <Pin size={16} className={a.pinned ? "filled" : ""} />
                  </button>
                  <button
                    className="icon-btn danger"
                    title="Sil"
                    onClick={() => handleDelete(a.id)}
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>

              {/* Card Body */}
              <div className="card-body" onClick={() => {
                if (a.type === "survey") {
                  router.push(`/announcements/survey/${a.id}`);
                } else {
                  handleExpandAnnouncement(a.id);
                }
              }}>
                <div className="card-body-content">
                  <div className="card-body-text">
                    <h3>{a.title}</h3>
                    <p className="content-preview">
                      {a.summary || a.content.substring(0, 150)}
                      {a.content.length > 150 && !a.summary && "..."}
                    </p>
                  </div>
                  {a.type !== "survey" && (
                    <div className="expand-icon">
                      {expandedAnnouncementId === a.id ? <ChevronUp size={20} /> : <ChevronDown size={20} />}
                    </div>
                  )}
                </div>
              </div>

              {/* Expanded Detail Section */}
              {expandedAnnouncementId === a.id && a.type !== "survey" && (
                <div className="expanded-detail">
                  {expandedLoading ? (
                    <div className="expanded-loading">
                      <Loader2 className="spinner" size={24} />
                      <span>Yükleniyor...</span>
                    </div>
                  ) : expandedDetail ? (
                    <>
                      {/* Meta Info */}
                      <div className="detail-meta">
                        <div className="meta-item">
                          <User size={14} />
                          <span>
                            {expandedDetail.publisher 
                              ? `${expandedDetail.publisher.first_name} ${expandedDetail.publisher.last_name}`
                              : "-"
                            }
                          </span>
                        </div>
                        <div className="meta-item">
                          <span 
                            className="priority-tag"
                            style={{ background: getPriorityLabel(expandedDetail.priority).color }}
                          >
                            {getPriorityLabel(expandedDetail.priority).label}
                          </span>
                        </div>
                      </div>

                      {/* Full Content */}
                      <div className="detail-content">
                        {expandedDetail.content.split("\n").map((line, idx) => (
                          <p key={idx}>{line || <br />}</p>
                        ))}
                      </div>

                      {/* Read List Toggle */}
                      <div className="reads-section">
                        <button 
                          className="reads-toggle"
                          onClick={(e) => {
                            e.stopPropagation();
                            setShowReads(!showReads);
                          }}
                        >
                          <Eye size={14} />
                          <span>Okuyanlar ({expandedDetail.read_count})</span>
                          <span className="toggle-arrow">{showReads ? "▲" : "▼"}</span>
                        </button>

                        {showReads && expandedDetail.reads && (
                          <div className="reads-list">
                            {expandedDetail.reads.length > 0 ? (
                              expandedDetail.reads.map((read) => (
                                <div key={read.id} className="read-item">
                                  <span className="read-user">
                                    {read.user?.first_name} {read.user?.last_name}
                                  </span>
                                  <span className="read-role">{getRoleLabel(read.user?.role)}</span>
                                  <span className="read-branch">{read.branch?.name}</span>
                                  <span className="read-time">
                                    {new Date(read.read_at).toLocaleString("tr-TR")}
                                  </span>
                                </div>
                              ))
                            ) : (
                              <p className="no-reads">Henüz okunmamış</p>
                            )}
                          </div>
                        )}
                      </div>
                    </>
                  ) : null}
                </div>
              )}

              {/* Card Footer */}
              <div className="card-footer">
                <div className="card-stats">
                  <span className="stat" title="Hedef Kitle">
                    <Building2 size={14} />
                    {getTargetDescription(a)}
                  </span>
                  {a.type === "survey" && (
                    <span className="stat" title="Yanıtlar">
                      <UserCheck size={14} />
                      {a.response_count} yanıt
                    </span>
                  )}
                  <span className="stat" title="Okunma">
                    <Eye size={14} />
                    {a.read_count} okunma
                  </span>
                </div>
                <div className="card-meta">
                  <span className="date">
                    <Calendar size={14} />
                    {new Date(a.published_at).toLocaleDateString("tr-TR")}
                  </span>
                  {a.expires_at && (
                    <span className={`expiry ${new Date(a.expires_at) < new Date() ? "expired" : ""}`}>
                      <Clock size={14} />
                      {new Date(a.expires_at) < new Date() 
                        ? "Süresi doldu" 
                        : `${new Date(a.expires_at).toLocaleDateString("tr-TR")}'e kadar`
                      }
                    </span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
      </div>

      <style jsx>{`
        .page-container {
          padding: 24px;
          max-width: 100%;
          margin: 0 auto;
        }

        .fixed-header {
          margin-bottom: 24px;
        }

        .page-header {
          display: flex;
          justify-content: space-between;
          align-items: flex-start;
          margin-bottom: 24px;
          flex-wrap: wrap;
          gap: 16px;
        }

        .header-left {
          flex: 1;
          min-width: 200px;
        }

        .page-header h1 {
          margin: 0;
          font-size: 24px;
          font-weight: 600;
        }

        .text-muted {
          color: #666;
          margin-top: 4px;
        }

        .header-actions {
          display: flex;
          gap: 12px;
          flex-shrink: 0;
        }

        .btn {
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 10px 16px;
          border-radius: 8px;
          font-weight: 500;
          cursor: pointer;
          border: none;
          transition: all 0.2s;
          white-space: nowrap;
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

        .filters-bar {
          display: flex;
          justify-content: space-between;
          align-items: center;
          gap: 16px;
        }

        .content-area {
          width: 100%;
        }

        @media (max-width: 768px) {
          .page-header {
            flex-direction: column;
          }
          .header-actions {
            width: 100%;
            justify-content: flex-start;
          }
          .filters-bar {
            flex-direction: column;
            align-items: stretch;
          }
          .tabs {
            overflow-x: auto;
          }
          .search-box {
            width: 100%;
          }
        }

        .tabs {
          display: flex;
          gap: 8px;
        }

        .tab {
          display: flex;
          align-items: center;
          gap: 6px;
          padding: 8px 16px;
          border: 1px solid #e2e8f0;
          border-radius: 8px;
          background: white;
          cursor: pointer;
          transition: all 0.2s;
        }

        .tab:hover {
          background: #f8fafc;
        }

        .tab.active {
          background: #3b82f6;
          color: white;
          border-color: #3b82f6;
        }

        .tab .badge {
          background: rgba(0,0,0,0.1);
          padding: 2px 8px;
          border-radius: 12px;
          font-size: 12px;
        }

        .tab.active .badge {
          background: rgba(255,255,255,0.2);
        }

        .search-box {
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 8px 16px;
          border: 1px solid #e2e8f0;
          border-radius: 8px;
          background: white;
        }

        .search-box input {
          border: none;
          outline: none;
          flex: 1;
          min-width: 150px;
        }

        .announcements-grid {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        .announcement-card {
          background: white;
          border-radius: 12px;
          border: 1px solid #e2e8f0;
          overflow: hidden;
          transition: all 0.2s;
          width: 100%;
        }

        .announcement-card:hover {
          box-shadow: 0 4px 12px rgba(0,0,0,0.08);
          transform: translateY(-2px);
        }

        .announcement-card.pinned {
          border-color: #fbbf24;
          background: linear-gradient(to bottom, #fffbeb 0%, white 100px);
        }

        .card-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 12px 16px;
          border-bottom: 1px solid #f1f5f9;
        }

        .card-type {
          display: flex;
          gap: 8px;
          align-items: center;
        }

        .type-badge {
          display: flex;
          align-items: center;
          gap: 4px;
          padding: 4px 10px;
          border-radius: 16px;
          font-size: 12px;
          font-weight: 500;
        }

        .type-badge.announcement {
          background: #dbeafe;
          color: #1e40af;
        }

        .type-badge.survey {
          background: #dcfce7;
          color: #166534;
        }

        .pin-badge {
          display: flex;
          align-items: center;
          gap: 4px;
          padding: 4px 8px;
          background: #fef3c7;
          color: #92400e;
          border-radius: 12px;
          font-size: 11px;
        }

        .priority-badge {
          display: flex;
          align-items: center;
          gap: 4px;
          padding: 4px 10px;
          border-radius: 12px;
          font-size: 11px;
          font-weight: 600;
        }

        .priority-badge.urgent {
          background: #fef2f2;
          color: #dc2626;
          animation: pulse-urgent 1.5s ease-in-out infinite;
        }

        .priority-badge.high {
          background: #fff7ed;
          color: #ea580c;
        }

        @keyframes pulse-urgent {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.7; }
        }

        .announcement-card.priority-4 {
          border-left: 4px solid #dc2626;
        }

        .announcement-card.priority-3 {
          border-left: 4px solid #f59e0b;
        }

        .card-actions {
          display: flex;
          gap: 4px;
        }

        .icon-btn {
          display: flex;
          align-items: center;
          justify-content: center;
          width: 32px;
          height: 32px;
          border-radius: 6px;
          border: none;
          background: transparent;
          cursor: pointer;
          color: #64748b;
          transition: all 0.2s;
        }

        .icon-btn:hover {
          background: #f1f5f9;
          color: #334155;
        }

        .icon-btn.danger:hover {
          background: #fef2f2;
          color: #dc2626;
        }

        .icon-btn.warning:hover {
          background: #fffbeb;
          color: #d97706;
        }

        .icon-btn .filled {
          fill: #fbbf24;
          color: #fbbf24;
        }

        .card-body {
          padding: 16px;
          cursor: pointer;
        }

        .card-body h3 {
          margin: 0 0 8px 0;
          font-size: 16px;
          font-weight: 600;
        }

        .content-preview {
          color: #64748b;
          font-size: 14px;
          line-height: 1.5;
          margin: 0;
        }

        .card-footer {
          padding: 12px 16px;
          background: #f8fafc;
          border-top: 1px solid #f1f5f9;
        }

        .card-stats {
          display: flex;
          flex-wrap: wrap;
          gap: 12px;
          margin-bottom: 8px;
        }

        .stat {
          display: flex;
          align-items: center;
          gap: 4px;
          font-size: 12px;
          color: #64748b;
        }

        .card-meta {
          display: flex;
          justify-content: space-between;
          align-items: center;
        }

        .date, .expiry {
          display: flex;
          align-items: center;
          gap: 4px;
          font-size: 12px;
          color: #94a3b8;
        }

        .expiry.expired {
          color: #dc2626;
        }

        .empty-state {
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 80px 20px;
          text-align: center;
          color: #64748b;
          width: 100%;
          background: white;
          border-radius: 12px;
          border: 1px solid #e2e8f0;
        }

        .empty-state h3 {
          margin: 16px 0 8px;
          color: #334155;
        }

        .loading-container {
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 80px 20px;
        }

        .spinner {
          width: 40px;
          height: 40px;
          border: 3px solid #e2e8f0;
          border-top-color: #3b82f6;
          border-radius: 50%;
          animation: spin 1s linear infinite;
        }

        @keyframes spin {
          to { transform: rotate(360deg); }
        }

        .alert {
          padding: 12px 16px;
          border-radius: 8px;
          margin-bottom: 16px;
          display: flex;
          justify-content: space-between;
          align-items: center;
        }

        .alert-error {
          background: #fef2f2;
          color: #dc2626;
          border: 1px solid #fecaca;
        }

        .btn-sm {
          padding: 4px 12px;
          font-size: 12px;
        }

        /* Expanded card styles */
        .card-body-content {
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: 16px;
        }

        .card-body-text {
          flex: 1;
        }

        .expand-icon {
          color: #94a3b8;
          flex-shrink: 0;
          transition: transform 0.2s;
        }

        .announcement-card.expanded .expand-icon {
          transform: rotate(180deg);
        }

        .expanded-detail {
          padding: 16px;
          background: #f8fafc;
          border-top: 1px solid #e2e8f0;
          animation: slideDown 0.2s ease-out;
        }

        @keyframes slideDown {
          from {
            opacity: 0;
            max-height: 0;
          }
          to {
            opacity: 1;
            max-height: 2000px;
          }
        }

        .expanded-loading {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          padding: 24px;
          color: #64748b;
        }

        .expanded-loading .spinner {
          width: 24px;
          height: 24px;
          animation: spin 1s linear infinite;
        }

        .detail-meta {
          display: flex;
          flex-wrap: wrap;
          gap: 16px;
          margin-bottom: 16px;
          padding-bottom: 12px;
          border-bottom: 1px solid #e2e8f0;
        }

        .detail-meta .meta-item {
          display: flex;
          align-items: center;
          gap: 6px;
          color: #64748b;
          font-size: 13px;
        }

        .priority-tag {
          padding: 2px 8px;
          border-radius: 4px;
          color: white;
          font-size: 11px;
          font-weight: 500;
        }

        .detail-content {
          background: white;
          padding: 16px;
          border-radius: 8px;
          border: 1px solid #e2e8f0;
          margin-bottom: 16px;
        }

        .detail-content p {
          margin: 0 0 8px 0;
          line-height: 1.6;
          color: #334155;
        }

        .detail-content p:last-child {
          margin-bottom: 0;
        }

        .reads-section {
          margin-top: 12px;
        }

        .reads-toggle {
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 8px 12px;
          background: white;
          border: 1px solid #e2e8f0;
          border-radius: 6px;
          cursor: pointer;
          font-size: 13px;
          color: #64748b;
          transition: all 0.2s;
        }

        .reads-toggle:hover {
          background: #f1f5f9;
        }

        .toggle-arrow {
          margin-left: auto;
          font-size: 10px;
        }

        .reads-list {
          margin-top: 8px;
          background: white;
          border: 1px solid #e2e8f0;
          border-radius: 6px;
          max-height: 200px;
          overflow-y: auto;
        }

        .read-item {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
          padding: 8px 12px;
          border-bottom: 1px solid #f1f5f9;
          font-size: 12px;
        }

        .read-item:last-child {
          border-bottom: none;
        }

        .read-user {
          font-weight: 500;
          color: #334155;
        }

        .read-role {
          color: #64748b;
          padding: 1px 6px;
          background: #f1f5f9;
          border-radius: 4px;
        }

        .read-branch {
          color: #64748b;
        }

        .read-time {
          color: #94a3b8;
          margin-left: auto;
        }

        .no-reads {
          padding: 16px;
          text-align: center;
          color: #94a3b8;
          margin: 0;
        }

        /* History Filters */
        .history-filters {
          display: flex;
          flex-wrap: wrap;
          gap: 16px;
          padding: 16px;
          background: #f8fafc;
          border-radius: 8px;
          margin-top: 16px;
          align-items: flex-end;
        }

        .filter-group {
          display: flex;
          flex-direction: column;
          gap: 4px;
        }

        .filter-group label {
          display: flex;
          align-items: center;
          gap: 4px;
          font-size: 12px;
          color: #64748b;
          font-weight: 500;
        }

        .filter-group input[type="date"] {
          padding: 8px 12px;
          border: 1px solid #e2e8f0;
          border-radius: 6px;
          font-size: 13px;
          background: white;
        }

        .filter-group input[type="date"]:focus {
          outline: none;
          border-color: #3b82f6;
          box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
        }

        .type-select {
          padding: 8px 12px;
          border: 1px solid #e2e8f0;
          border-radius: 6px;
          font-size: 13px;
          background: white;
          cursor: pointer;
          min-width: 120px;
        }

        .type-select:focus {
          outline: none;
          border-color: #3b82f6;
          box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
        }

        .sort-btn {
          display: flex;
          align-items: center;
          gap: 6px;
          padding: 8px 12px;
          border: 1px solid #e2e8f0;
          border-radius: 6px;
          background: white;
          font-size: 13px;
          cursor: pointer;
          transition: all 0.2s;
        }

        .sort-btn:hover {
          background: #f1f5f9;
          border-color: #cbd5e1;
        }

        .clear-filters-btn {
          padding: 8px 12px;
          border: none;
          background: #ef4444;
          color: white;
          border-radius: 6px;
          font-size: 13px;
          cursor: pointer;
          transition: all 0.2s;
        }

        .clear-filters-btn:hover {
          background: #dc2626;
        }

        /* Expired card style */
        .announcement-card.expired {
          opacity: 0.85;
          border-left: 4px solid #94a3b8;
        }

        .announcement-card.expired .card-header {
          background: #f1f5f9;
        }
      `}</style>
    </div>
  );
}
