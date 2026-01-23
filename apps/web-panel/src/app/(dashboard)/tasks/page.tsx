"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import "./tasks.css";

type Task = {
  id: string;
  title: string;
  description: string | null;
  status: string | null;
  priority: string | null;
  due_date: string | null;
  completed_at?: string | null;
  approved_at?: string | null;
  approved_by?: string | null;
  created_at: string | null;
  created_by: string;
  creator_name?: string | null;
  creator_role?: string | null;
  is_creator?: boolean;
  branch_name?: string | null;
  branch_id: string | null;
  parent_task_id: string | null;
  source_task_id?: string | null;
  is_archived?: boolean;
  task_assignees?: { user_id: string }[];
  completion_percentage?: number | null;
};

type TaskNode = Task & { children: TaskNode[] };

type DraftNode = {
  id: string;
  title: string;
  description: string;
  priority: string;
  due_date: string;
  children: DraftNode[];
};

type Assignee = {
  id: string;
  first_name: string | null;
  last_name: string | null;
  email: string | null;
  role: string | null;
};

const priorities = [
  { value: "dusuk", label: "Düşük", emoji: "🟢" },
  { value: "orta", label: "Orta", emoji: "🟡" },
  { value: "yuksek", label: "Yüksek", emoji: "🔴" },
];

const statusLabels: Record<string, { label: string; emoji: string }> = {
  atandi: { label: "Atandı", emoji: "📋" },
  devam_ediyor: { label: "Devam Ediyor", emoji: "🔄" },
  tamamlandi: { label: "Tamamlandı", emoji: "✅" },
  onaylandi: { label: "Onaylandı", emoji: "🏆" },
};

const scopes = [
  { value: "all", label: "Tüm görevler" },
  { value: "branchAssigned", label: "Şubeye atanan görevler" },
  { value: "myCreated", label: "Oluşturduğum görevler" },
];

type Tab = "active" | "completed" | "archived";

function getQuestEmoji(task: Task): string {
  if (task.status === "onaylandi") return "🏆";
  if (task.status === "tamamlandi") return "✅";
  const isOverdue = task.due_date && new Date(task.due_date) < new Date();
  if (isOverdue) return "⚠️";
  if (task.priority === "yuksek") return "🔥";
  return "🎯";
}

function getProgress(node: TaskNode): number {
  if (node.children.length === 0) {
    return node.completion_percentage ?? 0;
  }
  const total = node.children.reduce((acc, child) => acc + getProgress(child), 0);
  return Math.round(total / node.children.length);
}

function countDescendants(node: TaskNode): { total: number; completed: number } {
  let total = 0;
  let completed = 0;
  node.children.forEach((child) => {
    total += 1;
    if ((child.completion_percentage ?? 0) >= 100) completed += 1;
    const sub = countDescendants(child);
    total += sub.total;
    completed += sub.completed;
  });
  return { total, completed };
}

