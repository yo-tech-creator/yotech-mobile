import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/task_models.dart';
import '../../domain/providers/tasks_providers.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import 'forward_task_page.dart';

/// Modern Görev Detay Sayfası
class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({super.key, required this.node});

  final TaskNode node;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final Set<String> _expandedIds = {};
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.node.task;
    final progress = widget.node.progress;
    final progressPercent = (progress * 100).round();

    final authState = ref.watch(authProvider);
    final currentUserId = authState.maybeWhen(
      authenticated: (user) => user.id,
      orElse: () => null,
    );
    final currentUserRole = authState.maybeWhen(
      authenticated: (user) => user.role,
      orElse: () => null,
    );

    final isCreator = currentUserId == task.createdBy;
    final canApprove =
        isCreator && task.status == TaskStatus.completed && task.isMainQuest;
    final canArchive = isCreator && task.status == TaskStatus.approved;
    final canForward = (currentUserRole == 'sube_muduru' ||
            currentUserRole == 'bolge_muduru') &&
        task.status != TaskStatus.approved;

    // Kart stili
    final style = _getCardStyle(task, progress);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: style.bgStart,
            foregroundColor: style.text,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroSection(
                node: widget.node,
                style: style,
                progressPercent: progressPercent,
              ),
            ),
            actions: [
              if (canForward)
                IconButton(
                  onPressed: () => _forwardTask(context),
                  icon: const Icon(Icons.forward_to_inbox),
                  tooltip: 'Görevi İlet',
                ),
              if (canArchive)
                IconButton(
                  onPressed: _archiveTask,
                  icon: const Icon(Icons.archive_outlined),
                  tooltip: 'Arşivle',
                ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') _confirmDelete(context);
                },
                itemBuilder: (context) => [
                  if (isCreator)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Görevi Sil',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Stats
                  _QuickStatsRow(node: widget.node, style: style),

                  const SizedBox(height: 20),

                  // Action Buttons
                  if (canApprove || task.status != TaskStatus.approved)
                    _ActionSection(
                      task: task,
                      isCreator: isCreator,
                      canApprove: canApprove,
                      isUpdating: _isUpdating,
                      onApprove: _approveTask,
                      onProgressChanged: _updateProgress,
                    ),

                  // Description
                  if (task.description != null &&
                      task.description!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _DescriptionCard(description: task.description!),
                  ],

                  // Meta Info
                  const SizedBox(height: 20),
                  _MetaInfoCard(task: task),

                  // Subtasks
                  if (widget.node.children.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SubtasksSection(
                      children: widget.node.children,
                      expandedIds: _expandedIds,
                      onToggle: (id) {
                        setState(() {
                          if (_expandedIds.contains(id)) {
                            _expandedIds.remove(id);
                          } else {
                            _expandedIds.add(id);
                          }
                        });
                      },
                      onStatusChange: _updateSubtaskStatus,
                    ),
                  ],

                  // Attachments
                  const SizedBox(height: 24),
                  _AttachmentsSection(
                    taskId: task.id,
                    canAdd: task.status != TaskStatus.approved,
                    onAddPressed: () => _openAddAttachment(context),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: task.status != TaskStatus.approved
          ? FloatingActionButton.extended(
              onPressed: () => _openAddAttachment(context),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Fotoğraf Ekle'),
            )
          : null,
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
        bgStart: Color(0xFF43A047),
        bgEnd: Color(0xFF2E7D32),
        accent: Color(0xFF43A047),
        text: Colors.white,
      );
    }

    if (task.status == TaskStatus.completed) {
      return const _CardStyle(
        bgStart: Color(0xFF1E88E5),
        bgEnd: Color(0xFF1565C0),
        accent: Color(0xFF1E88E5),
        text: Colors.white,
      );
    }

    if (task.isOverdue) {
      return const _CardStyle(
        bgStart: Color(0xFFE53935),
        bgEnd: Color(0xFFC62828),
        accent: Color(0xFFE53935),
        text: Colors.white,
      );
    }

    if (progress > 0.5) {
      return const _CardStyle(
        bgStart: Color(0xFFFF9800),
        bgEnd: Color(0xFFF57C00),
        accent: Color(0xFFFF9800),
        text: Colors.white,
      );
    }

    return const _CardStyle(
      bgStart: Color(0xFF6366F1),
      bgEnd: Color(0xFF4F46E5),
      accent: Color(0xFF6366F1),
      text: Colors.white,
    );
  }

  Future<void> _forwardTask(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ForwardTaskPage(node: widget.node),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      ref.invalidate(activeTasksProvider);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _archiveTask() async {
    setState(() => _isUpdating = true);

    try {
      final repository = ref.read(tasksRepositoryProvider);
      await repository.archiveTask(taskId: widget.node.task.id);

      ref.invalidate(activeTasksProvider);
      ref.invalidate(archivedTasksProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.archive, color: Colors.white),
                SizedBox(width: 8),
                Text('Görev arşivlendi'),
              ],
            ),
            backgroundColor: Colors.purple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _approveTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Flexible(child: Text('Görevi Onayla')),
          ],
        ),
        content: const Text(
          'Bu görevi onaylamak istediğinize emin misiniz? '
          'Onaylanan görevler düzenlenemez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdating = true);

    try {
      final repository = ref.read(tasksRepositoryProvider);
      final authState = ref.read(authProvider);
      final currentUserId = authState.maybeWhen(
        authenticated: (user) => user.id,
        orElse: () => null,
      );

      if (currentUserId == null) throw Exception('Kullanıcı bulunamadı');

      await repository.approveTask(
        taskId: widget.node.task.id,
        approverId: currentUserId,
      );

      ref.invalidate(activeTasksProvider);
      ref.invalidate(completedTasksProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Görev onaylandı! 🎉'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateProgress(double value) async {
    setState(() => _isUpdating = true);

    try {
      final repository = ref.read(tasksRepositoryProvider);

      await repository.updateTaskProgress(
        taskId: widget.node.task.id,
        percentage: value.round(),
      );

      ref.invalidate(activeTasksProvider);
      ref.invalidate(completedTasksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateSubtaskStatus(TaskNode node, bool completed) async {
    setState(() => _isUpdating = true);

    try {
      final repository = ref.read(tasksRepositoryProvider);
      final newProgress = completed ? 100 : 0;

      await repository.updateTaskProgress(
        taskId: node.task.id,
        percentage: newProgress,
      );
      ref.invalidate(activeTasksProvider);
      ref.invalidate(completedTasksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Flexible(child: Text('Görevi Sil')),
          ],
        ),
        content: const Text(
          'Bu görevi silmek istediğinize emin misiniz? '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(tasksRepositoryProvider);
      await repository.deleteTaskCascade(node: widget.node);

      ref.invalidate(activeTasksProvider);
      ref.invalidate(completedTasksProvider);
      ref.invalidate(archivedTasksProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Görev silindi'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openAddAttachment(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AttachmentBottomSheet(
        taskId: widget.node.task.id,
        onAttached: () {
          ref.invalidate(taskAttachmentsProvider(widget.node.task.id));
        },
      ),
    );
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

// ============================================================================
// Hero Section
// ============================================================================

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.node,
    required this.style,
    required this.progressPercent,
  });

  final TaskNode node;
  final _CardStyle style;
  final int progressPercent;

  @override
  Widget build(BuildContext context) {
    final task = node.task;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.bgStart, style.bgEnd],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Quest Badge
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          task.parentTaskId == null ? '⭐' : '📌',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          task.parentTaskId == null ? 'Ana Görev' : 'Yan Görev',
                          style: TextStyle(
                            color: style.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Progress Circle
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '%$progressPercent',
                        style: TextStyle(
                          color: style.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Text(
                    _getEmoji(task),
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: style.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: node.progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getEmoji(Task task) {
    if (task.status == TaskStatus.approved) return '🏆';
    if (task.status == TaskStatus.completed) return '✅';
    if (task.isOverdue) return '⚠️';
    if (task.priority == TaskPriority.high) return '🔥';
    return '🎯';
  }
}

// ============================================================================
// Quick Stats Row
// ============================================================================

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.node,
    required this.style,
  });

  final TaskNode node;
  final _CardStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = node.task;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.flag,
            label: 'Öncelik',
            value: task.priority.label,
            emoji: task.priority.emoji,
            color: _getPriorityColor(task.priority),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.sync,
            label: 'Durum',
            value: task.status.label,
            emoji: task.status.emoji,
            color: style.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_today,
            label: 'Son Tarih',
            value: task.dueDate != null
                ? DateFormat('dd MMM', 'tr').format(task.dueDate!)
                : 'Yok',
            emoji: task.isOverdue ? '⚠️' : '📅',
            color: task.isOverdue ? Colors.red : theme.colorScheme.primary,
          ),
        ),
      ],
    );
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
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Action Section
// ============================================================================

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.task,
    required this.isCreator,
    required this.canApprove,
    required this.isUpdating,
    required this.onApprove,
    required this.onProgressChanged,
  });

  final Task task;
  final bool isCreator;
  final bool canApprove;
  final bool isUpdating;
  final VoidCallback onApprove;
  final ValueChanged<double> onProgressChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canApprove) ...[
            FilledButton.icon(
              onPressed: isUpdating ? null : onApprove,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text(
                'Görevi Onayla 🎉',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'İlerleme Durumu',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '%${task.completionPercentage.round()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: task.completionPercentage.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '${task.completionPercentage}%',
                onChanged: isUpdating ? null : onProgressChanged,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0%',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4))),
                Text('50%',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4))),
                Text('100%',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Description Card
// ============================================================================

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description});
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📝', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Açıklama',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Meta Info Card
// ============================================================================

