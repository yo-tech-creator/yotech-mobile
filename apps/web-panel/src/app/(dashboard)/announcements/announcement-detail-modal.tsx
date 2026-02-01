"use client";

import { useState, useEffect } from "react";
import { createBrowserClient } from "@supabase/ssr";
import { 
  X, 
  Bell,
  Calendar,
  Eye,
  User,
  Building2,
  Clock,
  Loader2,
  Pin
} from "lucide-react";
import type { Announcement } from "@/types/announcements";

interface Props {
  announcementId: string;
  onClose: () => void;
}

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

export function AnnouncementDetailModal({ announcementId, onClose }: Props) {
  const [announcement, setAnnouncement] = useState<AnnouncementDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showReads, setShowReads] = useState(false);

  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  useEffect(() => {
    loadAnnouncement();
    markAsRead();
  }, [announcementId]);

  const markAsRead = async () => {
    try {
      await fetch(`/api/announcements/${announcementId}/read`, {
        method: "POST",
      });
    } catch (err) {
      console.error("Error marking as read:", err);
    }
  };

  const loadAnnouncement = async () => {
    try {
      setLoading(true);
      setError(null);

      // Get announcement from API (bypasses RLS)
      const response = await fetch(`/api/announcements/${announcementId}`);
      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || "Duyuru bulunamadı");
      }

      setAnnouncement(result.announcement as AnnouncementDetail);
    } catch (err: unknown) {
      console.error("Error loading announcement:", err);
      const error = err as { message?: string };
      setError(error.message || "Duyuru yüklenirken bir hata oluştu");
    } finally {
      setLoading(false);
    }
  };

  const getTargetDescription = (a: AnnouncementDetail) => {
    // Determine scope from target_branches
    if (!a.target_branches || a.target_branches.length === 0) {
      return "Tüm Şubeler";
    }
    return `${a.target_branches.length} Seçili Şube`;
  };

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

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div className="header-title">
            <Bell size={24} />
            <span>Duyuru Detayı</span>
          </div>
          <button className="close-btn" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <div className="modal-body">
          {loading ? (
            <div className="loading">
              <Loader2 className="spinner" size={32} />
              <p>Yükleniyor...</p>
            </div>
          ) : error ? (
            <div className="error">
              <p>{error}</p>
              <button className="btn btn-primary" onClick={loadAnnouncement}>
                Tekrar Dene
              </button>
            </div>
          ) : announcement ? (
            <>
              {/* Title & Badges */}
              <div className="announcement-header">
                <h2>{announcement.title}</h2>
                <div className="badges">
                  {announcement.pinned && (
                    <span className="badge pinned">
                      <Pin size={12} />
                      Sabitlendi
                    </span>
                  )}
                  <span 
                    className="badge priority"
                    style={{ 
                      background: getPriorityLabel(announcement.priority).color,
                      color: "white"
                    }}
                  >
                    {getPriorityLabel(announcement.priority).label}
                  </span>
                </div>
              </div>

              {/* Meta Info */}
              <div className="meta-grid">
                <div className="meta-item">
                  <User size={16} />
                  <div>
                    <span className="meta-label">Yayınlayan</span>
                    <span className="meta-value">
                      {announcement.publisher 
                        ? `${announcement.publisher.first_name} ${announcement.publisher.last_name}`
                        : "-"
                      }
                    </span>
                  </div>
                </div>
                <div className="meta-item">
                  <Calendar size={16} />
                  <div>
                    <span className="meta-label">Yayın Tarihi</span>
                    <span className="meta-value">
                      {new Date(announcement.published_at).toLocaleDateString("tr-TR", {
                        day: "numeric",
                        month: "long",
                        year: "numeric",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </span>
                  </div>
                </div>
                <div className="meta-item">
                  <Building2 size={16} />
                  <div>
                    <span className="meta-label">Hedef Kitle</span>
                    <span className="meta-value">{getTargetDescription(announcement)}</span>
                  </div>
                </div>
                <div className="meta-item">
                  <Eye size={16} />
                  <div>
                    <span className="meta-label">Okunma</span>
                    <span className="meta-value">{announcement.read_count} kişi</span>
                  </div>
                </div>
                {announcement.expires_at && (
                  <div className="meta-item">
                    <Clock size={16} />
                    <div>
                      <span className="meta-label">Bitiş Tarihi</span>
                      <span className={`meta-value ${new Date(announcement.expires_at) < new Date() ? "expired" : ""}`}>
                        {new Date(announcement.expires_at).toLocaleDateString("tr-TR")}
                        {new Date(announcement.expires_at) < new Date() && " (Süresi doldu)"}
                      </span>
                    </div>
                  </div>
                )}
              </div>

              {/* Content */}
              <div className="content-section">
                <h3>İçerik</h3>
                <div className="content-text">
                  {announcement.content.split("\n").map((line, idx) => (
                    <p key={idx}>{line || <br />}</p>
                  ))}
                </div>
              </div>

              {/* Read List */}
              <div className="reads-section">
                <button 
                  className="reads-toggle"
                  onClick={() => setShowReads(!showReads)}
                >
                  <Eye size={16} />
                  <span>Okuyanlar ({announcement.read_count})</span>
                  <span className="toggle-icon">{showReads ? "▲" : "▼"}</span>
                </button>

                {showReads && (
                  <div className="reads-list">
                    {announcement.reads && announcement.reads.length > 0 ? (
                      announcement.reads.map((read) => (
                        <div key={read.id} className="read-item">
                          <div className="read-user">
                            <span className="user-name">
                              {read.user?.first_name} {read.user?.last_name}
                            </span>
                            <span className="user-role">{getRoleLabel(read.user?.role)}</span>
                          </div>
                          <div className="read-branch">{read.branch?.name}</div>
                          <div className="read-time">
                            {new Date(read.read_at).toLocaleString("tr-TR")}
                          </div>
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
            max-width: 700px;
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
            font-size: 18px;
            font-weight: 600;
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

          .announcement-header {
            margin-bottom: 20px;
          }

          .announcement-header h2 {
            margin: 0 0 12px;
            font-size: 22px;
          }

          .badges {
            display: flex;
            gap: 8px;
          }

          .badge {
            display: flex;
            align-items: center;
            gap: 4px;
            padding: 4px 10px;
            border-radius: 16px;
            font-size: 12px;
            font-weight: 500;
          }

          .badge.pinned {
            background: #fef3c7;
            color: #92400e;
          }

          .meta-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 16px;
            padding: 16px;
            background: #f8fafc;
            border-radius: 10px;
            margin-bottom: 24px;
          }

          .meta-item {
            display: flex;
            align-items: flex-start;
            gap: 10px;
            color: #64748b;
          }

          .meta-item > div {
            display: flex;
            flex-direction: column;
          }

          .meta-label {
            font-size: 12px;
            color: #94a3b8;
          }

          .meta-value {
            font-size: 14px;
            color: #334155;
          }

          .meta-value.expired {
            color: #dc2626;
          }

          .content-section {
            margin-bottom: 24px;
          }

          .content-section h3 {
            margin: 0 0 12px;
            font-size: 14px;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: 0.05em;
          }

          .content-text {
            padding: 16px;
            background: #f8fafc;
            border-radius: 10px;
            line-height: 1.7;
          }

          .content-text p {
            margin: 0 0 8px;
          }

          .content-text p:last-child {
            margin-bottom: 0;
          }

          .reads-section {
            border-top: 1px solid #e2e8f0;
            padding-top: 16px;
          }

          .reads-toggle {
            display: flex;
            align-items: center;
            gap: 8px;
            width: 100%;
            padding: 12px;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            background: white;
            cursor: pointer;
            font-size: 14px;
            transition: all 0.2s;
          }

          .reads-toggle:hover {
            background: #f8fafc;
          }

          .toggle-icon {
            margin-left: auto;
            font-size: 10px;
            color: #94a3b8;
          }

          .reads-list {
            margin-top: 12px;
            max-height: 250px;
            overflow-y: auto;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
          }

          .read-item {
            display: grid;
            grid-template-columns: 2fr 1fr 1fr;
            gap: 12px;
            padding: 10px 14px;
            border-bottom: 1px solid #f1f5f9;
            font-size: 13px;
          }

          .read-item:last-child {
            border-bottom: none;
          }

          .read-user {
            display: flex;
            flex-direction: column;
          }

          .user-name {
            font-weight: 500;
            color: #334155;
          }

          .user-role {
            font-size: 11px;
            color: #94a3b8;
          }

          .read-branch {
            color: #64748b;
          }

          .read-time {
            color: #94a3b8;
            text-align: right;
          }

          .no-reads {
            padding: 24px;
            text-align: center;
            color: #94a3b8;
            font-style: italic;
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

          .btn-primary:hover {
            background: #2563eb;
          }
        `}</style>
      </div>
    </div>
  );
}
