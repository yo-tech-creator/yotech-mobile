import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/shared.dart';
import '../../domain/models/visual_audit_models.dart';
import '../../domain/providers/visual_audit_providers.dart';
import 'visual_audit_detail_page.dart';

/// Görsel Denetim Ana Sayfası
class VisualAuditPage extends ConsumerStatefulWidget {
  const VisualAuditPage({super.key});

  @override
  ConsumerState<VisualAuditPage> createState() => _VisualAuditPageState();
}

class _VisualAuditPageState extends ConsumerState<VisualAuditPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedDate = ref.watch(selectedDateProvider);
    final tasksAsync = ref.watch(visualAuditTasksProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // Header
          _buildHeader(context, theme, selectedDate),

          // Tarih seçici
          _buildDateSelector(context, theme, selectedDate),

          // Görev listesi
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => AppErrorState(
                message: 'Görevler yüklenemedi: $error',
                onRetry: () => ref.invalidate(visualAuditTasksProvider),
              ),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.camera_alt_outlined,
                    title: 'Görev Yok',
                    subtitle: 'Bu tarih için görsel denetim görevi bulunmuyor.',
                  );
                }

                return _buildTaskList(context, theme, tasks);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, ThemeData theme, DateTime selectedDate) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF3B82F6),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Görsel Denetim',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isToday
                        ? 'Bugünkü görevleriniz'
                        : DateFormat('d MMMM yyyy', 'tr').format(selectedDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => ref.invalidate(visualAuditTasksProvider),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Yenile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(
      BuildContext context, ThemeData theme, DateTime selectedDate) {
    final today = DateTime.now();
    final dates =
        List.generate(7, (i) => today.subtract(Duration(days: 3 - i)));

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = DateUtils.isSameDay(date, selectedDate);
          final isToday = DateUtils.isSameDay(date, today);

          return GestureDetector(
            onTap: () {
              ref.read(selectedDateProvider.notifier).state = date;
            },
            child: Container(
              width: 56,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: const Color(0xFF3B82F6), width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE', 'tr').format(date).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : theme.colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date.day.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskList(
      BuildContext context, ThemeData theme, List<VisualAuditTask> tasks) {
    // Saate göre grupla
    final Map<String, List<VisualAuditTask>> grouped = {};
    for (final task in tasks) {
      final time = task.displayTime;
      grouped.putIfAbsent(time, () => []).add(task);
    }

    final sortedTimes = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedTimes.length,
      itemBuilder: (context, index) {
        final time = sortedTimes[index];
        final timeTasks = grouped[time]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saat başlığı
            Padding(
              padding: EdgeInsets.only(bottom: 12, top: index > 0 ? 16 : 0),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),

            // Görevler
            ...timeTasks.map((task) => _buildTaskCard(context, theme, task)),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard(
      BuildContext context, ThemeData theme, VisualAuditTask task) {
    final color = _parseColor(task.sectionColor);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VisualAuditDetailPage(taskId: task.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: task.isOverdue
                ? Colors.red.withOpacity(0.3)
                : color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Bölüm ikonu
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getSectionIcon(task.sectionIcon),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.sectionName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStatusBadge(theme, task),
                      const SizedBox(width: 8),
                      Text(
                        '${task.photoCount}/${task.minPhotos} foto',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Sağ ok
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme, VisualAuditTask task) {
    Color bgColor;
    Color textColor;
    String text;

    if (task.isOverdue) {
      bgColor = Colors.red.withOpacity(0.1);
      textColor = Colors.red;
      text = 'Gecikmiş';
    } else {
      switch (task.status) {
        case VisualAuditStatus.pending:
          bgColor = Colors.orange.withOpacity(0.1);
          textColor = Colors.orange;
          text = 'Bekliyor';
          break;
        case VisualAuditStatus.inProgress:
          bgColor = Colors.blue.withOpacity(0.1);
          textColor = Colors.blue;
          text = 'Devam Ediyor';
          break;
        case VisualAuditStatus.completed:
          bgColor = Colors.green.withOpacity(0.1);
          textColor = Colors.green;
          text = 'Tamamlandı';
          break;
        case VisualAuditStatus.approved:
          bgColor = Colors.green.withOpacity(0.15);
          textColor = Colors.green.shade700;
          text = 'Onaylandı ✓';
          break;
        case VisualAuditStatus.rejected:
          bgColor = Colors.red.withOpacity(0.1);
          textColor = Colors.red;
          text = 'Düzeltme İstendi';
          break;
        case VisualAuditStatus.missed:
          bgColor = Colors.grey.withOpacity(0.1);
          textColor = Colors.grey;
          text = 'Kaçırıldı';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
    } catch (_) {}
    return const Color(0xFF3B82F6);
  }

  IconData _getSectionIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'apple':
      case 'manav':
        return Icons.eco_rounded;
      case 'sandwich':
      case 'sarkuteri':
        return Icons.lunch_dining_rounded;
      case 'beef':
      case 'kasap':
        return Icons.restaurant_rounded;
      case 'croissant':
      case 'unlu':
        return Icons.bakery_dining_rounded;
      case 'banknote':
      case 'kasa':
        return Icons.point_of_sale_rounded;
      case 'store':
        return Icons.store_rounded;
      case 'shelf':
        return Icons.shelves;
      case 'fridge':
        return Icons.kitchen_rounded;
      default:
        return Icons.camera_alt_rounded;
    }
  }
}
