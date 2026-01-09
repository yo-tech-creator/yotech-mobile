import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/core/localization/localization_extensions.dart';
import 'package:yotech_mobile/features/break_tracking/data/models/break_session.dart';
import 'package:yotech_mobile/features/break_tracking/presentation/providers/break_tracking_providers.dart';

class BreakQuickActionCard extends ConsumerWidget {
  const BreakQuickActionCard({super.key, this.onViewHistory});

  final VoidCallback? onViewHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(breakSessionProvider);
    final session = sessionAsync.valueOrNull;
    final hasActive = session?.isActive == true;
    final isLoading = sessionAsync.isLoading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timer,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.breakQuickTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (onViewHistory != null)
                    TextButton(
                      onPressed: onViewHistory,
                      child: Text(context.l10n.breakQuickHistory),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (sessionAsync.hasError)
                Text(
                  context.l10n.breakQuickLoadError('${sessionAsync.error}'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                )
              else if (hasActive)
                _ActiveBreakInfo(session: session!)
              else
                Text(
                  context.l10n.breakQuickIdle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => _handlePrimaryAction(context, ref, hasActive),
                      icon: Icon(hasActive ? Icons.stop : Icons.play_arrow),
                      label: Text(hasActive
                          ? context.l10n.breakQuickStop
                          : context.l10n.breakQuickStart),
                    ),
                  ),
                  if (!isLoading && hasActive)
                    IconButton(
                      tooltip: context.l10n.breakQuickRefreshTooltip,
                      onPressed: () =>
                          ref.read(breakSessionProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePrimaryAction(
    BuildContext context,
    WidgetRef ref,
    bool hasActive,
  ) async {
    final notifier = ref.read(breakSessionProvider.notifier);
    try {
      if (hasActive) {
        await notifier.endBreak();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.breakQuickEndSuccess)),
        );
      } else {
        await notifier.startBreak();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.breakQuickStartSuccess)),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.breakQuickFailure('$e'))),
      );
    }
  }
}

class _ActiveBreakInfo extends StatelessWidget {
  const _ActiveBreakInfo({required this.session});

  final BreakSession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.breakQuickStartedAt(
            _formatTime(session.startedAt),
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        _ElapsedTimer(startedAt: session.startedAt),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${pad(local.hour)}:${pad(local.minute)}';
  }
}

class _ElapsedTimer extends StatefulWidget {
  const _ElapsedTimer({required this.startedAt});

  final DateTime startedAt;

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  late Timer _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.startedAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.startedAt);
      });
    });
  }

  @override
  void didUpdateWidget(covariant _ElapsedTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) {
      _elapsed = DateTime.now().difference(widget.startedAt);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes % 60;
    final seconds = _elapsed.inSeconds % 60;
    String two(int value) => value.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.breakQuickElapsed(
          '${two(hours)}:${two(minutes)}:${two(seconds)}',
        ),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
