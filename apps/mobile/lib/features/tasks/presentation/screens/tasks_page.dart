import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/task_models.dart';
import '../../domain/providers/tasks_providers.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import 'task_detail_page.dart';
import 'create_task_page.dart';

/// Görevler Ana Sayfası - Tüm roller için modern tasarım
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    final authState = ref.watch(authProvider);

    final userRole = authState.maybeWhen(
      authenticated: (user) => user.role,
      orElse: () => null,
    );

    final hasBranch = authState.maybeWhen(
      authenticated: (user) =>
          user.branchId != null && user.branchId!.isNotEmpty,
      orElse: () => false,
    );

    // Rol bazlı görev oluşturma yetkisi
    final canCreate = userRole == 'sube_muduru' ||
        userRole == 'bolge_muduru' ||
        userRole == 'firma_admin';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Modern Header
          SliverToBoxAdapter(
            child: _TasksHeader(
              canCreate: canCreate && hasBranch,
              userRole: userRole,
            ),
          ),
          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabController: _tabController,
              theme: theme,
            ),
          ),
        ],
        body: hasBranch
            ? TabBarView(
                controller: _tabController,
                children: [
                  _TasksListView(
                    provider: activeTasksProvider,
                    emptyIcon: Icons.task_alt,
                    emptyTitle: 'Aktif görev yok',
                    emptySubtitle: 'Tüm görevler tamamlanmış! 🎉',
                  ),
                  _TasksListView(
                    provider: completedTasksProvider,
                    emptyIcon: Icons.check_circle_outline,
                    emptyTitle: 'Tamamlanan görev yok',
                    emptySubtitle: 'Tamamlanan görevler burada görünecek',
                  ),
                  _TasksListView(
                    provider: archivedTasksProvider,
                    emptyIcon: Icons.inventory_2_outlined,
                    emptyTitle: 'Arşiv boş',
                    emptySubtitle: 'Arşivlenen görevler burada görünecek',
                  ),
                ],
              )
            : const _NoBranchView(),
      ),
    );
  }
}

/// Modern Header
class _TasksHeader extends ConsumerWidget {
  const _TasksHeader({
    required this.canCreate,
    this.userRole,
  });

  final bool canCreate;
  final String? userRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Görevler',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getRoleDescription(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (canCreate)
                FilledButton.icon(
                  onPressed: () => _openCreateTask(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.colorScheme.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Yeni Görev',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick Stats
          const _QuickStats(),
        ],
      ),
    );
  }

  String _getRoleDescription() {
    switch (userRole) {
      case 'bolge_muduru':
        return 'Bölge görevlerini yönetin';
      case 'sube_muduru':
        return 'Şube görevlerini yönetin';
      case 'personel':
        return 'Size atanan görevleri görüntüleyin';
      default:
        return 'Görevlerinizi takip edin';
    }
  }

  void _openCreateTask(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateTaskPage(),
        fullscreenDialog: true,
      ),
    );
  }
}

/// Hızlı İstatistikler
class _QuickStats extends ConsumerWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeTasksProvider);
    final completedAsync = ref.watch(completedTasksProvider);

    final activeCount = activeAsync.maybeWhen(
      data: (tasks) => tasks.length,
      orElse: () => 0,
    );

    final completedCount = completedAsync.maybeWhen(
      data: (tasks) => tasks.length,
      orElse: () => 0,
    );

    return Row(
      children: [
        _StatChip(
          icon: Icons.pending_actions,
          label: 'Aktif',
          value: '$activeCount',
        ),
        const SizedBox(width: 12),
        _StatChip(
          icon: Icons.check_circle,
          label: 'Tamamlanan',
          value: '$completedCount',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            '$value $label',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab Bar Delegate
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({
    required this.tabController,
    required this.theme,
  });

  final TabController tabController;
  final ThemeData theme;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: tabController,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.5),
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: '🔥 Aktif'),
          Tab(text: '✅ Tamamlanan'),
          Tab(text: '📦 Arşiv'),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

/// Görev Listesi View
class _TasksListView extends ConsumerWidget {
  const _TasksListView({
    required this.provider,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final AutoDisposeFutureProvider<List<TaskNode>> provider;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(provider);

    return tasksAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => _ErrorView(
        message: 'Görevler yüklenemedi',
        onRetry: () => ref.invalidate(provider),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return _EmptyView(
            icon: emptyIcon,
            title: emptyTitle,
            subtitle: emptySubtitle,
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(provider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) => TaskCard(node: tasks[index]),
          ),
        );
      },
    );
  }
}

