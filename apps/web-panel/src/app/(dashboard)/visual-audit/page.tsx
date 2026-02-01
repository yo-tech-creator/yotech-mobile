"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { Settings, Plus, Send, X, Clock, CheckCircle, AlertCircle, Camera, Loader2, ChevronLeft, ChevronRight, Calendar, Trash2, Check } from "lucide-react";
import { toast } from "sonner";
import { createTask, getTasks, getStats, getSections, getBranches, getTaskPhotos, getTaskComments, addComment, deleteTasks } from "./actions";
import "./visual-audit.css";

// Types
interface Task {
  id: string;
  branch_id: string;
  branch_name: string;
  section_id: string;
  section_name: string;
  section_color: string;
  status: string;
  scheduled_date: string;
  scheduled_time: string;
  deadline_at: string;
  min_photos: number;
  notes: string | null;
  created_by: string | null;
  created_by_name: string | null;
  created_at: string;
  completed_at: string | null;
  photo_count: number;
}

interface Section {
  id: string;
  name: string;
  color: string;
  is_active: boolean;
}

interface Branch {
  id: string;
  name: string;
}

interface Stats {
  total_tasks: number;
  pending_tasks: number;
  completed_tasks: number;
  overdue_tasks: number;
}

interface Photo {
  id: string;
  photo_url: string;
  uploaded_at: string;
  uploaded_by: string;
  users: { full_name: string } | null;
}

interface Comment {
  id: string;
  comment: string;
  created_at: string;
  user_id: string;
  users: { full_name: string } | null;
}

