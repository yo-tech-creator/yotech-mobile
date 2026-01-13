import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/models/auth_state.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../region_manager/domain/models/branch_task_node.dart';
import '../../domain/providers/branch_tasks_providers.dart';
import '../../data/branch_tasks_repository.dart';

enum _TaskFilter {
  aktif,
  tamamlanan,
  subeAtanan,
  olusturdugum,
}

class BranchTasksPage extends ConsumerStatefulWidget {
  const BranchTasksPage({super.key});

  @override
  ConsumerState<BranchTasksPage> createState() => _BranchTasksPageState();
}

class _BranchTasksPageState extends ConsumerState<BranchTasksPage> {
  final Set<String> _expandedTaskIds = <String>{};
  _TaskFilter _filter = _TaskFilter.aktif;

  @override
  Widget build(BuildContext context) {
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

    final canCancel = authState.maybeWhen<bool>(
      authenticated: (user) =>
          user.role == 'sube_muduru' || user.role == 'bolge_muduru',
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Görevler')),
      floatingActionButton: canCreate && userBranchId != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                final branchId = userBranchId;
                await _openCreateTaskSheet(
                  userBranchId: branchId,
                  authState: authState,
                );
              },
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('Görev ekle'),
            )
          : null,
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Görevler yüklenemedi: $error',
          onRetry: () => ref.invalidate(branchTaskTreeProvider),
        ),
        data: (tasks) {
          if (!hasBranch) {
            return const _InfoState(
              icon: Icons.store_mall_directory_outlined,
              title: 'Şube ataması gerekli',
              description:
                  'Bu modülü kullanabilmek için bir şubeye atanmanız gerekir.',
            );
          }

          if (tasks.isEmpty) {
            return const _InfoState(
              icon: Icons.checklist_rounded,
              title: 'Görev bulunmuyor',
              description:
                  'Şubeniz için henüz görev planlanmadı. Görev tanımlandığında burada görünecek.',
            );
          }

          final filteredTasks = _applyFilter(
            tasks,
            filter: _filter,
            currentUserId: currentUser?.id,
          );

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Text('Görünüm'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<_TaskFilter>(
                        key: ValueKey(_filter),
                        initialValue: _filter,
                        items: const [
                          DropdownMenuItem(
                            value: _TaskFilter.aktif,
                            child: Text('Aktif görevler'),
                          ),
                          DropdownMenuItem(
                            value: _TaskFilter.tamamlanan,
                            child: Text('Tamamlanan görevler'),
                          ),
                          DropdownMenuItem(
                            value: _TaskFilter.subeAtanan,
                            child: Text('Şubeye atanan görevler'),
                          ),
                          DropdownMenuItem(
                            value: _TaskFilter.olusturdugum,
                            child: Text('Oluşturduğum görevler'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _filter = value);
                          }
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(branchTaskTreeProvider.future),
                  child: filteredTasks.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          children: const [
                            _InfoState(
                              icon: Icons.search_off,
                              title: 'Bu filtrede görev yok',
                              description:
                                  'Farklı bir görünüm seçerek görevleri görüntüleyin.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final node = filteredTasks[index];
                            return _buildTaskNode(
                              context: context,
                              node: node,
                              ancestors: const <BranchTaskNode>[],
                              currentUserId: currentUser?.id,
                              canCancel: canCancel,
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTaskNode({
    required BuildContext context,
    required BranchTaskNode node,
    required List<BranchTaskNode> ancestors,
    required String? currentUserId,
    required bool canCancel,
    int depth = 0,
  }) {
    final theme = Theme.of(context);
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _expandedTaskIds.contains(node.record.id);
    final isCompleted = node.record.status == BranchTaskStatus.completed;
    final statusColor = _statusColor(node.record.status, theme);
    final backgroundColor = _taskBackgroundColor(
        theme: theme, depth: depth, isCompleted: isCompleted);
    final borderColor =
        _taskBorderColor(theme: theme, depth: depth, isCompleted: isCompleted);
    final progress = depth == 0 ? _taskProgress(node) : null;
    final progressPercent =
        progress != null ? (progress * 100).clamp(0, 100).round() : null;
    final isCancelable = canCancel && currentUserId == node.record.managerId;
    final isCreator =
        currentUserId != null && currentUserId == node.record.managerId;
    final canApprove =
        depth == 0 && isCreator && (progress ?? 0) >= 1 && !isCompleted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: EdgeInsets.only(left: depth == 0 ? 0 : 16.0, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: depth == 0 ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isCompleted,
                onChanged: (value) => _onTaskCheckboxChanged(
                  node: node,
                  shouldComplete: value ?? false,
                  ancestors: ancestors,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: InkWell(
                            onTap: hasChildren
                                ? () => _toggleExpansion(node)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasChildren)
                                    AnimatedRotation(
                                      turns: isExpanded ? 0.25 : 0,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: const Icon(Icons.chevron_right,
                                          size: 20),
                                    )
                                  else
                                    const SizedBox(width: 20),
                                  if (hasChildren) const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      node.record.title,
                                      style: depth == 0
                                          ? theme.textTheme.titleMedium
                                              ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            )
                                          : theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(_statusLabel(node.record.status)),
                          backgroundColor: statusColor.withValues(alpha: 0.12),
                          labelStyle: theme.textTheme.labelMedium
                              ?.copyWith(color: statusColor),
                        ),
                        if (isCancelable && !isCompleted)
                          TextButton.icon(
                            onPressed: () => _confirmCancelTask(node),
                            icon: const Icon(
                                Icons.cancel_schedule_send_outlined,
                                size: 18),
                            label: const Text('İptal et'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Öncelik: ${_priorityLabel(node.record.priority)} · Atayan: ${(node.record.managerName ?? 'Bilinmiyor')} (${_roleLabel(node.record.managerRole)})',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (depth == 0 && progressPercent != null) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (progress ?? 0).clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '%$progressPercent tamamlandı',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (canApprove) ...[
                      const SizedBox(height: 6),
                      FilledButton.icon(
                        onPressed: () => _approveTask(node),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Görevi onayla'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (node.record.description != null &&
              node.record.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              node.record.description!,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Oluşturma: ${_formatDateTime(node.record.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          if (node.record.updatedAt != node.record.createdAt)
            Text(
              'Son güncelleme: ${_formatDateTime(node.record.updatedAt)}',
              style: theme.textTheme.bodySmall,
            ),
          if (hasChildren && isExpanded) ...[
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: node.children
                  .map(
                    (child) => _buildTaskNode(
                      context: context,
                      node: child,
                      ancestors: [...ancestors, node],
                      currentUserId: currentUserId,
                      canCancel: canCancel,
                      depth: depth + 1,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onTaskCheckboxChanged({
    required BranchTaskNode node,
    required bool shouldComplete,
    required List<BranchTaskNode> ancestors,
  }) async {
    final newStatus =
        shouldComplete ? BranchTaskStatus.completed : BranchTaskStatus.pending;
    if (node.record.status == newStatus) {
      return;
    }

    try {
      final repository = ref.read(branchTasksRepositoryProvider);
      await repository.updateTaskStatus(
          taskId: node.record.id, status: newStatus);

      if (shouldComplete && node.children.isNotEmpty) {
        await _markDescendantsComplete(
          root: node,
          repository: repository,
        );
      } else if (!shouldComplete && node.children.isNotEmpty) {
        await _markDescendantsPending(
          root: node,
          repository: repository,
        );
      }

      if (ancestors.isNotEmpty) {
        for (var index = ancestors.length - 1; index >= 0; index--) {
          final ancestor = ancestors[index];
          final allChildrenCompleted = ancestor.children.every(
            (child) => _isNodeCompleteAfterToggle(
              child,
              toggledNode: node,
              shouldComplete: shouldComplete,
            ),
          );

          final anyChildrenCompleted = ancestor.children.any(
            (child) => _isNodeCompleteAfterToggle(
              child,
              toggledNode: node,
              shouldComplete: shouldComplete,
            ),
          );

          final nextStatus = allChildrenCompleted
              ? BranchTaskStatus.completed
              : (anyChildrenCompleted
                  ? BranchTaskStatus.inProgress
                  : BranchTaskStatus.pending);

          if (ancestor.record.status != nextStatus) {
            await repository.updateTaskStatus(
              taskId: ancestor.record.id,
              status: nextStatus,
            );
          }
        }
      }

      final _ = await ref.refresh(branchTaskTreeProvider.future);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görev güncellenemedi: $error')),
        );
      }
    }
  }

  Future<void> _confirmCancelTask(BranchTaskNode node) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Görevi iptal et'),
          content: const Text(
              'Görevi iptal etmek istediğinize emin misiniz? Alt görevler de silinecek.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('İptal et'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) return;

    try {
      final repository = ref.read(branchTasksRepositoryProvider);
      await repository.deleteTaskCascade(root: node);
      final _ = await ref.refresh(branchTaskTreeProvider.future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görev iptal edildi')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görev iptal edilemedi: $error')),
        );
      }
    }
  }

  Future<void> _approveTask(BranchTaskNode node) async {
    try {
      final repository = ref.read(branchTasksRepositoryProvider);
      await repository.updateTaskStatus(
        taskId: node.record.id,
        status: BranchTaskStatus.completed,
      );
      final _ = await ref.refresh(branchTaskTreeProvider.future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görev onaylandı')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görev onaylanamadı: $error')),
        );
      }
    }
  }

  Future<void> _markDescendantsComplete({
    required BranchTaskNode root,
    required BranchTasksRepository repository,
  }) async {
    final queue = <BranchTaskNode>[...root.children];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (current.record.status != BranchTaskStatus.completed) {
        await repository.updateTaskStatus(
          taskId: current.record.id,
          status: BranchTaskStatus.completed,
        );
      }
      queue.addAll(current.children);
    }
  }

  Future<void> _markDescendantsPending({
    required BranchTaskNode root,
    required BranchTasksRepository repository,
  }) async {
    final queue = <BranchTaskNode>[...root.children];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (current.record.status != BranchTaskStatus.pending) {
        await repository.updateTaskStatus(
          taskId: current.record.id,
          status: BranchTaskStatus.pending,
        );
      }
      queue.addAll(current.children);
    }
  }

  void _toggleExpansion(BranchTaskNode node) {
    if (node.children.isEmpty) {
      return;
    }
    setState(() {
      if (_expandedTaskIds.contains(node.record.id)) {
        _expandedTaskIds.remove(node.record.id);
        _collapseDescendants(node);
      } else {
        _expandedTaskIds.add(node.record.id);
      }
    });
  }

  void _collapseDescendants(BranchTaskNode node) {
    for (final child in node.children) {
      _expandedTaskIds.remove(child.record.id);
      _collapseDescendants(child);
    }
  }

  Future<void> _openCreateTaskSheet({
    required String userBranchId,
    required AuthState authState,
  }) async {
    final user = authState.maybeWhen(
      authenticated: (u) => u,
      orElse: () => null,
    );
    if (user == null) return;

    final result = await showModalBottomSheet<_BranchTaskCreateResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BranchTaskCreateSheet(),
    );

    if (result == null) return;

    final repo = ref.read(branchTasksRepositoryProvider);
    try {
      final root = await repo.createTask(
        tenantId: user.tenantId,
        creatorId: user.id,
        branchId: userBranchId,
        title: result.title,
        description: result.description,
        priority: result.priority,
        dueDate: result.dueDate,
      );

      await _createDraftSubtree(
        repo: repo,
        parentId: root.id,
        tenantId: user.tenantId,
        branchId: userBranchId,
        creatorId: user.id,
        nodes: result.children,
      );

      final _ = await ref.refresh(branchTaskTreeProvider.future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görev oluşturuldu')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görev oluşturulamadı: $e')),
        );
      }
    }
  }

  Future<void> _createDraftSubtree({
    required BranchTasksRepository repo,
    required String parentId,
    required String tenantId,
    required String branchId,
    required String creatorId,
    required List<_DraftInput> nodes,
  }) async {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final record = await repo.createTask(
        tenantId: tenantId,
        creatorId: creatorId,
        branchId: branchId,
        title: node.title,
        description: node.description,
        priority: node.priority,
        dueDate: node.dueDate,
        parentTaskId: parentId,
        sortOrder: i,
      );
      if (node.children.isNotEmpty) {
        await _createDraftSubtree(
          repo: repo,
          parentId: record.id,
          tenantId: tenantId,
          branchId: branchId,
          creatorId: creatorId,
          nodes: node.children,
        );
      }
    }
  }

  Color _taskBackgroundColor({
    required ThemeData theme,
    required int depth,
    required bool isCompleted,
  }) {
    if (isCompleted) {
      return theme.colorScheme.secondaryContainer;
    }
    final baseSurface = theme.colorScheme.surface;
    if (depth == 0) {
      return Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.04),
        baseSurface,
      );
    }
    if (depth == 1) {
      return Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.08),
        baseSurface,
      );
    }
    return Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: 0.12),
      baseSurface,
    );
  }

  Color _taskBorderColor({
    required ThemeData theme,
    required int depth,
    required bool isCompleted,
  }) {
    if (isCompleted) {
      return theme.colorScheme.secondary;
    }
    if (depth == 0) {
      return theme.colorScheme.primary.withValues(alpha: 0.45);
    }
    return theme.colorScheme.primary.withValues(alpha: 0.25);
  }

  double _taskProgress(BranchTaskNode node) {
    final total = _descendantCount(node);
    if (total == 0) {
      return node.record.status == BranchTaskStatus.completed ? 1 : 0;
    }
    final completed = _completedDescendantCount(node);
    return completed / total;
  }

  int _descendantCount(BranchTaskNode node) {
    var total = node.children.length;
    for (final child in node.children) {
      total += _descendantCount(child);
    }
    return total;
  }

  int _completedDescendantCount(BranchTaskNode node) {
    var completed = 0;
    for (final child in node.children) {
      if (child.record.status == BranchTaskStatus.completed) {
        completed += 1;
      }
      completed += _completedDescendantCount(child);
    }
    return completed;
  }

  Color _statusColor(BranchTaskStatus status, ThemeData theme) {
    switch (status) {
      case BranchTaskStatus.pending:
        return theme.colorScheme.tertiary;
      case BranchTaskStatus.inProgress:
        return theme.colorScheme.primary;
      case BranchTaskStatus.completed:
        return theme.colorScheme.secondary;
    }
  }

  String _statusLabel(BranchTaskStatus status) {
    switch (status) {
      case BranchTaskStatus.pending:
        return 'Beklemede';
      case BranchTaskStatus.inProgress:
        return 'Devam ediyor';
      case BranchTaskStatus.completed:
        return 'Tamamlandı';
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }

  List<BranchTaskNode> _applyFilter(
    List<BranchTaskNode> nodes, {
    required _TaskFilter filter,
    required String? currentUserId,
  }) {
    BranchTaskNode? filterNode(BranchTaskNode node) {
      final filteredChildren =
          node.children.map(filterNode).whereType<BranchTaskNode>().toList();

      final matches = switch (filter) {
        _TaskFilter.aktif => node.record.status != BranchTaskStatus.completed,
        _TaskFilter.tamamlanan =>
          node.record.status == BranchTaskStatus.completed,
        _TaskFilter.subeAtanan =>
          node.record.status != BranchTaskStatus.completed &&
              node.record.managerRole == 'bolge_muduru',
        _TaskFilter.olusturdugum =>
          currentUserId != null && node.record.managerId == currentUserId,
      };

      if (matches || filteredChildren.isNotEmpty) {
        return BranchTaskNode(record: node.record, children: filteredChildren);
      }
      return null;
    }

    return nodes.map(filterNode).whereType<BranchTaskNode>().toList();
  }

  String _priorityLabel(String? value) {
    switch (value) {
      case 'yuksek':
        return 'Yüksek';
      case 'orta':
        return 'Orta';
      case 'dusuk':
        return 'Düşük';
      default:
        return 'Belirtilmedi';
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'bolge_muduru':
        return 'Bölge Müdürü';
      case 'sube_muduru':
        return 'Şube Müdürü';
      case 'personel':
        return 'Personel';
      case 'firma_admin':
        return 'Firma Admin';
      case 'grand_admin':
        return 'Grand Admin';
      default:
        return 'Rol bilinmiyor';
    }
  }

  bool _containsNode(BranchTaskNode node, String targetId) {
    for (final child in node.children) {
      if (child.record.id == targetId) {
        return true;
      }
      if (_containsNode(child, targetId)) {
        return true;
      }
    }
    return false;
  }

  bool _isNodeCompleteAfterToggle(
    BranchTaskNode node, {
    required BranchTaskNode toggledNode,
    required bool shouldComplete,
  }) {
    if (node.record.id == toggledNode.record.id) {
      return shouldComplete;
    }
    if (_containsNode(node, toggledNode.record.id)) {
      return shouldComplete;
    }
    return node.record.status == BranchTaskStatus.completed;
  }
}

