"use client";

import Link from "next/link";
import { Fragment, useEffect, useMemo, useState } from "react";
import "./shifts.css";

type Person = { id: string; name: string; position: string; annual_leave_days?: number | null };
type Pattern = { id: string; title: string; start: string; end: string; color: string };
type AssignmentMap = Record<string, string>; // key: personId-dateIso -> patternId
type LeaveMap = Record<string, number>;
type PublishedWeek = { assignments: AssignmentMap; leaveRemaining?: LeaveMap; patterns?: Pattern[] };
type PublishedStore = { weeks: Record<string, PublishedWeek> };

const normalizeIso = (value: string) => (typeof value === "string" ? value.slice(0, 10) : "");

const parseAssignmentKey = (key: string) => {
  const iso = normalizeIso(key.slice(-10));
  const personId = key.length > 11 ? key.slice(0, key.length - 11) : "";
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
  const diff = (day === 0 ? -6 : 1 - day); // Monday as start
  d.setDate(d.getDate() + diff);
  d.setHours(0, 0, 0, 0);
  return d;
};

const formatRange = (start: Date) => {
  const end = new Date(start);
  end.setDate(end.getDate() + 6);
  const fmt = (d: Date) => d.toLocaleDateString("tr-TR", { day: "2-digit", month: "2-digit", year: "numeric" });
  return `${fmt(start)} - ${fmt(end)}`;
};

const formatDayLabel = (date: Date) => {
  const weekday = date.toLocaleDateString("tr-TR", { weekday: "long" });
  const dayNum = date.toLocaleDateString("tr-TR", { day: "2-digit" });
  return `${weekday} ${dayNum}`;
};

const weekKey = (d: Date) => {
  return formatIsoDate(d);
};

const DEFAULT_WEEK_START = startOfWeek(new Date());

