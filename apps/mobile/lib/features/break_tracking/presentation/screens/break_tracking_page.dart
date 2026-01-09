import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/core/localization/localization_extensions.dart';
import 'package:yotech_mobile/features/break_tracking/data/models/break_session.dart';
import 'package:yotech_mobile/features/break_tracking/presentation/providers/break_tracking_providers.dart';
import 'package:yotech_mobile/features/break_tracking/presentation/widgets/break_quick_action_card.dart';

class ShiftsHubPage extends ConsumerWidget {
  const ShiftsHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(breakHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.breaksTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(breakSessionProvider.notifier).refresh();
          ref.invalidate(breakHistoryProvider);
          await ref.read(breakHistoryProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            BreakQuickActionCard(
              onViewHistory: () => _scrollToHistory(context),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.l10n.breaksTodayTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            historyAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return const _EmptyHistoryPlaceholder();
                }
                return _BreakHistoryList(sessions: sessions);
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.breaksHistoryError('$e')),
              ),
            ),
            const SizedBox(height: 24),
            const _ShiftHighlightsCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _scrollToHistory(BuildContext context) {
    final primary = PrimaryScrollController.maybeOf(context);
    if (primary == null) {
      return;
    }
    primary.animateTo(
      200,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}

class _ShiftHighlightsCard extends StatelessWidget {
  const _ShiftHighlightsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.breaksHighlightsTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.breaksHighlightsDescription,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _ShiftHighlightTile(
                icon: Icons.view_week,
                title: context.l10n.breaksHighlightWeeklyTitle,
                description: context.l10n.breaksHighlightWeeklyDescription,
              ),
              _ShiftHighlightTile(
                icon: Icons.sync,
                title: context.l10n.breaksHighlightLeaveTitle,
                description: context.l10n.breaksHighlightLeaveDescription,
              ),
              _ShiftHighlightTile(
                icon: Icons.notifications_active,
                title: context.l10n.breaksHighlightNotificationTitle,
                description:
                    context.l10n.breaksHighlightNotificationDescription,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftHighlightTile extends StatelessWidget {
  const _ShiftHighlightTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakHistoryList extends StatelessWidget {
  const _BreakHistoryList({required this.sessions});

  final List<BreakSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final session = sessions[index];
            final start = _formatDate(session.startedAt);
            final end = session.endedAt != null
                ? _formatDate(session.endedAt!)
                : context.l10n.breaksOngoing;
            final duration = session.durationSeconds != null
                ? _formatDuration(Duration(seconds: session.durationSeconds!))
                : '—';
            return ListTile(
              leading: Icon(
                session.endedAt == null ? Icons.timelapse : Icons.check_circle,
                color: session.endedAt == null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
              ),
              title: Text('$start - $end'),
              subtitle: Text(context.l10n.breaksDurationLabel(duration)),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _formatDuration(Duration duration) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(duration.inHours)}:${two(duration.inMinutes % 60)}:${two(duration.inSeconds % 60)}';
  }
}

class _EmptyHistoryPlaceholder extends StatelessWidget {
  const _EmptyHistoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.free_breakfast,
              size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            context.l10n.breaksEmptyMessage,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
