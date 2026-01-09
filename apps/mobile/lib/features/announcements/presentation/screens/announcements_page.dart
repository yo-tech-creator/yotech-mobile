import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/core/localization/localization_extensions.dart';
import 'package:yotech_mobile/features/announcements/data/models/announcement.dart';
import 'package:yotech_mobile/features/announcements/presentation/providers/announcement_providers.dart';

class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.announcementsTitle)),
      body: announcementsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const _AnnouncementsEmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final announcement = items[index];
              return _AnnouncementTile(announcement: announcement);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AnnouncementsErrorState(
          message: context.l10n.announcementsLoadError('$error'),
          onRetry: () => ref.invalidate(announcementsStreamProvider),
        ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showDetails(context, announcement),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              announcement.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _formatRelative(context, announcement.publishedAt),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              announcement.displaySummary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, Announcement announcement) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottomInset + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatRelative(context, announcement.publishedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (announcement.author != null &&
                    announcement.author!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.announcementsAuthor('${announcement.author}'),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  announcement.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnnouncementsEmptyState extends StatelessWidget {
  const _AnnouncementsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.campaign_outlined, size: 42, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              context.l10n.announcementsEmptyMessage,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementsErrorState extends StatelessWidget {
  const _AnnouncementsErrorState(
      {required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRelative(BuildContext context, DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  final l10n = context.l10n;
  if (diff.inMinutes < 1) return l10n.relativeJustNow;
  if (diff.inMinutes < 60) {
    return l10n.relativeMinutes(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return l10n.relativeHours(diff.inHours);
  }
  return l10n.relativeDays(diff.inDays);
}
