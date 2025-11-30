import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/inventory_transfer/data/models/inventory_transfer_model.dart';
import 'package:yotech_mobile/features/inventory_transfer/presentation/providers/inventory_transfer_provider.dart';

class NoticeDetailScreen extends ConsumerStatefulWidget {
  final DepotNotice notice;

  const NoticeDetailScreen({super.key, required this.notice});

  @override
  ConsumerState<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends ConsumerState<NoticeDetailScreen> {
  final _offerQuantityController = TextEditingController();
  final _offerMessageController = TextEditingController();

  @override
  void dispose() {
    _offerQuantityController.dispose();
    _offerMessageController.dispose();
    super.dispose();
  }

  void _showMakeOfferDialog() {
    _offerQuantityController.text = widget.notice.quantity.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teklif Ver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _offerQuantityController,
              decoration: const InputDecoration(labelText: 'Miktar'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _offerMessageController,
              decoration: const InputDecoration(labelText: 'Mesaj'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(inventoryTransferListProvider.notifier)
                    .createOffer(
                      noticeId: widget.notice.id,
                      quantity: double.parse(_offerQuantityController.text),
                      message: _offerMessageController.text,
                    );
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Teklif gönderildi')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Hata: $e')),
                );
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user =
        ref.watch(authProvider).mapOrNull(authenticated: (s) => s.user);
    final isOwner = user?.branchId == widget.notice.branchId;

    return Scaffold(
      appBar: AppBar(title: Text(widget.notice.productName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            if (isOwner) ...[
              const Text(
                'Gelen Teklifler',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildOffersList(),
            ] else if (widget.notice.status == DepotNoticeStatus.open) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showMakeOfferDialog,
                  child: const Text('Talep Et / Gönder'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Durum', widget.notice.status.name),
            _row(
                'Tip',
                widget.notice.type == DepotNoticeType.surplus
                    ? 'Fazla'
                    : 'Eksik'),
            _row('Miktar', '${widget.notice.quantity} ${widget.notice.unit}'),
            if (widget.notice.note != null) _row('Not', widget.notice.note!),
            _row('Oluşturulma',
                widget.notice.createdAt.toString().split(' ')[0]),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    final offers = widget.notice.offers ?? [];
    if (offers.isEmpty) {
      return const Text('Henüz teklif yok.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return Card(
          child: ListTile(
            title: Text('${offer.quantity} adet'),
            subtitle: Text(offer.message ?? 'Mesaj yok'),
            trailing: offer.status == DepotOfferStatus.pending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () {
                          ref
                              .read(inventoryTransferListProvider.notifier)
                              .acceptOffer(offer.id, widget.notice.id);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          ref
                              .read(inventoryTransferListProvider.notifier)
                              .rejectOffer(offer.id);
                        },
                      ),
                    ],
                  )
                : Text(offer.status.name),
          ),
        );
      },
    );
  }
}
