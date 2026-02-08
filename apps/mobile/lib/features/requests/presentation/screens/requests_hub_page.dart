import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/shared.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../data/request_repository.dart';
import '../../domain/models/branch_request.dart';
import '../../domain/models/equipment_request_type.dart';
import '../../domain/models/malfunction_issue_type.dart';
import '../../domain/models/request_status.dart';
import 'department_management_page.dart';
import 'request_form_page.dart';
import '../widgets/request_category_theme.dart';

class RequestsHubPage extends ConsumerStatefulWidget {
  const RequestsHubPage({super.key});

  @override
  ConsumerState<RequestsHubPage> createState() => _RequestsHubPageState();
}

class _RequestsHubPageState extends ConsumerState<RequestsHubPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  RequestStatus? _statusFilter; // null = tümü
  bool _isManager = false;

  int get _tabCount => _isManager ? 3 : 2;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initTabController();
  }

  void _initTabController() {
    final user = ref.read(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );

    final isManager = user != null &&
        (user.role == 'firma_admin' || user.role == 'bolge_muduru');

    // Tab sayısı değiştiyse controller'ı yeniden oluştur
    if (_tabController == null || _isManager != isManager) {
      _tabController?.dispose();
      _isManager = isManager;
      _tabController = TabController(length: _tabCount, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _refreshPersonal() {
    return ref.refresh(personalRequestsProvider.future);
  }

  Future<void> _refreshIncoming() {
    return ref.refresh(incomingRequestsProvider.future);
  }

  Future<void> _showRequestDetails(BranchRequest request) async {
    final result = await showModalBottomSheet<_RequestDetailsResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RequestDetailsSheet(request: request),
    );

    if (!mounted || result == null) {
      return;
    }

    switch (result) {
      case _RequestDetailsResult.cancelled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talep iptal edildi.')),
        );
        ref.invalidate(personalRequestsProvider);
        break;
      case _RequestDetailsResult.edit:
        final updated = await Navigator.of(context).push<BranchRequest>(
          MaterialPageRoute(
            builder: (_) => RequestFormPage.edit(request: request),
          ),
        );
        if (!mounted) {
          return;
        }
        if (updated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Talep güncellendi.')),
          );
          ref.invalidate(personalRequestsProvider);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final personalRequestsAsync = ref.watch(personalRequestsProvider);
    final incomingRequestsAsync = ref.watch(incomingRequestsProvider);
    final user = ref.watch(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomPadding =
        MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight;

    const categories = RequestCategoryThemes.values;

    // İstatistikler - Taleplerim için
    final myStats = personalRequestsAsync.maybeWhen(
      data: (requests) {
        final pending =
            requests.where((r) => r.status == RequestStatus.pending).length;
        final inProgress =
            requests.where((r) => r.status == RequestStatus.inProgress).length;
        final resolved =
            requests.where((r) => r.status == RequestStatus.resolved).length;
        return (
          pending: pending,
          inProgress: inProgress,
          resolved: resolved,
          total: requests.length
        );
      },
      orElse: () => (pending: 0, inProgress: 0, resolved: 0, total: 0),
    );

    // İstatistikler - Gelen Talepler için
    final incomingStats = incomingRequestsAsync.maybeWhen(
      data: (requests) {
        final pending =
            requests.where((r) => r.status == RequestStatus.pending).length;
        final inProgress =
            requests.where((r) => r.status == RequestStatus.inProgress).length;
        return (
          pending: pending,
          inProgress: inProgress,
          total: requests.length
        );
      },
      orElse: () => (pending: 0, inProgress: 0, total: 0),
    );

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Header Card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary,
                    colors.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.support_agent,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Talep Merkezi',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'İhtiyaçlarınızı hızlıca iletin',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
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

          // Kategori Başlığı
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.category_outlined,
                      size: 20, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Yeni Talep Oluştur',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Kategori Kartları - Yatay Kaydırmalı
          SliverToBoxAdapter(
            child: SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final definition = categories[index];
                  return _CategoryCard(
                    definition: definition,
                    onTap: user?.branchId == null
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            final result = await navigator.push(
                              MaterialPageRoute(
                                builder: (_) => RequestFormPage(
                                  category: definition.category,
                                ),
                              ),
                            );
                            if (!mounted || result is! BranchRequest) {
                              return;
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${definition.title} oluşturuldu.',
                                ),
                              ),
                            );
                            ref.invalidate(personalRequestsProvider);
                          },
                  );
                },
              ),
            ),
          ),

          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: colors.primary,
                unselectedLabelColor: colors.onSurfaceVariant,
                indicatorColor: colors.primary,
                indicatorWeight: 3,
                isScrollable: _isManager, // 3 tab için scroll
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.outbox_outlined, size: 18),
                        const SizedBox(width: 8),
                        const Text('Taleplerim'),
                        if (myStats.total > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${myStats.total}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 18),
                        const SizedBox(width: 8),
                        const Text('Gelen Talepler'),
                        if (incomingStats.total > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: incomingStats.pending > 0
                                  ? Colors.orange.shade100
                                  : colors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${incomingStats.total}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: incomingStats.pending > 0
                                    ? Colors.orange.shade800
                                    : colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Departman Yönetimi - sadece yöneticiler için
                  if (_isManager)
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Departmanlar'),
                        ],
                      ),
                    ),
                ],
              ),
              backgroundColor: theme.scaffoldBackgroundColor,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: Taleplerim
            _buildMyRequestsTab(
              personalRequestsAsync,
              myStats,
              colors,
              theme,
              bottomPadding,
            ),
            // TAB 2: Gelen Talepler
            _buildIncomingRequestsTab(
              incomingRequestsAsync,
              incomingStats,
              colors,
              theme,
              bottomPadding,
            ),
            // TAB 3: Departman Yönetimi - sadece yöneticiler için
            if (_isManager) const DepartmentManagementPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRequestsTab(
    AsyncValue<List<BranchRequest>> requestsAsync,
    ({int pending, int inProgress, int resolved, int total}) stats,
    ColorScheme colors,
    ThemeData theme,
    double bottomPadding,
  ) {
    return RefreshIndicator(
      onRefresh: _refreshPersonal,
      child: requestsAsync.when(
        data: (requests) {
          // Filtreleme uygula
          final filteredRequests = _statusFilter == null
              ? requests
              : requests.where((r) => r.status == _statusFilter).toList();

          if (filteredRequests.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 20),
                // Stats
                if (requests.isNotEmpty)
                  _buildStatsRow(
                      stats.pending, stats.inProgress, stats.resolved, colors),
                AppEmptyState(
                  icon: _statusFilter != null
                      ? Icons.filter_list_off
                      : Icons.inbox_outlined,
                  title: _statusFilter != null
                      ? 'Sonuç Bulunamadı'
                      : 'Henüz Talep Yok',
                  subtitle: _statusFilter != null
                      ? 'Bu durumdaki talep bulunamadı.\nFiltreyi kaldırmak için yukarıdaki butona tıklayın.'
                      : 'Yukarıdaki kategorilerden birini seçerek\nilk talebinizi oluşturabilirsiniz.',
                ),
              ],
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 16),
            itemCount: filteredRequests.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildStatsRow(
                      stats.pending, stats.inProgress, stats.resolved, colors),
                );
              }
              final request = filteredRequests[index - 1];
              final definition = RequestCategoryThemes.of(request.category);
              return _RequestCard(
                request: request,
                definition: definition,
                onTap: () => _showRequestDetails(request),
              );
            },
          );
        },
        loading: () => const Center(child: AppLoading()),
        error: (error, _) => Center(
          child: AppErrorState(
            title: 'Bir Hata Oluştu',
            message: 'Talepler yüklenirken sorun oluştu.\n$error',
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingRequestsTab(
    AsyncValue<List<BranchRequest>> requestsAsync,
    ({int pending, int inProgress, int total}) stats,
    ColorScheme colors,
    ThemeData theme,
    double bottomPadding,
  ) {
    return RefreshIndicator(
      onRefresh: _refreshIncoming,
      child: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 40),
                AppEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Gelen Talep Yok',
                  subtitle:
                      'Size atanmış veya yönetiminize\ndüşen talep bulunmuyor.',
                ),
              ],
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 16),
            itemCount: requests.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildIncomingStatsRow(
                      stats.pending, stats.inProgress, colors),
                );
              }
              final request = requests[index - 1];
              final definition = RequestCategoryThemes.of(request.category);
              return _RequestCard(
                request: request,
                definition: definition,
                onTap: () => _showRequestDetails(request),
                showCreator: true,
                showBranchName: true,
              );
            },
          );
        },
        loading: () => const Center(child: AppLoading()),
        error: (error, _) => Center(
          child: AppErrorState(
            title: 'Bir Hata Oluştu',
            message: 'Talepler yüklenirken sorun oluştu.\n$error',
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(
      int pending, int inProgress, int resolved, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatItem(
            count: pending,
            label: 'Bekleyen',
            color: Colors.amber,
            isSelected: _statusFilter == RequestStatus.pending,
            onTap: () => setState(() {
              _statusFilter = _statusFilter == RequestStatus.pending
                  ? null
                  : RequestStatus.pending;
            }),
          ),
          const SizedBox(width: 12),
          _StatItem(
            count: inProgress,
            label: 'İşlemde',
            color: Colors.blue,
            isSelected: _statusFilter == RequestStatus.inProgress,
            onTap: () => setState(() {
              _statusFilter = _statusFilter == RequestStatus.inProgress
                  ? null
                  : RequestStatus.inProgress;
            }),
          ),
          const SizedBox(width: 12),
          _StatItem(
            count: resolved,
            label: 'Çözüldü',
            color: Colors.green,
            isSelected: _statusFilter == RequestStatus.resolved,
            onTap: () => setState(() {
              _statusFilter = _statusFilter == RequestStatus.resolved
                  ? null
                  : RequestStatus.resolved;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingStatsRow(
      int pending, int inProgress, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatItem(
            count: pending,
            label: 'Bekleyen',
            color: Colors.orange,
            isSelected: false,
            onTap: null,
          ),
          const SizedBox(width: 12),
          _StatItem(
            count: inProgress,
            label: 'İşlemde',
            color: Colors.blue,
            isSelected: false,
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate(this.tabBar, {required this.backgroundColor});

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.count,
    required this.label,
    required this.color,
    this.isSelected = false,
    this.onTap,
  });

  final int count;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: color, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.definition,
    this.onTap,
  });

  final RequestCategoryThemeData definition;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              definition.color.withValues(alpha: 0.15),
              definition.color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: definition.color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: definition.color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: definition.color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                definition.icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            const Spacer(),
            Text(
              definition.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Oluştur',
                  style: TextStyle(
                    color: definition.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: definition.color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.definition,
    required this.onTap,
    this.showCreator = false,
    this.showBranchName = false,
  });

  final BranchRequest request;
  final RequestCategoryThemeData definition;
  final VoidCallback onTap;
  final bool showCreator;
  final bool showBranchName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusInfo = _getStatusInfo(request.status, colors);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Category Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: definition.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      definition.icon,
                      color: definition.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          definition.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: colors.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(request.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusInfo.icon,
                          size: 14,
                          color: statusInfo.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusInfo.label,
                          style: TextStyle(
                            color: statusInfo.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Branch name for incoming requests
              if (showBranchName && request.branchName != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.store_outlined,
                          size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Şube: ${request.branchName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Created By info for incoming requests
              if (showCreator && request.payload?['creator_name'] != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 16, color: colors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Talep Eden: ${request.payload!['creator_name']}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Assigned to - İşleme Alan info
              if (showBranchName && request.assignedTo != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_ind_outlined,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'İşleme Alan: ${request.assignedToName ?? 'Bilinmiyor'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Unclaimed indicator
              if (showBranchName &&
                  request.assignedTo == null &&
                  request.status == RequestStatus.pending) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.front_hand_outlined,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'İşleme alınmadı - Talebi işleme alabilirsiniz',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
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
    );
  }

  _StatusInfo _getStatusInfo(RequestStatus status, ColorScheme colors) {
    switch (status) {
      case RequestStatus.pending:
        return _StatusInfo(
          color: Colors.amber.shade700,
          icon: Icons.hourglass_empty,
          label: 'Bekliyor',
        );
      case RequestStatus.inProgress:
        return const _StatusInfo(
          color: Colors.blue,
          icon: Icons.sync,
          label: 'İşlemde',
        );
      case RequestStatus.resolved:
        return const _StatusInfo(
          color: Colors.green,
          icon: Icons.check_circle_outline,
          label: 'Çözüldü',
        );
      case RequestStatus.cancelled:
        return const _StatusInfo(
          color: Colors.grey,
          icon: Icons.cancel_outlined,
          label: 'İptal',
        );
      case RequestStatus.rejected:
        return const _StatusInfo(
          color: Colors.red,
          icon: Icons.block,
          label: 'Reddedildi',
        );
      case RequestStatus.failed:
        return const _StatusInfo(
          color: Colors.deepOrange,
          icon: Icons.error_outline,
          label: 'Tamamlanamadı',
        );
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }
}

class _StatusInfo {
  const _StatusInfo({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;
}

enum _RequestDetailsResult {
  cancelled,
  edit,
}

class _RequestDetailsSheet extends ConsumerStatefulWidget {
  const _RequestDetailsSheet({required this.request});

  final BranchRequest request;

  @override
  ConsumerState<_RequestDetailsSheet> createState() =>
      _RequestDetailsSheetState();
}

class _RequestDetailsSheetState extends ConsumerState<_RequestDetailsSheet> {
  bool _isCancelling = false;
  bool _isUpdatingStatus = false;
  bool _isClaiming = false;
  bool _isTransferring = false;
  final Map<String, Future<String?>> _attachmentUrlFutures =
      <String, Future<String?>>{};

  static const String _storageBucket = 'request-files';

  bool get _canModify {
    final status = widget.request.status;
    return status == RequestStatus.pending ||
        status == RequestStatus.inProgress;
  }

  /// Talebi işleme alabilir mi kontrolü
  /// - Kullanıcı bir departmana ait olmalı
  /// - Talep o departmana atanmış olmalı (veya departmana atanmamışsa target_user_id ile eşleşmeli)
  /// - Talep henüz atanmamış olmalı
  /// - Kendi talebi olmamalı
  /// - Pending durumunda olmalı
  bool get _canClaim {
    final authState = ref.read(authProvider);
    final currentUser = authState.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );

    if (currentUser == null) return false;
    if (widget.request.createdBy == currentUser.id) return false;
    if (widget.request.assignedTo != null) return false;
    if (widget.request.status != RequestStatus.pending) return false;

    // Kullanıcı bir departmana ait olmalı
    if (currentUser.departmentId == null) return false;

    // Talep bir departmana atanmışsa, kullanıcının o departmanda olması gerekir
    if (widget.request.targetDepartmentId != null) {
      if (widget.request.targetDepartmentId != currentUser.departmentId) {
        return false;
      }
    } else {
      // Departmana atanmamışsa, target_user_id ile eşleşmeli veya target_user_id olmamalı
      if (widget.request.targetUserId != null &&
          widget.request.targetUserId != currentUser.id) {
        return false;
      }
    }

    return true;
  }

  /// Talebi devredebilir mi kontrolü
  /// - Talep bu kullanıcıya atanmış olmalı
  bool get _canTransfer {
    final authState = ref.read(authProvider);
    final currentUser = authState.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );
    if (currentUser == null) return false;
    return widget.request.assignedTo == currentUser.id;
  }

  /// Workflow işlemleri yapabilecek yetkili mi kontrolü
  /// Talep eden kişi kendi talebini yönetemez
  bool get _canManageWorkflow {
    final authState = ref.read(authProvider);
    final currentUser = authState.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );
    if (currentUser == null) return false;

    // Kendi talebini yönetemez
    if (widget.request.createdBy == currentUser.id) {
      return false;
    }

    // Hedef kullanıcı ise (ve talebi kendisi oluşturmadıysa)
    final targetUserId = widget.request.payload?['target_user_id'] as String?;
    if (targetUserId != null && targetUserId == currentUser.id) {
      return true;
    }

    // Yönetici rolleri
    final managerRoles = ['firma_admin', 'bolge_muduru', 'sube_muduru'];
    return managerRoles.contains(currentUser.role);
  }

  List<String> get _attachmentReferences {
    final attachments = widget.request.payload?['attachments'];
    if (attachments is List) {
      return attachments
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  Future<void> _handleCancel() async {
    if (!_canModify || _isCancelling) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Talebi iptal et'),
        content: const Text(
          'Talebi iptal etmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isCancelling = true);

    try {
      final repo = ref.read(requestRepositoryProvider);
      await repo.updateStatus(
        requestId: widget.request.id,
        status: RequestStatus.cancelled,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(_RequestDetailsResult.cancelled);
    } on PostgrestException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Talep iptal edilemedi: ${error.message}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beklenmeyen bir hata oluştu: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  void _handleEdit() {
    if (!_canModify) {
      return;
    }
    Navigator.of(context).pop(_RequestDetailsResult.edit);
  }

  Future<void> _updateRequestStatus(
      RequestStatus newStatus, String actionLabel) async {
    if (_isUpdatingStatus) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$actionLabel?'),
        content: Text(
          'Bu talebi "$actionLabel" olarak işaretlemek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUpdatingStatus = true);

    try {
      final repo = ref.read(requestRepositoryProvider);
      await repo.updateRequestStatusWorkflow(
        requestId: widget.request.id,
        newStatus: newStatus,
      );
      if (!mounted) return;
      Navigator.of(context)
          .pop(_RequestDetailsResult.cancelled); // Listeyi yenilemek için
    } on PostgrestException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: ${error.message}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beklenmeyen bir hata oluştu: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  void _handleTakeInProgress() =>
      _updateRequestStatus(RequestStatus.inProgress, 'İşleme Al');
  void _handleReject() =>
      _updateRequestStatus(RequestStatus.rejected, 'Reddet');
  void _handleResolve() =>
      _updateRequestStatus(RequestStatus.resolved, 'Tamamlandı');
  void _handleFail() =>
      _updateRequestStatus(RequestStatus.failed, 'Tamamlanamadı');

  /// Talebi işleme al (claim)
  Future<void> _handleClaim() async {
    if (_isClaiming) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Talebi İşleme Al'),
        content: const Text(
          'Bu talebi işleme almak istediğinizden emin misiniz?\n\nTalep size atanacak ve diğer kullanıcılar tarafından alınamaz hale gelecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('İşleme Al'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClaiming = true);

    try {
      final repo = ref.read(requestRepositoryProvider);
      await repo.claimRequest(widget.request.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Talep başarıyla işleme alındı.')),
      );
      Navigator.of(context).pop(_RequestDetailsResult.cancelled);
    } on PostgrestException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: ${error.message}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beklenmeyen bir hata oluştu: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isClaiming = false);
      }
    }
  }

  /// Talebi devret
  Future<void> _handleTransfer() async {
    if (_isTransferring) return;

    // Departman arkadaşlarını yükle
    final colleagues = await ref.read(departmentColleaguesProvider.future);

    if (colleagues.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Departmanınızda transfer edilebilecek kullanıcı bulunamadı.'),
        ),
      );
      return;
    }

    // Kullanıcı seçimi dialog'ı
    if (!mounted) return;
    final selectedUser = await showDialog<DepartmentUser>(
      context: context,
      builder: (context) => _TransferUserSelectionDialog(
        colleagues: colleagues,
      ),
    );

    if (selectedUser == null || !mounted) return;

    // Transfer sebebi iste
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _TransferReasonDialog(),
    );

    if (!mounted) return;

    setState(() => _isTransferring = true);

    try {
      final repo = ref.read(requestRepositoryProvider);
      await repo.createTransferRequest(
        requestId: widget.request.id,
        toUserId: selectedUser.id,
        reason: reason,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Transfer talebi ${selectedUser.fullName} kullanıcısına gönderildi.'),
        ),
      );
      Navigator.of(context).pop(_RequestDetailsResult.cancelled);
    } on PostgrestException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: ${error.message}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beklenmeyen bir hata oluştu: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }

  Future<String?> _getAttachmentUrl(String reference) {
    return _attachmentUrlFutures.putIfAbsent(reference, () async {
      final storage = Supabase.instance.client.storage.from(_storageBucket);

      String? path;
      if (reference.startsWith('http')) {
        path = _extractStoragePath(reference);
        if (path == null) {
          return reference;
        }
      } else {
        path = reference;
      }

      try {
        return await storage.createSignedUrl(path, 60 * 60);
      } catch (_) {
        if (reference.startsWith('http')) {
          return reference;
        }
        return null;
      }
    });
  }

  String? _extractStoragePath(String reference) {
    try {
      final uri = Uri.parse(reference);
      if (!uri.pathSegments.contains(_storageBucket)) {
        return null;
      }
      final bucketIndex = uri.pathSegments.indexOf(_storageBucket);
      if (bucketIndex == -1 || bucketIndex + 1 >= uri.pathSegments.length) {
        return null;
      }
      final segments = uri.pathSegments.sublist(bucketIndex + 1);
      return segments.join('/');
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAttachmentReference(String reference) async {
    final resolvedUrl = await _getAttachmentUrl(reference);
    if (!mounted) {
      return;
    }
    if (resolvedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görsel yüklenemedi.')),
      );
      return;
    }
    _openImage(resolvedUrl);
  }

  void _openImage(String url) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, _, __) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                color: Colors.white54),
                            SizedBox(height: 8),
                            Text(
                              'Görsel yüklenemedi',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final definition = RequestCategoryThemes.of(request.category);
    final attachmentReferences = _attachmentReferences;
    final payload = request.payload ?? const <String, dynamic>{};
    final malfunctionLabel = payload['malfunction_type_label'] as String? ??
        MalfunctionIssueTypeX.maybeFromValue(
                payload['malfunction_type'] as String?)
            ?.label;
    final equipmentLabel = payload['equipment_type_label'] as String? ??
        EquipmentRequestTypeX.maybeFromValue(
                payload['equipment_type'] as String?)
            ?.label;

    final canModify = _canModify;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Header with gradient
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        definition.color.withValues(alpha: 0.15),
                        definition.color.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: definition.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: definition.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          definition.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              definition.title,
                              style: TextStyle(
                                color: definition.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Status and Date
                Row(
                  children: [
                    Expanded(
                      child: _DetailItem(
                        icon: Icons.flag_outlined,
                        label: 'Durum',
                        value: request.status.label,
                        valueColor: _getStatusColor(request.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DetailItem(
                        icon: Icons.access_time,
                        label: 'Oluşturulma',
                        value: _formatDateTime(request.createdAt),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (malfunctionLabel != null)
                  _DetailItem(
                    icon: Icons.warning_amber_outlined,
                    label: 'Arıza Türü',
                    value: malfunctionLabel,
                  ),
                if (equipmentLabel != null)
                  _DetailItem(
                    icon: Icons.build_outlined,
                    label: 'Ekipman Türü',
                    value: equipmentLabel,
                  ),
                if (request.description != null &&
                    request.description!.isNotEmpty)
                  _DetailItem(
                    icon: Icons.notes_outlined,
                    label: 'Açıklama',
                    value: request.description!,
                  ),
                if (request.branchName != null &&
                    request.branchName!.isNotEmpty)
                  _DetailItem(
                    icon: Icons.store_outlined,
                    label: 'Şube',
                    value: request.branchName!,
                  ),
                if (request.targetDepartment != null &&
                    request.targetDepartment!.isNotEmpty)
                  _DetailItem(
                    icon: Icons.business_outlined,
                    label: 'Hedef Birim',
                    value: request.targetDepartment!,
                  ),
                if (request.assignedTo != null)
                  _DetailItem(
                    icon: Icons.assignment_ind_outlined,
                    label: 'İşleme Alan',
                    value: request.assignedToName ?? 'Bilinmiyor',
                    valueColor: Colors.green,
                  ),

                // Attachments
                if (attachmentReferences.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Ekler (${attachmentReferences.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: attachmentReferences.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final reference = attachmentReferences[index];
                        return FutureBuilder<String?>(
                          future: _getAttachmentUrl(reference),
                          builder: (context, snapshot) {
                            return InkWell(
                              onTap: () => _openAttachmentReference(reference),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 80,
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  image: snapshot.hasData &&
                                          snapshot.data != null
                                      ? DecorationImage(
                                          image: NetworkImage(snapshot.data!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : snapshot.hasError || snapshot.data == null
                                        ? const Icon(Icons.image_outlined)
                                        : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],

                // Actions - Talep sahibi için
                if (canModify) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isCancelling ? null : _handleCancel,
                          icon: _isCancelling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cancel_outlined),
                          label: const Text('İptal Et'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _handleEdit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Düzenle'),
                        ),
                      ),
                    ],
                  ),
                ],

                // Workflow Actions - Yetkililer için
                if (_canManageWorkflow) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Talep Yönetimi',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (request.status == RequestStatus.pending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUpdatingStatus ? null : _handleReject,
                            icon: _isUpdatingStatus
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.block),
                            label: const Text('Reddet'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isUpdatingStatus
                                ? null
                                : _handleTakeInProgress,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('İşleme Al'),
                          ),
                        ),
                      ],
                    ),
                  ] else if (request.status == RequestStatus.inProgress) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUpdatingStatus ? null : _handleFail,
                            icon: _isUpdatingStatus
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.error_outline),
                            label: const Text('Tamamlanamadı'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepOrange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                _isUpdatingStatus ? null : _handleResolve,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Tamamlandı'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                // Claim Action - Atanmamış talepler için
                if (_canClaim) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Talebi Üstlen',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu talep henüz kimseye atanmamış. Talebi işleme alarak üstlenebilirsiniz.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isClaiming ? null : _handleClaim,
                      icon: _isClaiming
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.front_hand),
                      label: const Text('Talebi İşleme Al'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ),
                ],

                // Transfer Action - Atanmış talepler için
                if (_canTransfer) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Talebi Devret',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu talep size atanmış. Departmanınızdaki başka bir kullanıcıya devredebilirsiniz.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isTransferring ? null : _handleTransfer,
                      icon: _isTransferring
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.swap_horiz),
                      label: const Text('Departman Üyesine Devret'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
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

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Colors.amber.shade700;
      case RequestStatus.inProgress:
        return Colors.blue;
      case RequestStatus.resolved:
        return Colors.green;
      case RequestStatus.cancelled:
        return Colors.grey;
      case RequestStatus.rejected:
        return Colors.red;
      case RequestStatus.failed:
        return Colors.deepOrange;
    }
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
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

/// Transfer için kullanıcı seçimi dialog'ı
class _TransferUserSelectionDialog extends StatelessWidget {
  const _TransferUserSelectionDialog({required this.colleagues});

  final List<DepartmentUser> colleagues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: const Text('Kullanıcı Seç'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: colleagues.length,
          itemBuilder: (context, index) {
            final user = colleagues[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Text(
                  user.fullName.isNotEmpty
                      ? user.fullName[0].toUpperCase()
                      : '?',
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
              ),
              title: Text(user.fullName),
              subtitle: Text(user.roleLabel),
              onTap: () => Navigator.of(context).pop(user),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}

/// Transfer sebebi girişi dialog'ı
class _TransferReasonDialog extends StatefulWidget {
  @override
  State<_TransferReasonDialog> createState() => _TransferReasonDialogState();
}

class _TransferReasonDialogState extends State<_TransferReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfer Sebebi'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Sebep (opsiyonel)',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context)
              .pop(_controller.text.isNotEmpty ? _controller.text : null),
          child: const Text('Transfer Et'),
        ),
      ],
    );
  }
}
