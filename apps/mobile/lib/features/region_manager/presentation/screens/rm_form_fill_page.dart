import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../forms/domain/models/form_models.dart';
import '../../../forms/presentation/providers/forms_providers.dart'
    hide branchPersonnelProvider;
import '../../../auth/domain/providers/auth_provider.dart';
import '../../domain/models/managed_branch.dart';
import '../../domain/models/branch_personnel.dart';
import '../../domain/providers/region_manager_providers.dart';
import 'rm_completed_forms_page.dart';

/// Bölge Müdürü Form doldurma sayfası - Şube ve Personel seçimli
class RmFormFillPage extends ConsumerStatefulWidget {
  const RmFormFillPage({super.key, required this.form});

  final PublishedForm form;

  @override
  ConsumerState<RmFormFillPage> createState() => _RmFormFillPageState();
}

class _RmFormFillPageState extends ConsumerState<RmFormFillPage> {
  final Map<String, FormItemResult> _answers = {};
  final Map<String, String> _comments = {};
  final PageController _pageController = PageController();
  int _currentSectionIndex = 0;
  bool _isSubmitting = false;
  String? _sessionId;

  // Şube ve personel seçimi
  ManagedBranch? _selectedBranch;
  BranchPersonnel? _selectedManager;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = widget.form.sections;
    final branchesAsync = ref.watch(regionManagerBranchesProvider);