class _MetaInfoCard extends StatelessWidget {
  const _MetaInfoCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy HH:mm', 'tr');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('ℹ️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Detaylar',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.person_outline,
            label: 'Oluşturan',
            value: task.creatorName ?? 'Bilinmiyor',
          ),
          if (task.branchName != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.store_outlined,
              label: 'Şube',
              value: task.branchName!,
            ),
          ],
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.access_time,
            label: 'Oluşturulma',
            value: dateFormat.format(task.createdAt),
          ),
          if (task.approvedAt != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.check_circle_outline,
              label: 'Onaylanma',
              value: dateFormat.format(task.approvedAt!),
            ),
          ],
          if (task.isForwarded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forward, size: 16, color: Colors.purple),
                  SizedBox(width: 8),
                  Text(
                    'Bu görev iletilmiş',
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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

    return Row(
      children: [
        Icon(icon,
            size: 18, color: theme.colorScheme.onSurface.withOpacity(0.5)),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Subtasks Section
// ============================================================================

class _SubtasksSection extends StatelessWidget {
  const _SubtasksSection({
    required this.children,
    required this.expandedIds,
    required this.onToggle,
    required this.onStatusChange,
  });

  final List<TaskNode> children;
  final Set<String> expandedIds;
  final ValueChanged<String> onToggle;
  final void Function(TaskNode, bool) onStatusChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📋', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Alt Görevler',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${children.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children.map((node) => _SubtaskTile(
              node: node,
              depth: 0,
              expandedIds: expandedIds,
              onToggle: onToggle,
              onStatusChange: onStatusChange,
            )),
      ],
    );
  }
}

class _SubtaskTile extends StatelessWidget {
  const _SubtaskTile({
    required this.node,
    required this.depth,
    required this.expandedIds,
    required this.onToggle,
    required this.onStatusChange,
  });

  final TaskNode node;
  final int depth;
  final Set<String> expandedIds;
  final ValueChanged<String> onToggle;
  final void Function(TaskNode, bool) onStatusChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = node.task;
    final isCompleted = task.status == TaskStatus.completed ||
        task.status == TaskStatus.approved;
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = expandedIds.contains(task.id);

    final depthColors = [
      Colors.indigo,
      Colors.purple,
      Colors.pink,
    ];
    final color = depthColors[depth.clamp(0, 2)];

    return Container(
      margin: EdgeInsets.only(left: depth * 16.0, bottom: 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withOpacity(0.08)
                  : color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCompleted
                    ? Colors.green.withOpacity(0.3)
                    : color.withOpacity(0.2),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: hasChildren ? () => onToggle(task.id) : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Checkbox
                      GestureDetector(
                        onTap: () => onStatusChange(node, !isCompleted),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color:
                                isCompleted ? Colors.green : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isCompleted ? Colors.green : color,
                              width: 2,
                            ),
                          ),
                          child: isCompleted
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title
                      Expanded(
                        child: Text(
                          task.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            decoration:
                                isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted
                                ? theme.colorScheme.onSurface.withOpacity(0.5)
                                : null,
                          ),
                        ),
                      ),
                      // Expand icon
                      if (hasChildren)
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: color,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Children
          if (hasChildren && isExpanded)
            ...node.children.map((child) => _SubtaskTile(
                  node: child,
                  depth: depth + 1,
                  expandedIds: expandedIds,
                  onToggle: onToggle,
                  onStatusChange: onStatusChange,
                )),
        ],
      ),
    );
  }
}

