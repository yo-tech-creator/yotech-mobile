import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/core/localization/localization_extensions.dart';
import 'package:yotech_mobile/features/announcements/data/models/announcement.dart';
import 'package:yotech_mobile/features/announcements/data/repositories/announcements_repository.dart';
import 'package:yotech_mobile/features/announcements/presentation/providers/announcement_providers.dart';
import 'package:yotech_mobile/features/announcements/presentation/screens/survey_page.dart';
import 'package:yotech_mobile/features/announcements/presentation/screens/create_announcement_page.dart';
import 'package:yotech_mobile/features/announcements/presentation/screens/create_survey_page.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/shared/shared.dart';

class AnnouncementsPage extends ConsumerStatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  ConsumerState<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends ConsumerState<AnnouncementsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // History filters
  String _historySearchQuery = '';
  bool _sortNewestFirst = true;
  String _historyTypeFilter = 'all'; // 'all', 'surveys', 'announcements'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.campaign, color: Colors.white),
                ),
                title: const Text('Duyuru Oluştur'),
                subtitle: const Text('Personele bilgilendirme paylaşın'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const CreateAnnouncementPage(),
                    ),
                  );
                  if (result == true) {
                    ref.invalidate(announcementsStreamProvider);
                  }
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.poll, color: Colors.white),
                ),
                title: const Text('Anket Oluştur'),
                subtitle: const Text('Personelden geri bildirim alın'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const CreateSurveyPage(),
                    ),
                  );
                  if (result == true) {
                    ref.invalidate(announcementsStreamProvider);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(announcementsStreamProvider);
    final authState = ref.watch(authProvider);

    // Check if user can create announcements
    final canCreate = authState.maybeWhen(
      authenticated: (user) =>
          user.role == 'bolge_muduru' || user.role == 'sube_muduru',
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.announcementsTitle),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: context.l10n.announcementsTabAll),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.campaign, size: 18),
                  const SizedBox(width: 4),
                  Text(context.l10n.announcementsTabAnnouncements),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.poll, size: 18),
                  const SizedBox(width: 4),
                  Text(context.l10n.announcementsTabSurveys),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, size: 18),
                  const SizedBox(width: 4),
                  Text(context.l10n.announcementsTabCompleted),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => _showCreateOptions(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: announcementsAsync.when(
        data: (items) {
          return TabBarView(
            controller: _tabController,
            children: [
              // All (exclude expired)
              _buildAnnouncementsList(
                items.where((a) => !a.isExpired).toList(),
              ),
              // Only announcements (exclude expired)
              _buildAnnouncementsList(
                items.where((a) => !a.isSurvey && !a.isExpired).toList(),
              ),
              // Only surveys (pending - not responded and not expired)
              _buildAnnouncementsList(
                items
                    .where((a) => a.isSurvey && !a.hasResponded && !a.isExpired)
                    .toList(),
              ),
              // History: Completed surveys (responded) OR expired items (both surveys and announcements)
              _buildHistoryList(
                items
                    .where((a) => (a.isSurvey && a.hasResponded) || a.isExpired)
                    .toList(),
              ),
            ],
          );
        },
        loading: () => const AppLoading(),
        error: (error, _) => AppErrorState(
          message: context.l10n.announcementsLoadError('$error'),
          onRetry: () => ref.invalidate(announcementsStreamProvider),
        ),
      ),
    );
  }

  Widget _buildAnnouncementsList(List<Announcement> items) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.campaign_outlined,
        title: 'Henüz duyuru yok',
        subtitle: 'Yeni duyurular burada görünecek',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(announcementsStreamProvider);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final announcement = items[index];
          return _AnnouncementTile(
            announcement: announcement,
            onTap: () => _handleAnnouncementTap(announcement),
          );
        },
      ),
    );
  }

  Widget _buildHistoryList(List<Announcement> items) {
    // Apply type filter
    var filteredItems = items.where((a) {
      if (_historyTypeFilter == 'surveys') return a.isSurvey;
      if (_historyTypeFilter == 'announcements') return !a.isSurvey;
      return true; // 'all'
    }).toList();

    // Apply search filter
    filteredItems = filteredItems.where((a) {
      if (_historySearchQuery.isEmpty) return true;
      return a.title.toLowerCase().contains(_historySearchQuery.toLowerCase());
    }).toList();

    // Apply sort
    filteredItems.sort((a, b) {
      return _sortNewestFirst
          ? b.publishedAt.compareTo(a.publishedAt)
          : a.publishedAt.compareTo(b.publishedAt);
    });

    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              // Type filter chips
              Row(
                children: [
                  _buildTypeFilterChip('all', context.l10n.announcementsTabAll),
                  const SizedBox(width: 8),
                  _buildTypeFilterChip(
                      'surveys', context.l10n.announcementsTabSurveys),
                  const SizedBox(width: 8),
                  _buildTypeFilterChip('announcements',
                      context.l10n.announcementsTabAnnouncements),
                ],
              ),
              const SizedBox(height: 8),
              // Search and sort row
              Row(
                children: [
                  // Search field
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: context.l10n.filterByTitle,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: _historySearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() => _historySearchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() => _historySearchQuery = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort button
                  PopupMenuButton<bool>(
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _sortNewestFirst
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _sortNewestFirst
                              ? context.l10n.sortNewest
                              : context.l10n.sortOldest,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    onSelected: (newest) {
                      setState(() => _sortNewestFirst = newest);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: true,
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_downward, size: 18),
                            const SizedBox(width: 8),
                            Text(context.l10n.sortNewest),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: false,
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_upward, size: 18),
                            const SizedBox(width: 8),
                            Text(context.l10n.sortOldest),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // List
        Expanded(
          child: filteredItems.isEmpty
              ? AppEmptyState(
                  icon: Icons.history,
                  title: context.l10n.completedSurveysEmpty,
                  subtitle: context.l10n.completedSurveysSubtitle,
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(announcementsStreamProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final announcement = filteredItems[index];
                      return _AnnouncementTile(
                        announcement: announcement,
                        onTap: () => _handleAnnouncementTap(announcement),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTypeFilterChip(String value, String label) {
    final isSelected = _historyTypeFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _historyTypeFilter = value);
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _handleAnnouncementTap(Announcement announcement) {
    if (announcement.isSurvey) {
      Navigator.of(context)
          .push(
        MaterialPageRoute<bool>(
          builder: (context) => SurveyPage(announcement: announcement),
        ),
      )
          .then((submitted) {
        if (submitted == true) {
          ref.invalidate(announcementsStreamProvider);
        }
      });
    } else {
      _showDetails(context, announcement);
    }
  }

  void _showDetails(BuildContext context, Announcement announcement) {
    // Mark as read when opening details
    ref.read(announcementsRepositoryProvider).markAsRead(announcement.id);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
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
                            announcement.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatRelative(
                                    context, announcement.publishedAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              if (announcement.author != null &&
                                  announcement.author!.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 14,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  announcement.author!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Divider
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Divider(
                  height: 1,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: bottomInset + 24,
                  ),
                  child: Text(
                    announcement.content,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.7,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({
    required this.announcement,
    required this.onTap,
  });

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSurvey = announcement.isSurvey;
    final isDark = theme.brightness == Brightness.dark;

    // Modern gradient colors
    final surveyGradient = [
      const Color(0xFF10B981).withValues(alpha: 0.15),
      const Color(0xFF059669).withValues(alpha: 0.05),
    ];
    final announcementGradient = [
      const Color(0xFF3B82F6).withValues(alpha: 0.15),
      const Color(0xFF2563EB).withValues(alpha: 0.05),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isSurvey ? surveyGradient : announcementGradient,
            ),
            border: Border.all(
              color: announcement.pinned
                  ? Colors.amber.withValues(alpha: 0.8)
                  : (isSurvey
                          ? const Color(0xFF10B981)
                          : const Color(0xFF3B82F6))
                      .withValues(alpha: 0.3),
              width: announcement.pinned ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isSurvey
                        ? const Color(0xFF10B981)
                        : const Color(0xFF3B82F6))
                    .withValues(alpha: isDark ? 0.1 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with badges
                Row(
                  children: [
                    // Type badge with icon
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSurvey
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSurvey
                                ? Icons.poll_rounded
                                : Icons.campaign_rounded,
                            size: 14,
                            color: isSurvey
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isSurvey
                                ? context.l10n.announcementTypeSurvey
                                : context.l10n.announcementTypeAnnouncement,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSurvey
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF3B82F6),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (announcement.pinned) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Priority badge (only for non-normal priorities)
                    if (announcement.priority != 2) ...[
                      _buildPriorityBadge(context, announcement.priority),
                      const SizedBox(width: 8),
                    ],
                    if (announcement.isExpired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_off_rounded,
                              size: 12,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.announcementExpired,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Title
                Text(
                  announcement.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                // Date with icon
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatRelative(context, announcement.publishedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Summary
                Text(
                  announcement.displaySummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
                // Survey action hint
                if (isSurvey && !announcement.isExpired) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: announcement.hasResponded
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          announcement.hasResponded
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          size: 16,
                          color: announcement.hasResponded
                              ? const Color(0xFF10B981)
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          announcement.hasResponded
                              ? context.l10n.surveyCompleted
                              : context.l10n.surveyTapToRespond,
                          style: TextStyle(
                            fontSize: 13,
                            color: announcement.hasResponded
                                ? const Color(0xFF10B981)
                                : theme.colorScheme.primary,
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
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(BuildContext context, int priority) {
    // Priority: 1 = low, 2 = normal, 3 = high, 4 = urgent
    late final String label;
    late final Color color;
    late final IconData icon;

    switch (priority) {
      case 1:
        label = 'Düşük';
        color = Colors.grey;
        icon = Icons.arrow_downward_rounded;
        break;
      case 3:
        label = 'Yüksek';
        color = Colors.orange;
        icon = Icons.arrow_upward_rounded;
        break;
      case 4:
        label = 'Acil';
        color = Colors.red;
        icon = Icons.priority_high_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
