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
  created_at: string | null;
  created_by: string;
  branch_id: string | null;
  parent_task_id: string | null;
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
  { value: "dusuk", label: "Düşük" },
  { value: "orta", label: "Orta" },
  { value: "yuksek", label: "Yüksek" },
];

const scopes = [
  { value: "mine", label: "Bana atanan / oluşturduğum" },
  { value: "branch", label: "Şubedeki tüm görevler" },
];

function TaskCard({
  node,
  assigneeLookup,
  onCompletionChange,
}: {
  node: TaskNode;
  assigneeLookup: Map<string, Assignee>;
  onCompletionChange: (taskId: string, completion: number) => Promise<void>;
}) {
  const [localCompletion, setLocalCompletion] = useState<number>(node.completion_percentage ?? 0);
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

  const handleQuickSet = (value: number) => {
    setLocalCompletion(value);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    void onCompletionChange(node.id, value);
  };
  const assigneeNames = (node.task_assignees ?? [])
    .map((a) => assigneeLookup.get(a.user_id))
    .filter(Boolean)
    .map((a) => [a!.first_name, a!.last_name].filter(Boolean).join(" ") || a!.email || a!.id)
    .join(", ");

  const hasChildren = node.children.length > 0;
  return (
    <details className="task-card" open={false} aria-label="task-card">
      <summary>
        <div className="task-summary">
          <div className="task-title-block">
            <strong>{node.title}</strong>
            <div className="time-stamp">
              {node.priority ? `Öncelik: ${node.priority}` : ""}
              {node.status ? ` · Durum: ${node.status}` : ""}
            </div>
          </div>
          <div className="task-summary-right">
            {typeof node.completion_percentage === "number" ? (
              <div className="pill pill-progress">
                <span>{node.completion_percentage}%</span>
              </div>
            ) : null}
            {node.due_date ? <div className="badge">Son: {new Date(node.due_date).toLocaleDateString()}</div> : null}
          </div>
        </div>
        {assigneeNames ? <div className="time-stamp">Atanan: {assigneeNames}</div> : null}
      </summary>
      {node.description ? <p className="task-desc">{node.description}</p> : null}
      <div className="progress-row">
        <label htmlFor={`progress-${node.id}`}>İlerleme</label>
        <input
          id={`progress-${node.id}`}
          type="range"
          min={0}
          max={100}
          step={10}
          value={localCompletion}
          onChange={(e) => handleCompletionChange(Number(e.target.value))}
        />
        <span className="progress-value">{localCompletion}%</span>
        <button type="button" className="ghost" onClick={() => handleQuickSet(100)}>
          Tamamla
        </button>
        <button type="button" className="ghost" onClick={() => handleQuickSet(0)}>
          Sıfırla
        </button>
      </div>
      {hasChildren ? (
        <div className="task-children">
          {node.children.map((child) => (
            <TaskCard key={child.id} node={child} assigneeLookup={assigneeLookup} onCompletionChange={onCompletionChange} />
          ))}
        </div>
      ) : null}
    </details>
  );
}

