import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/break_tracking/data/models/break_session.dart';
import 'package:yotech_mobile/features/break_tracking/presentation/providers/break_tracking_providers.dart';
import 'package:yotech_mobile/features/break_tracking/presentation/widgets/break_quick_action_card.dart';
import 'package:yotech_mobile/shared/shared.dart';

/// Vardiya ve Mola Takibi Sayfası
/// - Benim Molalarım: Kendi mola geçmişim
/// - Ekip Molaları: Şube müdürü için personel molaları
class ShiftsAndBreaksPage extends ConsumerStatefulWidget {
  const ShiftsAndBreaksPage({super.key});

  @override
  ConsumerState<ShiftsAndBreaksPage> createState() =>
      _ShiftsAndBreaksPageState();
}

class _ShiftsAndBreaksPageState extends ConsumerState<ShiftsAndBreaksPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isManager {
    final authState = ref.read(authProvider);
    final role = authState.maybeWhen(
      authenticated: (user) => user.role,
      orElse: () => null,
    );
    return role == 'sube_muduru' ||
        role == 'bolge_muduru' ||
        role == 'firma_admin';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isManager = _isManager;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Header with gradient
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.secondaryContainer,
                      cs.secondary.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.arrow_back,
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.coffee_rounded,
                                color: cs.onSecondaryContainer,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mola Takibi',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSecondaryContainer,
                                    ),
                                  ),
                                  Text(
                                    'Günlük mola geçmişiniz',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: cs.onSecondaryContainer
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Tab Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                tabBar: TabBar(
                  controller: _tabController,
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.person_outline, size: 20),
                      text: 'Molalarım',
                    ),
                    Tab(
                      icon: Icon(
                        isManager ? Icons.groups_outlined : Icons.lock_outline,
                        size: 20,
                      ),
                      text: 'Ekip Molaları',
                    ),
                  ],
                ),
                backgroundColor: cs.surface,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Benim Molalarım
            _MyBreaksTab(
              selectedDate: _selectedDate,
              onDateChanged: (date) => setState(() => _selectedDate = date),
            ),
            // Ekip Molaları
            isManager
                ? _TeamBreaksTab(
                    selectedDate: _selectedDate,
                    onDateChanged: (date) =>
                        setState(() => _selectedDate = date),
                  )
                : const _NoPermissionView(),
          ],
        ),
      ),
    );
  }
}