/// Modern Görev Kartı
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.node,
    this.depth = 0,
  });

  final TaskNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = node.task;
    final progress = node.progress;
    final progressPercent = (progress * 100).round();

    // Kart stil ayarları
    final style = _getCardStyle(task, progress);

    return Container(
      margin: EdgeInsets.only(bottom: 16, left: depth * 16.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(context),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [style.bgStart, style.bgEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: style.accent.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Badge + Actions
                  Row(
                    children: [
                      _QuestBadge(isMainQuest: task.parentTaskId == null),
                      if (task.isForwarded) ...[
                        const SizedBox(width: 8),
                        const _ForwardedBadge(),
                      ],
                      const Spacer(),
                      _ProgressCircle(
                        progress: progress,
                        color: style.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Row(
                    children: [
                      Text(
                        _getEmoji(task),
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: style.text,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Description
                  if (task.description != null &&
                      task.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      task.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: style.text.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Tags Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Tag(
                        label: task.priority.label,
                        emoji: task.priority.emoji,
                        color: _getPriorityColor(task.priority),
                      ),
                      _Tag(
                        label: task.status.label,
                        emoji: task.status.emoji,
                        color: style.accent,
                      ),
                      if (task.dueDate != null)
                        _Tag(
                          label: _formatDueDate(task.dueDate!),
                          emoji: task.isOverdue ? '⚠️' : '📅',
                          color: task.isOverdue ? Colors.red : Colors.grey,
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Progress Bar
                  _ProgressBar(
                    progress: progress,
                    color: style.accent,
                    label: '%$progressPercent tamamlandı',
                  ),

                  // Subtasks info
                  if (node.children.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SubtaskInfo(
                      completed: node.completedDescendants,
                      total: node.totalDescendants,
                      color: style.text,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Footer
                  _CardFooter(task: task, textColor: style.text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(node: node),
      ),
    );
  }

  _CardStyle _getCardStyle(Task task, double progress) {
    if (task.isArchived) {
      return _CardStyle(
        bgStart: const Color(0xFFF5F5F5),
        bgEnd: const Color(0xFFEEEEEE),
        accent: Colors.grey,
        text: Colors.grey.shade700,
      );
    }

    if (task.status == TaskStatus.approved) {
      return const _CardStyle(
        bgStart: Color(0xFFE8F5E9),
        bgEnd: Color(0xFFC8E6C9),
        accent: Color(0xFF43A047),
        text: Color(0xFF1B5E20),
      );
    }

    if (task.status == TaskStatus.completed) {
      return const _CardStyle(
        bgStart: Color(0xFFE3F2FD),
        bgEnd: Color(0xFFBBDEFB),
        accent: Color(0xFF1E88E5),
        text: Color(0xFF0D47A1),
      );
    }

    if (task.isOverdue) {
      return const _CardStyle(
        bgStart: Color(0xFFFFEBEE),
        bgEnd: Color(0xFFFFCDD2),
        accent: Color(0xFFE53935),
        text: Color(0xFFB71C1C),
      );
    }

    if (progress > 0.5) {
      return const _CardStyle(
        bgStart: Color(0xFFFFF3E0),
        bgEnd: Color(0xFFFFE0B2),
        accent: Color(0xFFFF9800),
        text: Color(0xFFE65100),
      );
    }

    if (progress > 0) {
      return const _CardStyle(
        bgStart: Color(0xFFFCE4EC),
        bgEnd: Color(0xFFF8BBD0),
        accent: Color(0xFFE91E63),
        text: Color(0xFF880E4F),
      );
    }

    return const _CardStyle(
      bgStart: Color(0xFFF3E5F5),
      bgEnd: Color(0xFFE1BEE7),
      accent: Color(0xFF9C27B0),
      text: Color(0xFF4A148C),
    );
  }

  String _getEmoji(Task task) {
    if (task.status == TaskStatus.approved) return '🏆';
    if (task.status == TaskStatus.completed) return '✅';
    if (task.isOverdue) return '⚠️';
    if (task.priority == TaskPriority.high) return '🔥';
    return '🎯';
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;

    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    if (diff == -1) return 'Dün';
    if (diff < -1) return '${-diff} gün önce';
    if (diff < 7) return '$diff gün kaldı';

    return DateFormat('dd MMM', 'tr').format(date);
  }
}

class _CardStyle {
  const _CardStyle({
    required this.bgStart,
    required this.bgEnd,
    required this.accent,
    required this.text,
  });

  final Color bgStart;
  final Color bgEnd;
  final Color accent;
  final Color text;
}

/// Quest Badge
class _QuestBadge extends StatelessWidget {
  const _QuestBadge({required this.isMainQuest});
  final bool isMainQuest;

  @override
  Widget build(BuildContext context) {
    final color =
        isMainQuest ? const Color(0xFF6366F1) : const Color(0xFF8B5CF6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMainQuest ? '⭐' : '📌',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(width: 4),
          Text(
            isMainQuest ? 'Ana Görev' : 'Yan Görev',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Forwarded Badge
class _ForwardedBadge extends StatelessWidget {
  const _ForwardedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forward, size: 12, color: Colors.purple),
          SizedBox(width: 4),
          Text(
            'İletildi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress Circle
class _ProgressCircle extends StatelessWidget {
  const _ProgressCircle({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 4,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(color.withOpacity(0.2)),
          ),
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(color),
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text(
              '${(progress * 100).round()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tag Widget
class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.emoji,
    required this.color,
  });

  final String label;
  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
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

/// Progress Bar
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.color,
    required this.label,
  });

  final double progress;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'İlerleme',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color.withOpacity(0.8),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

/// Subtask Info
class _SubtaskInfo extends StatelessWidget {
  const _SubtaskInfo({
    required this.completed,
    required this.total,
    required this.color,
  });

  final int completed;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist_rounded,
              size: 16, color: color.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(
            '$completed / $total alt görev tamamlandı',
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card Footer
class _CardFooter extends StatelessWidget {
  const _CardFooter({
    required this.task,
    required this.textColor,
  });

  final Task task;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.person_outline, size: 14, color: textColor.withOpacity(0.6)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            task.creatorName ?? 'Bilinmiyor',
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.7),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (task.branchName != null) ...[
          Icon(Icons.store_outlined,
              size: 14, color: textColor.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(
            task.branchName!,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }
}

/// Empty View
class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error View
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

/// No Branch View
class _NoBranchView extends StatelessWidget {
  const _NoBranchView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.store_mall_directory_outlined,
                size: 48,
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Şube Ataması Gerekli',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu modülü kullanabilmek için bir şubeye atanmanız gerekir.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