// Quest Card - Oyun tarzı görev kartı
function QuestCard({
  node,
  assigneeLookup,
  onCompletionChange,
  onApprove,
  onArchive,
  onDelete,
  depth = 0,
}: {
  node: TaskNode;
  assigneeLookup: Map<string, Assignee>;
  onCompletionChange: (taskId: string, completion: number) => Promise<void>;
  onApprove: (taskId: string) => Promise<void>;
  onArchive: (taskId: string, archive: boolean) => Promise<void>;
  onDelete: (taskId: string) => Promise<void>;
  depth?: number;
}) {
  const [localCompletion, setLocalCompletion] = useState<number>(node.completion_percentage ?? 0);
  const [isOpen, setIsOpen] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    setLocalCompletion(node.completion_percentage ?? 0);
  }, [node.id, node.completion_percentage]);

  const handleCompletionChange = (value: number) => {
    setLocalCompletion(value);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      void onCompletionChange(node.id, value);
    }, 400);
  };

  const progress = getProgress(node);
  const { total, completed } = countDescendants(node);
  const hasChildren = node.children.length > 0;
  const isMainQuest = !node.parent_task_id;
  const isApproved = node.status === "onaylandi";
  const isCompleted = node.status === "tamamlandi" || isApproved;
  const canApprove = node.is_creator && isMainQuest && (node.completion_percentage ?? 0) >= 100 && !isApproved;
  const canArchive = node.is_creator && isApproved && !node.is_archived;
  const isOverdue = node.due_date && new Date(node.due_date) < new Date() && !isCompleted;
  const statusInfo = statusLabels[node.status ?? "atandi"] ?? statusLabels.atandi;

  const assigneeNames = (node.task_assignees ?? [])
    .map((a) => {
      const person = assigneeLookup.get(a.user_id);
      const name = person ? [person.first_name, person.last_name].filter(Boolean).join(" ") : "";
      return name || person?.email || "";
    })
    .filter(Boolean)
    .join(", ");

  // Quest type label
  const questTypeLabel = isMainQuest ? "Ana Görev" : depth === 1 ? "Yan Görev" : "Alt Görev";
  const questTypeBadge = isMainQuest ? "quest-main" : depth === 1 ? "quest-side" : "quest-sub";

  return (
    <div className={`quest-card ${isApproved ? "quest-approved" : ""} ${isOverdue ? "quest-overdue" : ""}`} style={{ marginLeft: depth * 16 }}>
      <div className="quest-header" onClick={() => hasChildren && setIsOpen(!isOpen)}>
        <div className="quest-icon">{getQuestEmoji(node)}</div>
        <div className="quest-info">
          <div className="quest-title-row">
            <span className={`quest-type-badge ${questTypeBadge}`}>{questTypeLabel}</span>
            <h3 className="quest-title">{node.title}</h3>
          </div>
          <div className="quest-meta">
            {node.priority && (
              <span className={`quest-priority priority-${node.priority}`}>
                {priorities.find((p) => p.value === node.priority)?.emoji} {priorities.find((p) => p.value === node.priority)?.label}
              </span>
            )}
            <span className="quest-status">
              {statusInfo.emoji} {statusInfo.label}
            </span>
            {node.due_date && (
              <span className={`quest-due ${isOverdue ? "overdue" : ""}`}>
                📅 {new Date(node.due_date).toLocaleDateString("tr-TR")}
              </span>
            )}
          </div>
        </div>
        <div className="quest-progress-ring">
          <svg viewBox="0 0 36 36" className="circular-chart">
            <path
              className="circle-bg"
              d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
            />
            <path
              className={`circle ${isApproved ? "approved" : isCompleted ? "completed" : isOverdue ? "overdue" : ""}`}
              strokeDasharray={`${progress}, 100`}
              d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
            />
            <text x="18" y="20.35" className="percentage">{progress}%</text>
          </svg>
        </div>
        {hasChildren && (
          <div className="quest-expand">
            {isOpen ? "▼" : "▶"} {completed}/{total}
          </div>
        )}
      </div>

      {/* Detaylar */}
      <div className="quest-details">
        {node.description && <p className="quest-desc">{node.description}</p>}
        <div className="quest-details-meta">
          {node.creator_name && (
            <span className="meta-item">
              👤 Atayan: {node.creator_name} {node.creator_role && `(${node.creator_role})`}
            </span>
          )}
          {node.branch_name && <span className="meta-item">🏪 {node.branch_name}</span>}
          {assigneeNames && <span className="meta-item">👥 {assigneeNames}</span>}
          {node.source_task_id && <span className="meta-item">📤 İletilmiş görev</span>}
        </div>

        {/* İlerleme kontrolü */}
        {!isApproved && (
          <div className="quest-progress-control">
            <label>İlerleme</label>
            <input
              type="range"
              min={0}
              max={100}
              step={10}
              value={localCompletion}
              onChange={(e) => handleCompletionChange(Number(e.target.value))}
            />
            <span className="progress-value">{localCompletion}%</span>
            <button type="button" className="btn-ghost" onClick={() => { setLocalCompletion(100); void onCompletionChange(node.id, 100); }}>
              Tamamla
            </button>
            <button type="button" className="btn-ghost" onClick={() => { setLocalCompletion(0); void onCompletionChange(node.id, 0); }}>
              Sıfırla
            </button>
          </div>
        )}

        {/* Aksiyon butonları */}
        <div className="quest-actions">
          {canApprove && (
            <button type="button" className="btn-primary btn-approve" onClick={() => onApprove(node.id)}>
              ✅ Onayla
            </button>
          )}
          {canArchive && (
            <button type="button" className="btn-secondary" onClick={() => onArchive(node.id, true)}>
              📦 Arşivle
            </button>
          )}
          {node.is_archived && (
            <button type="button" className="btn-secondary" onClick={() => onArchive(node.id, false)}>
              📂 Arşivden Çıkar
            </button>
          )}
          {node.is_creator && !isApproved && (
            <button type="button" className="btn-danger" onClick={() => onDelete(node.id)}>
              🗑️ Sil
            </button>
          )}
        </div>
      </div>

      {/* Alt görevler */}
      {hasChildren && isOpen && (
        <div className="quest-children">
          {node.children.map((child) => (
            <QuestCard
              key={child.id}
              node={child}
              assigneeLookup={assigneeLookup}
              onCompletionChange={onCompletionChange}
              onApprove={onApprove}
              onArchive={onArchive}
              onDelete={onDelete}
              depth={depth + 1}
            />
          ))}
        </div>
      )}
    </div>
  );
}

