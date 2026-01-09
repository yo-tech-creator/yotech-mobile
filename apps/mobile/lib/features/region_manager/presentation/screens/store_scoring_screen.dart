import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../domain/models/managed_branch.dart';
import '../../domain/models/store_scoring_models.dart';
import '../../domain/providers/region_manager_providers.dart';

typedef _SessionEntryLabelResolver = String Function(
  StoreScoringSessionEntry entry,
  int index,
);

class StoreScoringScreen extends ConsumerStatefulWidget {
  const StoreScoringScreen({super.key});

  @override
  ConsumerState<StoreScoringScreen> createState() => _StoreScoringScreenState();
}

class _StoreScoringScreenState extends ConsumerState<StoreScoringScreen> {
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  final TextEditingController _notesController = TextEditingController();
  final Map<String, StoreScoringItemResult?> _selections =
      <String, StoreScoringItemResult?>{};
  final Map<String, StoreScoringItem> _items = <String, StoreScoringItem>{};

  StoreScoringForm? _activeForm;
  String? _selectedFormVersionId;
  String? _selectedBranchId;
  double _maxScore = 0;
  bool _isCreating = false;
  bool _isSubmitting = false;
  String? _editingSessionId;
  DateTime? _editingOriginalScoredAt;
  StoreScoringSessionDetail? _cachedSessionDetail;
  String? _cachedSessionDetailId;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  _SessionEntryLabelResolver _createEntryLabelResolver(
    String formVersionId,
    List<StoreScoringForm> forms,
  ) {
    final matchingForm = forms.firstWhereOrNull(
      (form) => form.formVersionId == formVersionId,
    );

    if (matchingForm == null) {
      return (entry, index) {
        final fromBackend = entry.label.trim();
        if (fromBackend.isNotEmpty) {
          return fromBackend;
        }
        return 'Madde ${index + 1}';
      };
    }

    final itemsById = <String, StoreScoringItem>{
      for (final section in matchingForm.sections)
        for (final item in section.items) item.id: item,
    };

    return (entry, index) {
      final fromBackend = entry.label.trim();
      if (fromBackend.isNotEmpty) {
        return fromBackend;
      }
      final fromForm = itemsById[entry.itemId]?.label.trim() ?? '';
      if (fromForm.isNotEmpty) {
        return fromForm;
      }
      return 'Madde ${index + 1}';
    };
  }

