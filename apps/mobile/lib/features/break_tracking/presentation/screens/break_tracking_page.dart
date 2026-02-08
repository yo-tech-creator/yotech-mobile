import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/break_tracking/presentation/providers/break_tracking_providers.dart';
import 'package:yotech_mobile/features/break_tracking/presentation/screens/shifts_and_breaks_page.dart';
import 'package:yotech_mobile/features/break_tracking/presentation/widgets/break_quick_action_card.dart';
import 'package:yotech_mobile/shared/shared.dart';

class ShiftPattern {
  final String id;
  final String title;
  final String start;
  final String end;
  final String color;

  const ShiftPattern(
      {required this.id,
      required this.title,
      required this.start,
      required this.end,
      required this.color});

  factory ShiftPattern.fromMap(Map<String, dynamic> map) {
    return ShiftPattern(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      start: map['start']?.toString() ?? '',
      end: map['end']?.toString() ?? '',
      color: map['color']?.toString() ?? '#2563EB',
    );
  }
}

class ShiftWeek {
  final DateTime weekStart;
  final DateTime weekEnd;
  final Map<String, String> assignments;
  final Map<String, ShiftPattern> patterns;
  final Map<String, String> peopleNames;

  const ShiftWeek({
    required this.weekStart,
    required this.weekEnd,
    required this.assignments,
    required this.patterns,
    required this.peopleNames,
  });
}

