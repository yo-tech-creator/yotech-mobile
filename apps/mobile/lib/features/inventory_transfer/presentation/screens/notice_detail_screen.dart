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
  late DepotNotice _notice;
  String? _acceptingOfferId;
  String? _rejectingOfferId;
  ProviderSubscription<AsyncValue<List<DepotNotice>>>? _noticesSubscription;

  @override
  void initState() {
    super.initState();
    _notice = widget.notice;
    _noticesSubscription = ref.listenManual<AsyncValue<List<DepotNotice>>>(
      inventoryTransferListProvider,
      (previous, next) {
        next.whenData((notices) {
          final latest = _findNoticeById(notices, widget.notice.id);
          if (latest != null && mounted) {
            setState(() => _notice = latest);
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _offerQuantityController.dispose();
    _offerMessageController.dispose();
    _noticesSubscription?.close();
    super.dispose();
  }

  void _showMakeOfferDialog() {
    final defaultQuantity = _notice.remainingQuantity > 0
        ? _notice.remainingQuantity
        : _notice.quantity;
    _offerQuantityController.text =
        defaultQuantity.clamp(1, _notice.quantity).toInt().toString();

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
              final quantity =
                  int.tryParse(_offerQuantityController.text.trim());
              if (quantity == null || quantity <= 0) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Geçerli bir miktar girin.')),
                );
                return;
              }
              try {
                await ref
                    .read(inventoryTransferListProvider.notifier)
                    .createOffer(
                      noticeId: _notice.id,
                      quantity: quantity.toDouble(),
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

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('İlanı Sil'),
            content: const Text(
              'Bu ilanı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref
          .read(inventoryTransferListProvider.notifier)
          .deleteNotice(_notice.id);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('İlan silindi')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Silme başarısız: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user =
        ref.watch(authProvider).mapOrNull(authenticated: (s) => s.user);
    final isOwner = user?.id == _notice.createdBy;

    return Scaffold(
      appBar: AppBar(
        title: Text(_notice.productName),
        actions: [
          if (isOwner)
            IconButton(
              tooltip: 'İlanı Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
        ],
      ),
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
            ] else if (_notice.status == DepotNoticeStatus.open) ...[
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
    final remaining = _notice.remainingQuantity;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Durum', _statusLabel(_notice.status)),
            _row('Tip',
                _notice.type == DepotNoticeType.surplus ? 'Fazla' : 'Eksik'),
            if (_notice.branchName != null)
              _row('Şube', _notice.branchName ?? ''),
            _row('Miktar', '${_notice.quantity} ${_notice.unit}'),
            _row('Kalan', '${_formatQuantity(remaining)} ${_notice.unit}'),
            if (_notice.note != null) _row('Not', _notice.note!),
            _row('Oluşturulma', _notice.createdAt.toString().split(' ')[0]),
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
    final offers = _notice.offers ?? [];
    if (offers.isEmpty) {
      return const Text('Henüz teklif yok.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        final isAccepting = _acceptingOfferId == offer.id;
        final isRejecting = _rejectingOfferId == offer.id;
        return Card(
          child: ListTile(
            title: Text('${offer.quantity} ${_notice.unit}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.branchName ?? 'Şube bilgisi yok'),
                if ((offer.message ?? '').isNotEmpty)
                  Text(
                    offer.message!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            trailing: offer.status == DepotOfferStatus.pending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: isAccepting
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => _acceptingOfferId = offer.id);
                                try {
                                  await ref
                                      .read(inventoryTransferListProvider
                                          .notifier)
                                      .acceptOffer(
                                          offer: offer, notice: _notice);
                                  if (!mounted) return;
                                  messenger.showSnackBar(const SnackBar(
                                      content: Text('Teklif onaylandı')));
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Hata: $e')),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _acceptingOfferId = null);
                                  }
                                }
                              },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: isRejecting
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => _rejectingOfferId = offer.id);
                                try {
                                  await ref
                                      .read(inventoryTransferListProvider
                                          .notifier)
                                      .rejectOffer(offer.id);
                                  if (!mounted) return;
                                  messenger.showSnackBar(const SnackBar(
                                      content: Text('Teklif reddedildi')));
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Hata: $e')),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _rejectingOfferId = null);
                                  }
                                }
                              },
                      ),
                    ],
                  )
                : Chip(
                    backgroundColor:
                        _offerStatusColor(offer.status).withValues(alpha: 0.15),
                    label: Text(
                      _offerStatusLabel(offer.status),
                      style: TextStyle(color: _offerStatusColor(offer.status)),
                    ),
                  ),
          ),
        );
      },
    );
  }

  String _statusLabel(DepotNoticeStatus status) {
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

  String _offerStatusLabel(DepotOfferStatus status) {
    switch (status) {
      case DepotOfferStatus.pending:
        return 'Beklemede';
      case DepotOfferStatus.accepted:
        return 'Onaylandı';
      case DepotOfferStatus.rejected:
        return 'Reddedildi';
      case DepotOfferStatus.expired:
        return 'Süre Doldu';
      case DepotOfferStatus.cancelled:
        return 'İptal Edildi';
      case DepotOfferStatus.delivered:
        return 'Teslim Edildi';
    }
  }

  Color _offerStatusColor(DepotOfferStatus status) {
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

  DepotNotice? _findNoticeById(List<DepotNotice> notices, String id) {
    for (final notice in notices) {
      if (notice.id == id) return notice;
    }
    return null;
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
}
