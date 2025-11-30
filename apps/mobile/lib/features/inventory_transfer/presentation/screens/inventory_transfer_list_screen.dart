import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/core/routing/app_router.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/inventory_transfer/data/models/inventory_transfer_model.dart';
import 'package:yotech_mobile/features/inventory_transfer/presentation/providers/inventory_transfer_provider.dart';

enum _NoticeFilter { all, surplus, shortage }

class InventoryTransferListScreen extends ConsumerStatefulWidget {
  const InventoryTransferListScreen({super.key});

  @override
  ConsumerState<InventoryTransferListScreen> createState() =>
      _InventoryTransferListScreenState();
}

class _InventoryTransferListScreenState
    extends ConsumerState<InventoryTransferListScreen> {
  _NoticeFilter _filter = _NoticeFilter.all;

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(inventoryTransferListProvider);
    final user =
        ref.watch(authProvider).mapOrNull(authenticated: (s) => s.user);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Depolar Arası Sevk'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tüm İlanlar'),
              Tab(text: 'İlanlarım'),
            ],
          ),
        ),
        body: noticesAsync.when(
          data: (notices) {
            final myBranchId = user?.branchId;
            final allNotices =
                notices.where((n) => n.branchId != myBranchId).toList();
            final myNotices =
                notices.where((n) => n.branchId == myBranchId).toList();

            return TabBarView(
              children: [
                _buildAllNotices(allNotices),
                _NoticeList(notices: myNotices, isMyList: true),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Hata: $err')),
        ),
      ),
    );
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

  const _NoticeList({required this.notices, required this.isMyList});

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) {
      return const Center(child: Text('Kayıt bulunamadı'));
    }

    return ListView.builder(
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
                '${notice.productName} (${notice.quantity} ${notice.unit})'),
            subtitle: Text(
              '${notice.type == DepotNoticeType.surplus ? 'Fazla' : 'Eksik'} - ${notice.status.name}',
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
    );
  }
}