final publishedShiftProvider = FutureProvider<ShiftWeek?>((ref) async {
  final auth = ref.watch(authProvider);
  return await auth.maybeWhen<Future<ShiftWeek?>>(
    authenticated: (user) async {
      final client = Supabase.instance.client;

      final branchId = user.branchId;

      var filterQuery = client
          .from('shifts')
          .select('week_start_date, week_end_date, shift_data')
          .eq('tenant_id', user.tenantId);

      if (branchId != null) {
        filterQuery = filterQuery.eq('branch_id', branchId);
      }

      final response = await filterQuery
          .order('week_start_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;

      final startIso =
          response['week_start_date']?.toString().substring(0, 10) ?? '';
      final endIso =
          response['week_end_date']?.toString().substring(0, 10) ?? '';

      DateTime parseIso(String iso) {
        final parts = iso.split('-').map(int.tryParse).toList();
        if (parts.length == 3 && parts.every((e) => e != null)) {
          return DateTime(parts[0]!, parts[1]!, parts[2]!);
        }
        return DateTime.now();
      }

      final weekStart = parseIso(startIso);
      final weekEnd = parseIso(endIso.isNotEmpty ? endIso : startIso);

      final rawShiftData =
          response['shift_data'] as Map<String, dynamic>? ?? {};
      final rawAssignments =
          (rawShiftData['assignments'] as Map?)?.cast<String, String>() ??
              <String, String>{};
      final patternsList = (rawShiftData['patterns'] as List?) ?? const [];

      Map<String, String> normalizeAssignments(Map<String, String> input) {
        final out = <String, String>{};
        input.forEach((key, value) {
          if (key.length < 11) return;
          final iso = key.substring(key.length - 10);
          final personId = key.substring(0, key.length - 11);
          out['$personId-$iso'] = value;
        });
        return out;
      }

      final assignments = normalizeAssignments(rawAssignments);

      final patterns = <String, ShiftPattern>{};
      for (final p in patternsList) {
        if (p is Map<String, dynamic>) {
          final pat = ShiftPattern.fromMap(p);
          if (pat.id.isNotEmpty) patterns[pat.id] = pat;
        }
      }

      final personIds =
          assignments.keys.map((k) => k.substring(0, k.length - 11)).toSet();
      final peopleNames = <String, String>{};
      if (personIds.isNotEmpty) {
        String nameFromRow(Map<String, dynamic> row) {
          final name = [row['first_name'], row['last_name']]
              .whereType<String>()
              .join(' ')
              .trim();
          if (name.isNotEmpty) return name;
          final emp = row['employee_code']?.toString();
          if (emp != null && emp.isNotEmpty) return emp;
          final mail = row['email']?.toString();
          if (mail != null && mail.isNotEmpty) return mail;
          return '';
        }

        var userQuery = client
            .from('users')
            .select('id, first_name, last_name, employee_code, email')
            .eq('tenant_id', user.tenantId);
        if (branchId != null) {
          userQuery = userQuery.eq('branch_id', branchId);
        }
        final userResp = List<Map<String, dynamic>>.from(
            await userQuery.inFilter('id', personIds.toList()));

        if (userResp.isEmpty && branchId != null) {
          // Fallback: try without branch filter so names still show if assignments cross branches.
          final fallbackResp = List<Map<String, dynamic>>.from(await client
              .from('users')
              .select('id, first_name, last_name, employee_code, email')
              .eq('tenant_id', user.tenantId)
              .inFilter('id', personIds.toList()));
          userResp.addAll(fallbackResp);
        }

        for (final row in userResp) {
          final id = row['id']?.toString();
          if (id == null) continue;
          final name = nameFromRow(row);
          if (name.isNotEmpty) {
            peopleNames[id] = name;
          }
        }

        final missing = personIds.difference(peopleNames.keys.toSet());
        if (missing.isNotEmpty) {
          // Final fallback: use branch team RPC to honor RLS policies used in profile screen.
          final rpcResp = await client.rpc('get_branch_team_members', params: {
            'p_user_id': user.id,
          });
          final rpcList =
              (rpcResp as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final row in rpcList) {
            final memberId = row['member_id']?.toString();
            if (memberId == null || !missing.contains(memberId)) continue;
            final name = nameFromRow(row);
            peopleNames[memberId] = name.isNotEmpty ? name : memberId;
          }
        }
      }

      return ShiftWeek(
        weekStart: weekStart,
        weekEnd: weekEnd,
        assignments: assignments,
        patterns: patterns,
        peopleNames: peopleNames,
      );
    },
    orElse: () async => null,
  );
});

class ShiftsHubPage extends ConsumerWidget {
  const ShiftsHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncWeek = ref.watch(publishedShiftProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Vardiya & Mola')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(publishedShiftProvider);
          ref.invalidate(breakSessionProvider);
          await Future.wait([
            ref.read(publishedShiftProvider.future),
            ref.read(breakSessionProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 16),
            // Mola Takip Bölümü
            BreakQuickActionCard(
              onViewHistory: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ShiftsAndBreaksPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Vardiya Bölümü Başlığı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.calendar_month,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Yayınlanmış Vardiya',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Vardiya İçeriği
            asyncWeek.when(
              data: (week) {
                if (week == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: AppEmptyState(
                        icon: Icons.event_busy,
                        title: 'Yayınlanmış vardiya bulunamadı'),
                  );
                }
                return _ShiftWeekViewEmbedded(week: week);
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: AppErrorState(message: 'Vardiya alınamadı: $e'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ListView içinde kullanılmak üzere tasarlanmış gömülü vardiya görünümü
class _ShiftWeekViewEmbedded extends StatelessWidget {
  const _ShiftWeekViewEmbedded({required this.week});
  final ShiftWeek week;

  List<DateTime> get days =>
      List.generate(7, (i) => week.weekStart.add(Duration(days: i)));

  String formatRange(DateTime start, DateTime end) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    return '${fmt(start)} - ${fmt(end)}';
  }

  Map<String, Map<String, String>> _groupByPerson() {
    final map = <String, Map<String, String>>{};
    week.assignments.forEach((key, patId) {
      if (key.length < 11) return;
      final iso = key.substring(key.length - 10);
      final personId = key.substring(0, key.length - 11);
      map.putIfAbsent(personId, () => <String, String>{});
      map[personId]![iso] = patId;
    });
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final people = _groupByPerson();
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom + 72;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hafta aralığı',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(formatRange(week.weekStart, week.weekEnd),
                      style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRect(
            child: InteractiveViewer(
              minScale: 0.7,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: _ShiftTable(
                    days: days,
                    people: people,
                    week: week,
                    theme: theme,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ShiftTable extends StatelessWidget {
  const _ShiftTable({
    required this.days,
    required this.people,
    required this.week,
    required this.theme,
  });

  final List<DateTime> days;
  final Map<String, Map<String, String>> people;
  final ShiftWeek week;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(140)
    };
    for (var i = 0; i < days.length; i++) {
      columnWidths[i + 1] = const FixedColumnWidth(120);
    }

    final headerCells = [
      const _HeaderCell(label: 'Personel'),
      ...days.map((d) => _HeaderCell(
          label:
              '${_weekday(d.weekday)}\n${d.day.toString().padLeft(2, '0')}')),
    ];

    final rows = people.entries.map((entry) {
      final personId = entry.key;
      final name = week.peopleNames[personId] ?? _shorten(personId);
      final assignments = entry.value;
      final cells = [
        _NameCell(label: name, theme: theme),
        ...days.map((day) {
          final iso =
              '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          final patId = assignments[iso];
          final pat = patId != null ? week.patterns[patId] : null;
          return _PatternCell(pattern: pat, theme: theme);
        }),
      ];
      return TableRow(children: cells);
    }).toList();

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder.all(
          color: theme.dividerColor.withValues(alpha: 0.4), width: 0.5),
      columnWidths: columnWidths,
      children: [TableRow(children: headerCells), ...rows],
    );
  }

  String _weekday(int w) {
    switch (w) {
      case DateTime.monday:
        return 'Pzt';
      case DateTime.tuesday:
        return 'Sal';
      case DateTime.wednesday:
        return 'Çar';
      case DateTime.thursday:
        return 'Per';
      case DateTime.friday:
        return 'Cum';
      case DateTime.saturday:
        return 'Cmt';
      case DateTime.sunday:
        return 'Paz';
      default:
        return '';
    }
  }

  String _shorten(String id) {
    if (id.length <= 6) return id;
    return '${id.substring(0, 3)}...${id.substring(id.length - 3)}';
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style:
            theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.label, required this.theme});
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        label,
        style:
            theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PatternCell extends StatelessWidget {
  const _PatternCell({required this.pattern, required this.theme});
  final ShiftPattern? pattern;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final pat = pattern;
    final color = pat != null ? _hexToColor(pat.color) : Colors.grey.shade300;
    final title = pat?.title ?? '(boş)';
    final time = (pat?.start.isNotEmpty == true && pat?.end.isNotEmpty == true)
        ? '${pat!.start} - ${pat.end}'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: color.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  overflow: TextOverflow.ellipsis)),
          if (time.isNotEmpty)
            Text(time,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

Color _hexToColor(String hex) {
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}
