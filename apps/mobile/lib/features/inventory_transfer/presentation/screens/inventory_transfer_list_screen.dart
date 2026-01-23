import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/core/routing/app_router.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/inventory_transfer/data/models/inventory_transfer_model.dart';
import 'package:yotech_mobile/features/inventory_transfer/presentation/providers/inventory_transfer_provider.dart';

enum _NoticeFilter { all, surplus, shortage }

class InventoryTransferListScreen extends ConsumerStatefulWidget {
  const InventoryTransferListScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<InventoryTransferListScreen> createState() =>
      _InventoryTransferListScreenState();
}

class _InventoryTransferListScreenState
    extends ConsumerState<InventoryTransferListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _NoticeFilter _filter = _NoticeFilter.all;
  DepotOfferStatus? _offerStatusFilter; // Taleplerim tab için filtre
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final clampedIndex = widget.initialTabIndex.clamp(0, 2).toInt();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: clampedIndex,
    );
    _tabController.addListener(_handleTabControllerChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyTabSeen(_tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabControllerChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabControllerChange() {
    if (_tabController.indexIsChanging) return;
    _notifyTabSeen(_tabController.index);
  }

  void _notifyTabSeen(int index) {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    final userId = user?.id;
    if (userId == null) return;
    final notifier =
        ref.read(inventoryTransferAlertStatusProvider(userId).notifier);
    if (index == 1) {
      notifier.markIncomingSeen();
    } else if (index == 2) {
      notifier.markDecisionSeen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(inventoryTransferListProvider);
    final user =
        ref.watch(authProvider).mapOrNull(authenticated: (s) => s.user);
    final indicators = ref.watch(inventoryTransferIndicatorsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: noticesAsync.when(
        data: (notices) {
          final myBranchId = user?.branchId;
          final allNotices =
              notices.where(_isActiveNotice).toList(growable: false);
          final myNotices = myBranchId == null
              ? <DepotNotice>[]
              : notices
                  .where((n) => n.branchId == myBranchId && n.hasRemaining)
                  .toList();
          final myOffers = _buildMyOffers(notices, user?.id);

          // İstatistikleri hesapla
          final openCount = allNotices.length;
          final pendingOffers = myOffers
              .where((o) => o.offer.status == DepotOfferStatus.pending)
              .length;
          final acceptedOffers = myOffers
              .where((o) => o.offer.status == DepotOfferStatus.accepted)
              .length;

          return NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: _buildHeader(
                  context,
                  openCount: openCount,
                  pendingOffers: pendingOffers,
                  acceptedOffers: acceptedOffers,
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  tabBar: TabBar(
                    controller: _tabController,
                    labelColor: cs.primary,
                    unselectedLabelColor: cs.onSurfaceVariant,
                    indicatorColor: cs.primary,
                    indicatorWeight: 3,
                    tabs: [
                      const Tab(text: 'Tüm İlanlar'),
                      Tab(
                        child: _BadgeTabLabel(
                          label: 'İlanlarım',
                          count: indicators.incomingOfferCount,
                        ),
                      ),
                      Tab(
                        child: _BadgeTabLabel(
                          label: 'Taleplerim',
                          count: indicators.awaitingDecisionCount,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: cs.surface,
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildAllNotices(allNotices),
                _NoticeList(
                  notices: myNotices,
                  isMyList: true,
                  onRefresh: _refreshNotices,
                  emptyTitle: 'Henüz ilan yok',
                  emptySubtitle: 'Fazla veya eksik ürün ilanı oluşturun',
                ),
                _OfferHistoryList(
                  offers: myOffers,
                  onRefresh: _refreshNotices,
                  statusFilter: _offerStatusFilter,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Hata: $err'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _refreshNotices,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required int openCount,
    required int pendingOffers,
    required int acceptedOffers,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer,
            cs.primary.withValues(alpha: 0.7),
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: cs.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Depolar Arası Sevk',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          'Şubeler arası ürün transferi',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Yeni İlan butonu
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openCreateNotice,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 18, color: cs.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Yeni İlan',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // İstatistik kartları - tıklanabilir filtreler
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.campaign_outlined,
                      label: 'Açık İlan',
                      value: openCount.toString(),
                      color: Colors.blue,
                      isSelected: _tabController.index == 0,
                      onTap: () {
                        _tabController.animateTo(0);
                        setState(() => _offerStatusFilter = null);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.hourglass_empty,
                      label: 'Bekleyen',
                      value: pendingOffers.toString(),
                      color: Colors.orange,
                      isSelected: _tabController.index == 2 &&
                          _offerStatusFilter == DepotOfferStatus.pending,
                      onTap: () {
                        _tabController.animateTo(2);
                        setState(() {
                          _offerStatusFilter =
                              _offerStatusFilter == DepotOfferStatus.pending
                                  ? null
                                  : DepotOfferStatus.pending;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Onaylanan',
                      value: acceptedOffers.toString(),
                      color: Colors.green,
                      isSelected: _tabController.index == 2 &&
                          _offerStatusFilter == DepotOfferStatus.accepted,
                      onTap: () {
                        _tabController.animateTo(2);
                        setState(() {
                          _offerStatusFilter =
                              _offerStatusFilter == DepotOfferStatus.accepted
                                  ? null
                                  : DepotOfferStatus.accepted;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isActiveNotice(DepotNotice notice) {
    return notice.status != DepotNoticeStatus.fulfilled && notice.hasRemaining;
  }

  List<_OfferWithNotice> _buildMyOffers(
    List<DepotNotice> notices,
    String? userId,
  ) {
    if (userId == null) return const <_OfferWithNotice>[];
    final items = <_OfferWithNotice>[];
    for (final notice in notices) {
      for (final offer in notice.offers ?? const <NoticeOffer>[]) {
        if (offer.offeredBy == userId &&
            offer.status != DepotOfferStatus.delivered) {
          items.add(_OfferWithNotice(offer: offer, notice: notice));
        }
      }
    }
    items.sort((a, b) => b.offer.createdAt.compareTo(a.offer.createdAt));
    return items;
  }

  List<DepotNotice> _applyFilter(List<DepotNotice> notices) {
    var filtered = notices;

    // Tip filtresi
    switch (_filter) {
      case _NoticeFilter.surplus:
        filtered = filtered
            .where((notice) => notice.type == DepotNoticeType.surplus)
            .toList();
      case _NoticeFilter.shortage:
        filtered = filtered
            .where((notice) => notice.type == DepotNoticeType.shortage)
            .toList();
      case _NoticeFilter.all:
        break;
    }

    // Arama filtresi
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((n) =>
              n.productName.toLowerCase().contains(query) ||
              (n.branchName?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    return filtered;
  }

  void _openCreateNotice() {
    Navigator.of(context).pushNamed(AppRouter.createInventoryTransfer);
  }

  Future<void> _refreshNotices() async {
    await ref.read(inventoryTransferListProvider.notifier).refresh();
  }

  Widget _buildAllNotices(List<DepotNotice> notices) {
    final filtered = _applyFilter(notices);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Arama alanı
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Ürün veya şube ara...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        // Filtre chip'leri
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterChip('Tümü', _NoticeFilter.all),
              const SizedBox(width: 8),
              _buildFilterChip('Fazla', _NoticeFilter.surplus),
              const SizedBox(width: 8),
              _buildFilterChip('Eksik', _NoticeFilter.shortage),
              const Spacer(),
              Text(
                '${filtered.length} ilan',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _NoticeList(
            notices: filtered,
            isMyList: false,
            onRefresh: _refreshNotices,
            emptyTitle:
                _searchQuery.isNotEmpty ? 'Sonuç bulunamadı' : 'Henüz ilan yok',
            emptySubtitle: _searchQuery.isNotEmpty
                ? 'Farklı bir arama deneyin'
                : 'Diğer şubelerden ilan bekleyin',
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, _NoticeFilter filter) {
    final isSelected = _filter == filter;
    final cs = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (!selected) return;
        setState(() => _filter = filter);
      },
      selectedColor: cs.primaryContainer,
      checkmarkColor: cs.onPrimaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

// İstatistik kartı widget'ı
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isSelected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? color : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TabBar için persistent header delegate
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

class _NoticeList extends StatelessWidget {
  final List<DepotNotice> notices;
  final bool isMyList;
  final Future<void> Function()? onRefresh;
  final String emptyTitle;
  final String emptySubtitle;

  const _NoticeList({
    required this.notices,
    required this.isMyList,
    this.onRefresh,
    this.emptyTitle = 'Kayıt bulunamadı',
    this.emptySubtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: ListView(
          children: [
            const SizedBox(height: 80),
            _EmptyState(
              icon: Icons.inventory_2_outlined,
              title: emptyTitle,
              subtitle: emptySubtitle,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: notices.length,
        itemBuilder: (context, index) {
          final notice = notices[index];
          return _NoticeCard(notice: notice);
        },
      ),
    );
  }
}

// Modern ilan kartı
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final DepotNotice notice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSurplus = notice.type == DepotNoticeType.surplus;
    final typeColor = isSurplus ? Colors.green : Colors.orange;
    final typeIcon = isSurplus ? Icons.trending_up : Icons.trending_down;
    final typeLabel = isSurplus ? 'FAZLA' : 'EKSİK';
    final statusInfo = _getStatusInfo(notice.status);
    final hasOffers = (notice.offers ?? []).isNotEmpty;
    final offerCount = notice.offers?.length ?? 0;

    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: hasOffers
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.5),
              width: hasOffers ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRouter.inventoryTransferDetail,
                arguments: notice,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst kısım: Tip badge + Durum
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 14, color: typeColor),
                            const SizedBox(width: 4),
                            Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusInfo.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusInfo.icon,
                                size: 12, color: statusInfo.color),
                            const SizedBox(width: 4),
                            Text(
                              statusInfo.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusInfo.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Ürün adı
                  Text(
                    notice.productName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Şube bilgisi
                  Row(
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          notice.branchName ?? 'Şube bilgisi yok',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Alt kısım: Miktar bilgileri
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _QuantityInfo(
                            label: 'Toplam',
                            value: _formatQuantity(notice.quantity),
                            unit: notice.unit,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: cs.outlineVariant,
                        ),
                        Expanded(
                          child: _QuantityInfo(
                            label: 'Kalan',
                            value: _formatQuantity(notice.remainingQuantity),
                            unit: notice.unit,
                            isHighlight: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Teklif sayısı göstergesi - tıklanabilir
                  if ((notice.offers ?? []).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showOffersSheet(context, notice),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 14,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${notice.offers!.length} teklif',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Detay',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: cs.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Teklif badge'i - sağ üst köşede
        if (hasOffers)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_offer, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '$offerCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  _StatusInfo _getStatusInfo(DepotNoticeStatus status) {
    switch (status) {
      case DepotNoticeStatus.open:
        return const _StatusInfo(
          label: 'Açık',
          color: Colors.blue,
          icon: Icons.radio_button_checked,
        );
      case DepotNoticeStatus.inTransfer:
        return const _StatusInfo(
          label: 'Transferde',
          color: Colors.orange,
          icon: Icons.local_shipping_outlined,
        );
      case DepotNoticeStatus.fulfilled:
        return const _StatusInfo(
          label: 'Tamamlandı',
          color: Colors.green,
          icon: Icons.check_circle_outline,
        );
      case DepotNoticeStatus.cancelled:
        return const _StatusInfo(
          label: 'İptal',
          color: Colors.grey,
          icon: Icons.cancel_outlined,
        );
    }
  }

  void _showOffersSheet(BuildContext context, DepotNotice notice) {
    final cs = Theme.of(context).colorScheme;
    final offers = notice.offers ?? [];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.people, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gelen Teklifler',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            notice.productName,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Offer list
                if (offers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Henüz teklif yok')),
                  )
                else
                  ...offers.map((offer) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              child: Icon(Icons.store,
                                  color: cs.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    offer.branchName ?? 'Bilinmeyen Şube',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${offer.quantity} adet teklif edildi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getOfferStatusColor(offer.status)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getOfferStatusLabel(offer.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getOfferStatusColor(offer.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getOfferStatusColor(DepotOfferStatus status) {
    switch (status) {
      case DepotOfferStatus.pending:
        return Colors.orange;
      case DepotOfferStatus.accepted:
        return Colors.green;
      case DepotOfferStatus.rejected:
        return Colors.red;
      case DepotOfferStatus.delivered:
        return Colors.blue;
      case DepotOfferStatus.expired:
        return Colors.grey;
      case DepotOfferStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getOfferStatusLabel(DepotOfferStatus status) {
    switch (status) {
      case DepotOfferStatus.pending:
        return 'Bekliyor';
      case DepotOfferStatus.accepted:
        return 'Onaylandı';
      case DepotOfferStatus.rejected:
        return 'Reddedildi';
      case DepotOfferStatus.delivered:
        return 'Teslim Edildi';
      case DepotOfferStatus.expired:
        return 'Süresi Doldu';
      case DepotOfferStatus.cancelled:
        return 'İptal Edildi';
    }
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
}

class _QuantityInfo extends StatelessWidget {
  const _QuantityInfo({
    required this.label,
    required this.value,
    required this.unit,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? cs.primary : cs.onSurface,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Empty state widget'ı
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    this.subtitle = '',
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

String _formatQuantity(double value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  final formatted = value.toStringAsFixed(1);
  return formatted.endsWith('.0')
      ? formatted.substring(0, formatted.length - 2)
      : formatted;
}

class _OfferHistoryList extends ConsumerStatefulWidget {
  final List<_OfferWithNotice> offers;
  final Future<void> Function()? onRefresh;
  final DepotOfferStatus? statusFilter;

  const _OfferHistoryList({
    required this.offers,
    this.onRefresh,
    this.statusFilter,
  });

  @override
  ConsumerState<_OfferHistoryList> createState() => _OfferHistoryListState();
}

class _OfferHistoryListState extends ConsumerState<_OfferHistoryList> {
  String? _processingOfferId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Filtreyi uygula
    final filteredOffers = widget.statusFilter == null
        ? widget.offers
        : widget.offers
            .where((o) => o.offer.status == widget.statusFilter)
            .toList();

    if (filteredOffers.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh ?? () async {},
        child: ListView(
          children: [
            const SizedBox(height: 80),
            _EmptyState(
              icon: widget.statusFilter != null
                  ? Icons.filter_list_off
                  : Icons.compare_arrows,
              title: widget.statusFilter != null
                  ? 'Sonuç Bulunamadı'
                  : 'Henüz talepte bulunmadınız',
              subtitle: widget.statusFilter != null
                  ? 'Bu durumdaki talep bulunamadı'
                  : 'Diğer şubelerin ilanlarına teklif verin',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: filteredOffers.length,
        itemBuilder: (context, index) {
          final item = filteredOffers[index];
          final statusInfo = _getOfferStatusInfo(item.offer.status, cs);
          final isProcessing = _processingOfferId == item.offer.id;
          final showActions = _shouldShowActions(item.offer.status);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: statusInfo.color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst kısım: Durum badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusInfo.color.withValues(alpha: 0.12),
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
                            const SizedBox(width: 5),
                            Text(
                              statusInfo.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusInfo.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${item.offer.quantity.toInt()} ${item.notice.unit}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Ürün adı
                  Text(
                    item.notice.productName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Transfer yönü
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kaynak',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.offer.branchName ?? 'Şubeniz',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: cs.primary,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Hedef',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.notice.branchName ?? 'Hedef şube',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Mesaj varsa göster
                  if (item.offer.message != null &&
                      item.offer.message!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.message_outlined,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.offer.message!,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Action butonları
                  if (showActions) ...[
                    const SizedBox(height: 14),
                    if (isProcessing)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      Row(
                        children: [
                          if (_canEdit(item.offer.status))
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.edit_outlined,
                                label: 'Düzenle',
                                onTap: () => _handleEditOffer(item),
                                color: cs.primary,
                              ),
                            ),
                          if (_canEdit(item.offer.status) &&
                              _canCancel(item.offer.status))
                            const SizedBox(width: 8),
                          if (_canCancel(item.offer.status))
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.close,
                                label: 'İptal',
                                onTap: () => _handleCancelOffer(item),
                                color: Colors.red,
                              ),
                            ),
                          if (_canMarkDelivered(item.offer.status)) ...[
                            if (_canCancel(item.offer.status))
                              const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: _ActionButton(
                                icon: Icons.check_circle,
                                label: 'Teslim Aldım',
                                onTap: () => _handleMarkDelivered(item),
                                color: Colors.green,
                                filled: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  _OfferStatusInfo _getOfferStatusInfo(
      DepotOfferStatus status, ColorScheme cs) {
    switch (status) {
      case DepotOfferStatus.pending:
        return _OfferStatusInfo(
          label: 'Beklemede',
          color: cs.primary,
          icon: Icons.hourglass_empty,
        );
      case DepotOfferStatus.accepted:
        return _OfferStatusInfo(
          label: 'Onaylandı',
          color: Colors.green,
          icon: Icons.check_circle_outline,
        );
      case DepotOfferStatus.rejected:
        return _OfferStatusInfo(
          label: 'Reddedildi',
          color: Colors.red,
          icon: Icons.cancel_outlined,
        );
      case DepotOfferStatus.expired:
        return _OfferStatusInfo(
          label: 'Süresi Doldu',
          color: Colors.orange,
          icon: Icons.timer_off_outlined,
        );
      case DepotOfferStatus.cancelled:
        return _OfferStatusInfo(
          label: 'İptal Edildi',
          color: Colors.grey,
          icon: Icons.block,
        );
      case DepotOfferStatus.delivered:
        return _OfferStatusInfo(
          label: 'Teslim Edildi',
          color: Colors.blueGrey,
          icon: Icons.local_shipping,
        );
    }
  }

  Future<void> _handleEditOffer(_OfferWithNotice item) async {
    final result = await _showEditOfferDialog(item);
    if (result == null) return;
    await _runAction(item.offer.id, () async {
      await ref.read(inventoryTransferListProvider.notifier).updateOwnOffer(
            offer: item.offer,
            quantity: result.quantity,
            message: result.message,
          );
    });
    _showSnackBar('Talep güncellendi');
  }

  Future<void> _handleCancelOffer(_OfferWithNotice item) async {
    final ownerBranch = item.notice.branchName ?? 'Karşı şube';
    final confirmed = await _confirmAction(
      title: 'Talebi iptal et',
      message:
          'Bu talebi iptal etmek istediğinize emin misiniz? $ownerBranch iptalden haberdar edilecek ve ilan miktarı geri yüklenecek.',
    );
    if (!confirmed) return;
    await _runAction(item.offer.id, () async {
      await ref
          .read(inventoryTransferListProvider.notifier)
          .cancelOwnOffer(item.offer);
    });
    _showSnackBar('Talep iptal edildi');
  }

  Future<void> _handleMarkDelivered(_OfferWithNotice item) async {
    final confirmed = await _confirmAction(
      title: 'Teslim alındı mı?',
      message:
          'Ürünleri fiziksel olarak teslim aldıysanız talebi tamamlayabilirsiniz. Talep listesinden kaldırılacak.',
    );
    if (!confirmed) return;
    await _runAction(item.offer.id, () async {
      await ref
          .read(inventoryTransferListProvider.notifier)
          .markOfferDelivered(item.offer);
    });
    _showSnackBar('Talep tamamlandı');
  }

  Future<void> _runAction(
      String offerId, Future<void> Function() action) async {
    setState(() => _processingOfferId = offerId);
    try {
      await action();
      await widget.onRefresh?.call();
    } catch (e) {
      _showSnackBar('Hata: $e');
    } finally {
      if (mounted) {
        setState(() => _processingOfferId = null);
      }
    }
  }

  Future<bool> _confirmAction(
      {required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Onayla'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<_OfferEditResult?> _showEditOfferDialog(_OfferWithNotice item) async {
    final quantityController = TextEditingController(
      text: _formatQuantity(item.offer.quantity),
    );
    final messageController =
        TextEditingController(text: item.offer.message ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_OfferEditResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Talebi Güncelle'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Miktar (${item.notice.unit})',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Miktar gerekli';
                    }
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) {
                      return 'Geçerli bir miktar girin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: messageController,
                  decoration:
                      const InputDecoration(labelText: 'Not (opsiyonel)'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final parsed = double.parse(
                    quantityController.text.replaceAll(',', '.'),
                  );
                  Navigator.of(context).pop(
                    _OfferEditResult(
                      quantity: parsed,
                      message: messageController.text.trim().isEmpty
                          ? null
                          : messageController.text.trim(),
                    ),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    quantityController.dispose();
    messageController.dispose();
    return result;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _canEdit(DepotOfferStatus status) => status == DepotOfferStatus.pending;

  bool _canCancel(DepotOfferStatus status) =>
      status == DepotOfferStatus.pending || status == DepotOfferStatus.accepted;

  bool _canMarkDelivered(DepotOfferStatus status) =>
      status == DepotOfferStatus.accepted;

  bool _shouldShowActions(DepotOfferStatus status) =>
      _canEdit(status) || _canCancel(status) || _canMarkDelivered(status);

  String _formatQuantity(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}

class _OfferStatusInfo {
  final String label;
  final Color color;
  final IconData icon;

  const _OfferStatusInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
}

// Action button widget'ı
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        height: 40,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 13)),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(fontSize: 13, color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

class _OfferEditResult {
  const _OfferEditResult({required this.quantity, this.message});

  final double quantity;
  final String? message;
}

class _OfferWithNotice {
  final NoticeOffer offer;
  final DepotNotice notice;

  const _OfferWithNotice({
    required this.offer,
    required this.notice,
  });
}

class _BadgeTabLabel extends StatelessWidget {
  const _BadgeTabLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Text(label);
    }

    return SizedBox(
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(label),
          ),
          Positioned(
            top: -6,
            right: -18,
            child: _BadgeDot(count: count),
          ),
        ],
      ),
    );
  }
}

class _BadgeDot extends StatelessWidget {
  const _BadgeDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