export default function ShiftsPage() {
  const [weekStart, setWeekStart] = useState<Date>(DEFAULT_WEEK_START);
  const [patterns, setPatterns] = useState<Pattern[]>(initialPatterns);
  const [publishedAssignments, setPublishedAssignments] = useState<AssignmentMap>({});
  const [people, setPeople] = useState<Person[]>([]);
  const [leaveRemaining, setLeaveRemaining] = useState<LeaveMap>({});
  const [publishedStore, setPublishedStore] = useState<PublishedStore>({ weeks: {} });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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
          // fallback static list
          setPeople([
            { id: "p1", name: "Ahmet Yılmaz", position: "Kasa Reyon" },
            { id: "p2", name: "Zeynep Kara", position: "Kasa Reyon" },
            { id: "p3", name: "Mert Demir", position: "Şarküteri" },
            { id: "p4", name: "Elif Aksoy", position: "Manav" },
            { id: "p5", name: "Can Aydın", position: "Depo" },
            { id: "p6", name: "Derya Er", position: "Depo" },
          ]);
          setError((err as Error).message);
        }
      } finally {
        if (active) setLoading(false);
      }
    };

    const loadPublished = async () => {
      try {
        const res = await fetch("/api/shifts");
        if (!res.ok) throw new Error("Yayınlanmış vardiya alınamadı");
        const body = (await res.json()) as { weeks?: Array<{ week_start_date: string; week_end_date: string; shift_data?: any }> };
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
        if (body.weeks && body.weeks.length) {
          const latest = [...body.weeks].sort((a, b) => (a.week_start_date > b.week_start_date ? -1 : 1))[0];
          const latestDate = parseIsoDate(latest.week_start_date);
          setWeekStart(startOfWeek(latestDate));
        }
      } catch (err) {
        if (!active) return;
        setError((err as Error).message);
      }
    };

    void loadPeople();
    void loadPublished();
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    const key = weekKey(weekStart);
    const wk = publishedStore.weeks?.[key];
    setPublishedAssignments(wk?.assignments || {});
    setLeaveRemaining(wk?.leaveRemaining || {});
    setPatterns(wk?.patterns && wk.patterns.length ? wk.patterns : initialPatterns);
  }, [weekStart, publishedStore]);

  const days = useMemo(() => {
    return Array.from({ length: 7 }).map((_, idx) => {
      const d = new Date(weekStart);
      d.setDate(d.getDate() + idx);
      return d;
    });
  }, [weekStart]);

  const grouped = useMemo(() => {
    const map: Record<string, Person[]> = {};
    people.forEach((p) => {
      map[p.position] = map[p.position] ? [...map[p.position], p] : [p];
    });
    return map;
  }, [people]);

  const allowance = useMemo(() => {
    const base: LeaveMap = { ...leaveRemaining };
    people.forEach((p) => {
      if (base[p.id] === undefined) base[p.id] = 14;
    });
    return base;
  }, [leaveRemaining, people]);

  const weekOptions = useMemo(() => {
    const keys = Object.keys(publishedStore.weeks || {});
    return keys
      .sort((a, b) => (a > b ? -1 : 1))
      .map((iso) => {
        const start = parseIsoDate(iso);
        return { iso, label: formatRange(start) };
      });
  }, [publishedStore]);

  const goPrevWeek = () => setWeekStart((prev) => new Date(prev.getTime() - 7 * 86400000));
  const goNextWeek = () => setWeekStart((prev) => new Date(prev.getTime() + 7 * 86400000));
  const handleSelectWeek = (iso: string) => {
    if (!iso) return;
    const d = parseIsoDate(iso);
    setWeekStart(startOfWeek(d));
  };

  const annualUsage = useMemo(() => {
    const usage: Record<string, number> = {};
    Object.entries(publishedAssignments).forEach(([key, patId]) => {
      const pat = patterns.find((p) => p.id === patId);
      if (!pat) return;
      if (pat.title.toLowerCase().includes("yıllık")) {
        const personId = key.split("-")[0];
        usage[personId] = (usage[personId] || 0) + 1;
      }
    });
    return usage;
  }, [publishedAssignments, patterns]);

  return (
    <div className="page">
      <header className="page-header page-header--with-action">
        <div className="page-header__body">
          <h2>Vardiya Planı</h2>
          <p>Yayınlanmış haftalık tabloyu görüntüle; yeni vardiyayı düzenleme ekranında hazırla.</p>
          <div className="range-row">
            <div className="range-actions">
              <button className="ghost ghost-strong nav-button" type="button" onClick={goPrevWeek}>
                Önceki hafta
              </button>
              <button className="ghost ghost-strong nav-button" type="button" onClick={goNextWeek}>
                Sonraki hafta
              </button>
              {weekOptions.length ? (
                <select className="ghost" value={weekKey(weekStart)} onChange={(e) => handleSelectWeek(e.target.value)}>
                  {weekOptions.map((opt) => (
                    <option key={opt.iso} value={opt.iso}>
                      {opt.label}
                    </option>
                  ))}
                </select>
              ) : null}
            </div>
          </div>
          {loading ? <p className="muted">Personel listesi yükleniyor…</p> : null}
          {error ? <p className="muted">{error}</p> : null}
        </div>
        <Link className="primary" href="/shifts/new">
          Yeni vardiya hazırla
        </Link>
      </header>

      <div className="card shift-matrix-card">
        <div className="matrix-header">
          <div className="matrix-header__left">
            <h3>Yayınlanmış vardiya</h3>
          </div>
          <div className="matrix-header__center">
            <span className="matrix-date">{formatRange(weekStart)}</span>
          </div>
          <div className="matrix-header__right" />
        </div>
        <div className="matrix-scroll">
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
                <Fragment key={`pub-${position}`}>
                  <tr className="position-row">
                    <td colSpan={8}>{position}</td>
                  </tr>
                  {members.map((person) => (
                    <tr key={person.id}>
                      <td className="person-cell">{person.name}</td>
                      {days.map((d) => {
                        const iso = formatIsoDate(d);
                        const key = `${person.id}-${iso}`;
                        const patId = publishedAssignments[key] || "";
                        const pat = patterns.find((p) => p.id === patId);
                        const label = pat ? pat.title : "—";
                        const timeLabel = pat && pat.start && pat.end ? `${pat.start} / ${pat.end}` : "";
                        const isAnnualLeave = pat?.title.toLowerCase().includes("yıllık");
                        const entitlement = allowance[person.id];
                        return (
                          <td key={iso}>
                            <div
                              className="cell-chip"
                              style={{
                                background: pat ? `${pat.color}22` : "var(--card-bg)",
                                borderColor: pat ? pat.color : "var(--card-border)",
                              }}
                            >
                              <div className="cell-label">{label}</div>
                              {timeLabel ? <div className="cell-time">{timeLabel}</div> : null}
                              {isAnnualLeave && entitlement !== undefined ? (
                                <div className="cell-leave">Yıllık izin hakkı: {entitlement}</div>
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
      </div>
    </div>
  );
}