    if (sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.form.title)),
        body: const Center(
          child: Text('Bu formda henüz bölüm bulunmuyor.'),
        ),
      );
    }

    final currentSection = sections[_currentSectionIndex];
    final progress = _calculateProgress();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.form.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
      ),
      body: Column(
        children: [
          // Şube ve Personel Seçimi
          _BranchManagerSelector(
            selectedBranch: _selectedBranch,
            selectedManager: _selectedManager,
            branchesAsync: branchesAsync,
            onBranchChanged: (branch) {
              setState(() {
                _selectedBranch = branch;
                _selectedManager = null; // Şube değişince personel sıfırla
              });
            },
            onManagerChanged: (manager) {
              setState(() {
                _selectedManager = manager;
              });
            },
          ),
          // Section header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primaryContainer.withAlpha(50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                        '${_currentSectionIndex + 1}/${sections.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentSection.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${currentSection.items.length} madde',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
          // Items list
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sections.length,
              onPageChanged: (index) {
                setState(() {
                  _currentSectionIndex = index;
                });
              },
              itemBuilder: (context, sectionIndex) {
                final section = sections[sectionIndex];
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: section.items.length,
                  itemBuilder: (context, itemIndex) {
                    final item = section.items[itemIndex];
                    return _FormItemCard(
                      key: ValueKey(item.id),
                      item: item,
                      itemIndex: itemIndex + 1,
                      selectedResult: _answers[item.id],
                      comment: _comments[item.id],
                      onResultChanged: (result) {
                        setState(() {
                          _answers[item.id] = result;
                        });
                      },
                      onCommentChanged: (comment) {
                        setState(() {
                          _comments[item.id] = comment;
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (_currentSectionIndex > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _goToPreviousSection,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Önceki'),
                      ),
                    ),
                  if (_currentSectionIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _currentSectionIndex < sections.length - 1
                        ? FilledButton.icon(
                            onPressed: _goToNextSection,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Sonraki'),
                          )
                        : FilledButton.icon(
                            onPressed: _isSubmitting ? null : _submitForm,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(
                                _isSubmitting ? 'Gönderiliyor...' : 'Tamamla'),
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

  double _calculateProgress() {
    final allItems = widget.form.sections.expand((s) => s.items).toList();
    if (allItems.isEmpty) return 0;

    final answeredCount =
        allItems.where((item) => _answers.containsKey(item.id)).length;
    return answeredCount / allItems.length;
  }

  void _goToPreviousSection() {
    if (_currentSectionIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextSection() {
    final currentSection = widget.form.sections[_currentSectionIndex];
    final requiredItems =
        currentSection.items.where((item) => item.isRequired).toList();

    // Zorunlu maddeleri kontrol et
    for (final item in requiredItems) {
      if (!_answers.containsKey(item.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lütfen zorunlu maddeleri doldurun: ${item.label}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    if (_currentSectionIndex < widget.form.sections.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitForm() async {
    // Şube seçimi kontrolü
    if (_selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen bir şube seçin'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Şube müdürü seçimi kontrolü
    if (_selectedManager == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen şube müdürünü seçin'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Tüm zorunlu maddeleri kontrol et
    final allItems = widget.form.sections.expand((s) => s.items).toList();
    final requiredItems = allItems.where((item) => item.isRequired).toList();

    for (final item in requiredItems) {
      if (!_answers.containsKey(item.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lütfen tüm zorunlu maddeleri doldurun'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authState = ref.read(authProvider);
      final repo = ref.read(formsRepositoryProvider);

      await authState.whenOrNull(
        authenticated: (user) async {
          // Oturum oluştur - seçilen şube ve personel için
          _sessionId = await repo.createSession(
            formVersionId: widget.form.formVersionId,
            branchId: _selectedBranch!.id,
            evaluatorId: user.id,
            evaluatedUserId: _selectedManager?.id,
          );

          // Puanları hesapla ve cevapları topla
          double totalPositive = 0;
          double totalNegative = 0;
          double totalPossible = 0;
          final List<Map<String, dynamic>> responses = [];

          for (final item in allItems) {
            totalPossible += item.positivePoints;

            final result = _answers[item.id];
            if (result != null) {
              double points = 0;
              switch (result) {
                case FormItemResult.positive:
                  points = item.positivePoints;
                  totalPositive += points;
                  break;
                case FormItemResult.negative:
                  points = -item.negativePoints;
                  totalNegative += item.negativePoints;
                  break;
                case FormItemResult.neutral:
                  points = item.positivePoints / 2;
                  totalPositive += points;
                  break;
                case FormItemResult.notApplicable:
                  totalPossible -= item.positivePoints;
                  break;
              }

              // Cevabı listeye ekle
              responses.add({
                'item_id': item.id,
                'result': result.name == 'notApplicable'
                    ? 'not_applicable'
                    : result.name,
                'points_awarded': points,
                'comment': _comments[item.id],
              });
            }
          }

          // Tüm cevapları tek seferde kaydet (batch insert)
          await repo.saveAllItemResponses(
            sessionId: _sessionId!,
            responses: responses,
          );

          // Oturumu tamamla
          await repo.completeSession(
            sessionId: _sessionId!,
            totalPositive: totalPositive,
            totalNegative: totalNegative,
            totalPossible: totalPossible,
          );
        },
      );

      if (mounted) {
        // Başarılı mesajı göster ve geri dön
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Form başarıyla kaydedildi! (${_selectedBranch!.name} - ${_selectedManager!.displayName})'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        // Provider'ları invalidate et
        ref.invalidate(completedSessionsProvider);
        ref.invalidate(rmCompletedSessionsProvider);

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

/// Şube ve Şube Müdürü seçim widget'ı
class _BranchManagerSelector extends ConsumerWidget {
  const _BranchManagerSelector({
    required this.selectedBranch,
    required this.selectedManager,
    required this.branchesAsync,
    required this.onBranchChanged,
    required this.onManagerChanged,
  });

  final ManagedBranch? selectedBranch;
  final BranchPersonnel? selectedManager;
  final AsyncValue<List<ManagedBranch>> branchesAsync;
  final void Function(ManagedBranch?) onBranchChanged;
  final void Function(BranchPersonnel?) onManagerChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(50),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Şube Seçimi
          Row(
            children: [
              Icon(
                Icons.store,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Şube:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: branchesAsync.when(
                  loading: () => const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const Text('Şubeler yüklenemedi'),
                  data: (branches) => DropdownButtonFormField<ManagedBranch>(
                    initialValue: selectedBranch,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    hint: const Text('Şube seçin'),
                    items: branches.map((branch) {
                      return DropdownMenuItem(
                        value: branch,
                        child: Text(
                          branch.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: onBranchChanged,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Şube Müdürü Seçimi
          Row(
            children: [
              Icon(
                Icons.person,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Şube Müdürü:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: selectedBranch == null
                    ? Text(
                        'Önce şube seçin',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(100),
                        ),
                      )
                    : _BranchManagerDropdown(
                        branchId: selectedBranch!.id,
                        selectedManager: selectedManager,
                        onChanged: onManagerChanged,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Şube müdürü dropdown widget'ı
class _BranchManagerDropdown extends ConsumerWidget {
  const _BranchManagerDropdown({
    required this.branchId,
    required this.selectedManager,
    required this.onChanged,
  });

  final String branchId;
  final BranchPersonnel? selectedManager;
  final void Function(BranchPersonnel?) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final personnelAsync = ref.watch(
      branchPersonnelProvider(BranchPersonnelScope(branchId)),
    );

    return personnelAsync.when(
      loading: () => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Text('Personel yüklenemedi'),
      data: (personnel) {
        // Sadece şube müdürlerini filtrele
        final managers = personnel
            .where((p) => p.role == 'sube_muduru' && p.isActive)
            .toList();

        if (managers.isEmpty) {
          return Text(
            'Bu şubede müdür bulunmuyor',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          );
        }

        return DropdownButtonFormField<BranchPersonnel>(
          initialValue: selectedManager,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          hint: const Text('Müdür seçin'),
          items: managers.map((manager) {
            return DropdownMenuItem(
              value: manager,
              child: Text(
                manager.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        );
      },
    );
  }
}

/// Form maddesi kartı
class _FormItemCard extends StatefulWidget {
  const _FormItemCard({
    super.key,
    required this.item,
    required this.itemIndex,
    required this.selectedResult,
    required this.comment,
    required this.onResultChanged,
    required this.onCommentChanged,
  });

  final FormItem item;
  final int itemIndex;
  final FormItemResult? selectedResult;
  final String? comment;
  final void Function(FormItemResult) onResultChanged;
  final void Function(String) onCommentChanged;

  @override
  State<_FormItemCard> createState() => _FormItemCardState();
}

class _FormItemCardState extends State<_FormItemCard> {
  bool _showComment = false;
  late TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.comment);
    _showComment = widget.comment?.isNotEmpty ?? false;
  }

  @override
  void didUpdateWidget(covariant _FormItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.comment != oldWidget.comment) {
      _commentController.text = widget.comment ?? '';
      if ((widget.comment?.isNotEmpty ?? false) && !_showComment) {
        _showComment = true;
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: widget.item.isRequired && widget.selectedResult == null
            ? BorderSide(color: theme.colorScheme.error.withAlpha(100))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Madde başlığı
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.itemIndex}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.item.isRequired)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Zorunlu',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (widget.item.positivePoints > 0 ||
                          widget.item.negativePoints > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${widget.item.positivePoints.toStringAsFixed(0)} / -${widget.item.negativePoints.toStringAsFixed(0)} puan',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Cevap butonları
            Wrap(
              spacing: 6,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ResultButton(
                  result: FormItemResult.positive,
                  isSelected: widget.selectedResult == FormItemResult.positive,
                  onTap: () => widget.onResultChanged(FormItemResult.positive),
                ),
                _ResultButton(
                  result: FormItemResult.negative,
                  isSelected: widget.selectedResult == FormItemResult.negative,
                  onTap: () => widget.onResultChanged(FormItemResult.negative),
                ),
                _ResultButton(
                  result: FormItemResult.neutral,
                  isSelected: widget.selectedResult == FormItemResult.neutral,
                  onTap: () => widget.onResultChanged(FormItemResult.neutral),
                ),
                _ResultButton(
                  result: FormItemResult.notApplicable,
                  isSelected:
                      widget.selectedResult == FormItemResult.notApplicable,
                  onTap: () =>
                      widget.onResultChanged(FormItemResult.notApplicable),
                ),
                IconButton(
                  icon: Icon(
                    _showComment ? Icons.comment : Icons.comment_outlined,
                    size: 20,
                    color: _showComment
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withAlpha(100),
                  ),
                  onPressed: () {
                    setState(() {
                      _showComment = !_showComment;
                    });
                  },
                  tooltip: 'Yorum ekle',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            // Yorum alanı
            if (_showComment) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Yorum ekle...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                maxLines: 2,
                onChanged: widget.onCommentChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultButton extends StatelessWidget {
  const _ResultButton({
    required this.result,
    required this.isSelected,
    required this.onTap,
  });

  final FormItemResult result;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color getColor() {
      switch (result) {
        case FormItemResult.positive:
          return Colors.green;
        case FormItemResult.negative:
          return Colors.red;
        case FormItemResult.neutral:
          return Colors.orange;
        case FormItemResult.notApplicable:
          return Colors.grey;
      }
    }

    IconData getIcon() {
      switch (result) {
        case FormItemResult.positive:
          return Icons.check_circle;
        case FormItemResult.negative:
          return Icons.cancel;
        case FormItemResult.neutral:
          return Icons.remove_circle;
        case FormItemResult.notApplicable:
          return Icons.block;
      }
    }

    final color = getColor();

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(40) : color.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withAlpha(120),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              getIcon(),
              size: 16,
              color: isSelected ? color : color.withAlpha(180),
            ),
            const SizedBox(width: 3),
            Text(
              result.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : color.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
