"use client";

import Link from "next/link";
import { Fragment, useEffect, useMemo, useRef, useState, type MouseEvent } from "react";
import "../shifts.css";

type Person = { id: string; name: string; position: string; annual_leave_days?: number | null };
type Pattern = { id: string; title: string; start: string; end: string; color: string };
type AssignmentMap = Record<string, string>; // key: personId-dateIso -> patternId
type LeaveMap = Record<string, number>;
type PublishedWeek = { assignments: AssignmentMap; leaveRemaining?: LeaveMap; patterns?: Pattern[] };
type PublishedStore = { weeks: Record<string, PublishedWeek> };

const normalizeIso = (value: string) => (typeof value === "string" ? value.slice(0, 10) : "");

const parseAssignmentKey = (key: string) => {
  const iso = normalizeIso(key.slice(-10));
  const personId = key.length > 11 ? key.slice(0, key.length - 11) : ""; // remove '-' + 10 chars
  return { personId, iso };
};

const normalizeAssignments = (assignments: AssignmentMap | undefined | null): AssignmentMap => {
  if (!assignments) return {};
  const next: AssignmentMap = {};
  Object.entries(assignments).forEach(([key, pat]) => {
    const { personId, iso } = parseAssignmentKey(key);
    if (!personId || !iso) return;
    next[`${personId}-${iso}`] = pat;
  });
  return next;
};
const parseIsoDate = (iso: string) => {
  const [y, m, d] = iso.split("-").map((v) => Number(v));
  return new Date(y || 0, (m || 1) - 1, d || 1, 0, 0, 0, 0);
};

const formatIsoDate = (d: Date) => {
  const local = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0);
  const y = local.getFullYear();
  const m = `${local.getMonth() + 1}`.padStart(2, "0");
  const day = `${local.getDate()}`.padStart(2, "0");
  return `${y}-${m}-${day}`;
};

const isoToDate = (iso: string) => parseIsoDate(iso);

const weekKey = (d: Date) => formatIsoDate(d);

const initialPatterns: Pattern[] = [
  { id: "pat1", title: "08:00-16:00", start: "08:00", end: "16:00", color: "#1890ff" },
  { id: "pat2", title: "14:00-22:30", start: "14:00", end: "22:30", color: "#f59e0b" },
  { id: "pat3", title: "İZİN", start: "", end: "", color: "#ef4444" },
  { id: "pat4", title: "Resmi tatil", start: "", end: "", color: "#9ca3af" },
  { id: "pat5", title: "Yıllık izin", start: "", end: "", color: "#fb7185" },
  { id: "pat6", title: "Rapor", start: "", end: "", color: "#a855f7" },
];

const startOfWeek = (date: Date) => {
  const d = new Date(date);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day; // Pazartesi başlangıç
  d.setDate(d.getDate() + diff);
  d.setHours(0, 0, 0, 0);
  return d;
};

const formatDayLabel = (date: Date) => {
  const weekday = date.toLocaleDateString("tr-TR", { weekday: "long" });
  const dayNum = date.toLocaleDateString("tr-TR", { day: "2-digit" });
  return `${weekday} ${dayNum}`;
};

const formatRange = (start: Date) => {
  const end = new Date(start);
  end.setDate(end.getDate() + 6);
  const fmt = (d: Date) => d.toLocaleDateString("tr-TR", { day: "2-digit", month: "2-digit", year: "numeric" });
  return `${fmt(start)} - ${fmt(end)}`;
};

const DEFAULT_WEEK_START = startOfWeek(new Date());