/// Benim Molalarım Sekmesi
class _MyBreaksTab extends ConsumerWidget {
  const _MyBreaksTab({
    required this.selectedDate,
    required this.onDateChanged,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Seçilen güne göre molalar
    final startOfDay =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final breaksAsync = ref.watch(breakHistoryWithDateProvider(startOfDay));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(breakHistoryWithDateProvider(startOfDay));
        ref.invalidate(breakSessionProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mola Başlat/Bitir Kartı
          BreakQuickActionCard(
            onViewHistory: () {},
          ),
          const SizedBox(height: 16),

          // Tarih Seçici
          _DateSelector(
            selectedDate: selectedDate,
            onDateChanged: onDateChanged,
          ),
          const SizedBox(height: 16),

          // Günlük Özet
          breaksAsync.when(
            data: (breaks) => _DailySummaryCard(breaks: breaks),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Mola Listesi
          Text(
            'Mola Geçmişi',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          breaksAsync.when(
            data: (breaks) {
              if (breaks.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.coffee_outlined,
                        size: 48,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Bu tarihte mola kaydı yok',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children:
                    breaks.map((b) => _BreakSessionCard(session: b)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Hata: $e'),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Ekip Molaları Sekmesi
class _TeamBreaksTab extends ConsumerWidget {
  const _TeamBreaksTab({
    required this.selectedDate,
    required this.onDateChanged,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final startOfDay =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final breaksAsync = ref.watch(teamBreakSessionsProvider(startOfDay));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(teamBreakSessionsProvider(startOfDay));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tarih Seçici
          _DateSelector(
            selectedDate: selectedDate,
            onDateChanged: onDateChanged,
          ),
          const SizedBox(height: 16),

          // Ekip Özeti
          breaksAsync.when(
            data: (breaks) => _TeamSummaryCard(breaks: breaks),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Kişi Bazlı Gruplu Liste
          Text(
            'Ekip Mola Geçmişi',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          breaksAsync.when(
            data: (breaks) {
              if (breaks.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 48,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Bu tarihte ekip mola kaydı yok',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Group by user
              final grouped = <String, List<BreakSession>>{};
              for (final b in breaks) {
                final key = b.userName ?? b.userId;
                grouped.putIfAbsent(key, () => []).add(b);
              }

              return Column(
                children: grouped.entries.map((entry) {
                  return _PersonBreaksCard(
                    personName: entry.key,
                    breaks: entry.value,
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Hata: $e'),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Tarih Seçici Widget
class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.selectedDate,
    required this.onDateChanged,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                onDateChanged(selectedDate.subtract(const Duration(days: 1)));
              },
            ),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: now,
                  );
                  if (picked != null) {
                    onDateChanged(picked);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        isToday
                            ? 'Bugün'
                            : DateFormat('EEEE', 'tr').format(selectedDate),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('d MMMM yyyy', 'tr').format(selectedDate),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: isToday
                  ? null
                  : () {
                      onDateChanged(selectedDate.add(const Duration(days: 1)));
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// Günlük Özet Kartı
class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({required this.breaks});

  final List<BreakSession> breaks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Toplam süre hesapla
    int totalSeconds = 0;
    for (final b in breaks) {
      if (b.durationSeconds != null) {
        totalSeconds += b.durationSeconds!;
      } else if (b.isActive) {
        // Devam eden mola için şu ana kadar geçen süre
        totalSeconds += DateTime.now().difference(b.startedAt).inSeconds;
      }
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final durationText = hours > 0 ? '${hours}s ${minutes}dk' : '${minutes}dk';

    return Card(
      elevation: 0,
      color: cs.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.timer_outlined,
                color: cs.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Günlük Toplam',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    durationText,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${breaks.length} mola',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ekip Özet Kartı
class _TeamSummaryCard extends StatelessWidget {
  const _TeamSummaryCard({required this.breaks});

  final List<BreakSession> breaks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Kişi sayısı
    final uniqueUsers = breaks.map((b) => b.userId).toSet().length;

    // Aktif mola sayısı
    final activeBreaks = breaks.where((b) => b.isActive).length;

    // Toplam süre
    int totalSeconds = 0;
    for (final b in breaks) {
      if (b.durationSeconds != null) {
        totalSeconds += b.durationSeconds!;
      } else if (b.isActive) {
        totalSeconds += DateTime.now().difference(b.startedAt).inSeconds;
      }
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final durationText = hours > 0 ? '${hours}s ${minutes}dk' : '${minutes}dk';

    return Card(
      elevation: 0,
      color: cs.tertiaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _SummaryItem(
                  icon: Icons.groups,
                  label: 'Kişi',
                  value: '$uniqueUsers',
                  color: cs.tertiary,
                ),
                _SummaryItem(
                  icon: Icons.coffee,
                  label: 'Mola',
                  value: '${breaks.length}',
                  color: cs.secondary,
                ),
                _SummaryItem(
                  icon: Icons.timer,
                  label: 'Toplam',
                  value: durationText,
                  color: cs.primary,
                ),
              ],
            ),
            if (activeBreaks > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: cs.error),
                    const SizedBox(width: 8),
                    Text(
                      '$activeBreaks kişi şu an molada',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek Mola Kartı
class _BreakSessionCard extends StatelessWidget {
  const _BreakSessionCard({required this.session});

  final BreakSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final startTime = DateFormat('HH:mm').format(session.startedAt.toLocal());
    final endTime = session.endedAt != null
        ? DateFormat('HH:mm').format(session.endedAt!.toLocal())
        : 'Devam ediyor';

    String durationText = '';
    if (session.durationSeconds != null) {
      final mins = session.durationSeconds! ~/ 60;
      durationText = '$mins dk';
    } else if (session.isActive) {
      final mins = DateTime.now().difference(session.startedAt).inMinutes;
      durationText = '$mins dk (devam)';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: session.isActive
              ? cs.primary
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: session.isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: session.isActive
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                session.isActive ? Icons.coffee : Icons.coffee_outlined,
                color: session.isActive ? cs.primary : cs.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$startTime - $endTime',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (durationText.isNotEmpty)
                    Text(
                      durationText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (session.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Aktif',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kişi Bazlı Mola Kartı
class _PersonBreaksCard extends StatelessWidget {
  const _PersonBreaksCard({
    required this.personName,
    required this.breaks,
  });

  final String personName;
  final List<BreakSession> breaks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Toplam süre
    int totalSeconds = 0;
    bool hasActive = false;
    for (final b in breaks) {
      if (b.durationSeconds != null) {
        totalSeconds += b.durationSeconds!;
      } else if (b.isActive) {
        hasActive = true;
        totalSeconds += DateTime.now().difference(b.startedAt).inSeconds;
      }
    }
    final mins = totalSeconds ~/ 60;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              hasActive ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
          width: hasActive ? 2 : 1,
        ),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: CircleAvatar(
          backgroundColor:
              hasActive ? cs.primaryContainer : cs.surfaceContainerHighest,
          child: Text(
            personName.isNotEmpty ? personName[0].toUpperCase() : '?',
            style: TextStyle(
              color: hasActive ? cs.primary : cs.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                personName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Molada',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${breaks.length} mola • Toplam $mins dk',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        children: breaks.map((b) {
          final startTime = DateFormat('HH:mm').format(b.startedAt.toLocal());
          final endTime = b.endedAt != null
              ? DateFormat('HH:mm').format(b.endedAt!.toLocal())
              : 'Devam';
          final duration =
              b.durationSeconds != null ? '${b.durationSeconds! ~/ 60} dk' : '';

          return ListTile(
            dense: true,
            leading: Icon(
              b.isActive ? Icons.circle : Icons.circle_outlined,
              size: 12,
              color: b.isActive ? cs.primary : cs.outline,
            ),
            title: Text('$startTime - $endTime'),
            trailing: duration.isNotEmpty ? Text(duration) : null,
          );
        }).toList(),
      ),
    );
  }
}

/// Yetki Yok Görünümü
class _NoPermissionView extends StatelessWidget {
  const _NoPermissionView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: AppEmptyState(
        icon: Icons.lock_outline,
        title: 'Erişim Yetkiniz Yok',
        subtitle:
            'Ekip molalarını görüntülemek için şube müdürü veya üstü yetki gerekir.',
      ),
    );
  }
}

/// TabBar için SliverPersistentHeaderDelegate
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