class _DraftInput {
  const _DraftInput({
    required this.title,
    this.description,
    this.priority,
    this.dueDate,
    this.children = const <_DraftInput>[],
  });

  final String title;
  final String? description;
  final String? priority;
  final DateTime? dueDate;
  final List<_DraftInput> children;
}

class _BranchTaskCreateResult {
  const _BranchTaskCreateResult({
    required this.title,
    this.description,
    this.priority,
    this.dueDate,
    this.children = const <_DraftInput>[],
  });

  final String title;
  final String? description;
  final String? priority;
  final DateTime? dueDate;
  final List<_DraftInput> children;
}

class _DraftNode {
  _DraftNode()
      : titleController = TextEditingController(),
        noteController = TextEditingController();

  final TextEditingController titleController;
  final TextEditingController noteController;
  String priority = 'orta';
  DateTime? dueDate;
  final List<_DraftNode> children = <_DraftNode>[];

  void dispose() {
    titleController.dispose();
    noteController.dispose();
    for (final child in children) {
      child.dispose();
    }
  }
}

class _BranchTaskCreateSheet extends StatefulWidget {
  @override
  State<_BranchTaskCreateSheet> createState() => _BranchTaskCreateSheetState();
}

class _BranchTaskCreateSheetState extends State<_BranchTaskCreateSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _priority = 'orta';
  DateTime? _dueDate;
  final List<_DraftNode> _children = <_DraftNode>[];
  final Set<_DraftNode> _invalid = <_DraftNode>{};
  String? _titleError;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    for (final child in _children) {
      child.dispose();
    }
    super.dispose();
  }

  void _addChild({_DraftNode? parent, int depth = 0}) {
    if (depth > 1) return;
    setState(() {
      final node = _DraftNode();
      if (parent == null) {
        _children.add(node);
      } else {
        parent.children.add(node);
      }
    });
  }

  void _removeChild(List<_DraftNode> siblings, int index) {
    setState(() {
      final removed = siblings.removeAt(index);
      _invalid.remove(removed);
      removed.dispose();
    });
  }

  List<_DraftInput> _collect(List<_DraftNode> nodes) {
    final results = <_DraftInput>[];
    for (final node in nodes) {
      final title = node.titleController.text.trim();
      if (title.isEmpty) {
        _invalid.add(node);
        continue;
      }
      results.add(
        _DraftInput(
          title: title,
          description: node.noteController.text.trim().isEmpty
              ? null
              : node.noteController.text.trim(),
          priority: node.priority,
          dueDate: node.dueDate,
          children: _collect(node.children),
        ),
      );
    }
    return results;
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Başlık zorunlu');
      return;
    }
    _invalid.clear();
    final children = _collect(_children);
    if (_invalid.isNotEmpty) {
      setState(() {});
      return;
    }
    Navigator.of(context).pop(
      _BranchTaskCreateResult(
        title: title,
        description: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        priority: _priority,
        dueDate: _dueDate,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Görev oluştur',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Ana görev başlığı',
                  errorText: _titleError,
                ),
                onChanged: (_) => setState(() => _titleError = null),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                items: const [
                  DropdownMenuItem(
                      value: 'dusuk', child: Text('Düşük öncelik')),
                  DropdownMenuItem(value: 'orta', child: Text('Orta öncelik')),
                  DropdownMenuItem(
                      value: 'yuksek', child: Text('Yüksek öncelik')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'orta'),
                decoration: const InputDecoration(labelText: 'Öncelik'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  hintText: 'Detay veya hatırlatma',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? now,
                    firstDate: now.subtract(const Duration(days: 1)),
                    lastDate: now.add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Son tarih (opsiyonel)'),
                  child: Text(
                    _dueDate == null
                        ? 'Seçilmedi'
                        : '${_dueDate!.day.toString().padLeft(2, '0')}.${_dueDate!.month.toString().padLeft(2, '0')}.${_dueDate!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Alt görevler (isteğe bağlı, en fazla iki seviye)',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._buildDraftList(_children, depth: 0),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addChild(depth: 0),
                  icon: const Icon(Icons.add),
                  label: const Text('Alt görev ekle'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDraftList(List<_DraftNode> nodes, {required int depth}) {
    return nodes.asMap().entries.map((entry) {
      final index = entry.key;
      final node = entry.value;
      return _buildDraftNode(
          node: node, siblings: nodes, index: index, depth: depth);
    }).toList();
  }

  Widget _buildDraftNode({
    required _DraftNode node,
    required List<_DraftNode> siblings,
    required int index,
    required int depth,
  }) {
    final theme = Theme.of(context);
    final canAddNested = depth < 1;
    return Container(
      margin: EdgeInsets.only(left: depth == 0 ? 0 : 12.0 * depth, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: node.titleController,
            decoration: InputDecoration(
              labelText: depth == 0 ? 'Alt görev' : 'Görev detayı',
              errorText: _invalid.contains(node) ? 'Başlık zorunlu' : null,
            ),
            onChanged: (_) {
              if (_invalid.remove(node)) {
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: node.noteController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Not (opsiyonel)'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: node.priority,
            items: const [
              DropdownMenuItem(value: 'dusuk', child: Text('Düşük')),
              DropdownMenuItem(value: 'orta', child: Text('Orta')),
              DropdownMenuItem(value: 'yuksek', child: Text('Yüksek')),
            ],
            onChanged: (v) => setState(() => node.priority = v ?? 'orta'),
            decoration: const InputDecoration(labelText: 'Öncelik'),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: node.dueDate ?? now,
                firstDate: now.subtract(const Duration(days: 1)),
                lastDate: now.add(const Duration(days: 365 * 2)),
              );
              if (picked != null) {
                setState(() => node.dueDate = picked);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration:
                  const InputDecoration(labelText: 'Son tarih (opsiyonel)'),
              child: Text(
                node.dueDate == null
                    ? 'Seçilmedi'
                    : '${node.dueDate!.day.toString().padLeft(2, '0')}.${node.dueDate!.month.toString().padLeft(2, '0')}.${node.dueDate!.year}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (canAddNested)
                TextButton.icon(
                  onPressed: () => _addChild(parent: node, depth: depth + 1),
                  icon: const Icon(Icons.subdirectory_arrow_right),
                  label: const Text('Alt görev ekle'),
                ),
              const Spacer(),
              IconButton(
                onPressed: () => _removeChild(siblings, index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoState extends StatelessWidget {
  const _InfoState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
