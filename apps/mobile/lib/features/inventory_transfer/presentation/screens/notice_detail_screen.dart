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
    _offerMessageController.clear();

    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teklif Ver',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        _notice.productName,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _offerQuantityController,
                decoration: InputDecoration(
                  labelText: 'Miktar (${_notice.unit})',
                  prefixIcon: const Icon(Icons.numbers),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _offerMessageController,
                decoration: InputDecoration(
                  labelText: 'Mesaj (isteğe bağlı)',
                  prefixIcon: const Icon(Icons.message_outlined),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final quantity =
                            int.tryParse(_offerQuantityController.text.trim());
                        if (quantity == null || quantity <= 0) {
                          messenger.showSnackBar(
                            const SnackBar(
                                content: Text('Geçerli bir miktar girin.')),
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
                      icon: const Icon(Icons.send),
                      label: const Text('Gönder'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.delete_outline, color: Colors.red, size: 32),
            ),
            title: const Text('İlanı Sil'),
            content: const Text(
              'Bu ilanı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    final cs = Theme.of(context).colorScheme;
    final isSurplus = _notice.type == DepotNoticeType.surplus;
    final typeColor = isSurplus ? Colors.green : Colors.orange;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            actions: [
              if (isOwner)
                IconButton(
                  tooltip: 'İlanı Sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _confirmDelete,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Tip badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSurplus
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                size: 16,
                                color: typeColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isSurplus ? 'FAZLA ÜRÜN' : 'EKSİK ÜRÜN',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Ürün adı
                        Text(
                          _notice.productName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // İçerik
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildInfoCard(),
                const SizedBox(height: 20),
                if (isOwner) ...[
                  _buildOffersSection(),
                ] else if (_notice.status == DepotNoticeStatus.open) ...[
                  _buildOfferButton(),
                ],
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      // FAB for making offer
      floatingActionButton: !isOwner && _notice.status == DepotNoticeStatus.open
          ? FloatingActionButton.extended(
              onPressed: _showMakeOfferDialog,
              icon: const Icon(Icons.send),
              label: const Text('Teklif Ver'),
            )
          : null,
    );
  }

  Widget _buildInfoCard() {
    final remaining = _notice.remainingQuantity;
    final cs = Theme.of(context).colorScheme;
    final statusInfo = _getStatusInfo(_notice.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Durum
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
                      Icon(statusInfo.icon, size: 14, color: statusInfo.color),
                      const SizedBox(width: 4),
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
                  _notice.createdAt.toString().split(' ')[0],
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Şube bilgisi
            _InfoRow(
              icon: Icons.store_outlined,
              label: 'Şube',
              value: _notice.branchName ?? 'Şube bilgisi yok',
            ),
            const SizedBox(height: 16),
            // Miktar bilgileri
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _QuantityDisplay(
                      label: 'Toplam',
                      value: _formatQuantity(_notice.quantity),
                      unit: _notice.unit,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: cs.outlineVariant,
                  ),
                  Expanded(
                    child: _QuantityDisplay(
                      label: 'Kalan',
                      value: _formatQuantity(remaining),
                      unit: _notice.unit,
                      isHighlight: true,
                    ),
                  ),
                ],
              ),
            ),
            if (_notice.note != null && _notice.note!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoRow(
                icon: Icons.notes_outlined,
                label: 'Not',
                value: _notice.note!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOffersSection() {
    final offers = _notice.offers ?? [];
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people_outline, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Gelen Teklifler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            if (offers.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${offers.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (offers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz teklif yok',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...offers.map((offer) => _buildOfferCard(offer)),
      ],
    );
  }

  Widget _buildOfferCard(NoticeOffer offer) {
    final isAccepting = _acceptingOfferId == offer.id;
    final isRejecting = _rejectingOfferId == offer.id;
    final cs = Theme.of(context).colorScheme;
    final statusInfo = _getOfferStatusInfo(offer.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: statusInfo.color.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.store_outlined,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.branchName ?? 'Şube bilgisi yok',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_formatQuantity(offer.quantity)} ${_notice.unit}',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusInfo.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusInfo.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusInfo.color,
                    ),
                  ),
                ),
              ],
            ),
            if ((offer.message ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        offer.message!,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (offer.status == DepotOfferStatus.pending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isRejecting
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _rejectingOfferId = offer.id);
                              try {
                                await ref
                                    .read(
                                        inventoryTransferListProvider.notifier)
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
                      icon: isRejecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.close, color: Colors.red),
                      label: Text(
                        'Reddet',
                        style:
                            TextStyle(color: isRejecting ? null : Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isAccepting
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _acceptingOfferId = offer.id);
                              try {
                                await ref
                                    .read(
                                        inventoryTransferListProvider.notifier)
                                    .acceptOffer(offer: offer, notice: _notice);
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
                      icon: isAccepting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Onayla'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOfferButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _showMakeOfferDialog,
        icon: const Icon(Icons.send),
        label: const Text('Talep Et / Gönder'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  ({String label, Color color, IconData icon}) _getStatusInfo(
      DepotNoticeStatus status) {
    switch (status) {
      case DepotNoticeStatus.open:
        return (
          label: 'Açık İlan',
          color: Colors.blue,
          icon: Icons.radio_button_checked
        );
      case DepotNoticeStatus.inTransfer:
        return (
          label: 'Transferde',
          color: Colors.orange,
          icon: Icons.local_shipping_outlined
        );
      case DepotNoticeStatus.fulfilled:
        return (
          label: 'Tamamlandı',
          color: Colors.green,
          icon: Icons.check_circle_outline
        );
      case DepotNoticeStatus.cancelled:
        return (
          label: 'İptal',
          color: Colors.grey,
          icon: Icons.cancel_outlined
        );
    }
  }

  ({String label, Color color}) _getOfferStatusInfo(DepotOfferStatus status) {
    switch (status) {
      case DepotOfferStatus.pending:
        return (label: 'Beklemede', color: Colors.blue);
      case DepotOfferStatus.accepted:
        return (label: 'Onaylandı', color: Colors.green);
      case DepotOfferStatus.rejected:
        return (label: 'Reddedildi', color: Colors.red);
      case DepotOfferStatus.expired:
        return (label: 'Süre Doldu', color: Colors.orange);
      case DepotOfferStatus.cancelled:
        return (label: 'İptal Edildi', color: Colors.grey);
      case DepotOfferStatus.delivered:
        return (label: 'Teslim Edildi', color: Colors.blueGrey);
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

// Helper widgets
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuantityDisplay extends StatelessWidget {
  const _QuantityDisplay({
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
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? cs.primary : cs.onSurface,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 14,
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
