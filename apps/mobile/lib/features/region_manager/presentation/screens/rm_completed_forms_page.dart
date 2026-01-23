import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../forms/domain/models/form_models.dart';
import '../../../forms/presentation/providers/forms_providers.dart';
import '../../../forms/presentation/screens/form_session_detail_page.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../domain/models/managed_branch.dart';
import '../../domain/providers/region_manager_providers.dart';

/// Bölge Müdürü için tamamlanmış formlar filtresi
class RmCompletedSessionsFilter {
  const RmCompletedSessionsFilter({
    this.branchId,
    this.formVersionId,
    this.startDate,
    this.endDate,
    this.onlyMine = false,
  });

  final String? branchId;
  final String? formVersionId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool onlyMine;

  bool get hasFilter =>
      branchId != null ||
      formVersionId != null ||
      startDate != null ||
      endDate != null ||
      onlyMine;

  RmCompletedSessionsFilter copyWith({
    String? branchId,
    String? formVersionId,
    DateTime? startDate,
    DateTime? endDate,
    bool? onlyMine,
    bool clearBranch = false,
    bool clearForm = false,
  }) {
    return RmCompletedSessionsFilter(
      branchId: clearBranch ? null : branchId ?? this.branchId,
      formVersionId: clearForm ? null : formVersionId ?? this.formVersionId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      onlyMine: onlyMine ?? this.onlyMine,
    );
  }
}

/// Bölge Müdürü için filtre provider
final rmCompletedSessionsFilterProvider =
    StateProvider<RmCompletedSessionsFilter>((ref) {
  return const RmCompletedSessionsFilter();
});

/// Bölge Müdürü için tamamlanmış formlar provider
final rmCompletedSessionsProvider =
    FutureProvider.autoDispose<List<FormSession>>((ref) async {
  final authState = ref.watch(authProvider);
  final filter = ref.watch(rmCompletedSessionsFilterProvider);
  final repo = ref.watch(formsRepositoryProvider);
  final branchesAsync = ref.watch(regionManagerBranchesProvider);

  return authState.maybeWhen(
    authenticated: (user) async {
      // Sadece benim doldurduklarım filtresi
      if (filter.onlyMine) {
        return repo.fetchCompletedSessions(
          tenantId: user.tenantId,
          evaluatorId: user.id,
          branchId: filter.branchId,
          formVersionId: filter.formVersionId,
          startDate: filter.startDate,
          endDate: filter.endDate,
        );
      }

      // Yönetilen şubeleri al
      final branches = await branchesAsync.when(
        data: (data) async => data,
        loading: () async => <ManagedBranch>[],
        error: (_, __) async => <ManagedBranch>[],
      );

      if (branches.isEmpty) {
        return [];
      }

      // Eğer şube filtresi varsa sadece o şubeyi kullan
      // Yoksa tüm yönetilen şubelerdeki formları getir
      if (filter.branchId != null) {
        return repo.fetchCompletedSessions(
          tenantId: user.tenantId,
          branchId: filter.branchId,
          formVersionId: filter.formVersionId,
          startDate: filter.startDate,
          endDate: filter.endDate,
        );
      }

      // Tüm şubelerdeki formları paralel olarak getir
      final allSessions = <FormSession>[];
      for (final branch in branches) {
        final sessions = await repo.fetchCompletedSessions(
          tenantId: user.tenantId,
          branchId: branch.id,
          formVersionId: filter.formVersionId,
          startDate: filter.startDate,
          endDate: filter.endDate,
        );
        allSessions.addAll(sessions);
      }

      // Tarihe göre sırala
      allSessions.sort((a, b) => b.scoredAt.compareTo(a.scoredAt));

      return allSessions;
    },
    orElse: () => [],
  );
});

