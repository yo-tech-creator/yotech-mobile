import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/shared.dart';
import '../../../auth/domain/models/auth_state.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../region_manager/domain/models/branch_task_node.dart';
import '../../domain/providers/branch_tasks_providers.dart';
import 'create_task_page.dart';

/// Modern Şube Görevleri Sayfası
/// Tüm roller için: bölge müdürü, şube müdürü, personel
class BranchTasksPage extends ConsumerStatefulWidget {
  const BranchTasksPage({super.key});

  @override
  ConsumerState<BranchTasksPage> createState() => _BranchTasksPageState();
}

class _BranchTasksPageState extends ConsumerState<BranchTasksPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _expandedTaskIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(branchTaskTreeProvider);
    final authState = ref.watch(authProvider);

    final currentUser = authState.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );

    final userBranchId = authState.maybeWhen<String?>(
      authenticated: (user) => user.branchId,
      orElse: () => null,
    );

    final canCreate = authState.maybeWhen<bool>(
      authenticated: (user) =>
          user.role == 'sube_muduru' || user.role == 'bolge_muduru',
      orElse: () => false,
    );

    final hasBranch = authState.maybeWhen<bool>(
      authenticated: (user) =>
          user.branchId != null && user.branchId!.isNotEmpty,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // Modern Header with Add Button
          _TasksHeader(
            tabController: _tabController,
            showAddButton: canCreate && userBranchId != null,
            onAddPressed: () => _openCreateTask(userBranchId!, authState),
          ),

          // Content
          Expanded(
            child: tasksAsync.when(
              loading: () => const _LoadingState(),
              error: (error, _) => AppErrorState(
                message: 'Görevler yüklenemedi',
                onRetry: () => ref.invalidate(branchTaskTreeProvider),
              ),
              data: (tasks) {
                if (!hasBranch) {
                  return const AppEmptyState(
                    icon: Icons.store_mall_directory_outlined,
                    title: 'Şube ataması gerekli',
                    subtitle:
                        'Bu modülü kullanabilmek için bir şubeye atanmanız gerekir.',
                  );
                }

                if (tasks.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'Henüz görev yok',
                    subtitle:
                        'Şubeniz için görev tanımlandığında burada görünecek.',
                  );
                }

                // Görevleri filtrele
                final activeTasks = tasks
                    .where((t) => t.record.status != BranchTaskStatus.completed)
                    .toList();
                final completedTasks = tasks
                    .where((t) => t.record.status == BranchTaskStatus.completed)
                    .toList();
                final myTasks = tasks
                    .where((t) => t.record.managerId == currentUser?.id)
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _TasksList(
                      tasks: activeTasks,
                      expandedIds: _expandedTaskIds,
                      onToggleExpand: _toggleExpand,
                      onRefresh: () =>
                          ref.refresh(branchTaskTreeProvider.future),
                      currentUserId: currentUser?.id,
                      emptyMessage: 'Aktif görev bulunmuyor',
                    ),
                    _TasksList(
                      tasks: completedTasks,
                      expandedIds: _expandedTaskIds,
                      onToggleExpand: _toggleExpand,
                      onRefresh: () =>
                          ref.refresh(branchTaskTreeProvider.future),
                      currentUserId: currentUser?.id,
                      emptyMessage: 'Tamamlanan görev yok',
                    ),
                    _TasksList(
                      tasks: myTasks,
                      expandedIds: _expandedTaskIds,
                      onToggleExpand: _toggleExpand,
                      onRefresh: () =>
                          ref.refresh(branchTaskTreeProvider.future),
                      currentUserId: currentUser?.id,
                      emptyMessage: 'Oluşturduğunuz görev yok',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleExpand(String taskId) {
    setState(() {
      if (_expandedTaskIds.contains(taskId)) {
        _expandedTaskIds.remove(taskId);
      } else {
        _expandedTaskIds.add(taskId);
      }
    });
  }

  Future<void> _openCreateTask(String branchId, AuthState authState) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateTaskPage()),
    );
    if (result == true) {
      ref.invalidate(branchTaskTreeProvider);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════════════════════

class _TasksHeader extends StatelessWidget {
  const _TasksHeader({
    required this.tabController,
    this.showAddButton = false,
    this.onAddPressed,
  });

  final TabController tabController;
  final bool showAddButton;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header Row with Add Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Şube görev yönetimi',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  if (showAddButton)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onAddPressed,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Görev Ekle',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.8),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Aktif'),
                  Tab(text: 'Tamamlanan'),
                  Tab(text: 'Benim'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TASKS LIST
// ══════════════════════════════════════════════════════════════════════════════

class _TasksList extends StatelessWidget {
  const _TasksList({
    required this.tasks,
    required this.expandedIds,
    required this.onToggleExpand,
    required this.onRefresh,
    required this.currentUserId,
    required this.emptyMessage,
  });

  final List<BranchTaskNode> tasks;
  final Set<String> expandedIds;
  final void Function(String) onToggleExpand;
  final Future<void> Function() onRefresh;
  final String? currentUserId;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return AppEmptyState(
        icon: Icons.inbox_outlined,
        title: emptyMessage,
        subtitle: 'Bu kategoride görev bulunmuyor.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final node = tasks[index];
          return _ModernTaskCard(
            node: node,
            isExpanded: expandedIds.contains(node.record.id),
            onToggleExpand: () => onToggleExpand(node.record.id),
            expandedIds: expandedIds,
            onToggleExpandChild: onToggleExpand,
            currentUserId: currentUserId,
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODERN TASK CARD
// ══════════════════════════════════════════════════════════════════════════════

class _ModernTaskCard extends ConsumerWidget {
  const _ModernTaskCard({
    required this.node,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.expandedIds,
    required this.onToggleExpandChild,
    required this.currentUserId,
    this.depth = 0,
  });

  final BranchTaskNode node;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final Set<String> expandedIds;
  final void Function(String) onToggleExpandChild;
  final String? currentUserId;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final record = node.record;
    final hasChildren = node.children.isNotEmpty;
    final isCompleted = record.status == BranchTaskStatus.completed;
    final progress = _calculateProgress(node);

    // Öncelik rengi - sadece yazı ve çerçeve için
    final priorityColor = _getPriorityColor(record.priority, theme);
    final borderColor = _getBorderColor(record.priority, theme);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(
        left: depth > 0 ? 16.0 : 0,
        bottom: depth == 0 ? 12 : 8,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTaskDetails(context, ref),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: depth == 0
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
              border: Border.all(
                color: depth == 0
                    ? borderColor
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: depth == 0 ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Expand Button or Status Icon
                          // depth < 2: 3. seviye (depth=2) görevlerde genişletme oku gösterilmez
                          if (hasChildren && depth < 2)
                            GestureDetector(
                              onTap: onToggleExpand,
                              child: AnimatedRotation(
                                turns: isExpanded ? 0.25 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color:
                                        priorityColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: priorityColor,
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: depth == 0
                                    ? priorityColor.withValues(alpha: 0.15)
                                    : _getStatusColor(record.status)
                                        .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getStatusIcon(record.status),
                                size: 20,
                                color: depth == 0
                                    ? priorityColor
                                    : _getStatusColor(record.status),
                              ),
                            ),

                          const SizedBox(width: 12),

                          // Title & Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: depth == 0 ? priorityColor : null,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // Status Badge
                                _StatusBadge(
                                  status: record.status,
                                  foregroundColor:
                                      depth == 0 ? priorityColor : null,
                                ),
                              ],
                            ),
                          ),

                          // Progress Circle (only for root tasks)
                          if (depth == 0) ...[
                            const SizedBox(width: 12),
                            _ProgressCircle(
                              progress: progress,
                              size: 48,
                              foregroundColor: priorityColor,
                            ),
                          ],
                        ],
                      ),

                      // Description
                      if (record.description != null &&
                          record.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          record.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Meta Info
                      const SizedBox(height: 12),
                      _MetaRow(
                        record: record,
                        foregroundColor: depth == 0 ? priorityColor : null,
                        childCount: node.children.length,
                      ),
                    ],
                  ),
                ),

                // Children (Expanded) - Maksimum 2 seviye (A-B-C), D seviyesi gösterilmez
                if (hasChildren && isExpanded && depth < 2) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: node.children.map((child) {
                        return _ModernTaskCard(
                          node: child,
                          isExpanded: expandedIds.contains(child.record.id),
                          onToggleExpand: () =>
                              onToggleExpandChild(child.record.id),
                          expandedIds: expandedIds,
                          onToggleExpandChild: onToggleExpandChild,
                          currentUserId: currentUserId,
                          depth: depth + 1,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTaskDetails(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final record = node.record;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      record.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Status & Priority
                    Row(
                      children: [
                        _StatusBadge(
                            status: record.status,
                            foregroundColor: theme.colorScheme.onSurface),
                        const SizedBox(width: 12),
                        if (record.priority != null)
                          _PriorityBadge(priority: record.priority!),
                      ],
                    ),

                    // Description
                    if (record.description != null &&
                        record.description!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Açıklama',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        record.description!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],

                    // Info Cards
                    const SizedBox(height: 20),
                    _InfoCard(
                      icon: Icons.calendar_today_rounded,
                      label: 'Oluşturulma',
                      value: DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR')
                          .format(record.createdAt),
                    ),
                    if (record.dueDate != null)
                      _InfoCard(
                        icon: Icons.event_rounded,
                        label: 'Bitiş Tarihi',
                        value: DateFormat('dd MMMM yyyy', 'tr_TR')
                            .format(record.dueDate!),
                      ),
                    if (record.managerName != null)
                      _InfoCard(
                        icon: Icons.person_rounded,
                        label: 'Oluşturan',
                        value: record.managerName!,
                      ),

                    // Alt Görevler
                    if (node.children.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Alt Görevler (${node.children.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...node.children.map((child) => _SubtaskTile(
                            record: child.record,
                          )),
                    ],

                    const SizedBox(height: 24),

                    // Actions
                    if (record.status != BranchTaskStatus.completed)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _completeTask(context, ref);
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Görevi Tamamla'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeTask(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(branchTasksRepositoryProvider);
      await repository.updateTaskStatus(
        taskId: node.record.id,
        status: BranchTaskStatus.completed,
      );
      ref.invalidate(branchTaskTreeProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Görev tamamlandı! 🎉'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Önceliğe göre renk döndürür - sadece yazı ve çerçeve için kullanılır
  Color _getPriorityColor(String? priority, ThemeData theme) {
    switch (priority?.toLowerCase()) {
      case 'yuksek':
      case 'high':
        return theme.colorScheme.error;
      case 'orta':
      case 'medium':
        return theme.colorScheme.tertiary;
      case 'dusuk':
      case 'low':
        return theme.colorScheme.secondary;
      default:
        return theme.colorScheme.primary;
    }
  }

  /// Çerçeve rengi - önceliğe göre hafif renk
  Color _getBorderColor(String? priority, ThemeData theme) {
    return _getPriorityColor(priority, theme).withValues(alpha: 0.4);
  }

  double _calculateProgress(BranchTaskNode node) {
    if (node.children.isEmpty) {
      return node.record.status == BranchTaskStatus.completed ? 1.0 : 0.0;
    }

    int completed = 0;
    int total = 0;

    void countTasks(BranchTaskNode n) {
      if (n.children.isEmpty) {
        total++;
        if (n.record.status == BranchTaskStatus.completed) {
          completed++;
        }
      } else {
        for (final child in n.children) {
          countTasks(child);
        }
      }
    }

    for (final child in node.children) {
      countTasks(child);
    }

    return total > 0 ? completed / total : 0.0;
  }

  Color _getStatusColor(BranchTaskStatus status) {
    switch (status) {
      case BranchTaskStatus.completed:
        return Colors.green;
      case BranchTaskStatus.inProgress:
        return Colors.blue;
      case BranchTaskStatus.pending:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(BranchTaskStatus status) {
    switch (status) {
      case BranchTaskStatus.completed:
        return Icons.check_circle_rounded;
      case BranchTaskStatus.inProgress:
        return Icons.play_circle_rounded;
      case BranchTaskStatus.pending:
        return Icons.schedule_rounded;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATUS BADGE
// ══════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    this.foregroundColor,
  });

  final BranchTaskStatus status;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BranchTaskStatus.completed => ('Tamamlandı', Colors.green),
      BranchTaskStatus.inProgress => ('Devam Ediyor', Colors.blue),
      BranchTaskStatus.pending => ('Beklemede', Colors.orange),
    };

    final useCustomColor = foregroundColor != null;
    final displayColor = useCustomColor ? foregroundColor! : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: displayColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: displayColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: displayColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRIORITY BADGE
// ══════════════════════════════════════════════════════════════════════════════

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority.toLowerCase()) {
      'yuksek' || 'high' => ('Yüksek', Colors.red),
      'orta' || 'medium' => ('Orta', Colors.orange),
      'dusuk' || 'low' => ('Düşük', Colors.green),
      _ => (priority, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROGRESS CIRCLE
// ══════════════════════════════════════════════════════════════════════════════

class _ProgressCircle extends StatelessWidget {
  const _ProgressCircle({
    required this.progress,
    this.size = 48,
    this.foregroundColor,
  });

  final double progress;
  final double size;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).round();
    final color = foregroundColor ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Circle
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(
              color.withValues(alpha: 0.2),
            ),
          ),
          // Progress Circle
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          // Percentage Text
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// META ROW
// ══════════════════════════════════════════════════════════════════════════════

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.record,
    this.foregroundColor,
    required this.childCount,
  });

  final BranchTaskRecord record;
  final Color? foregroundColor;
  final int childCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = foregroundColor?.withValues(alpha: 0.8) ??
        theme.colorScheme.onSurfaceVariant;
    final iconColor = foregroundColor?.withValues(alpha: 0.65) ??
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        // Priority
        if (record.priority != null)
          _MetaChip(
            icon: Icons.flag_rounded,
            label: _priorityLabel(record.priority!),
            iconColor: iconColor,
            textColor: textColor,
          ),

        // Due Date
        if (record.dueDate != null)
          _MetaChip(
            icon: Icons.calendar_today_rounded,
            label: DateFormat('dd MMM', 'tr_TR').format(record.dueDate!),
            iconColor: iconColor,
            textColor: textColor,
          ),

        // Child Count
        if (childCount > 0)
          _MetaChip(
            icon: Icons.account_tree_rounded,
            label: '$childCount alt görev',
            iconColor: iconColor,
            textColor: textColor,
          ),

        // Manager
        if (record.managerName != null)
          _MetaChip(
            icon: Icons.person_outline_rounded,
            label: record.managerName!,
            iconColor: iconColor,
            textColor: textColor,
          ),
      ],
    );
  }

  String _priorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'yuksek':
      case 'high':
        return 'Yüksek';
      case 'orta':
      case 'medium':
        return 'Orta';
      case 'dusuk':
      case 'low':
        return 'Düşük';
      default:
        return priority;
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// INFO CARD
// ══════════════════════════════════════════════════════════════════════════════

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUBTASK TILE
// ══════════════════════════════════════════════════════════════════════════════

class _SubtaskTile extends StatelessWidget {
  const _SubtaskTile({required this.record});

  final BranchTaskRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = record.status == BranchTaskStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color:
                isCompleted ? Colors.green : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              record.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATE WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 16),
          Text(
            'Görevler yükleniyor...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