export default function VisualAuditPage() {
  // Data states
  const [tasks, setTasks] = useState<Task[]>([]);
  const [sections, setSections] = useState<Section[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [stats, setStats] = useState<Stats>({ total_tasks: 0, pending_tasks: 0, completed_tasks: 0, overdue_tasks: 0 });
  
  // UI states
  const [loading, setLoading] = useState(true);
  const [selectedTask, setSelectedTask] = useState<Task | null>(null);
  const [taskPhotos, setTaskPhotos] = useState<Photo[]>([]);
  const [taskComments, setTaskComments] = useState<Comment[]>([]);
  const [newComment, setNewComment] = useState("");
  const [sendingComment, setSendingComment] = useState(false);
  
  // Multi-select states
  const [multiSelectMode, setMultiSelectMode] = useState(false);
  const [selectedTaskIds, setSelectedTaskIds] = useState<Set<string>>(new Set());
  const [deletingTasks, setDeletingTasks] = useState(false);
  const [longPressTimer, setLongPressTimer] = useState<NodeJS.Timeout | null>(null);
  
  // New task form states
  const [showNewTaskForm, setShowNewTaskForm] = useState(false);
  const [creatingTask, setCreatingTask] = useState(false);
  const [taskForm, setTaskForm] = useState({
    section_ids: [] as string[],
    branch_ids: [] as string[],
    deadline_minutes: 60,
    min_photos: 1,
    note: "",
    scheduled_hour: 9, // Görevin başlama saati (0-23)
    recurrence: "none" as "none" | "daily" | "weekly",
    selectedDays: [] as number[], // 0=Pazar, 1=Pazartesi, ..., 6=Cumartesi
    recurrenceWeeks: 2, // Kaç hafta için
  });

  const dayNames = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"];

  const toggleDay = (day: number) => {
    setTaskForm(prev => ({
      ...prev,
      selectedDays: prev.selectedDays.includes(day)
        ? prev.selectedDays.filter(d => d !== day)
        : [...prev.selectedDays, day].sort(),
    }));
  };
  
  // Filter states
  const [filterStatus, setFilterStatus] = useState<string>("all");
  const [filterBranch, setFilterBranch] = useState<string>("all");
  const [filterSection, setFilterSection] = useState<string>("all");
  const [filterDate, setFilterDate] = useState<string>(new Date().toISOString().split("T")[0]);
  const [filterHour, setFilterHour] = useState<string>("all");
  const [showDatePicker, setShowDatePicker] = useState(false);

  // Date navigation helpers
  const goToPreviousDay = () => {
    const date = new Date(filterDate);
    date.setDate(date.getDate() - 1);
    setFilterDate(date.toISOString().split("T")[0]);
  };

  const goToNextDay = () => {
    const date = new Date(filterDate);
    date.setDate(date.getDate() + 1);
    setFilterDate(date.toISOString().split("T")[0]);
  };

  const goToToday = () => {
    setFilterDate(new Date().toISOString().split("T")[0]);
  };

  const isToday = filterDate === new Date().toISOString().split("T")[0];

  const formatDisplayDate = (dateStr: string) => {
    const date = new Date(dateStr);
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    if (dateStr === today.toISOString().split("T")[0]) return "Bugün";
    if (dateStr === yesterday.toISOString().split("T")[0]) return "Dün";
    if (dateStr === tomorrow.toISOString().split("T")[0]) return "Yarın";

    return date.toLocaleDateString("tr-TR", { weekday: "long", day: "numeric", month: "long" });
  };

  // Data fetching
  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      // filterDate null ise tüm görevler, değilse o tarihin görevleri
      const dateParam = filterDate || null;
      const [tasksData, sectionsData, branchesData, statsData] = await Promise.all([
        getTasks(dateParam),
        getSections(),
        getBranches(),
        getStats(dateParam),
      ]);
      setTasks(tasksData as Task[]);
      setSections(sectionsData);
      setBranches(branchesData);
      setStats(statsData as Stats);
    } catch (error) {
      console.error("Error fetching data:", error);
      toast.error("Veriler yüklenirken hata oluştu");
    } finally {
      setLoading(false);
    }
  }, [filterDate]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Multi-select handlers
  const handleLongPressStart = (taskId: string) => {
    const timer = setTimeout(() => {
      setMultiSelectMode(true);
      setSelectedTaskIds(new Set([taskId]));
    }, 500); // 500ms long press
    setLongPressTimer(timer);
  };

  const handleLongPressEnd = () => {
    if (longPressTimer) {
      clearTimeout(longPressTimer);
      setLongPressTimer(null);
    }
  };

  const toggleTaskSelection = (taskId: string) => {
    setSelectedTaskIds(prev => {
      const newSet = new Set(prev);
      if (newSet.has(taskId)) {
        newSet.delete(taskId);
      } else {
        newSet.add(taskId);
      }
      // Eğer hiç seçili kalmadıysa çoklu seçim modundan çık
      if (newSet.size === 0) {
        setMultiSelectMode(false);
      }
      return newSet;
    });
  };

  const cancelMultiSelect = () => {
    setMultiSelectMode(false);
    setSelectedTaskIds(new Set());
  };

  const selectAllTasks = () => {
    setSelectedTaskIds(new Set(filteredTasks.map(t => t.id)));
  };

  const handleDeleteSelected = async () => {
    if (selectedTaskIds.size === 0) return;
    
    const confirmed = window.confirm(`${selectedTaskIds.size} görevi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.`);
    if (!confirmed) return;
    
    setDeletingTasks(true);
    try {
      const result = await deleteTasks(Array.from(selectedTaskIds));
      if (!result.success) throw new Error(result.error);
      
      toast.success(`${result.data.deleted} görev silindi`);
      cancelMultiSelect();
      fetchData();
    } catch (error) {
      const msg = error instanceof Error ? error.message : "Görevler silinemedi";
      toast.error(msg);
    } finally {
      setDeletingTasks(false);
    }
  };

  // Task detail
  const handleTaskClick = async (task: Task) => {
    // Çoklu seçim modundaysa detay gösterme, seçimi toggle et
    if (multiSelectMode) {
      toggleTaskSelection(task.id);
      return;
    }
    
    setSelectedTask(task);
    try {
      const [photos, comments] = await Promise.all([
        getTaskPhotos(task.id),
        getTaskComments(task.id),
      ]);
      setTaskPhotos(photos as Photo[]);
      setTaskComments(comments as Comment[]);
    } catch (error) {
      console.error("Error fetching task details:", error);
    }
  };

  // Send comment
  const handleSendComment = async () => {
    if (!selectedTask || !newComment.trim()) return;
    
    setSendingComment(true);
    try {
      const result = await addComment(selectedTask.id, newComment.trim());
      if (!result.success) throw new Error(result.error);
      
      toast.success("Yorum eklendi");
      setNewComment("");
      const comments = await getTaskComments(selectedTask.id);
      setTaskComments(comments as Comment[]);
    } catch (error) {
      const msg = error instanceof Error ? error.message : "Yorum eklenemedi";
      toast.error(msg);
    } finally {
      setSendingComment(false);
    }
  };

  // Create new task
  const handleCreateTask = async () => {
    if (taskForm.section_ids.length === 0) {
      toast.error("En az bir bölüm seçin");
      return;
    }

    // Weekly seçiliyse en az bir gün seçilmeli
    if (taskForm.recurrence === "weekly" && taskForm.selectedDays.length === 0) {
      toast.error("Haftanın en az bir gününü seçin");
      return;
    }

    setCreatingTask(true);
    try {
      const result = await createTask({
        branch_ids: taskForm.branch_ids,
        section_ids: taskForm.section_ids,
        deadline_minutes: taskForm.deadline_minutes,
        min_photos: taskForm.min_photos,
        note: taskForm.note || undefined,
        scheduled_hour: taskForm.scheduled_hour,
        recurrence: taskForm.recurrence,
        selectedDays: taskForm.selectedDays,
        recurrenceWeeks: taskForm.recurrenceWeeks,
      });

      if (!result.success) throw new Error(result.error);

      // Tekrarlı görev oluşturulduysa plan bilgisini göster
      if (taskForm.recurrence !== "none" && result.data && "tasks_created" in result.data) {
        toast.success(`Plan oluşturuldu: ${result.data.tasks_created} görev - Planlar sayfasından yönetebilirsiniz`);
      } else if (Array.isArray(result.data)) {
        toast.success(`${result.data.length} görev oluşturuldu`);
      }
      
      setShowNewTaskForm(false);
      setTaskForm({ section_ids: [], branch_ids: [], deadline_minutes: 60, min_photos: 1, note: "", scheduled_hour: 9, recurrence: "none", selectedDays: [], recurrenceWeeks: 2 });
      fetchData();
    } catch (error) {
      const msg = error instanceof Error ? error.message : "Görev oluşturulamadı";
      toast.error(msg);
    } finally {
      setCreatingTask(false);
    }
  };

  // Toggle section selection
  const toggleSection = (id: string) => {
    setTaskForm(prev => ({
      ...prev,
      section_ids: prev.section_ids.includes(id)
        ? prev.section_ids.filter(s => s !== id)
        : [...prev.section_ids, id],
    }));
  };

  // Toggle branch selection
  const toggleBranch = (id: string) => {
    setTaskForm(prev => ({
      ...prev,
      branch_ids: prev.branch_ids.includes(id)
        ? prev.branch_ids.filter(b => b !== id)
        : [...prev.branch_ids, id],
    }));
  };

  // Filter tasks
  const filteredTasks = tasks.filter(task => {
    // Status filter
    if (filterStatus === "pending" && task.status !== "pending") return false;
    if (filterStatus === "completed" && task.status !== "completed") return false;
    if (filterStatus === "overdue" && !(task.status === "pending" && new Date(task.deadline_at) < new Date())) return false;
    
    // Branch filter
    if (filterBranch !== "all" && task.branch_id !== filterBranch) return false;
    
    // Section filter
    if (filterSection !== "all" && task.section_id !== filterSection) return false;
    
    // Hour filter
    if (filterHour !== "all") {
      const taskHour = new Date(task.deadline_at).getHours();
      if (taskHour !== parseInt(filterHour)) return false;
    }
    
    return true;
  });

  // Get unique hours from tasks
  const uniqueHours = [...new Set(tasks.map(t => new Date(t.deadline_at).getHours()))].sort((a, b) => a - b);

  // Format time
  const formatTime = (dateStr: string) => {
    return new Date(dateStr).toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });
  };

  // Check if overdue
  const isOverdue = (task: Task) => task.status === "pending" && new Date(task.deadline_at) < new Date();

  return (
    <div className="va-page">
      {/* Header */}
      <div className="va-page-header">
        <div className="va-header-content">
          <h1>Görsel Denetim</h1>
          <p>Şubelerden fotoğraf talep edin ve inceleyin</p>
        </div>
        <div className="va-header-actions">
          <button className="va-btn-primary" onClick={() => setShowNewTaskForm(true)}>
            <Plus size={18} />
            Yeni Görev
          </button>
          <Link href="/visual-audit/plans" className="va-btn-secondary">
            <Calendar size={18} />
            Planlar
          </Link>
          <Link href="/visual-audit/settings" className="va-btn-ghost">
            <Settings size={18} />
            Ayarlar
          </Link>
        </div>
      </div>

      {/* Stats */}
      <div className="va-stats">
        <div className="va-stat-card">
          <div className="va-stat-icon total"><Camera size={20} /></div>
          <div className="va-stat-content">
            <span className="va-stat-value">{stats.total_tasks}</span>
            <span className="va-stat-label">Toplam</span>
          </div>
        </div>
        <div className="va-stat-card">
          <div className="va-stat-icon pending"><Clock size={20} /></div>
          <div className="va-stat-content">
            <span className="va-stat-value">{stats.pending_tasks}</span>
            <span className="va-stat-label">Bekleyen</span>
          </div>
        </div>
        <div className="va-stat-card">
          <div className="va-stat-icon completed"><CheckCircle size={20} /></div>
          <div className="va-stat-content">
            <span className="va-stat-value">{stats.completed_tasks}</span>
            <span className="va-stat-label">Tamamlanan</span>
          </div>
        </div>
        <div className="va-stat-card">
          <div className="va-stat-icon overdue"><AlertCircle size={20} /></div>
          <div className="va-stat-content">
            <span className="va-stat-value">{stats.overdue_tasks}</span>
            <span className="va-stat-label">Geciken</span>
          </div>
        </div>
      </div>

      {/* New Task Form */}
      {showNewTaskForm && (
        <div className="va-new-task-form">
          <div className="va-form-header">
            <h3>Yeni Görev Oluştur</h3>
            <button className="va-close-btn" onClick={() => setShowNewTaskForm(false)}>
              <X size={20} />
            </button>
          </div>
          
          <div className="va-form-body">
            {/* Sections */}
            <div className="va-form-group">
              <label>Bölümler * <span className="va-hint">(Hangi alanların fotoğrafı?)</span></label>
              <div className="va-chip-list">
                {sections.map(s => (
                  <button
                    key={s.id}
                    className={`va-chip ${taskForm.section_ids.includes(s.id) ? "active" : ""}`}
                    style={!taskForm.section_ids.includes(s.id) ? { borderColor: s.color } : undefined}
                    onClick={() => toggleSection(s.id)}
                  >
                    {s.name}
                  </button>
                ))}
                {sections.length === 0 && <p className="va-empty-text">Önce Ayarlar'dan bölüm ekleyin</p>}
              </div>
            </div>

            {/* Branches */}
            <div className="va-form-group">
              <label>Şubeler <span className="va-hint">(Boş = Tüm şubeler)</span></label>
              <div className="va-chip-list va-chip-list-scroll">
                {branches.map(b => (
                  <button
                    key={b.id}
                    className={`va-chip ${taskForm.branch_ids.includes(b.id) ? "active" : ""}`}
                    onClick={() => toggleBranch(b.id)}
                  >
                    {b.name}
                  </button>
                ))}
              </div>
            </div>

            {/* Options Row */}
            <div className="va-form-row">
              <div className="va-form-group">
                <label>Görev Saati</label>
                <select
                  value={taskForm.scheduled_hour}
                  onChange={e => setTaskForm({ ...taskForm, scheduled_hour: parseInt(e.target.value) })}
                  className="va-select"
                >
                  <option value={6}>06:00</option>
                  <option value={7}>07:00</option>
                  <option value={8}>08:00</option>
                  <option value={9}>09:00</option>
                  <option value={10}>10:00</option>
                  <option value={11}>11:00</option>
                  <option value={12}>12:00</option>
                  <option value={13}>13:00</option>
                  <option value={14}>14:00</option>
                  <option value={15}>15:00</option>
                  <option value={16}>16:00</option>
                  <option value={17}>17:00</option>
                  <option value={18}>18:00</option>
                  <option value={19}>19:00</option>
                  <option value={20}>20:00</option>
                  <option value={21}>21:00</option>
                  <option value={22}>22:00</option>
                </select>
              </div>
              <div className="va-form-group">
                <label>Süre Limiti</label>
                <select
                  value={taskForm.deadline_minutes}
                  onChange={e => setTaskForm({ ...taskForm, deadline_minutes: parseInt(e.target.value) })}
                  className="va-select"
                >
                  <option value={30}>30 dakika</option>
                  <option value={60}>1 saat</option>
                  <option value={120}>2 saat</option>
                  <option value={240}>4 saat</option>
                  <option value={480}>8 saat</option>
                </select>
              </div>
              <div className="va-form-group">
                <label>Min. Fotoğraf</label>
                <select
                  value={taskForm.min_photos}
                  onChange={e => setTaskForm({ ...taskForm, min_photos: parseInt(e.target.value) })}
                  className="va-select"
                >
                  <option value={1}>1 fotoğraf</option>
                  <option value={2}>2 fotoğraf</option>
                  <option value={3}>3 fotoğraf</option>
                  <option value={5}>5 fotoğraf</option>
                </select>
              </div>
            </div>

            {/* Note */}
            <div className="va-form-group">
              <label>Not <span className="va-hint">(Opsiyonel)</span></label>
              <input
                type="text"
                value={taskForm.note}
                onChange={e => setTaskForm({ ...taskForm, note: e.target.value })}
                placeholder="Personele iletilecek not..."
                className="va-input"
              />
            </div>

            {/* Recurrence */}
            <div className="va-form-group">
              <label>Tekrar <span className="va-hint">(Opsiyonel)</span></label>
              <div className="va-recurrence-options">
                <button
                  type="button"
                  className={`va-chip ${taskForm.recurrence === "none" ? "active" : ""}`}
                  onClick={() => setTaskForm({ ...taskForm, recurrence: "none", selectedDays: [] })}
                >
                  Tek Seferlik
                </button>
                <button
                  type="button"
                  className={`va-chip ${taskForm.recurrence === "daily" ? "active" : ""}`}
                  onClick={() => setTaskForm({ ...taskForm, recurrence: "daily", selectedDays: [] })}
                >
                  Her Gün
                </button>
                <button
                  type="button"
                  className={`va-chip ${taskForm.recurrence === "weekly" ? "active" : ""}`}
                  onClick={() => setTaskForm({ ...taskForm, recurrence: "weekly" })}
                >
                  Haftanın Günleri
                </button>
              </div>

              {/* Daily recurrence - weeks selector */}
              {taskForm.recurrence === "daily" && (
                <div className="va-recurrence-detail">
                  <span>Önümüzdeki</span>
                  <select
                    value={taskForm.recurrenceWeeks}
                    onChange={e => setTaskForm({ ...taskForm, recurrenceWeeks: parseInt(e.target.value) })}
                    className="va-select va-select-inline"
                  >
                    <option value={1}>1 hafta</option>
                    <option value={2}>2 hafta</option>
                    <option value={4}>1 ay</option>
                  </select>
                  <span>boyunca her gün</span>
                </div>
              )}

              {/* Weekly recurrence - day selector */}
              {taskForm.recurrence === "weekly" && (
                <div className="va-recurrence-detail">
                  <div className="va-day-selector">
                    {dayNames.map((name, index) => (
                      <button
                        key={index}
                        type="button"
                        className={`va-day-btn ${taskForm.selectedDays.includes(index) ? "active" : ""}`}
                        onClick={() => toggleDay(index)}
                      >
                        {name}
                      </button>
                    ))}
                  </div>
                  <div className="va-recurrence-weeks">
                    <span>Önümüzdeki</span>
                    <select
                      value={taskForm.recurrenceWeeks}
                      onChange={e => setTaskForm({ ...taskForm, recurrenceWeeks: parseInt(e.target.value) })}
                      className="va-select va-select-inline"
                    >
                      <option value={1}>1 hafta</option>
                      <option value={2}>2 hafta</option>
                      <option value={4}>1 ay</option>
                      <option value={8}>2 ay</option>
                    </select>
                  </div>
                </div>
              )}
            </div>
          </div>

          <div className="va-form-footer">
            <button className="va-btn-ghost" onClick={() => setShowNewTaskForm(false)}>İptal</button>
            <button
              className="va-btn-primary"
              onClick={handleCreateTask}
              disabled={creatingTask || taskForm.section_ids.length === 0}
            >
              <Send size={16} />
              {creatingTask ? "Gönderiliyor..." : "Görevi Gönder"}
            </button>
          </div>
        </div>
      )}

      {/* Date Navigation */}
      <div className="va-date-nav">
        <button className="va-date-nav-btn" onClick={goToPreviousDay}>
          <ChevronLeft size={20} />
        </button>
        
        <div className="va-date-display">
          <span className="va-date-label">{formatDisplayDate(filterDate)}</span>
          <span className="va-date-full">{new Date(filterDate).toLocaleDateString("tr-TR", { day: "numeric", month: "long", year: "numeric" })}</span>
        </div>
        
        <button className="va-date-nav-btn" onClick={goToNextDay}>
          <ChevronRight size={20} />
        </button>
        
        <div className="va-date-actions">
          {!isToday && (
            <button className="va-btn-small" onClick={goToToday}>
              Bugün
            </button>
          )}
          <div className="va-date-picker-wrapper">
            <button 
              className="va-btn-small va-btn-icon" 
              onClick={() => setShowDatePicker(!showDatePicker)}
              title="Takvimden seç"
            >
              <Calendar size={16} />
            </button>
            {showDatePicker && (
              <div className="va-date-picker-dropdown">
                <input
                  type="date"
                  value={filterDate}
                  onChange={e => {
                    setFilterDate(e.target.value);
                    setShowDatePicker(false);
                  }}
                  className="va-input"
                />
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="va-filters">
        {/* Branch Filter */}
        <div className="va-filter-group">
          <label>Şube</label>
          <select
            value={filterBranch}
            onChange={e => setFilterBranch(e.target.value)}
            className="va-select"
          >
            <option value="all">Tüm Şubeler</option>
            {branches.map(b => (
              <option key={b.id} value={b.id}>{b.name}</option>
            ))}
          </select>
        </div>
        
        {/* Section Filter */}
        <div className="va-filter-group">
          <label>Bölüm</label>
          <select
            value={filterSection}
            onChange={e => setFilterSection(e.target.value)}
            className="va-select"
          >
            <option value="all">Tüm Bölümler</option>
            {sections.map(s => (
              <option key={s.id} value={s.id}>{s.name}</option>
            ))}
          </select>
        </div>
        
        {/* Hour Filter */}
        <div className="va-filter-group">
          <label>Saat</label>
          <select
            value={filterHour}
            onChange={e => setFilterHour(e.target.value)}
            className="va-select"
          >
            <option value="all">Tüm Saatler</option>
            {uniqueHours.map(h => (
              <option key={h} value={h}>{h.toString().padStart(2, "0")}:00</option>
            ))}
          </select>
        </div>
      </div>

      {/* Status Tabs */}
      <div className="va-filter-tabs">
        <button className={`va-tab ${filterStatus === "all" ? "active" : ""}`} onClick={() => setFilterStatus("all")}>
          Tümü ({stats.total_tasks})
        </button>
        <button className={`va-tab ${filterStatus === "pending" ? "active" : ""}`} onClick={() => setFilterStatus("pending")}>
          Bekleyen ({stats.pending_tasks})
        </button>
        <button className={`va-tab ${filterStatus === "completed" ? "active" : ""}`} onClick={() => setFilterStatus("completed")}>
          Tamamlanan ({stats.completed_tasks})
        </button>
        <button className={`va-tab ${filterStatus === "overdue" ? "active" : ""}`} onClick={() => setFilterStatus("overdue")}>
          Geciken ({stats.overdue_tasks})
        </button>
      </div>

      {/* Result Count */}
      <div className="va-result-count">
        <span>{filteredTasks.length} görev gösteriliyor</span>
        {(filterBranch !== "all" || filterSection !== "all" || filterHour !== "all") && (
          <button 
            className="va-btn-link" 
            onClick={() => {
              setFilterBranch("all");
              setFilterSection("all");
              setFilterHour("all");
            }}
          >
            Filtreleri Temizle
          </button>
        )}
      </div>

      {/* Multi-select toolbar */}
      {multiSelectMode && (
        <div className="va-multiselect-toolbar">
          <div className="va-multiselect-info">
            <Check size={18} />
            <span>{selectedTaskIds.size} görev seçildi</span>
          </div>
          <div className="va-multiselect-actions">
            <button className="va-btn-small" onClick={selectAllTasks}>
              Tümünü Seç ({filteredTasks.length})
            </button>
            <button 
              className="va-btn-small va-btn-danger" 
              onClick={handleDeleteSelected}
              disabled={deletingTasks || selectedTaskIds.size === 0}
            >
              <Trash2 size={16} />
              {deletingTasks ? "Siliniyor..." : `Sil (${selectedTaskIds.size})`}
            </button>
            <button className="va-btn-small" onClick={cancelMultiSelect}>
              <X size={16} />
              İptal
            </button>
          </div>
        </div>
      )}

      {/* Task List */}
      {loading ? (
        <div className="va-loading">
          <Loader2 size={32} className="va-spinner" />
          <span>Yükleniyor...</span>
        </div>
      ) : filteredTasks.length === 0 ? (
        <div className="va-empty">
          <Camera size={48} />
          <span>Seçilen kriterlere uygun görev bulunmuyor</span>
        </div>
      ) : (
        <div className="va-task-grid">
          {filteredTasks.map(task => (
            <div
              key={task.id}
              className={`va-task-card ${task.status} ${isOverdue(task) ? "overdue" : ""} ${multiSelectMode ? "selectable" : ""} ${selectedTaskIds.has(task.id) ? "selected" : ""}`}
              onClick={() => handleTaskClick(task)}
              onMouseDown={() => handleLongPressStart(task.id)}
              onMouseUp={handleLongPressEnd}
              onMouseLeave={handleLongPressEnd}
              onTouchStart={() => handleLongPressStart(task.id)}
              onTouchEnd={handleLongPressEnd}
            >
              {/* Selection checkbox */}
              {multiSelectMode && (
                <div className={`va-task-checkbox ${selectedTaskIds.has(task.id) ? "checked" : ""}`}>
                  {selectedTaskIds.has(task.id) && <Check size={14} />}
                </div>
              )}
              <div className="va-task-header">
                <span className="va-task-section" style={{ background: task.section_color }}>
                  {task.section_name}
                </span>
                <span className={`va-task-status ${task.status} ${isOverdue(task) ? "overdue" : ""}`}>
                  {task.status === "completed" ? "Tamamlandı" : isOverdue(task) ? "Gecikti" : "Bekliyor"}
                </span>
              </div>
              <div className="va-task-body">
                <h4>{task.branch_name}</h4>
                {task.notes && <p className="va-task-note">{task.notes}</p>}
              </div>
              <div className="va-task-footer">
                <span className="va-task-photos">
                  <Camera size={14} />
                  {task.photo_count} / {task.min_photos}
                </span>
                <span className="va-task-deadline">
                  <Clock size={14} />
                  {task.scheduled_time?.slice(0, 5) || "--:--"} / {formatTime(task.deadline_at)}
                </span>
              </div>
              {task.created_by_name && (
                <div className="va-task-creator">
                  <span>Oluşturan: {task.created_by_name}</span>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Task Detail Modal */}
      {selectedTask && (
        <div className="va-modal-overlay" onClick={() => setSelectedTask(null)}>
          <div className="va-modal" onClick={e => e.stopPropagation()}>
            <div className="va-modal-header">
              <div>
                <h3>{selectedTask.branch_name}</h3>
                <span className="va-modal-section" style={{ background: selectedTask.section_color }}>
                  {selectedTask.section_name}
                </span>
              </div>
              <button className="va-close-btn" onClick={() => setSelectedTask(null)}>
                <X size={20} />
              </button>
            </div>

            <div className="va-modal-body">
              {/* Task Info */}
              <div className="va-modal-info">
                <div className="va-info-row">
                  <span>Durum:</span>
                  <span className={`va-status-badge ${selectedTask.status} ${isOverdue(selectedTask) ? "overdue" : ""}`}>
                    {selectedTask.status === "completed" ? "Tamamlandı" : isOverdue(selectedTask) ? "Gecikti" : "Bekliyor"}
                  </span>
                </div>
                <div className="va-info-row">
                  <span>Görev Saati:</span>
                  <span>{selectedTask.scheduled_time?.slice(0, 5) || "--:--"}</span>
                </div>
                <div className="va-info-row">
                  <span>Son Teslim:</span>
                  <span>{formatTime(selectedTask.deadline_at)}</span>
                </div>
                <div className="va-info-row">
                  <span>Fotoğraf:</span>
                  <span>{selectedTask.photo_count} / {selectedTask.min_photos}</span>
                </div>
                {selectedTask.created_by_name && (
                  <div className="va-info-row">
                    <span>Oluşturan:</span>
                    <span>{selectedTask.created_by_name}</span>
                  </div>
                )}
                {selectedTask.notes && (
                  <div className="va-info-row">
                    <span>Not:</span>
                    <span>{selectedTask.notes}</span>
                  </div>
                )}
              </div>

              {/* Photos */}
              <div className="va-modal-section">
                <h4>Fotoğraflar</h4>
                {taskPhotos.length === 0 ? (
                  <p className="va-empty-text">Henüz fotoğraf yüklenmedi</p>
                ) : (
                  <div className="va-photo-grid">
                    {taskPhotos.map(photo => (
                      <div key={photo.id} className="va-photo-item">
                        <img src={photo.photo_url} alt="Fotoğraf" />
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Comments */}
              <div className="va-modal-section">
                <h4>Yorumlar</h4>
                <div className="va-comments-list">
                  {taskComments.length === 0 ? (
                    <p className="va-empty-text">Henüz yorum yok</p>
                  ) : (
                    taskComments.map(comment => (
                      <div key={comment.id} className="va-comment">
                        <span className="va-comment-author">{comment.users?.full_name || "Kullanıcı"}</span>
                        <p>{comment.comment}</p>
                        <span className="va-comment-time">
                          {new Date(comment.created_at).toLocaleString("tr-TR")}
                        </span>
                      </div>
                    ))
                  )}
                </div>
                <div className="va-comment-input">
                  <input
                    type="text"
                    value={newComment}
                    onChange={e => setNewComment(e.target.value)}
                    placeholder="Yorum yazın..."
                    onKeyDown={e => e.key === "Enter" && handleSendComment()}
                  />
                  <button onClick={handleSendComment} disabled={sendingComment || !newComment.trim()}>
                    <Send size={18} />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