export default function TasksPage() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [assignees, setAssignees] = useState<Assignee[]>([]);
  const [scope, setScope] = useState<string>("mine");
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
    const res = await fetch(`/api/tasks?scope=${scope}`);
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
          n.id === parentId
            ? { ...n, children: [...n.children, draft] }
            : { ...n, children: attach(n.children) }
        );
      return attach(prev);
    });
  };

  const updateDraftField = (id: string, key: keyof DraftNode, value: string) => {
    const apply = (nodes: DraftNode[]): DraftNode[] =>
      nodes.map((n) =>
        n.id === id ? { ...n, [key]: value } : { ...n, children: apply(n.children) }
      );
    updateDrafts(apply);
  };

  const removeDraft = (id: string) => {
    const prune = (nodes: DraftNode[]): DraftNode[] =>
      nodes
        .filter((n) => n.id !== id)
        .map((n) => ({ ...n, children: prune(n.children) }));
    updateDrafts(prune);
  };

  const collectDrafts = (nodes: DraftNode[]): DraftNode[] => {
    const result: DraftNode[] = [];
    nodes.forEach((n) => {
      const title = n.title.trim();
      if (!title) return;
      result.push({
        ...n,
        title,
        children: collectDrafts(n.children),
      });
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
      if (!res.ok) {
        throw new Error("Alt görev oluşturulamadı");
      }
      const body = (await res.json()) as { id: string };
      if (node.children.length > 0) {
        await createChildTree(body.id, node.children);
      }
    }
  };

  const renderDrafts = (nodes: DraftNode[], depth = 0) => {
    return nodes.map((draft) => (
      <div key={draft.id} className="draft-card" style={{ marginLeft: depth * 12 }}>
        <div className="field">
          <label>Alt görev başlığı</label>
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
                  {p.label}
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
          {depth < 1 ? (
            <button type="button" className="ghost" onClick={() => addDraft(draft.id)}>
              Alt görev ekle
            </button>
          ) : (
            <span />
          )}
          <button type="button" className="ghost" onClick={() => removeDraft(draft.id)}>
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

  useEffect(() => {
    void loadAssignees();
  }, []);

  useEffect(() => {
    void loadTasks();
  }, [scope]);

  const createTask = async () => {
    setMessage(null);
    const assigneeIds =
      form.assigneeId === "__all__"
        ? assignees.map((a) => a.id)
        : form.assigneeId
        ? [form.assigneeId]
        : [];
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


  return (
    <div className="page">
      <header className="page-header">
        <h2>Görevler</h2>
        <p>Şube müdürü olarak görev atayın, size atanmış veya şubenizdeki görevleri görüntüleyin.</p>
      </header>

      {message ? <p className="alert alert-error">{message}</p> : null}

      {!showCreate ? (
        <div className="card create-task-card create-collapsed">
          <div className="create-task-header">
            <div>
              <p className="eyebrow">Yeni görev</p>
              <h3>Görev Oluştur</h3>
              <p className="muted">Başlık, öncelik ve atamaları belirleyip eklemek için tıklayın.</p>
            </div>
            <button type="button" className="primary" onClick={() => setShowCreate(true)}>
              Görev ekle
            </button>
          </div>
        </div>
      ) : (
        <div className="card create-task-card">
          <div className="create-task-header">
            <div>
              <p className="eyebrow">Yeni görev</p>
              <h3>Görev Oluştur</h3>
              <p className="muted">Başlık, öncelik ve atamaları belirleyip hızlıca ekleyin.</p>
            </div>
            <div className="header-actions">
              <label className="field compact">
                Personel
                <select
                  value={form.assigneeId}
                  onChange={(e) => setForm((p) => ({ ...p, assigneeId: e.target.value }))}
                >
                  <option value="">(Atama yapma)</option>
                  <option value="__all__">Tüm personeller</option>
                  {assignees.map((a) => (
                    <option key={a.id} value={a.id}>
                      {[a.first_name, a.last_name].filter(Boolean).join(" ") || a.email || a.id}
                    </option>
                  ))}
                </select>
              </label>
              <div className="pill pill-progress">Taslak</div>
            </div>
          </div>

          <div className="form-grid">
            <label className="field full">
              Başlık
              <input value={form.title} onChange={(e) => setForm((p) => ({ ...p, title: e.target.value }))} placeholder="Örn: Kampanya lansman hazırlığı" />
            </label>

            <label className="field">
              Öncelik
              <select value={form.priority} onChange={(e) => setForm((p) => ({ ...p, priority: e.target.value }))}>
                {priorities.map((p) => (
                  <option key={p.value} value={p.value}>
                    {p.label}
                  </option>
                ))}
              </select>
            </label>

            <label className="field">
              Son Tarih (opsiyonel)
              <input type="date" value={form.due_date} onChange={(e) => setForm((p) => ({ ...p, due_date: e.target.value }))} />
            </label>



            <label className="field full">
              Açıklama
              <textarea
                value={form.description}
                onChange={(e) => setForm((p) => ({ ...p, description: e.target.value }))}
                rows={3}
                placeholder="Ek bilgi, beklenen çıktı, kaynak linkleri"
              />
            </label>

              <div className="drafts-block full">
                <div className="drafts-header">
                  <h4>Alt Görevler</h4>
                  <button type="button" className="ghost" onClick={() => addDraft()}>
                    Alt görev ekle
                  </button>
                </div>
                <p className="muted" style={{ marginTop: 0 }}>
                  En fazla iki seviye alt görev ekleyebilirsin. Boş bırakılırsa yalnızca ana görev oluşturulur.
                </p>
                {childDrafts.length === 0 ? (
                  <p className="muted">Henüz alt görev eklenmedi.</p>
                ) : (
                  <div className="drafts-list">{renderDrafts(childDrafts)}</div>
                )}
              </div>
          </div>

          <div className="actions create-actions">
            <div className="hint">Kaydedince görev atanmış kişilerin listesine düşer.</div>
            <div className="actions" style={{ gap: 8 }}>
              <button type="button" className="ghost" onClick={() => setShowCreate(false)}>
                Vazgeç
              </button>
              <button type="button" className="primary" onClick={createTask} disabled={!form.title.trim()}>
                Kaydet
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="card">
        <div className="controls" style={{ justifyContent: "space-between", alignItems: "center" }}>
          <h3>Görev Listesi</h3>
          <label>
            Görünüm
            <select value={scope} onChange={(e) => setScope(e.target.value)}>
              {scopes.map((s) => (
                <option key={s.value} value={s.value}>
                  {s.label}
                </option>
              ))}
            </select>
          </label>
        </div>

        {loading ? <p>Yükleniyor...</p> : null}
        {!loading && tasks.length === 0 ? <p>Görev bulunamadı.</p> : null}

        <div className="task-grid">
          {taskTree.map((t) => (
            <TaskCard key={t.id} node={t} assigneeLookup={assigneeLookup} onCompletionChange={updateCompletion} />
          ))}
        </div>
      </div>
    </div>
  );
}
