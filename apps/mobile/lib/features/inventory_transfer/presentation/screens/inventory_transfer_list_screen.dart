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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Depolar Arası Sevk'),
        bottom: TabBar(
          controller: _tabController,
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
      ),
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

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAllNotices(allNotices),
              _NoticeList(
                notices: myNotices,
                isMyList: true,
                onRefresh: _refreshNotices,
              ),
              _OfferHistoryList(
                offers: myOffers,
                onRefresh: _refreshNotices,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
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
    switch (_filter) {
      case _NoticeFilter.surplus:
        return notices
            .where((notice) => notice.type == DepotNoticeType.surplus)
            .toList();
      case _NoticeFilter.shortage:
        return notices
            .where((notice) => notice.type == DepotNoticeType.shortage)
            .toList();
      case _NoticeFilter.all:
        return notices;
    }
  }

  void _openCreateNotice() {
    Navigator.of(context).pushNamed(AppRouter.createInventoryTransfer);
  }

  Future<void> _refreshNotices() async {
    await ref.read(inventoryTransferListProvider.notifier).refresh();
  }

  Widget _buildAllNotices(List<DepotNotice> notices) {
    final filtered = _applyFilter(notices);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openCreateNotice,
              icon: const Icon(Icons.add),
              label: const Text('İlan Ekle'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tüm ilanlar için filtreler',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterChip('Tümü', _NoticeFilter.all),
                  _buildFilterChip('Fazla Ürünler', _NoticeFilter.surplus),
                  _buildFilterChip('Eksik Ürünler', _NoticeFilter.shortage),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        Expanded(
          child: _NoticeList(
            notices: filtered,
            isMyList: false,
            onRefresh: _refreshNotices,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, _NoticeFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (selected) {
        if (!selected) return;
        setState(() => _filter = filter);
      },
    );
  }
}

class _NoticeList extends StatelessWidget {
  final List<DepotNotice> notices;
  final bool isMyList;
  final Future<void> Function()? onRefresh;

  const _NoticeList({
    required this.notices,
    required this.isMyList,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Kayıt bulunamadı')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView.builder(
        itemCount: notices.length,
        itemBuilder: (context, index) {
          final notice = notices[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(
                notice.type == DepotNoticeType.surplus
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                color: notice.type == DepotNoticeType.surplus
                    ? Colors.green
                    : Colors.red,
              ),
              title: Text(
                '${notice.productName} (${_formatQuantity(notice.remainingQuantity)} ${notice.unit} kaldı)',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${notice.branchName ?? 'Şube bilgisi yok'} • ${_noticeTypeLabel(notice.type)} - ${_noticeStatusLabel(notice.status)}',
                  ),
                  Text(
                    'Toplam: ${_formatQuantity(notice.quantity)} ${notice.unit}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRouter.inventoryTransferDetail,
                  arguments: notice,
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _noticeStatusLabel(DepotNoticeStatus status) {
    switch (status) {
      case DepotNoticeStatus.open:
        return 'İlan Aşaması';
      case DepotNoticeStatus.inTransfer:
        return 'Transferde';
      case DepotNoticeStatus.fulfilled:
        return 'Tamamlandı';
      case DepotNoticeStatus.cancelled:
        return 'İptal';
    }
  }

  String _noticeTypeLabel(DepotNoticeType type) {
    switch (type) {
      case DepotNoticeType.surplus:
        return 'Fazla';
      case DepotNoticeType.shortage:
        return 'Eksik';
    }
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

  const _OfferHistoryList({
    required this.offers,
    this.onRefresh,
  });

  @override
  ConsumerState<_OfferHistoryList> createState() => _OfferHistoryListState();
}

class _OfferHistoryListState extends ConsumerState<_OfferHistoryList> {
  String? _processingOfferId;

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh ?? () async {},
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Henüz bir talepte bulunmadınız')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: ListView.builder(
        itemCount: widget.offers.length,
        itemBuilder: (context, index) {
          final item = widget.offers[index];
          final statusColor = _statusColor(item.offer.status, context);
          final isProcessing = _processingOfferId == item.offer.id;
          final showActions = _shouldShowActions(item.offer.status);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.compare_arrows, color: statusColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.notice.productName} (${item.offer.quantity} ${item.notice.unit})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.offer.branchName ?? 'Şubeniz'} → ${item.notice.branchName ?? 'Hedef şube'}',
                            ),
                            if (item.offer.message != null &&
                                item.offer.message!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.offer.message!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey[700]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Chip(
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        label: Text(
                          _offerStatusLabel(item.offer.status),
                          style: TextStyle(color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  if (showActions) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    if (isProcessing)
                      const Center(child: CircularProgressIndicator())
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (_canEdit(item.offer.status))
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Talebi Güncelle'),
                              onPressed: () => _handleEditOffer(item),
                            ),
                          if (_canCancel(item.offer.status))
                            OutlinedButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text('İptal Et'),
                              onPressed: () => _handleCancelOffer(item),
                            ),
                          if (_canMarkDelivered(item.offer.status))
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Teslim Aldım'),
                              onPressed: () => _handleMarkDelivered(item),
                            ),
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

  Color _statusColor(DepotOfferStatus status, BuildContext context) {
    switch (status) {
      case DepotOfferStatus.accepted:
        return Colors.green;
      case DepotOfferStatus.rejected:
        return Colors.red;
      case DepotOfferStatus.expired:
        return Colors.orange;
      case DepotOfferStatus.pending:
        return Theme.of(context).colorScheme.primary;
      case DepotOfferStatus.cancelled:
        return Colors.grey;
      case DepotOfferStatus.delivered:
        return Colors.blueGrey;
    }
  }

  String _offerStatusLabel(DepotOfferStatus status) {
    switch (status) {
      case DepotOfferStatus.accepted:
        return 'Onaylandı';
      case DepotOfferStatus.rejected:
        return 'Reddedildi';
      case DepotOfferStatus.expired:
        return 'Süre Doldu';
      case DepotOfferStatus.pending:
        return 'Beklemede';
      case DepotOfferStatus.cancelled:
        return 'İptal Edildi';
      case DepotOfferStatus.delivered:
        return 'Teslim Edildi';
    }
  }

  String _formatQuantity(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toString();
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