  void _ensureActiveForm(List<StoreScoringForm> forms) {
    if (forms.isEmpty) {
      if (_activeForm != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _activeForm = null;
            _selectedFormVersionId = null;
            _items.clear();
            _selections.clear();
            _maxScore = 0;
          });
        });
      }
      return;
    }

    final desiredForm = forms.firstWhereOrNull(
          (form) => form.formVersionId == _selectedFormVersionId,
        ) ??
        forms.first;

    if (_activeForm?.formVersionId == desiredForm.formVersionId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _setActiveForm(desiredForm));
    });
  }

  void _setActiveForm(StoreScoringForm form) {
    _activeForm = form;
    _selectedFormVersionId = form.formVersionId;
    _items
      ..clear()
      ..addEntries(
        form.sections.expand((section) => section.items).map(
              (item) => MapEntry(item.id, item),
            ),
      );
    _selections
      ..clear()
      ..addEntries(
        _items.keys.map(
          (id) => MapEntry(id, null),
        ),
      );
    _maxScore =
        _items.values.fold<double>(0, (sum, item) => sum + item.positivePoints);
  }

  void _ensureSelectedBranch(List<ManagedBranch> branches) {
    if (branches.isEmpty) {
      if (_selectedBranchId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedBranchId = null);
        });
      }
      return;
    }

    final exists = branches.any((branch) => branch.id == _selectedBranchId);
    if (!exists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedBranchId = branches.first.id);
      });
    }
  }

  void _toggleResult(StoreScoringItem item, StoreScoringItemResult result) {
    setState(() {
      final current = _selections[item.id];
      if (current == result) {
        _selections[item.id] = null;
      } else {
        _selections[item.id] = result;
      }
    });
  }

  void _clearSelections() {
    for (final key in _selections.keys) {
      _selections[key] = null;
    }
  }

  void _resetSelections() {
    setState(_clearSelections);
  }

  void _beginNewSession() {
    setState(() {
      _isCreating = true;
      _editingSessionId = null;
      _editingOriginalScoredAt = null;
      _clearSelections();
    });
    _notesController.clear();
  }

  void _cancelNewSession() {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _isCreating = false;
      _editingSessionId = null;
      _editingOriginalScoredAt = null;
      _clearSelections();
    });
    _notesController.clear();
  }

  _ScoringSnapshot _snapshot() {
    var totalPositive = 0.0;
    var totalNegative = 0.0;
    var positiveCount = 0;
    var negativeCount = 0;
    var naCount = 0;
    var pendingCount = 0;

    _selections.forEach((itemId, selection) {
      final item = _items[itemId];
      if (item == null) {
        return;
      }
      switch (selection) {
        case StoreScoringItemResult.positive:
          totalPositive += item.positivePoints;
          positiveCount++;
          break;
        case StoreScoringItemResult.negative:
          totalNegative += item.negativePoints;
          negativeCount++;
          break;
        case StoreScoringItemResult.notApplicable:
          naCount++;
          break;
        case null:
          pendingCount++;
          break;
      }
    });

    final totalScore = totalPositive - totalNegative;

    return _ScoringSnapshot(
      totalPositive: totalPositive,
      totalNegative: totalNegative,
      totalScore: totalScore,
      positiveCount: positiveCount,
      negativeCount: negativeCount,
      notApplicableCount: naCount,
      pendingCount: pendingCount,
    );
  }

  Future<void> _submitForm(
    StoreScoringHistoryScope? historyScope,
    UserModel managerUser,
  ) async {
    final form = _activeForm;
    final branchId = _selectedBranchId;

    if (form == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seçili form bulunamadı.')),
      );
      return;
    }
    if (branchId == null || branchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şube seçmelisiniz.')),
      );
      return;
    }

    final missingRequired = _items.values.where((item) {
      if (!item.isRequired) {
        return false;
      }
      final selection = _selections[item.id];
      return selection != StoreScoringItemResult.positive &&
          selection != StoreScoringItemResult.negative;
    }).toList(growable: false);

    if (missingRequired.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Zorunlu maddeler için olumlu veya olumsuz seçim yapmalısınız.'),
        ),
      );
      return;
    }

    final snapshot = _snapshot();
    final entries = _items.values.map((item) {
      final selection = _selections[item.id];
      final result = selection ?? StoreScoringItemResult.notApplicable;
      final pointsAwarded = switch (result) {
        StoreScoringItemResult.positive => item.positivePoints,
        StoreScoringItemResult.negative => -item.negativePoints,
        StoreScoringItemResult.notApplicable => 0.0,
      };

      return StoreScoringSubmissionEntry(
        itemId: item.id,
        result: result,
        pointsAwarded: pointsAwarded,
        positivePoints: item.positivePoints,
        negativePoints: item.negativePoints,
        comment: null,
      );
    }).toList(growable: false);

    final scoredAt =
        _editingSessionId != null && _editingOriginalScoredAt != null
            ? _editingOriginalScoredAt!
            : DateTime.now();

    final submission = StoreScoringSubmission(
      tenantId: managerUser.tenantId,
      branchId: branchId,
      evaluatorId: managerUser.id,
      formVersionId: form.formVersionId,
      scoredAt: scoredAt,
      totalPositive: snapshot.totalPositive,
      totalNegative: snapshot.totalNegative,
      totalPossible: _maxScore,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      entries: entries,
    );

    setState(() => _isSubmitting = true);
    final repository = ref.read(storeScoringRepositoryProvider);
    final editingSessionId = _editingSessionId;

    final editingTargetId = editingSessionId;
    String? createdSessionId;
    final isEditing = editingTargetId != null;

    try {
      if (editingTargetId != null) {
        await repository.updateSession(editingTargetId, submission);
      } else {
        createdSessionId = await repository.submitSession(submission);
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _editingSessionId = null;
        _editingOriginalScoredAt = null;
        _isCreating = false;
        _clearSelections();
        _cachedSessionDetail = null;
        _cachedSessionDetailId = null;
      });
      _notesController.clear();

      if (historyScope != null) {
        ref.invalidate(storeScoringHistoryProvider(historyScope));
      }

      _logUi(
        'submitForm success editing=$isEditing branch=$branchId formVersion=${form.formVersionId} sessionId=${editingTargetId ?? createdSessionId}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Puanlama güncellendi.' : 'Puanlama kaydedildi.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logUi('submitForm error', error: error, stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydetme başarısız: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<StoreScoringSessionDetail> _loadSessionDetail(String sessionId) async {
    if (_cachedSessionDetailId == sessionId && _cachedSessionDetail != null) {
      return _cachedSessionDetail!;
    }

    final repository = ref.read(storeScoringRepositoryProvider);
    final detail = await repository.fetchSessionDetail(sessionId);
    if (mounted) {
      setState(() {
        _cachedSessionDetail = detail;
        _cachedSessionDetailId = sessionId;
      });
    }
    return detail;
  }

  Future<void> _openSessionDetail(
    StoreScoringSessionSummary summary,
    String branchName,
    List<StoreScoringForm> forms,
    List<ManagedBranch> branches,
  ) async {
    _logUi('openSessionDetail request sessionId=${summary.id}');
    try {
      final detail = await _loadSessionDetail(summary.id);
      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => _SessionDetailSheet(
          detail: detail,
          branchName: branchName,
          dateFormat: _dateFormat,
          labelResolver: _createEntryLabelResolver(detail.formVersionId, forms),
          onEdit: () {
            Navigator.of(context).pop();
            _startEditingFromDetail(detail, forms, branches);
          },
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Detay yüklenemedi: $error')),
        );
      }
    }
  }

  void _startEditingFromDetail(
    StoreScoringSessionDetail detail,
    List<StoreScoringForm> forms,
    List<ManagedBranch> branches,
  ) {
    final matchingForm = forms.firstWhereOrNull(
      (form) => form.formVersionId == detail.formVersionId,
    );

    if (matchingForm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Form sürümü bulunamadı: ${detail.formTitle} v${detail.version}',
          ),
        ),
      );
      return;
    }

    final branchExists = branches.any((branch) => branch.id == detail.branchId);
    if (!branchExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıtlı şube artık mevcut değil.'),
        ),
      );
      return;
    }

    _notesController.text = detail.notes ?? '';

    setState(() {
      _editingSessionId = detail.id;
      _editingOriginalScoredAt = detail.scoredAt;
      _isCreating = true;
      _selectedBranchId = detail.branchId;
      _setActiveForm(matchingForm);
      for (final entry in detail.entries) {
        if (_selections.containsKey(entry.itemId)) {
          _selections[entry.itemId] = entry.result;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final managerUser = authState.maybeWhen<UserModel?>(
      authenticated: (user) => user,
      orElse: () => null,
    );

    final formsAsync = ref.watch(storeScoringFormsProvider);
    final branchesAsync = ref.watch(regionManagerBranchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mağaza Puanlama'),
      ),
      body: formsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _InfoState(
          title: 'Formlar yüklenemedi',
          description: '$error',
          onRetry: () => ref.invalidate(storeScoringFormsProvider),
        ),
        data: (forms) {
          _ensureActiveForm(forms);

          final branches = branchesAsync.maybeWhen<List<ManagedBranch>>(
            data: (data) => data,
            orElse: () => const <ManagedBranch>[],
          );
          final branchesLoading = branchesAsync.isLoading;
          _ensureSelectedBranch(branches);

          if (managerUser == null) {
            return _InfoState(
              title: 'Oturum bilgisi bulunamadı',
              description: 'Devam etmek için tekrar giriş yapmalısınız.',
              onRetry: () {},
            );
          }

          if (forms.isEmpty) {
            return _InfoState(
              title: 'Yayınlanmış form yok',
              description:
                  'Varsayılan formu eklemek için seed fonksiyonunu çalıştırın ve tekrar deneyin.',
              onRetry: () => ref.invalidate(storeScoringFormsProvider),
            );
          }

          final historyScope =
              (_selectedBranchId != null && _selectedBranchId!.isNotEmpty)
                  ? StoreScoringHistoryScope(
                      branchId: _selectedBranchId!,
                      tenantId: managerUser.tenantId,
                    )
                  : null;

          final historyAsync = historyScope != null
              ? ref.watch(storeScoringHistoryProvider(historyScope))
              : null;

          final snapshot = _snapshot();
          final branchNames = {
            for (final branch in branches) branch.id: branch.name,
          };

          final latestSummary =
              historyAsync?.maybeWhen<StoreScoringSessionSummary?>(
            data: (sessions) => sessions.isNotEmpty ? sessions.first : null,
            orElse: () => null,
          );

          final listChildren = <Widget>[];

          if (latestSummary != null) {
            listChildren
              ..add(
                _LatestSessionCard(
                  summary: latestSummary,
                  dateFormat: _dateFormat,
                  isEditing: _editingSessionId == latestSummary.id,
                  onLoadDetail: () => _loadSessionDetail(latestSummary.id),
                  onEdit: (detail) => _startEditingFromDetail(
                    detail,
                    forms,
                    branches,
                  ),
                  labelResolver: _createEntryLabelResolver(
                    latestSummary.formVersionId,
                    forms,
                  ),
                ),
              )
              ..add(const SizedBox(height: 16));
          }

          if (_isCreating) {
            listChildren
              ..add(
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isSubmitting ? null : _cancelNewSession,
                    icon: const Icon(Icons.close),
                    label: Text(
                      _editingSessionId != null
                          ? 'Düzenlemeyi iptal et'
                          : 'Yeni puanlamayı iptal et',
                    ),
                  ),
                ),
              )
              ..add(const SizedBox(height: 8))
              ..add(
                _FormHeaderCard(
                  forms: forms,
                  activeFormId: _selectedFormVersionId,
                  onFormChanged: (formId) {
                    final nextForm = forms.firstWhereOrNull(
                      (form) => form.formVersionId == formId,
                    );
                    if (nextForm != null) {
                      setState(() => _setActiveForm(nextForm));
                    }
                  },
                  branches: branches,
                  branchLoading: branchesLoading,
                  selectedBranchId: _selectedBranchId,
                  onBranchChanged: (branchId) {
                    setState(() => _selectedBranchId = branchId);
                  },
                  notesController: _notesController,
                ),
              )
              ..add(const SizedBox(height: 16))
              ..add(
                _SummaryCard(
                  snapshot: snapshot,
                  maxScore: _maxScore,
                  isSubmitting: _isSubmitting,
                  isEditing: _editingSessionId != null,
                  onSubmit: () => _submitForm(historyScope, managerUser),
                  onReset: _resetSelections,
                ),
              )
              ..add(const SizedBox(height: 16));

            if (_activeForm != null) {
              listChildren.addAll(
                _activeForm!.sections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _StoreScoringSectionCard(
                      section: section,
                      selections: _selections,
                      onSelect: _toggleResult,
                    ),
                  ),
                ),
              );
            }

            listChildren.add(const SizedBox(height: 16));
          } else {
            listChildren
              ..add(
                _HistoryIntroCard(
                  activeForm: _activeForm,
                  branches: branches,
                  branchLoading: branchesLoading,
                  selectedBranchId: _selectedBranchId,
                  onBranchChanged: (branchId) {
                    setState(() => _selectedBranchId = branchId);
                  },
                  onStartNew: _beginNewSession,
                ),
              )
              ..add(const SizedBox(height: 16));
          }

          listChildren
            ..add(
              _HistorySection(
                historyAsync: historyAsync,
                branchNames: branchNames,
                selectedBranchId: _selectedBranchId,
                onOpenDetail: (summary, branchName) => _openSessionDetail(
                  summary,
                  branchName,
                  forms,
                  branches,
                ),
                dateFormat: _dateFormat,
              ),
            )
            ..add(const SizedBox(height: 24));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(storeScoringFormsProvider);
              ref.invalidate(regionManagerBranchesProvider);
              if (historyScope != null) {
                ref.invalidate(storeScoringHistoryProvider(historyScope));
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: listChildren,
            ),
          );
        },
      ),
    );
  }
}

