import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/task_models.dart';
import '../../domain/providers/tasks_providers.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../shared/providers/branches_provider.dart';
import '../../../auth/domain/providers/branch_users_provider.dart';

/// Modern Görev İletme Sayfası
/// Şube müdürü veya bölge müdürü alt görevleri personeline atayabilir
class ForwardTaskPage extends ConsumerStatefulWidget {
  const ForwardTaskPage({super.key, required this.node});

  final TaskNode node;

  @override
  ConsumerState<ForwardTaskPage> createState() => _ForwardTaskPageState();
}

class _ForwardTaskPageState extends ConsumerState<ForwardTaskPage> {
  final Set<String> _selectedSubtaskIds = {};
  final Set<String> _selectedAssigneeIds = {};
  final Map<String, String> _assigneeNames = {};
  String? _selectedBranchId;
  bool _isForwarding = false;
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final currentUserRole = authState.maybeWhen(
      authenticated: (user) => user.role,
      orElse: () => null,
    );

    final isBolgeMuduru = currentUserRole == 'bolge_muduru';
    final totalSteps = isBolgeMuduru ? 3 : 2;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Görevi İlet'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress Steps
          _ProgressSteps(
            currentStep: _currentStep,
            totalSteps: totalSteps,
            isBolgeMuduru: isBolgeMuduru,
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Info
                  _TaskInfoCard(node: widget.node),

                  const SizedBox(height: 24),

                  // Step Content
                  if (_currentStep == 0)
                    _SubtaskSelectionStep(
                      node: widget.node,
                      selectedIds: _selectedSubtaskIds,
                      onSelectionChanged: (ids) {
                        setState(() {
                          _selectedSubtaskIds.clear();
                          _selectedSubtaskIds.addAll(ids);
                        });
                      },
                    )
                  else if (_currentStep == 1 && isBolgeMuduru)
                    _BranchSelectionStep(
                      selectedBranchId: _selectedBranchId,
                      onBranchChanged: (id, name) {
                        setState(() {
                          _selectedBranchId = id;
                          _selectedAssigneeIds.clear();
                          _assigneeNames.clear();
                        });
                      },
                    )
                  else
                    _AssigneeSelectionStep(
                      branchId: isBolgeMuduru
                          ? _selectedBranchId
                          : authState.maybeWhen(
                              authenticated: (user) => user.branchId,
                              orElse: () => null,
                            ),
                      selectedIds: _selectedAssigneeIds,
                      assigneeNames: _assigneeNames,
                      onSelectionChanged: (ids, names) {
                        setState(() {
                          _selectedAssigneeIds.clear();
                          _selectedAssigneeIds.addAll(ids);
                          _assigneeNames.clear();
                          _assigneeNames.addAll(names);
                        });
                      },
                    ),
                ],
              ),
            ),
          ),

          // Navigation
          _NavigationBar(
            currentStep: _currentStep,
            totalSteps: totalSteps,
            canProceed: _canProceed(),
            isForwarding: _isForwarding,
            onBack: () => setState(() => _currentStep--),
            onNext: () => setState(() => _currentStep++),
            onForward: _forward,
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedSubtaskIds.isNotEmpty;
      case 1:
        final authState = ref.read(authProvider);
        final isBolgeMuduru = authState.maybeWhen(
          authenticated: (user) => user.role == 'bolge_muduru',
          orElse: () => false,
        );
        if (isBolgeMuduru) {
          return _selectedBranchId != null;
        }
        return _selectedAssigneeIds.isNotEmpty;
      case 2:
        return _selectedAssigneeIds.isNotEmpty;
      default:
        return false;
    }
  }

  /// Seçili subtask ID'lerine göre TaskNode'ları bul
  List<TaskNode> _findSelectedSubtaskNodes() {
    final selectedNodes = <TaskNode>[];

    void findNodes(List<TaskNode> nodes) {
      for (final node in nodes) {
        if (_selectedSubtaskIds.contains(node.task.id)) {
          selectedNodes.add(node);
        }
        findNodes(node.children);
      }
    }

    findNodes(widget.node.children);
    return selectedNodes;
  }

  Future<void> _forward() async {
    if (_selectedSubtaskIds.isEmpty || _selectedAssigneeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen en az bir alt görev ve bir personel seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isForwarding = true);

    try {
      final repository = ref.read(tasksRepositoryProvider);
      final authState = ref.read(authProvider);
      final currentUserId = authState.maybeWhen(
        authenticated: (user) => user.id,
        orElse: () => '',
      );

      final selectedNodes = _findSelectedSubtaskNodes();

      // Her seçili alt görev için iletme işlemi yap
      for (final subtaskNode in selectedNodes) {
        await repository.forwardSubtask(
          subtaskNode: subtaskNode,
          forwarderId: currentUserId,
          assigneeIds: _selectedAssigneeIds.toList(),
          branchId: _selectedBranchId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '${_selectedSubtaskIds.length} görev başarıyla iletildi! 🎉',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isForwarding = false);
      }
    }
  }
}

