import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/forms_providers.dart';
import '../../domain/models/form_models.dart';

/// Tamamlanmış form oturumu detay sayfası
class FormSessionDetailPage extends ConsumerWidget {
  const FormSessionDetailPage({super.key, required this.session});

  final FormSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    // Form detayını çek
    final formDetailAsync =
        ref.watch(formDetailProvider(session.formVersionId));
    // Oturum cevaplarını çek
    final sessionItemsAsync = ref.watch(sessionItemsProvider(session.id));

    Color getScoreColor() {
      if (session.score >= 80) return Colors.green;
      if (session.score >= 60) return Colors.orange;
      return Colors.red;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(session.formTitle ?? 'Form Detayı'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Özet kartı
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Skor
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: getScoreColor().withAlpha(30),
                      border: Border.all(
                        color: getScoreColor(),
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '%${session.score.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: getScoreColor(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Puan detayları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ScoreDetail(
                        label: 'Pozitif',
                        value: '+${session.totalPositive.toStringAsFixed(0)}',
                        color: Colors.green,
                      ),
                      _ScoreDetail(
                        label: 'Negatif',
                        value: '-${session.totalNegative.toStringAsFixed(0)}',
                        color: Colors.red,
                      ),
                      _ScoreDetail(
                        label: 'Toplam',
                        value: session.totalPossible.toStringAsFixed(0),
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Meta bilgiler
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Dolduran',
                    value: session.evaluatorName ?? 'Bilinmeyen',
                  ),
                  if (session.evaluatedUserName != null &&
                      session.evaluatedUserName!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.person_pin_outlined,
                      label: 'Değerlendirilen',
                      value: session.evaluatedUserName!,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.store_outlined,
                    label: 'Şube',
                    value: session.branchName ?? 'Bilinmeyen',
                  ),
                  if (session.branchManagerName != null &&
                      session.branchManagerName!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Şube Müdürü',
                      value: session.branchManagerName!,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'Tarih',
                    value: dateFormat.format(session.scoredAt),
                  ),
                  if (session.notes != null && session.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Notlar',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        session.notes!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Cevaplar başlığı
          Text(
            'Cevaplar',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          // Form detayı ve cevaplar
          formDetailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Form detayı yüklenemedi: $e'),
            data: (formDetailData) {
              if (formDetailData == null) {
                return const Text('Form bulunamadı');
              }
              final formDetail = formDetailData;

              return sessionItemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Cevaplar yüklenemedi: $e'),
                data: (sessionItems) {
                  // itemId -> sessionItem map
                  final itemAnswers = <String, FormSessionItem>{};
                  for (final item in sessionItems) {
                    itemAnswers[item.itemId] = item;
                  }

                  return Column(
                    children: formDetail.sections.map((section) {
                      return _SectionCard(
                        section: section,
                        itemAnswers: itemAnswers,
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _ScoreDetail extends StatelessWidget {
  const _ScoreDetail({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
          ),
        ),
      ],
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
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withAlpha(150),
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(150),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.itemAnswers,
  });

  final FormSection section;
  final Map<String, FormSessionItem> itemAnswers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(50),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Text(
              section.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Items
          ...section.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final answer = itemAnswers[item.id];

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: index < section.items.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outline.withAlpha(30),
                        ),
                      )
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Numara
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withAlpha(180),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (answer?.comment != null &&
                            answer!.comment!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Yorum: ${answer.comment}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cevap badge
                  if (answer != null)
                    _ResultBadge(result: answer.result)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Boş',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.result});

  final FormItemResult result;

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
          return Icons.check;
        case FormItemResult.negative:
          return Icons.close;
        case FormItemResult.neutral:
          return Icons.remove;
        case FormItemResult.notApplicable:
          return Icons.block;
      }
    }

    final color = getColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(getIcon(), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            result.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