export default function TasksPage() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [assignees, setAssignees] = useState<Assignee[]>([]);
  const [scope, setScope] = useState<string>("all");
  const [activeTab, setActiveTab] = useState<Tab>("active");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [showCreate, setShowCreate] = useState(false);

  const [form, setForm] = useState({
    title: "",
    description: "",
    priority: "orta",
    due_date: "",
    assigneeId: "",
  });
  const [childDrafts, setChildDrafts] = useState<DraftNode[]>([]);

  const assigneeLookup = useMemo(() => {
    const map = new Map<string, Assignee>();
    assignees.forEach((a) => map.set(a.id, a));
    return map;
  }, [assignees]);

  const loadTasks = async () => {
    setLoading(true);
    setMessage(null);
    const archived = activeTab === "archived" ? "true" : "false";
    const res = await fetch(`/api/tasks?scope=${scope}&archived=${archived}`);
    if (!res.ok) {
      const body = await res.json().catch(() => ({} as { message?: string }));
      setMessage(body.message ?? "Görevler alınamadı");
      setLoading(false);
      return;
    }
    const data = (await res.json()) as { tasks: Task[] };
    setTasks(data.tasks ?? []);
    setLoading(false);
  };

  const loadAssignees = async () => {
    const res = await fetch("/api/tasks/assignees");
    if (!res.ok) return;
    const data = (await res.json()) as { assignees: Assignee[] };
    setAssignees(data.assignees ?? []);
  };

  const makeDraft = (): DraftNode => ({
    id: Math.random().toString(36).slice(2),
    title: "",
    description: "",
    priority: "orta",
    due_date: "",
    children: [],
  });

  const updateDrafts = (updater: (prev: DraftNode[]) => DraftNode[]) => {
    setChildDrafts((prev) => updater(prev));
  };

  const addDraft = (parentId?: string) => {
    updateDrafts((prev) => {
      const draft = makeDraft();
      if (!parentId) return [...prev, draft];
      const attach = (nodes: DraftNode[]): DraftNode[] =>
        nodes.map((n) =>
          n.id === parentId ? { ...n, children: [...n.children, draft] } : { ...n, children: attach(n.children) }
        );
      return attach(prev);
    });
  };

  const updateDraftField = (id: string, key: keyof DraftNode, value: string) => {
    const apply = (nodes: DraftNode[]): DraftNode[] =>
      nodes.map((n) => (n.id === id ? { ...n, [key]: value } : { ...n, children: apply(n.children) }));
    updateDrafts(apply);
  };

  const removeDraft = (id: string) => {
    const prune = (nodes: DraftNode[]): DraftNode[] =>
      nodes.filter((n) => n.id !== id).map((n) => ({ ...n, children: prune(n.children) }));
    updateDrafts(prune);
  };

  const collectDrafts = (nodes: DraftNode[]): DraftNode[] => {
    const result: DraftNode[] = [];
    nodes.forEach((n) => {
      const title = n.title.trim();
      if (!title) return;
      result.push({ ...n, title, children: collectDrafts(n.children) });
    });
    return result;
  };

  const createChildTree = async (parentId: string, nodes: DraftNode[]) => {
    for (const node of nodes) {
      const payload = {
        title: node.title,
        description: node.description || null,
        priority: node.priority,
        due_date: node.due_date || null,
        assigneeIds: [] as string[],
        parent_task_id: parentId,
      };
      const res = await fetch("/api/tasks", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      if (!res.ok) throw new Error("Alt görev oluşturulamadı");
      const body = (await res.json()) as { id: string };
      if (node.children.length > 0) {
        await createChildTree(body.id, node.children);
      }
    }
  };

  const renderDrafts = (nodes: DraftNode[], depth = 0) => {
    return nodes.map((draft) => (
      <div key={draft.id} className="draft-card" style={{ marginLeft: depth * 16 }}>
        <div className="draft-type">{depth === 0 ? "📦 Yan Görev" : "📎 Alt Görev"}</div>
        <div className="field">
          <label>Başlık</label>
          <input value={draft.title} onChange={(e) => updateDraftField(draft.id, "title", e.target.value)} />
        </div>
        <div className="field">
          <label>Not (opsiyonel)</label>
          <textarea value={draft.description} onChange={(e) => updateDraftField(draft.id, "description", e.target.value)} rows={2} />
        </div>
        <div className="grid two" style={{ gap: 8 }}>
          <label className="field">
            Öncelik
            <select value={draft.priority} onChange={(e) => updateDraftField(draft.id, "priority", e.target.value)}>
              {priorities.map((p) => (
                <option key={p.value} value={p.value}>
                  {p.emoji} {p.label}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            Son Tarih
            <input type="date" value={draft.due_date} onChange={(e) => updateDraftField(draft.id, "due_date", e.target.value)} />
          </label>
        </div>
        <div className="actions" style={{ justifyContent: "space-between", marginTop: 6 }}>
          {depth < 2 ? (
            <button type="button" className="btn-ghost" onClick={() => addDraft(draft.id)}>
              + Alt görev ekle
            </button>
          ) : (
            <span />
          )}
          <button type="button" className="btn-ghost btn-danger-text" onClick={() => removeDraft(draft.id)}>
            Sil
          </button>
        </div>
        {draft.children.length > 0 ? renderDrafts(draft.children, depth + 1) : null}
      </div>
    ));
  };

  const updateCompletion = async (taskId: string, completion: number) => {
    setMessage(null);
    const res = await fetch("/api/tasks", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ taskId, completion_percentage: completion }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({} as { message?: string }));
      setMessage(body.message ?? "Güncelleme başarısız");
      return;
    }
    await loadTasks();
  };

  const approveTask = async (taskId: string) => {
    setMessage(null);
    const res = await fetch("/api/tasks", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ taskId, approve: true }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({} as { message?: string }));
      setMessage(body.message ?? "Onay başarısız");
      return;
    }
    await loadTasks();
  };

  const archiveTask = async (taskId: string, archive: boolean) => {
    setMessage(null);
    const res = await fetch("/api/tasks", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ taskId, archive, unarchive: !archive }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({} as { message?: string }));
      setMessage(body.message ?? "İşlem başarısız");
      return;
    }
    await loadTasks();
  };

  const deleteTask = async (taskId: string) => {
    const ok = window.confirm("Görevi ve alt görevlerini silmek istediğinize emin misiniz?");
    if (!ok) return;
    setMessage(null);
    const res = await fetch("/api/tasks", {
      method: "DELETE",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ taskId }),
    });
    if (!res.ok) {
      const body = await res.json().catch(() => ({} as { message?: string }));
      setMessage(body.message ?? "Görev silinemedi");
      return;
    }
    await loadTasks();
  };

  useEffect(() => {
    void loadAssignees();
  }, []);

  useEffect(() => {
    void loadTasks();
  }, [scope, activeTab]);

  const createTask = async () => {
    setMessage(null);
    const assigneeIds =
      form.assigneeId === "__all__" ? assignees.map((a) => a.id) : form.assigneeId ? [form.assigneeId] : [];
    const payload = {
      title: form.title,
      description: form.description || null,
      priority: form.priority,
      due_date: form.due_date || null,
      assigneeIds,
      parent_task_id: null,
    };
    const res = await fetch("/api/tasks", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      setMessage("Görev oluşturulamadı");
      return;
    }
    const body = (await res.json()) as { id: string };
    const cleaned = collectDrafts(childDrafts);
    if (body?.id && cleaned.length > 0) {
      try {
        await createChildTree(body.id, cleaned);
      } catch (err) {
        setMessage((err as Error).message);
      }
    }
    setForm({ title: "", description: "", priority: "orta", due_date: "", assigneeId: "" });
    setChildDrafts([]);
    setShowCreate(false);
    await loadTasks();
  };

  // Task tree oluştur
  const taskTree: TaskNode[] = useMemo(() => {
    const map = new Map<string, TaskNode>();
    tasks.forEach((t) => map.set(t.id, { ...t, children: [] }));
    const roots: TaskNode[] = [];
    map.forEach((node) => {
      if (node.parent_task_id && map.has(node.parent_task_id)) {
        map.get(node.parent_task_id)!.children.push(node);
      } else {
        roots.push(node);
      }
    });
    return roots;
  }, [tasks]);

  // Tab'a göre filtrele
  const filteredTasks = useMemo(() => {
    switch (activeTab) {
      case "active":
        return taskTree.filter((t) => t.status !== "onaylandi" && !t.is_archived);
      case "completed":
        return taskTree.filter((t) => (t.status === "tamamlandi" || t.status === "onaylandi") && !t.is_archived);
      case "archived":
        return taskTree.filter((t) => t.is_archived);
      default:
        return taskTree;
    }
  }, [taskTree, activeTab]);

  // Tab sayaçları
  const tabCounts = useMemo(() => {
    const active = taskTree.filter((t) => t.status !== "onaylandi" && !t.is_archived).length;
    const completed = taskTree.filter((t) => (t.status === "tamamlandi" || t.status === "onaylandi") && !t.is_archived).length;
    const archived = taskTree.filter((t) => t.is_archived).length;
    return { active, completed, archived };
  }, [taskTree]);

  return (
    <div className="page tasks-page">
      <header className="page-header">
        <div className="header-content">
          <h2>🎯 Görev Merkezi</h2>
          <p>Görevlerinizi yönetin, ilerlemeleri takip edin ve ekibinizle koordine olun.</p>
        </div>
        <button type="button" className="btn-primary btn-create" onClick={() => setShowCreate(!showCreate)}>
          {showCreate ? "✕ Kapat" : "✚ Yeni Görev"}
        </button>
      </header>

      {message && <div className="alert alert-error">{message}</div>}

      {/* Görev oluşturma formu */}
      {showCreate && (
        <div className="card create-task-card">
          <div className="create-header">
            <h3>🎯 Yeni Görev Oluştur</h3>
            <span className="badge badge-draft">Taslak</span>
          </div>

          <div className="form-grid">
            <label className="field full">
              Görev Başlığı
              <input
                value={form.title}
                onChange={(e) => setForm((p) => ({ ...p, title: e.target.value }))}
                placeholder="Örn: Kampanya lansman hazırlığı"
              />
            </label>

            <label className="field">
              Öncelik
              <select value={form.priority} onChange={(e) => setForm((p) => ({ ...p, priority: e.target.value }))}>
                {priorities.map((p) => (
                  <option key={p.value} value={p.value}>
                    {p.emoji} {p.label}
                  </option>
                ))}
              </select>
            </label>

            <label className="field">
              Son Tarih
              <input type="date" value={form.due_date} onChange={(e) => setForm((p) => ({ ...p, due_date: e.target.value }))} />
            </label>

            <label className="field">
              Personel Ata
              <select value={form.assigneeId} onChange={(e) => setForm((p) => ({ ...p, assigneeId: e.target.value }))}>
                <option value="">(Atama yapma)</option>
                <option value="__all__">Tüm personeller</option>
                {assignees.map((a) => (
                  <option key={a.id} value={a.id}>
                    {[a.first_name, a.last_name].filter(Boolean).join(" ") || a.email || a.id}
                  </option>
                ))}
              </select>
            </label>

            <label className="field full">
              Açıklama
              <textarea
                value={form.description}
                onChange={(e) => setForm((p) => ({ ...p, description: e.target.value }))}
                rows={3}
                placeholder="Görev hakkında detaylı bilgi"
              />
            </label>

            <div className="drafts-block full">
              <div className="drafts-header">
                <h4>📦 Alt Görevler</h4>
                <button type="button" className="btn-ghost" onClick={() => addDraft()}>
                  + Yan Görev Ekle
                </button>
              </div>
              <p className="muted">En fazla 3 seviye (Ana → Yan → Alt) görev oluşturabilirsiniz.</p>
              {childDrafts.length === 0 ? (
                <p className="muted">Henüz yan görev eklenmedi.</p>
              ) : (
                <div className="drafts-list">{renderDrafts(childDrafts)}</div>
              )}
            </div>
          </div>

          <div className="actions create-actions">
            <button type="button" className="btn-ghost" onClick={() => setShowCreate(false)}>
              Vazgeç
            </button>
            <button type="button" className="btn-primary" onClick={createTask} disabled={!form.title.trim()}>
              ✓ Görevi Oluştur
            </button>
          </div>
        </div>
      )}

      {/* Tab bar */}
      <div className="tab-bar">
        <button
          type="button"
          className={`tab ${activeTab === "active" ? "active" : ""}`}
          onClick={() => setActiveTab("active")}
        >
          🎯 Aktif <span className="tab-count">{tabCounts.active}</span>
        </button>
        <button
          type="button"
          className={`tab ${activeTab === "completed" ? "active" : ""}`}
          onClick={() => setActiveTab("completed")}
        >
          ✅ Tamamlanan <span className="tab-count">{tabCounts.completed}</span>
        </button>
        <button
          type="button"
          className={`tab ${activeTab === "archived" ? "active" : ""}`}
          onClick={() => setActiveTab("archived")}
        >
          📦 Arşiv <span className="tab-count">{tabCounts.archived}</span>
        </button>

        <div className="tab-spacer" />

        <label className="scope-select">
          <select value={scope} onChange={(e) => setScope(e.target.value)}>
            {scopes.map((s) => (
              <option key={s.value} value={s.value}>
                {s.label}
              </option>
            ))}
          </select>
        </label>
      </div>

      {/* Görev listesi */}
      <div className="card quest-list-card">
        {loading && <p className="loading">Yükleniyor...</p>}
        {!loading && filteredTasks.length === 0 && (
          <div className="empty-state">
            <span className="empty-icon">
              {activeTab === "active" ? "🎯" : activeTab === "completed" ? "✅" : "📦"}
            </span>
            <p>
              {activeTab === "active" && "Aktif görev bulunmuyor."}
              {activeTab === "completed" && "Tamamlanan görev bulunmuyor."}
              {activeTab === "archived" && "Arşivlenmiş görev bulunmuyor."}
            </p>
          </div>
        )}

        <div className="quest-list">
          {filteredTasks.map((t) => (
            <QuestCard
              key={t.id}
              node={t}
              assigneeLookup={assigneeLookup}
              onCompletionChange={updateCompletion}
              onApprove={approveTask}
              onArchive={archiveTask}
              onDelete={deleteTask}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
