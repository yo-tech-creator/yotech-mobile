import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/forms_providers.dart';
import '../../domain/models/form_models.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import 'form_session_detail_page.dart';

/// Tamamlanmış formlar sekmesi
class CompletedFormsTab extends ConsumerWidget {
  const CompletedFormsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final sessionsAsync = ref.watch(completedSessionsProvider);
    final filter = ref.watch(completedSessionsFilterProvider);
    final theme = Theme.of(context);

    // Kullanıcı rolüne göre filtre göster
    final isManager = authState.maybeWhen(
      authenticated: (user) =>
          user.role == 'sube_muduru' ||
          user.role == 'bolge_muduru' ||
          user.role == 'firma_admin' ||
          user.role == 'grand_admin',
      orElse: () => false,
    );

    return Column(
      children: [
        // Filtreler (sadece yöneticiler için)
        if (isManager) _FilterSection(filter: filter),
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
                    onPressed: () => ref.invalidate(completedSessionsProvider),
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
                                .read(completedSessionsFilterProvider.notifier)
                                .state = const CompletedSessionsFilter();
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
                  ref.invalidate(completedSessionsProvider);
                  await ref.read(completedSessionsProvider.future);
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

/// Filtre bölümü
class _FilterSection extends ConsumerStatefulWidget {
  const _FilterSection({required this.filter});

  final CompletedSessionsFilter filter;

  @override
  ConsumerState<_FilterSection> createState() => _FilterSectionState();
}

class _FilterSectionState extends ConsumerState<_FilterSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final personnelAsync = ref.watch(branchPersonnelProvider);
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  // Personel filtresi
                  personnelAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (personnel) {
                      if (personnel.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DropdownButtonFormField<String?>(
                          initialValue: widget.filter.evaluatorId,
                          decoration: InputDecoration(
                            labelText: 'Personel',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tümü'),
                            ),
                            ...personnel.map((p) {
                              final name =
                                  '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'
                                      .trim();
                              return DropdownMenuItem(
                                value: p['id'] as String,
                                child: Text(name),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            ref
                                .read(completedSessionsFilterProvider.notifier)
                                .state = widget.filter.copyWith(
                              evaluatorId: value,
                              clearEvaluator: value == null,
                            );
                          },
                        ),
                      );
                    },
                  ),
                  // Form filtresi
                  formsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (forms) {
                      if (forms.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DropdownButtonFormField<String?>(
                          initialValue: widget.filter.formVersionId,
                          decoration: InputDecoration(
                            labelText: 'Form',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tümü'),
                            ),
                            ...forms.map((f) {
                              return DropdownMenuItem(
                                value: f['id'] as String,
                                child: Text(f['title'] as String? ?? ''),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            ref
                                .read(completedSessionsFilterProvider.notifier)
                                .state = widget.filter.copyWith(
                              formVersionId: value,
                              clearForm: value == null,
                            );
                          },
                        ),
                      );
                    },
                  ),
                  // Tarih filtreleri
                  Row(
                    children: [
                      Expanded(
                        child: _DateFilterButton(
                          label: 'Başlangıç',
                          date: widget.filter.startDate,
                          onDateSelected: (date) {
                            ref
                                .read(completedSessionsFilterProvider.notifier)
                                .state = widget.filter.copyWith(
                              startDate: date,
                            );
                          },
                          onClear: () {
                            ref
                                .read(completedSessionsFilterProvider.notifier)
                                .state = CompletedSessionsFilter(
                              evaluatorId: widget.filter.evaluatorId,
                              formVersionId: widget.filter.formVersionId,
                              endDate: widget.filter.endDate,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DateFilterButton(
                          label: 'Bitiş',
                          date: widget.filter.endDate,
                          onDateSelected: (date) {
                            ref
                                .read(completedSessionsFilterProvider.notifier)
                                .state = widget.filter.copyWith(
                              endDate: date,
                            );
                          },
                          onClear: () {
                            ref
                                .read(completedSessionsFilterProvider.notifier)
                                .state = CompletedSessionsFilter(
                              evaluatorId: widget.filter.evaluatorId,
                              formVersionId: widget.filter.formVersionId,
                              startDate: widget.filter.startDate,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  // Temizle butonu
                  if (widget.filter.hasFilter)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            ref
                                .read(completedSessionsFilterProvider.notifier)
                                .state = const CompletedSessionsFilter();
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Tüm Filtreleri Temizle'),
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
  });

  final String label;
  final DateTime? date;
  final void Function(DateTime) onDateSelected;
  final VoidCallback onClear;

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withAlpha(80)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? dateFormat.format(date!) : label,
                style: TextStyle(
                  color: date != null
                      ? null
                      : theme.colorScheme.onSurface.withAlpha(100),
                ),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 16,
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
              // Detaylar
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    session.evaluatorName ?? 'Bilinmeyen',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(180),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.store_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session.branchName ?? 'Şube',
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
