import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/task_models.dart';
import '../../domain/providers/tasks_providers.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../../shared/providers/branches_provider.dart';
import '../../../auth/domain/providers/branch_users_provider.dart';

/// Modern Görev Oluşturma Sayfası - Wizard Tarzı
class CreateTaskPage extends ConsumerStatefulWidget {
  const CreateTaskPage({super.key});

  @override
  ConsumerState<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends ConsumerState<CreateTaskPage> {
  final _pageController = PageController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _currentStep = 0;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  String? _selectedBranchId;
  String? _selectedBranchName;
  final Set<String> _selectedAssigneeIds = {};
  final Map<String, String> _assigneeNames = {};
  final List<SubtaskDraft> _subtasks = [];
  bool _isCreating = false;

  // Wizard adımları
  late List<_WizardStep> _steps;

  @override
  void initState() {
    super.initState();
    _buildSteps();
  }

  void _buildSteps() {
    final authState = ref.read(authProvider);
    final userRole = authState.maybeWhen(
      authenticated: (user) => user.role,
      orElse: () => null,
    );

    final isBolgeMuduru = userRole == 'bolge_muduru';
    final isSubeMuduru = userRole == 'sube_muduru';
    final canAssign = isBolgeMuduru || isSubeMuduru;

    _steps = [
      _WizardStep(
        icon: Icons.edit_note,
        title: 'Görev Bilgileri',
        subtitle: 'Başlık ve açıklama',
      ),
      _WizardStep(
        icon: Icons.checklist,
        title: 'Alt Görevler',
        subtitle: 'Görevi parçalara bölün',
      ),
      if (isBolgeMuduru)
        _WizardStep(
          icon: Icons.store,
          title: 'Şube Seçimi',
          subtitle: 'Hangi şubeye?',
        ),
      if (canAssign)
        _WizardStep(
          icon: Icons.people,
          title: 'Atama',
          subtitle: 'Kime atanacak?',
        ),
      _WizardStep(
        icon: Icons.check_circle,
        title: 'Özet',
        subtitle: 'Son kontrol',
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            // Progress
            _buildProgress(context),
            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                },
                children: _buildPages(context),
              ),
            ),
            // Navigation
            _buildNavigation(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _confirmExit(context),
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✨ Yeni Görev Oluştur',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Adım ${_currentStep + 1}/${_steps.length}: ${_steps[_currentStep].title}',
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

  Widget _buildProgress(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < _currentStep;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          // Step indicator
          final stepIndex = index ~/ 2;
          final step = _steps[stepIndex];
          final isActive = stepIndex == _currentStep;
          final isCompleted = stepIndex < _currentStep;

          return GestureDetector(
            onTap: stepIndex < _currentStep
                ? () {
                    _pageController.animateToPage(
                      stepIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            child: Column(
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
                    size: isActive ? 24 : 20,
                    color: isCompleted
                        ? Colors.white
                        : isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildPages(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userRole = authState.maybeWhen(
      authenticated: (user) => user.role,
      orElse: () => null,
    );

    final isBolgeMuduru = userRole == 'bolge_muduru';
    final isSubeMuduru = userRole == 'sube_muduru';
    final canAssign = isBolgeMuduru || isSubeMuduru;

    final pages = <Widget>[
      _TaskInfoPage(
        titleController: _titleController,
        descriptionController: _descriptionController,
        priority: _priority,
        dueDate: _dueDate,
        onPriorityChanged: (p) => setState(() => _priority = p),
        onDueDateChanged: (d) => setState(() => _dueDate = d),
      ),
      _SubtasksPage(
        subtasks: _subtasks,
        onSubtasksChanged: (s) => setState(() {
          _subtasks.clear();
          _subtasks.addAll(s);
        }),
      ),
      if (isBolgeMuduru)
        _BranchSelectionPage(
          selectedBranchId: _selectedBranchId,
          onBranchChanged: (id, name) {
            setState(() {
              _selectedBranchId = id;
              _selectedBranchName = name;
              _selectedAssigneeIds.clear();
              _assigneeNames.clear();
            });
          },
        ),
      if (canAssign)
        _AssignmentPage(
          selectedBranchId: isBolgeMuduru
              ? _selectedBranchId
              : authState.maybeWhen(
                  authenticated: (user) => user.branchId,
                  orElse: () => null,
                ),
          selectedAssigneeIds: _selectedAssigneeIds,
          assigneeNames: _assigneeNames,
          onAssigneesChanged: (ids, names) {
            setState(() {
              _selectedAssigneeIds.clear();
              _selectedAssigneeIds.addAll(ids);
              _assigneeNames.clear();
              _assigneeNames.addAll(names);
            });
          },
        ),
      _SummaryPage(
        title: _titleController.text,
        description: _descriptionController.text,
        priority: _priority,
        dueDate: _dueDate,
        subtasksCount: _countTotalSubtasks(),
        branchName: _selectedBranchName,
        assigneeNames: _assigneeNames.values.toList(),
        isCreating: _isCreating,
      ),
    ];

    return pages;
  }

  int _countTotalSubtasks() {
    int count = 0;
    for (final subtask in _subtasks) {
      count += 1 + _countChildren(subtask);
    }
    return count;
  }

  int _countChildren(SubtaskDraft draft) {
    int count = draft.children.length;
    for (final child in draft.children) {
      count += _countChildren(child);
    }
    return count;
  }

  Widget _buildNavigation(BuildContext context) {
    final theme = Theme.of(context);
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == _steps.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
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
          if (!isFirstStep)
            OutlinedButton.icon(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Geri'),
            ),
          const Spacer(),
          if (isLastStep)
            FilledButton.icon(
              onPressed: _isCreating ? null : _createTask,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: _isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(_isCreating ? 'Oluşturuluyor...' : 'Oluştur 🎉'),
            )
          else
            FilledButton.icon(
              onPressed: _canProceed() ? _goNext : null,
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

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _titleController.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void _goNext() {
    // Validation for step 0
    if (_currentStep == 0 && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görev başlığı gerekli'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _createTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görev başlığı gerekli'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final repository = ref.read(tasksRepositoryProvider);
      final authState = ref.read(authProvider);

      final currentUser = authState.maybeWhen(
        authenticated: (user) => user,
        orElse: () => null,
      );

      if (currentUser == null) throw Exception('Kullanıcı bulunamadı');

      // Branch ID belirleme
      String? branchId = _selectedBranchId ?? currentUser.branchId;

      if (branchId == null || branchId.isEmpty) {
        throw Exception('Şube bilgisi bulunamadı');
      }

      // Draft oluştur
      final draft = TaskDraft(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        priority: _priority,
        dueDate: _dueDate,
        children: _convertSubtasks(_subtasks),
      );

      await repository.createTaskTree(
        tenantId: currentUser.tenantId,
        creatorId: currentUser.id,
        draft: draft,
        branchId: branchId,
        assigneeIds: _selectedAssigneeIds.isNotEmpty
            ? _selectedAssigneeIds.toList()
            : [currentUser.id],
      );

      // Providers'ları yenile
      ref.invalidate(activeTasksProvider);
      ref.invalidate(myCreatedTasksProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Görev başarıyla oluşturuldu! 🎉'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
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
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _confirmExit(BuildContext context) async {
    if (_titleController.text.isEmpty && _subtasks.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Çıkmak istediğinize emin misiniz?'),
          ],
        ),
        content: const Text('Girdiğiniz bilgiler kaybolacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Çık'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  /// SubtaskDraft listesini TaskDraft listesine dönüştür
  List<TaskDraft> _convertSubtasks(List<SubtaskDraft> subtasks) {
    return subtasks.where((s) => s.title.trim().isNotEmpty).map((s) {
      return TaskDraft(
        title: s.title.trim(),
        description: s.description,
        priority: s.priority,
        children: _convertSubtasks(s.children),
      );
    }).toList();
  }
}

/// Wizard Step Model
class _WizardStep {
  _WizardStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

/// Subtask Draft Model
class SubtaskDraft {
  SubtaskDraft({
    required this.title,
    this.description,
    this.priority = TaskPriority.medium,
    this.children = const [],
  });

  final String title;
  final String? description;
  final TaskPriority priority;
  final List<SubtaskDraft> children;

  SubtaskDraft copyWith({
    String? title,
    String? description,
    TaskPriority? priority,
    List<SubtaskDraft>? children,
  }) {
    return SubtaskDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      children: children ?? this.children,
    );
  }
}

// ============================================================================
// PAGE 1: Görev Bilgileri
// ============================================================================

class _TaskInfoPage extends StatelessWidget {
  const _TaskInfoPage({
    required this.titleController,
    required this.descriptionController,
    required this.priority,
    required this.dueDate,
    required this.onPriorityChanged,
    required this.onDueDateChanged,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TaskPriority priority;
  final DateTime? dueDate;
  final ValueChanged<TaskPriority> onPriorityChanged;
  final ValueChanged<DateTime?> onDueDateChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.secondary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('📝', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Görevi Tanımlayın',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Başlık ve açıklama ekleyerek görevinizi tanımlayın',
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

          const SizedBox(height: 24),

          // Title Field
          Text(
            'Görev Başlığı *',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              hintText: 'Örn: Aylık sayım yap',
              prefixIcon: const Icon(Icons.title),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 20),

          // Description Field
          Text(
            'Açıklama (Opsiyonel)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Görev hakkında detaylı bilgi...',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.description_outlined),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Priority Selection
          Text(
            'Öncelik',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: TaskPriority.values.map((p) {
              final isSelected = p == priority;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onPriorityChanged(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(
                      right: p != TaskPriority.high ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getPriorityColor(p).withOpacity(0.15)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _getPriorityColor(p)
                            : theme.colorScheme.outline.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          p.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? _getPriorityColor(p)
                                : theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Due Date
          Text(
            'Son Tarih (Opsiyonel)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _pickDate(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: dueDate != null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.3),
                  width: dueDate != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: dueDate != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dueDate != null
                          ? DateFormat('dd MMMM yyyy', 'tr').format(dueDate!)
                          : 'Tarih seçin',
                      style: TextStyle(
                        color: dueDate != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                  if (dueDate != null)
                    IconButton(
                      onPressed: () => onDueDateChanged(null),
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
    );

    if (picked != null) {
      onDueDateChanged(picked);
    }
  }
}

// ============================================================================
// PAGE 2: Alt Görevler
// ============================================================================

class _SubtasksPage extends StatefulWidget {
  const _SubtasksPage({
    required this.subtasks,
    required this.onSubtasksChanged,
  });

  final List<SubtaskDraft> subtasks;
  final ValueChanged<List<SubtaskDraft>> onSubtasksChanged;

  @override
  State<_SubtasksPage> createState() => _SubtasksPageState();
}

class _SubtasksPageState extends State<_SubtasksPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.withOpacity(0.1),
                  Colors.pink.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('📋', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alt Görevler (Opsiyonel)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Görevi daha küçük parçalara bölün. 3 seviye derinliğe kadar desteklenir.',
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

          const SizedBox(height: 24),

          // Subtasks list
          if (widget.subtasks.isNotEmpty) ...[
            ...widget.subtasks.asMap().entries.map((entry) {
              return _SubtaskCard(
                key: ValueKey('subtask_${entry.key}'),
                draft: entry.value,
                depth: 0,
                onRemove: () {
                  final newList = List<SubtaskDraft>.from(widget.subtasks);
                  newList.removeAt(entry.key);
                  widget.onSubtasksChanged(newList);
                },
                onUpdate: (updated) {
                  final newList = List<SubtaskDraft>.from(widget.subtasks);
                  newList[entry.key] = updated;
                  widget.onSubtasksChanged(newList);
                },
              );
            }),
            const SizedBox(height: 16),
          ],

          // Add button
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                final newList = List<SubtaskDraft>.from(widget.subtasks);
                newList.add(SubtaskDraft(title: ''));
                widget.onSubtasksChanged(newList);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Alt Görev Ekle'),
            ),
          ),

          // Info
          if (widget.subtasks.isEmpty) ...[
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.checklist_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Alt görev eklenmedi',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu adımı atlayabilirsiniz',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
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

class _SubtaskCard extends StatefulWidget {
  const _SubtaskCard({
    super.key,
    required this.draft,
    required this.depth,
    required this.onRemove,
    required this.onUpdate,
  });

  final SubtaskDraft draft;
  final int depth;
  final VoidCallback onRemove;
  final ValueChanged<SubtaskDraft> onUpdate;

  @override
  State<_SubtaskCard> createState() => _SubtaskCardState();
}

class _SubtaskCardState extends State<_SubtaskCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.draft.title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAddChild = widget.depth < 2; // Max 3 levels (0, 1, 2)
    final depthColors = [
      Colors.indigo,
      Colors.purple,
      Colors.pink,
    ];
    final color = depthColors[widget.depth];

    return Container(
      margin: EdgeInsets.only(
        left: widget.depth * 20.0,
        bottom: 12,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          widget.depth == 0
                              ? '📌'
                              : widget.depth == 1
                                  ? '📎'
                                  : '•',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Alt görev başlığı',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        onChanged: (value) {
                          widget.onUpdate(widget.draft.copyWith(title: value));
                        },
                      ),
                    ),
                    if (canAddChild)
                      IconButton(
                        onPressed: () {
                          widget.onUpdate(
                            widget.draft.copyWith(
                              children: [
                                ...widget.draft.children,
                                SubtaskDraft(title: ''),
                              ],
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: color,
                        ),
                        tooltip: 'Alt görev ekle',
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    IconButton(
                      onPressed: widget.onRemove,
                      icon: Icon(
                        Icons.remove_circle_outline,
                        size: 20,
                        color: Colors.red.withOpacity(0.7),
                      ),
                      tooltip: 'Kaldır',
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Children
          ...widget.draft.children.asMap().entries.map((entry) {
            return _SubtaskCard(
              key: ValueKey('child_${widget.depth}_${entry.key}'),
              draft: entry.value,
              depth: widget.depth + 1,
              onRemove: () {
                final newChildren =
                    List<SubtaskDraft>.from(widget.draft.children);
                newChildren.removeAt(entry.key);
                widget.onUpdate(widget.draft.copyWith(children: newChildren));
              },
              onUpdate: (updated) {
                final newChildren =
                    List<SubtaskDraft>.from(widget.draft.children);
                newChildren[entry.key] = updated;
                widget.onUpdate(widget.draft.copyWith(children: newChildren));
              },
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================================
// PAGE 3: Şube Seçimi (Bölge Müdürü için)
// ============================================================================

class _BranchSelectionPage extends ConsumerWidget {
  const _BranchSelectionPage({
    required this.selectedBranchId,
    required this.onBranchChanged,
  });

  final String? selectedBranchId;
  final void Function(String? id, String? name) onBranchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final branchesAsync = ref.watch(branchesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.cyan.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('🏪', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Şube Seçin',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Görevin atanacağı şubeyi seçin',
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

          const SizedBox(height: 24),

          branchesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Şubeler yüklenemedi: $e'),
            ),
            data: (branches) {
              return Column(
                children: branches.map((branch) {
                  final isSelected = branch.id == selectedBranchId;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                                : theme.colorScheme.outline.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withOpacity(0.1)
                                    : theme.colorScheme.outline
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.store,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    branch.name,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
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
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PAGE 4: Atama
// ============================================================================

class _AssignmentPage extends ConsumerWidget {
  const _AssignmentPage({
    required this.selectedBranchId,
    required this.selectedAssigneeIds,
    required this.assigneeNames,
    required this.onAssigneesChanged,
  });

  final String? selectedBranchId;
  final Set<String> selectedAssigneeIds;
  final Map<String, String> assigneeNames;
  final void Function(Set<String>, Map<String, String>) onAssigneesChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (selectedBranchId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
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
      );
    }

    final usersAsync = ref.watch(branchUsersProvider(selectedBranchId!));
    final authState = ref.watch(authProvider);
    final currentUserId = authState.maybeWhen(
      authenticated: (user) => user.id,
      orElse: () => null,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.withOpacity(0.1),
                  Colors.teal.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('👥', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Görev Ataması',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Görevi kime atamak istiyorsunuz?',
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

          const SizedBox(height: 24),

          usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (users) {
              final availableUsers =
                  users.where((u) => u.id != currentUserId).toList();

              if (availableUsers.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
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
                );
              }

              return Column(
                children: [
                  // Select all
                  InkWell(
                    onTap: () {
                      final allSelected =
                          selectedAssigneeIds.length == availableUsers.length &&
                              availableUsers.isNotEmpty;
                      if (allSelected) {
                        onAssigneesChanged({}, {});
                      } else {
                        final newIds = availableUsers.map((u) => u.id).toSet();
                        final newNames = {
                          for (final u in availableUsers)
                            u.id: u.fullName ?? 'İsimsiz'
                        };
                        onAssigneesChanged(newIds, newNames);
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
                            value: availableUsers.isNotEmpty &&
                                    selectedAssigneeIds.length ==
                                        availableUsers.length
                                ? true
                                : selectedAssigneeIds.isNotEmpty
                                    ? null // Bazıları seçili - tristate
                                    : false, // Hiçbiri seçili değil
                            tristate: true,
                            onChanged: (value) {
                              // Checkbox tıklandığında - tam tersine çevir
                              final allSelected = selectedAssigneeIds.length ==
                                      availableUsers.length &&
                                  availableUsers.isNotEmpty;
                              if (allSelected) {
                                onAssigneesChanged({}, {});
                              } else {
                                final newIds =
                                    availableUsers.map((u) => u.id).toSet();
                                final newNames = {
                                  for (final u in availableUsers)
                                    u.id: u.fullName ?? 'İsimsiz'
                                };
                                onAssigneesChanged(newIds, newNames);
                              }
                            },
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
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${selectedAssigneeIds.length}/${availableUsers.length}',
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

                  const SizedBox(height: 16),

                  // User list
                  ...availableUsers.map((user) {
                    final isSelected = selectedAssigneeIds.contains(user.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          final newIds = Set<String>.from(selectedAssigneeIds);
                          final newNames =
                              Map<String, String>.from(assigneeNames);

                          if (isSelected) {
                            newIds.remove(user.id);
                            newNames.remove(user.id);
                          } else {
                            newIds.add(user.id);
                            newNames[user.id] = user.fullName ?? 'İsimsiz';
                          }
                          onAssigneesChanged(newIds, newNames);
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
                                backgroundColor: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline
                                        .withOpacity(0.2),
                                child: Text(
                                  (user.fullName ?? '?')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : theme.colorScheme.onSurface,
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
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      _roleLabel(user.role),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
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
      ),
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
// PAGE 5: Özet
// ============================================================================

class _SummaryPage extends StatelessWidget {
  const _SummaryPage({
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.subtasksCount,
    required this.branchName,
    required this.assigneeNames,
    required this.isCreating,
  });

  final String title;
  final String description;
  final TaskPriority priority;
  final DateTime? dueDate;
  final int subtasksCount;
  final String? branchName;
  final List<String> assigneeNames;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber.withOpacity(0.1),
                  Colors.orange.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('🎯', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Son Kontrol',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Her şey doğru görünüyor mu?',
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

          const SizedBox(height: 24),

          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    const Text('📋', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Görev Başlığı',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          Text(
                            title.isNotEmpty ? title : '(Başlık girilmedi)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: title.isNotEmpty
                                  ? null
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📝', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Açıklama',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                            Text(
                              description,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Priority and Due Date
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(priority.emoji,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Öncelik',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                              Text(
                                priority.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Text('📅', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Son Tarih',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                              Text(
                                dueDate != null
                                    ? DateFormat('dd MMM yyyy', 'tr')
                                        .format(dueDate!)
                                    : 'Belirlenmedi',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Subtasks
                Row(
                  children: [
                    const Text('📋', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alt Görevler',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        Text(
                          '$subtasksCount adet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (branchName != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('🏪', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Şube',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          Text(
                            branchName!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

                if (assigneeNames.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('👥', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Atanan Kişiler',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: assigneeNames.map((name) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Ready message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Her şey hazır! "Oluştur" butonuna basarak görevi oluşturabilirsiniz.',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
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