export default function NewShiftPage() {
  const [weekStart, setWeekStart] = useState<Date>(DEFAULT_WEEK_START);
  const [patterns, setPatterns] = useState<Pattern[]>(initialPatterns);
  const [assignments, setAssignments] = useState<AssignmentMap>({});
  const [people, setPeople] = useState<Person[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [editingCell, setEditingCell] = useState<{ personId: string; iso: string; above?: boolean } | null>(null);
  const [leaveRemaining, setLeaveRemaining] = useState<LeaveMap>({});
  const [publishedStore, setPublishedStore] = useState<PublishedStore>({ weeks: {} });
  const draftPatternsRef = useRef<Pattern[] | null>(null);
  const matrixRef = useRef<HTMLDivElement>(null);
  const [publishing, setPublishing] = useState(false);
  const [copyFeedback, setCopyFeedback] = useState<string | null>(null);
  const [newPattern, setNewPattern] = useState<Pattern>({
    id: "",
    title: "",
    start: "08:00",
    end: "16:00",
    color: "#22c55e",
  });

  // personel listesi
  useEffect(() => {
    let active = true;
    const loadPeople = async () => {
      try {
        setLoading(true);
        setError(null);
        const res = await fetch("/api/personnel-with-position");
        if (!res.ok) throw new Error("Personel listesi alınamadı");
        const body = (await res.json()) as { people: Person[] };
        if (active) {
          setPeople(body.people || []);
          const leaveMap: LeaveMap = {};
          (body.people || []).forEach((p) => {
            const allowance = typeof p.annual_leave_days === "number" ? p.annual_leave_days : (p as any).annual_leave_remaining ?? (p as any).leave_remaining;
            leaveMap[p.id] = typeof allowance === "number" ? allowance : 14;
          });
          setLeaveRemaining(leaveMap);
        }
      } catch (err) {
        if (active) {
          setPeople([
            { id: "p1", name: "Ahmet Yılmaz", position: "Kasa Reyon" },
            { id: "p2", name: "Zeynep Kara", position: "Kasa Reyon" },
            { id: "p3", name: "Mert Demir", position: "Şarküteri" },
            { id: "p4", name: "Elif Aksoy", position: "Manav" },
            { id: "p5", name: "Can Aydın", position: "Depo" },
            { id: "p6", name: "Derya Er", position: "Depo" },
          ]);
          setLeaveRemaining({ p1: 10, p2: 8, p3: 12, p4: 14, p5: 6, p6: 9 });
          setError((err as Error).message);
        }
      } finally {
        if (active) setLoading(false);
      }
    };

    void loadPeople();
    return () => {
      active = false;
    };
  }, []);

  // taslak şablonları sunucudan çek
  useEffect(() => {
    let active = true;
    const loadDraft = async () => {
      try {
        const res = await fetch("/api/shifts/pattern-drafts");
        if (!res.ok) throw new Error("Taslak şablon alınamadı");
        const body = (await res.json()) as { patterns?: Pattern[] };
        if (!active) return;
        if (body.patterns && Array.isArray(body.patterns) && body.patterns.length) {
          draftPatternsRef.current = body.patterns as Pattern[];
          setPatterns(body.patterns as Pattern[]);
        }
      } catch (err) {
        console.warn("Taslak şablon yüklenemedi", err);
      }
    };

    void loadDraft();
    return () => {
      active = false;
    };
  }, []);

    useEffect(() => {
      let active = true;
      const loadPublished = async () => {
        try {
          const res = await fetch("/api/shifts");
          if (!res.ok) throw new Error("Yayınlanmış vardiya alınamadı");
          const body = (await res.json()) as { weeks?: Array<{ week_start_date: string; shift_data?: any }> };
          if (!active) return;
          const store: PublishedStore = { weeks: {} };
          (body.weeks || []).forEach((w) => {
            const key = normalizeIso((w as any).week_start_date || "");
            if (!key) return;
            const data = (w as any).shift_data || {};
            store.weeks[key] = {
              assignments: normalizeAssignments(data.assignments),
              leaveRemaining: data.leaveRemaining || {},
              patterns: data.patterns || [],
            };
          });
          setPublishedStore(store);
          if (draftPatternsRef.current) {
            setPatterns(draftPatternsRef.current);
          }
        } catch (err) {
          if (!active) return;
          setError((err as Error).message);
        }
      };

      void loadPublished();
      return () => {
        active = false;
      };
    }, []);

    useEffect(() => {
      const savedAssignments = localStorage.getItem("shiftDraftAssignments") || localStorage.getItem("draftAssignments");
      if (savedAssignments) {
        try {
          const parsed = JSON.parse(savedAssignments);
          if (parsed && typeof parsed === "object") setAssignments(parsed as AssignmentMap);
        } catch (_) {
          /* ignore */
        }
      }
    }, []);

    useEffect(() => {
      const payload = JSON.stringify(assignments);
      localStorage.setItem("shiftDraftAssignments", payload);
    }, [assignments]);

  const days = useMemo(() => {
    return Array.from({ length: 7 }).map((_, idx) => {
      const d = new Date(weekStart);
      d.setDate(d.getDate() + idx);
      return d;
    });
  }, [weekStart]);

  const annualUsage = useMemo(() => {
    const usage: Record<string, number> = {};
    Object.entries(assignments).forEach(([key, patId]) => {
      const pat = patterns.find((p) => p.id === patId);
      if (!pat) return;
      if (pat.title.toLowerCase().includes("yıllık")) {
        const personId = key.split("-")[0];
        usage[personId] = (usage[personId] || 0) + 1;
      }
    });
    return usage;
  }, [assignments, patterns]);

  const grouped = useMemo(() => {
    const map: Record<string, Person[]> = {};
    people.forEach((p) => {
      map[p.position] = map[p.position] ? [...map[p.position], p] : [p];
    });
    return map;
  }, [people]);

  const handleAssign = (personId: string, dateIso: string, patternId: string) => {
    setAssignments((prev) => ({ ...prev, [`${personId}-${dateIso}`]: patternId }));
    setEditingCell(null);
  };

  const saveDraftPatterns = async (nextPatterns: Pattern[]) => {
    try {
      await fetch("/api/shifts/pattern-drafts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ patterns: nextPatterns }),
      });
    } catch (err) {
      console.warn("Şablon taslağı kaydedilemedi", err);
    }
  };

  const toggleCell = (personId: string, iso: string, e: MouseEvent<HTMLDivElement>) => {
    const isOpen = editingCell?.personId === personId && editingCell.iso === iso;
    if (isOpen) {
      setEditingCell(null);
      return;
    }

    const rect = (e.currentTarget as HTMLDivElement).getBoundingClientRect();
    const containerRect = matrixRef.current?.getBoundingClientRect();
    const spaceBelow = containerRect ? containerRect.bottom - rect.bottom : window.innerHeight - rect.bottom;
    const needsAbove = spaceBelow < 260; // tahmini menü yüksekliği
    setEditingCell({ personId, iso, above: needsAbove });
  };

  const handleAddPattern = () => {
    if (!newPattern.title.trim()) return;
    const id = crypto.randomUUID();
    setPatterns((prev) => {
      const next = [...prev, { ...newPattern, id }];
      draftPatternsRef.current = next;
      void saveDraftPatterns(next);
      return next;
    });
    setNewPattern((p) => ({ ...p, title: "" }));
  };

  const copyPreviousWeek = () => {
    const prevStart = new Date(weekStart);
    prevStart.setDate(prevStart.getDate() - 7);
    prevStart.setHours(0, 0, 0, 0);

    const prevKey = weekKey(prevStart);
    const sourceWeek = publishedStore.weeks[prevKey];
    const source = sourceWeek?.assignments;

    if (!source || !Object.keys(source).length) {
      setCopyFeedback("Geçen haftaya ait yayınlanmış bir tablo bulunamadı.");
      return;
    }

    const sourcePatterns = sourceWeek?.patterns && sourceWeek.patterns.length ? sourceWeek.patterns : patterns;
    const sourceLeave = sourceWeek?.leaveRemaining && Object.keys(sourceWeek.leaveRemaining).length ? sourceWeek.leaveRemaining : leaveRemaining;

    const nextAssignments: AssignmentMap = { ...assignments };
    Object.entries(source).forEach(([key, patId]) => {
      const { personId, iso } = parseAssignmentKey(key);
      if (!personId || !iso) return;
      const date = isoToDate(iso);
      if (Number.isNaN(date.getTime())) return;
      const newDate = new Date(date);
      newDate.setDate(newDate.getDate() + 7);
      if (Number.isNaN(newDate.getTime())) return;
      const newIso = formatIsoDate(newDate);
      nextAssignments[`${personId}-${newIso}`] = patId;
    });

    setAssignments(nextAssignments);
    setPatterns(sourcePatterns);
    void saveDraftPatterns(sourcePatterns);
    setLeaveRemaining(sourceLeave);

    // Save to localStorage for backward compat
    localStorage.setItem("shiftDraftAssignments", JSON.stringify(nextAssignments));
    localStorage.setItem("draftAssignments", JSON.stringify(nextAssignments));
    localStorage.setItem("draftPatterns", JSON.stringify(sourcePatterns));
    setCopyFeedback("Geçen haftanın vardiyası taslağa kopyalandı.");
  };

  const goPrevWeek = () => setWeekStart((prev) => new Date(prev.getTime() - 7 * 86400000));
  const goNextWeek = () => setWeekStart((prev) => new Date(prev.getTime() + 7 * 86400000));

  const handlePublish = async () => {
    setPublishing(true);
    const weekStartIso = weekKey(weekStart);
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 6);
    const weekEndIso = formatIsoDate(weekEnd);
    try {
      const res = await fetch("/api/shifts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ weekStartIso, weekEndIso, assignments, leaveRemaining, patterns }),
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.message || "Yayınlama başarısız");
      }
      const nextStore = { ...publishedStore, weeks: { ...publishedStore.weeks, [weekStartIso]: { assignments: normalizeAssignments(assignments), leaveRemaining, patterns } } };
      setPublishedStore(nextStore);
      window.location.href = "/shifts";
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setPublishing(false);
    }
  };

  return (
    <div className="page">
      <header className="page-header page-header--with-action">
        <div className="page-header__body">
          <h2>Yeni Vardiya Hazırla</h2>
          <p>Hücrelere tıkla, şablon ata; yayınlamadan önce taslak oluştur.</p>
          <div className="range-row">
            <div className="range-actions">
              <button className="ghost ghost-strong nav-button" type="button" onClick={goPrevWeek}>
                Önceki hafta
              </button>
              <button className="ghost ghost-strong nav-button" type="button" onClick={goNextWeek}>
                Sonraki hafta
              </button>
            </div>
          </div>
        </div>
        <div className="cta-row">
          <button className="primary" type="button" onClick={handlePublish} disabled={publishing}>
            {publishing ? "Yayınlanıyor..." : "Yayınla"}
          </button>
          <Link className="ghost" href="/shifts">
            Yayınlanmış tabloya dön
          </Link>
        </div>
      </header>

      <div className="card shift-matrix-card">
        <div className="matrix-header">
          <div className="matrix-header__left">
            <h3>Taslak tablo</h3>
            <span className="muted">Hücreye tıkla, şablon seç.</span>
          </div>
          <div className="matrix-header__center">
            <span className="matrix-date">{formatRange(weekStart)}</span>
          </div>
          <div className="matrix-header__right">
            <button className="ghost" type="button" onClick={copyPreviousWeek}>Geçen haftayı kopyala</button>
          </div>
        </div>
        {copyFeedback ? <p className="hint">{copyFeedback}</p> : null}
        <div className="draft-layout">
          <div className="matrix-scroll" ref={matrixRef}>
            <table className="shift-matrix">
              <thead>
                <tr>
                  <th className="col-person">Personel</th>
                  {days.map((d) => {
                    const iso = formatIsoDate(d);
                    return <th key={iso}>{formatDayLabel(d)}</th>;
                  })}
                </tr>
              </thead>
              <tbody>
                {Object.entries(grouped).map(([position, members]) => (
                  <Fragment key={`draft-${position}`}>
                    <tr className="position-row">
                      <td colSpan={8}>{position}</td>
                    </tr>
                    {members.map((person) => (
                      <tr key={`${person.id}-draft`}>
                        <td className="person-cell">{person.name}</td>
                        {days.map((d) => {
                          const iso = formatIsoDate(d);
                          const key = `${person.id}-${iso}`;
                          const patId = assignments[key] || "";
                          const pat = patterns.find((p) => p.id === patId);
                          const label = pat ? pat.title : "(boş)";
                          const timeLabel = pat && pat.start && pat.end ? `${pat.start} / ${pat.end}` : "";
                          const isOpen = editingCell?.personId === person.id && editingCell.iso === iso;
                          const isAnnualLeave = pat?.title.toLowerCase().includes("yıllık");
                          const allowance = leaveRemaining[person.id] ?? 14;
                          return (
                            <td key={`${iso}-draft`}>
                              <div
                                className="cell-chip clickable"
                                style={{
                                  background: pat ? `${pat.color}22` : "var(--card-bg)",
                                  borderColor: pat ? pat.color : "var(--card-border)",
                                }}
                                onClick={(evt) => toggleCell(person.id, iso, evt)}
                              >
                                <div className="cell-label">{label}</div>
                                {timeLabel ? <div className="cell-time">{timeLabel}</div> : null}
                                {isAnnualLeave ? (
                                  <div className="cell-leave">Yıllık izin hakkı: {allowance}</div>
                                ) : null}
                                {isOpen ? (
                                  <div className={`cell-menu${editingCell?.above ? " menu-top" : ""}`}>
                                    {patterns.map((p) => (
                                      <button
                                        key={p.id}
                                        type="button"
                                        className="cell-menu-item"
                                        style={{ borderColor: p.color, background: `${p.color}22` }}
                                        onClick={() => handleAssign(person.id, iso, p.id)}
                                      >
                                        <span>{p.title}</span>
                                        {p.start && p.end ? <small>{p.start} - {p.end}</small> : <small>İzin / özel</small>}
                                      </button>
                                    ))}
                                    <button type="button" className="cell-menu-item cell-menu-clear" onClick={() => handleAssign(person.id, iso, "")}>Boş bırak</button>
                                  </div>
                                ) : null}
                              </div>
                            </td>
                          );
                        })}
                      </tr>
                    ))}
                  </Fragment>
                ))}
              </tbody>
            </table>
          </div>

          <section className="pattern-panel">
            <div className="section-head">
              <h3>Çalışma saati şablonları</h3>
              <p className="muted">Başlık, saat aralığı ve renk belirle; hücrelerde kullan.</p>
            </div>
            <div className="pattern-form">
              <label className="field">
                <span>Başlık</span>
                <input value={newPattern.title} onChange={(e) => setNewPattern((p) => ({ ...p, title: e.target.value }))} />
              </label>
              <label className="field">
                <span>Başlangıç</span>
                <input type="time" value={newPattern.start} onChange={(e) => setNewPattern((p) => ({ ...p, start: e.target.value }))} />
              </label>
              <label className="field">
                <span>Bitiş</span>
                <input type="time" value={newPattern.end} onChange={(e) => setNewPattern((p) => ({ ...p, end: e.target.value }))} />
              </label>
              <label className="field">
                <span>Renk</span>
                <input type="color" value={newPattern.color} onChange={(e) => setNewPattern((p) => ({ ...p, color: e.target.value }))} />
              </label>
              <button className="primary" type="button" onClick={handleAddPattern}>
                Şablon ekle
              </button>
            </div>
            <div className="pattern-list">
              {patterns.map((p) => (
                <div key={p.id} className="pattern-chip" style={{ background: `${p.color}22`, borderColor: p.color }}>
                  <span>{p.title}</span>
                  {p.start && p.end ? <span className="muted">{p.start} - {p.end}</span> : <span className="muted">İzin / özel</span>}
                </div>
              ))}
            </div>
          </section>
        </div>
      </div>

      {error ? <p className="muted">{error}</p> : null}
      {loading ? <p className="muted">Yükleniyor…</p> : null}
    </div>
  );
}