// ============================================================================
// Progress Steps
// ============================================================================

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({
    required this.currentStep,
    required this.totalSteps,
    required this.isBolgeMuduru,
  });

  final int currentStep;
  final int totalSteps;
  final bool isBolgeMuduru;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final steps = [
      const _StepInfo(icon: Icons.checklist, label: 'Alt Görevler'),
      if (isBolgeMuduru) const _StepInfo(icon: Icons.store, label: 'Şube'),
      const _StepInfo(icon: Icons.people, label: 'Personel'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          // Step
          final stepIndex = index ~/ 2;
          final step = steps[stepIndex];
          final isActive = stepIndex == currentStep;
          final isCompleted = stepIndex < currentStep;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 48 : 40,
                height: isActive ? 48 : 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : isActive
                          ? theme.colorScheme.primary.withOpacity(0.15)
                          : theme.colorScheme.outline.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: isActive
                      ? Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: Icon(
                  isCompleted ? Icons.check : step.icon,
                  size: 20,
                  color: isCompleted
                      ? Colors.white
                      : isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _StepInfo {
  const _StepInfo({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

// ============================================================================
// Task Info Card
// ============================================================================

class _TaskInfoCard extends StatelessWidget {
  const _TaskInfoCard({required this.node});
  final TaskNode node;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = node.task;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('📤', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İletilecek Görev',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${node.children.length} alt görev mevcut',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Step 1: Subtask Selection
// ============================================================================

class _SubtaskSelectionStep extends StatelessWidget {
  const _SubtaskSelectionStep({
    required this.node,
    required this.selectedIds,
    required this.onSelectionChanged,
  });

  final TaskNode node;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Tüm alt görevleri düzleştir
    final allSubtasks = <TaskNode>[];
    _flattenSubtasks(node.children, allSubtasks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alt Görevleri Seçin',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'İletmek istediğiniz görevleri işaretleyin',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Select All
        InkWell(
          onTap: () {
            if (selectedIds.length == allSubtasks.length) {
              onSelectionChanged({});
            } else {
              onSelectionChanged(allSubtasks.map((n) => n.task.id).toSet());
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: selectedIds.length == allSubtasks.length &&
                      allSubtasks.isNotEmpty,
                  tristate: selectedIds.isNotEmpty &&
                      selectedIds.length < allSubtasks.length,
                  onChanged: (_) {},
                ),
                const SizedBox(width: 8),
                Text(
                  'Tümünü Seç',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedIds.length}/${allSubtasks.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Subtasks List
        if (allSubtasks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Alt görev bulunamadı',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...allSubtasks.map((subtask) => _SubtaskItem(
                node: subtask,
                isSelected: selectedIds.contains(subtask.task.id),
                onToggle: () {
                  final newIds = Set<String>.from(selectedIds);
                  if (newIds.contains(subtask.task.id)) {
                    newIds.remove(subtask.task.id);
                  } else {
                    newIds.add(subtask.task.id);
                  }
                  onSelectionChanged(newIds);
                },
              )),
      ],
    );
  }

  void _flattenSubtasks(List<TaskNode> nodes, List<TaskNode> result) {
    for (final node in nodes) {
      result.add(node);
      _flattenSubtasks(node.children, result);
    }
  }
}

class _SubtaskItem extends StatelessWidget {
  const _SubtaskItem({
    required this.node,
    required this.isSelected,
    required this.onToggle,
  });

  final TaskNode node;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = node.task;
    final isCompleted = task.status == TaskStatus.completed ||
        task.status == TaskStatus.approved;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: isCompleted ? null : onToggle,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCompleted
                ? theme.colorScheme.outline.withOpacity(0.05)
                : isSelected
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? theme.colorScheme.outline.withOpacity(0.1)
                  : isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green
                      : isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCompleted
                        ? Colors.green
                        : isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: (isCompleted || isSelected)
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted
                            ? theme.colorScheme.onSurface.withOpacity(0.4)
                            : null,
                      ),
                    ),
                    if (isCompleted)
                      Text(
                        'Zaten tamamlanmış',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              // Priority
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(task.priority).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task.priority.emoji,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
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

// ============================================================================
// Step 2: Branch Selection (for Bölge Müdürü)
// ============================================================================

class _BranchSelectionStep extends ConsumerWidget {
  const _BranchSelectionStep({
    required this.selectedBranchId,
    required this.onBranchChanged,
  });

  final String? selectedBranchId;
  final void Function(String? id, String? name) onBranchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final branchesAsync = ref.watch(branchesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('🏪', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hedef Şube Seçin',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Görevin iletileceği şubeyi belirleyin',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        branchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (branches) {
            return Column(
              children: branches.map((branch) {
                final isSelected = branch.id == selectedBranchId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onBranchChanged(branch.id, branch.name),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withOpacity(0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withOpacity(0.15)
                                  : theme.colorScheme.outline.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.store,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              branch.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// Step 3: Assignee Selection
// ============================================================================

class _AssigneeSelectionStep extends ConsumerWidget {
  const _AssigneeSelectionStep({
    required this.branchId,
    required this.selectedIds,
    required this.assigneeNames,
    required this.onSelectionChanged,
  });

  final String? branchId;
  final Set<String> selectedIds;
  final Map<String, String> assigneeNames;
  final void Function(Set<String>, Map<String, String>) onSelectionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (branchId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.2),
              ),
              const SizedBox(height: 16),
              Text(
                'Önce bir şube seçin',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final usersAsync = ref.watch(branchUsersProvider(branchId!));
    final authState = ref.watch(authProvider);
    final currentUserId = authState.maybeWhen(
      authenticated: (user) => user.id,
      orElse: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('👥', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personel Seçin',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Görevi atayacağınız personelleri seçin',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        usersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (users) {
            final availableUsers =
                users.where((u) => u.id != currentUserId).toList();

            if (availableUsers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Atanabilecek personel yok',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                // Select All
                InkWell(
                  onTap: () {
                    if (selectedIds.length == availableUsers.length) {
                      onSelectionChanged({}, {});
                    } else {
                      final newIds = availableUsers.map((u) => u.id).toSet();
                      final newNames = {
                        for (final u in availableUsers)
                          u.id: u.fullName ?? 'İsimsiz'
                      };
                      onSelectionChanged(newIds, newNames);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: selectedIds.length == availableUsers.length,
                          tristate: selectedIds.isNotEmpty &&
                              selectedIds.length < availableUsers.length,
                          onChanged: (_) {},
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tümünü Seç',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${selectedIds.length}/${availableUsers.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Users List
                ...availableUsers.map((user) {
                  final isSelected = selectedIds.contains(user.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        final newIds = Set<String>.from(selectedIds);
                        final newNames =
                            Map<String, String>.from(assigneeNames);

                        if (isSelected) {
                          newIds.remove(user.id);
                          newNames.remove(user.id);
                        } else {
                          newIds.add(user.id);
                          newNames[user.id] = user.fullName ?? 'İsimsiz';
                        }
                        onSelectionChanged(newIds, newNames);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withOpacity(0.2),
                              child: Text(
                                (user.fullName ?? '?')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.fullName ?? 'İsimsiz',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    _roleLabel(user.role),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'sube_muduru':
        return 'Şube Müdürü';
      case 'personel':
        return 'Personel';
      case 'bolge_muduru':
        return 'Bölge Müdürü';
      default:
        return role ?? 'Bilinmiyor';
    }
  }
}

// ============================================================================
// Navigation Bar
// ============================================================================

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.currentStep,
    required this.totalSteps,
    required this.canProceed,
    required this.isForwarding,
    required this.onBack,
    required this.onNext,
    required this.onForward,
  });

  final int currentStep;
  final int totalSteps;
  final bool canProceed;
  final bool isForwarding;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastStep = currentStep == totalSteps - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (currentStep > 0)
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Geri'),
            ),
          const Spacer(),
          if (isLastStep)
            FilledButton.icon(
              onPressed: canProceed && !isForwarding ? onForward : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: isForwarding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(isForwarding ? 'Gönderiliyor...' : 'Gönder 🚀'),
            )
          else
            FilledButton.icon(
              onPressed: canProceed ? onNext : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Devam'),
            ),
        ],
      ),
    );
  }
}