/// Bölge Müdürü için tamamlanmış formlar sekmesi
class RmCompletedFormsTab extends ConsumerWidget {
  const RmCompletedFormsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(rmCompletedSessionsProvider);
    final filter = ref.watch(rmCompletedSessionsFilterProvider);
    final branchesAsync = ref.watch(regionManagerBranchesProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Filtreler
        _RmFilterSection(
          filter: filter,
          branchesAsync: branchesAsync,
        ),
        // Liste
        Expanded(
          child: sessionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Veriler yüklenemedi',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('$error',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.invalidate(rmCompletedSessionsProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
            data: (sessions) {
              if (sessions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64,
                          color: theme.colorScheme.onSurface.withAlpha(100)),
                      const SizedBox(height: 16),
                      Text(
                        filter.hasFilter
                            ? 'Filtreye uygun form bulunamadı'
                            : 'Henüz tamamlanmış form yok',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                      if (filter.hasFilter) ...[
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            ref
                                .read(
                                    rmCompletedSessionsFilterProvider.notifier)
                                .state = const RmCompletedSessionsFilter();
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Filtreleri Temizle'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(rmCompletedSessionsProvider);
                  await ref.read(rmCompletedSessionsProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return _SessionCard(session: session);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Bölge Müdürü için filtre bölümü
class _RmFilterSection extends ConsumerStatefulWidget {
  const _RmFilterSection({
    required this.filter,
    required this.branchesAsync,
  });

  final RmCompletedSessionsFilter filter;
  final AsyncValue<List<ManagedBranch>> branchesAsync;

  @override
  ConsumerState<_RmFilterSection> createState() => _RmFilterSectionState();
}

class _RmFilterSectionState extends ConsumerState<_RmFilterSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formsAsync = ref.watch(tenantFormsListProvider);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
      child: Column(
        children: [
          // Filtre toggle
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 20,
                    color: widget.filter.hasFilter
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withAlpha(150),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Filtreler',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: widget.filter.hasFilter
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                  if (widget.filter.hasFilter) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Aktif',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ],
              ),
            ),
          ),
          // Filtre içerikleri
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                children: [
                  // Mağaza ve Form filtreleri yan yana
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mağaza/Şube filtresi
                      Expanded(
                        child: widget.branchesAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (branches) {
                            if (branches.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return DropdownButtonFormField<String?>(
                              initialValue: widget.filter.branchId,
                              decoration: InputDecoration(
                                labelText: 'Mağaza',
                                prefixIcon: const Icon(Icons.store, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                isDense: true,
                              ),
                              isExpanded: true,
                              style: theme.textTheme.bodySmall,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Tüm Mağazalar'),
                                ),
                                ...branches.map((branch) {
                                  return DropdownMenuItem(
                                    value: branch.id,
                                    child: Text(branch.name,
                                        overflow: TextOverflow.ellipsis),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                ref
                                    .read(rmCompletedSessionsFilterProvider
                                        .notifier)
                                    .state = widget.filter.copyWith(
                                  branchId: value,
                                  clearBranch: value == null,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Form filtresi
                      Expanded(
                        child: formsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (forms) {
                            if (forms.isEmpty) return const SizedBox.shrink();

                            return DropdownButtonFormField<String?>(
                              initialValue: widget.filter.formVersionId,
                              decoration: InputDecoration(
                                labelText: 'Form',
                                prefixIcon:
                                    const Icon(Icons.assignment, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                isDense: true,
                              ),
                              isExpanded: true,
                              style: theme.textTheme.bodySmall,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Tüm Formlar'),
                                ),
                                ...forms.map((f) {
                                  return DropdownMenuItem(
                                    value: f['id'] as String,
                                    child: Text(f['title'] as String? ?? '',
                                        overflow: TextOverflow.ellipsis),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                ref
                                    .read(rmCompletedSessionsFilterProvider
                                        .notifier)
                                    .state = widget.filter.copyWith(
                                  formVersionId: value,
                                  clearForm: value == null,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Tarih filtreleri ve switch aynı satırda
                  Row(
                    children: [
                      // Tarihler
                      Expanded(
                        child: _DateFilterButton(
                          label: 'Başlangıç',
                          date: widget.filter.startDate,
                          compact: true,
                          onDateSelected: (date) {
                            ref
                                .read(
                                    rmCompletedSessionsFilterProvider.notifier)
                                .state = widget.filter.copyWith(
                              startDate: date,
                            );
                          },
                          onClear: () {
                            ref
                                .read(
                                    rmCompletedSessionsFilterProvider.notifier)
                                .state = RmCompletedSessionsFilter(
                              branchId: widget.filter.branchId,
                              formVersionId: widget.filter.formVersionId,
                              endDate: widget.filter.endDate,
                              onlyMine: widget.filter.onlyMine,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _DateFilterButton(
                          label: 'Bitiş',
                          date: widget.filter.endDate,
                          compact: true,
                          onDateSelected: (date) {
                            ref
                                .read(
                                    rmCompletedSessionsFilterProvider.notifier)
                                .state = widget.filter.copyWith(
                              endDate: date,
                            );
                          },
                          onClear: () {
                            ref
                                .read(
                                    rmCompletedSessionsFilterProvider.notifier)
                                .state = RmCompletedSessionsFilter(
                              branchId: widget.filter.branchId,
                              formVersionId: widget.filter.formVersionId,
                              startDate: widget.filter.startDate,
                              onlyMine: widget.filter.onlyMine,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Sadece benim doldurduklarım switch (kompakt)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: widget.filter.onlyMine
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withAlpha(80),
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: widget.filter.onlyMine
                              ? theme.colorScheme.primaryContainer.withAlpha(50)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: widget.filter.onlyMine
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withAlpha(150),
                            ),
                            const SizedBox(width: 4),
                            Switch(
                              value: widget.filter.onlyMine,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (value) {
                                ref
                                    .read(rmCompletedSessionsFilterProvider
                                        .notifier)
                                    .state = widget.filter.copyWith(
                                  onlyMine: value,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Temizle butonu
                  if (widget.filter.hasFilter)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            ref
                                .read(
                                    rmCompletedSessionsFilterProvider.notifier)
                                .state = const RmCompletedSessionsFilter();
                          },
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Filtreleri Temizle',
                              style: TextStyle(fontSize: 12)),
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

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.label,
    required this.date,
    required this.onDateSelected,
    required this.onClear,
    this.compact = false,
  });

  final String label;
  final DateTime? date;
  final void Function(DateTime) onDateSelected;
  final VoidCallback onClear;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          locale: const Locale('tr', 'TR'),
        );
        if (selectedDate != null) {
          onDateSelected(selectedDate);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withAlpha(80)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: compact ? 14 : 16,
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                date != null ? dateFormat.format(date!) : label,
                style: TextStyle(
                  fontSize: compact ? 11 : null,
                  color: date != null
                      ? null
                      : theme.colorScheme.onSurface.withAlpha(100),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: compact ? 14 : 16,
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Oturum kartı
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final FormSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    // Skor rengi
    Color getScoreColor() {
      if (session.score >= 80) return Colors.green;
      if (session.score >= 60) return Colors.orange;
      return Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FormSessionDetailPage(session: session),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.formTitle ?? 'Form',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Skor
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: getScoreColor().withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '%${session.score.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: getScoreColor(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Mağaza bilgisi - öne çıkarılmış
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.store,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      session.branchName ?? 'Şube',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Detaylar
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session.evaluatorName ?? 'Bilinmeyen',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(180),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(session.scoredAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