class _ScoringSnapshot {
  const _ScoringSnapshot({
    required this.totalPositive,
    required this.totalNegative,
    required this.totalScore,
    required this.positiveCount,
    required this.negativeCount,
    required this.notApplicableCount,
    required this.pendingCount,
  });

  final double totalPositive;
  final double totalNegative;
  final double totalScore;
  final int positiveCount;
  final int negativeCount;
  final int notApplicableCount;
  final int pendingCount;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.snapshot,
    required this.maxScore,
    required this.onReset,
    required this.onSubmit,
    required this.isSubmitting,
    required this.isEditing,
  });

  final _ScoringSnapshot snapshot;
  final double maxScore;
  final VoidCallback onReset;
  final VoidCallback onSubmit;
  final bool isSubmitting;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Özet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Net Puan: ${snapshot.totalScore.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(1)}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Olumlu: ${snapshot.positiveCount} • Olumsuz: ${snapshot.negativeCount} • N/A: ${snapshot.notApplicableCount} • Bekleyen: ${snapshot.pendingCount}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: isSubmitting ? null : onSubmit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(isEditing ? 'Güncelle' : 'Kaydet'),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: isSubmitting ? null : onReset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Seçimleri Temizle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreScoringSectionCard extends StatelessWidget {
  const _StoreScoringSectionCard({
    required this.section,
    required this.selections,
    required this.onSelect,
  });

  final StoreScoringSection section;
  final Map<String, StoreScoringItemResult?> selections;
  final void Function(StoreScoringItem item, StoreScoringItemResult result)
      onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < section.items.length; i++) ...[
              _StoreScoringItemRow(
                item: section.items[i],
                selection: selections[section.items[i].id],
                onSelect: onSelect,
              ),
              if (i < section.items.length - 1) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoreScoringItemRow extends StatelessWidget {
  const _StoreScoringItemRow({
    required this.item,
    required this.selection,
    required this.onSelect,
  });

  final StoreScoringItem item;
  final StoreScoringItemResult? selection;
  final void Function(StoreScoringItem item, StoreScoringItemResult result)
      onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle_outline, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _ScoreChoiceChip(
                      label: 'Olumlu',
                      selected: selection == StoreScoringItemResult.positive,
                      onTap: () => onSelect(
                        item,
                        StoreScoringItemResult.positive,
                      ),
                    ),
                    _ScoreChoiceChip(
                      label: 'Olumsuz',
                      selected: selection == StoreScoringItemResult.negative,
                      onTap: () => onSelect(
                        item,
                        StoreScoringItemResult.negative,
                      ),
                    ),
                    _ScoreChoiceChip(
                      label: 'N/A',
                      selected:
                          selection == StoreScoringItemResult.notApplicable,
                      onTap: () => onSelect(
                        item,
                        StoreScoringItemResult.notApplicable,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Puan: +${item.positivePoints.toStringAsFixed(1)} / -${item.negativePoints.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.isRequired)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Zorunlu madde',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
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

class _ScoreChoiceChip extends StatelessWidget {
  const _ScoreChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _FormHeaderCard extends StatelessWidget {
  const _FormHeaderCard({
    required this.forms,
    required this.activeFormId,
    required this.onFormChanged,
    required this.branches,
    required this.branchLoading,
    required this.selectedBranchId,
    required this.onBranchChanged,
    required this.notesController,
  });

  final List<StoreScoringForm> forms;
  final String? activeFormId;
  final ValueChanged<String?> onFormChanged;
  final List<ManagedBranch> branches;
  final bool branchLoading;
  final String? selectedBranchId;
  final ValueChanged<String?> onBranchChanged;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Form ve Şube', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: activeFormId,
              items: forms
                  .map(
                    (form) => DropdownMenuItem<String>(
                      value: form.formVersionId,
                      child: Text('${form.title} v${form.version}'),
                    ),
                  )
                  .toList(),
              onChanged: onFormChanged,
              decoration: const InputDecoration(
                labelText: 'Form',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedBranchId,
              isExpanded: true,
              items: branches
                  .map(
                    (branch) => DropdownMenuItem<String>(
                      value: branch.id,
                      child: Text(branch.name),
                    ),
                  )
                  .toList(),
              onChanged: branchLoading ? null : onBranchChanged,
              decoration: InputDecoration(
                labelText: branchLoading ? 'Şubeler yükleniyor...' : 'Şube',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notlar (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryIntroCard extends StatelessWidget {
  const _HistoryIntroCard({
    required this.branches,
    required this.branchLoading,
    required this.selectedBranchId,
    required this.onBranchChanged,
    required this.onStartNew,
    this.activeForm,
  });

  final List<ManagedBranch> branches;
  final bool branchLoading;
  final String? selectedBranchId;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onStartNew;
  final StoreScoringForm? activeForm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Geçmiş Puanlamalar', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Şubeyi seçip geçmiş kayıtları inceleyebilir veya yeni bir mağaza puanlaması başlatabilirsiniz.',
              style: theme.textTheme.bodyMedium,
            ),
            if (activeForm != null) ...[
              const SizedBox(height: 12),
              Text(
                'Aktif form: ${activeForm!.title} v${activeForm!.version}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedBranchId,
              isExpanded: true,
              items: branches
                  .map(
                    (branch) => DropdownMenuItem<String>(
                      value: branch.id,
                      child: Text(branch.name),
                    ),
                  )
                  .toList(),
              onChanged: branchLoading ? null : onBranchChanged,
              decoration: InputDecoration(
                labelText: branchLoading ? 'Şubeler yükleniyor...' : 'Şube',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onStartNew,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Yeni puanlama oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestSessionCard extends StatefulWidget {
  const _LatestSessionCard({
    required this.summary,
    required this.dateFormat,
    required this.onLoadDetail,
    required this.onEdit,
    required this.labelResolver,
    required this.isEditing,
  });

  final StoreScoringSessionSummary summary;
  final DateFormat dateFormat;
  final Future<StoreScoringSessionDetail> Function() onLoadDetail;
  final void Function(StoreScoringSessionDetail detail) onEdit;
  final _SessionEntryLabelResolver labelResolver;
  final bool isEditing;

  @override
  State<_LatestSessionCard> createState() => _LatestSessionCardState();
}

class _LatestSessionCardState extends State<_LatestSessionCard> {
  bool _expanded = false;
  bool _loading = false;
  Object? _error;
  StoreScoringSessionDetail? _detail;

  void _toggleExpanded() {
    final next = !_expanded;
    setState(() => _expanded = next);
    if (next && _detail == null && !_loading) {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await widget.onLoadDetail();
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _handleEdit() async {
    if (_loading) {
      return;
    }
    if (_detail == null) {
      await _loadDetail();
      if (!mounted || _detail == null) {
        return;
      }
    }
    widget.onEdit(_detail!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final netScore =
        widget.summary.totalPositive - widget.summary.totalNegative;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _toggleExpanded,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Son Puanlama',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.summary.formTitle} v${widget.summary.version}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.dateFormat.format(widget.summary.scoredAt)} • Net: ${netScore.toStringAsFixed(1)} / ${widget.summary.totalPossible.toStringAsFixed(1)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if ((widget.summary.notes ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Not: ${widget.summary.notes}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (widget.isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.edit,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Bu kaydı düzenliyorsunuz',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detay yüklenemedi: $_error',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _loadDetail,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tekrar dene'),
                      ),
                    ),
                  ],
                )
              else if (_detail != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Puan: ${(_detail!.totalPositive - _detail!.totalNegative).toStringAsFixed(1)} / ${_detail!.totalPossible.toStringAsFixed(1)}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if ((_detail!.notes ?? '').isNotEmpty) ...[
                      Text('Notlar', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(_detail!.notes ?? ''),
                      const SizedBox(height: 8),
                    ],
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: _detail!.entries.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final entry = _detail!.entries[index];
                          final label = widget.labelResolver(entry, index);
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              _SessionDetailSheet._iconFor(entry.result),
                            ),
                            title: Text(
                              label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Cevap: ${_SessionDetailSheet._resultLabel(entry.result)}',
                                ),
                                if (entry.comment?.isNotEmpty == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text('Not: ${entry.comment!}'),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              _SessionDetailSheet._pointsLabel(entry),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: widget.isEditing ? null : _handleEdit,
                        icon: const Icon(Icons.edit),
                        label: const Text('Düzenle'),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.historyAsync,
    required this.branchNames,
    required this.onOpenDetail,
    required this.dateFormat,
    this.selectedBranchId,
  });

  final AsyncValue<List<StoreScoringSessionSummary>>? historyAsync;
  final Map<String, String> branchNames;
  final Future<void> Function(
      StoreScoringSessionSummary summary, String branchName) onOpenDetail;
  final DateFormat dateFormat;
  final String? selectedBranchId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Geçmiş Formlar', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (historyAsync == null)
              Text(
                'Şube seçildiğinde geçmiş kayıtlar görüntülenir.',
                style: theme.textTheme.bodyMedium,
              )
            else
              historyAsync!.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Text(
                  'Geçmiş listelenemedi: $error',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                data: (sessions) {
                  _logUi(
                    'HistorySection data branch=${selectedBranchId ?? 'none'} rows=${sessions.length}',
                  );
                  if (sessions.isEmpty) {
                    return Text(
                      'Bu şube için kayıt bulunmuyor.',
                      style: theme.textTheme.bodyMedium,
                    );
                  }

                  return Column(
                    children: sessions.map((session) {
                      final branchName =
                          branchNames[session.branchId] ?? 'Bilinmeyen şube';
                      final netScore =
                          session.totalPositive - session.totalNegative;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history),
                          title: Text(
                            '${session.formTitle} v${session.version}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            '$branchName • ${dateFormat.format(session.scoredAt)}\nNet: ${netScore.toStringAsFixed(1)} / ${session.totalPossible.toStringAsFixed(1)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => onOpenDetail(session, branchName),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

void _logUi(
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  const name = 'StoreScoringScreen';
  debugPrint('[$name] $message${error != null ? ' | error: $error' : ''}');
  if (stackTrace != null) {
    debugPrint(stackTrace.toString());
  }
}

class _SessionDetailSheet extends StatelessWidget {
  const _SessionDetailSheet({
    required this.detail,
    required this.branchName,
    required this.dateFormat,
    required this.labelResolver,
    this.onEdit,
  });

  final StoreScoringSessionDetail detail;
  final String branchName;
  final DateFormat dateFormat;
  final _SessionEntryLabelResolver labelResolver;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${detail.formTitle} v${detail.version}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    tooltip: 'Kaydı düzenle',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$branchName • ${dateFormat.format(detail.scoredAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Net Puan: ${(detail.totalPositive - detail.totalNegative).toStringAsFixed(1)} / ${detail.totalPossible.toStringAsFixed(1)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if ((detail.notes ?? '').isNotEmpty) ...[
              Text('Notlar', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(detail.notes ?? ''),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: ListView.separated(
                itemCount: detail.entries.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = detail.entries[index];
                  final label = labelResolver(entry, index);
                  return ListTile(
                    dense: true,
                    leading: Icon(_iconFor(entry.result)),
                    title: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Cevap: ${_resultLabel(entry.result)}'),
                        if (entry.comment?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('Not: ${entry.comment!}'),
                          ),
                      ],
                    ),
                    trailing: Text(
                      _pointsLabel(entry),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(StoreScoringItemResult result) {
    switch (result) {
      case StoreScoringItemResult.positive:
        return Icons.check_circle;
      case StoreScoringItemResult.negative:
        return Icons.highlight_off;
      case StoreScoringItemResult.notApplicable:
        return Icons.horizontal_rule;
    }
  }

  static String _pointsLabel(StoreScoringSessionEntry entry) {
    switch (entry.result) {
      case StoreScoringItemResult.positive:
        return '+${entry.pointsAwarded.toStringAsFixed(1)}';
      case StoreScoringItemResult.negative:
        return entry.pointsAwarded.toStringAsFixed(1);
      case StoreScoringItemResult.notApplicable:
        return 'N/A';
    }
  }

  static String _resultLabel(StoreScoringItemResult result) {
    switch (result) {
      case StoreScoringItemResult.positive:
        return 'Olumlu';
      case StoreScoringItemResult.negative:
        return 'Olumsuz';
      case StoreScoringItemResult.notApplicable:
        return 'N/A';
    }
  }
}

class _InfoState extends StatelessWidget {
  const _InfoState({
    required this.title,
    required this.description,
    required this.onRetry,
  });

  final String title;
  final String description;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