// ============================================================================
// Attachments Section
// ============================================================================

class _AttachmentsSection extends ConsumerWidget {
  const _AttachmentsSection({
    required this.taskId,
    required this.canAdd,
    required this.onAddPressed,
  });

  final String taskId;
  final bool canAdd;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final attachmentsAsync = ref.watch(taskAttachmentsProvider(taskId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📎', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Ekler',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        attachmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (attachments) {
            if (attachments.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz ek yok',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      if (canAdd) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: onAddPressed,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Fotoğraf Ekle'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: attachments.length,
              itemBuilder: (context, index) {
                final attachment = attachments[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        attachment.fileUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _viewAttachment(context, attachment),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _viewAttachment(BuildContext context, TaskAttachment attachment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            attachment.fileUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Attachment Bottom Sheet
// ============================================================================

class _AttachmentBottomSheet extends ConsumerStatefulWidget {
  const _AttachmentBottomSheet({
    required this.taskId,
    required this.onAttached,
  });

  final String taskId;
  final VoidCallback onAttached;

  @override
  ConsumerState<_AttachmentBottomSheet> createState() =>
      _AttachmentBottomSheetState();
}

class _AttachmentBottomSheetState
    extends ConsumerState<_AttachmentBottomSheet> {
  // FUTURE: _isUploading aktif edilecek (image upload implement edildiğinde)
  final bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Fotoğraf Ekle',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _OptionCard(
                  icon: Icons.camera_alt,
                  label: 'Kamera',
                  color: Colors.blue,
                  onTap: _isUploading ? null : () => _pickImage('camera'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _OptionCard(
                  icon: Icons.photo_library,
                  label: 'Galeri',
                  color: Colors.purple,
                  onTap: _isUploading ? null : () => _pickImage('gallery'),
                ),
              ),
            ],
          ),
          if (_isUploading) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Yükleniyor...'),
          ],
        ],
      ),
    );
  }

  Future<void> _pickImage(String source) async {
    // FUTURE: Implement image picker
    // This would use image_picker package
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fotoğraf ekleme yakında aktif olacak'),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
