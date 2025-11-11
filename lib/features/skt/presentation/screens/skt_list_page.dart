import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/skt_record_model.dart';
import '../../domain/providers/skt_providers.dart';

class SktListPage extends ConsumerStatefulWidget {
  const SktListPage({super.key});

  @override
  ConsumerState<SktListPage> createState() => _SktListPageState();
}

class _SktListPageState extends ConsumerState<SktListPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: ref.read(sktSearchQueryProvider));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final timelineFilter = ref.watch(sktTimelineFilterProvider);
    final recordsAsync = ref.watch(sktFilteredRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SKT Takip'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: 'Ürün adı veya barkod',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: 'Yeni SKT kaydı',
                  onPressed: () => _showCreateRecordSheet(context),
                  icon: const Icon(Icons.add_box_outlined),
                ),
              ),
              onChanged: (value) =>
                  ref.read(sktSearchQueryProvider.notifier).state = value,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in SktTimelineFilter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: _timelineLabel(filter),
                          selected: filter == timelineFilter,
                          color: _timelineColor(filter, colors),
                          onSelected: () => ref
                              .read(sktTimelineFilterProvider.notifier)
                              .state = filter,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: recordsAsync.when(
                data: (records) => _buildRecordsList(records, colors),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => _ErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(sktRecordsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList(List<SktRecordModel> records, ColorScheme colors) {
    if (records.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.refresh(sktRecordsProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            _EmptyState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(sktRecordsProvider.future),
      child: ListView.separated(
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final record = records[index];
          final status = record.statusAt(DateTime.now());
          return _RecordCard(
            record: record,
            status: status,
            colors: colors,
            onTap: () => _showRecordActions(context, record),
          );
        },
      ),
    );
  }

  void _showRecordActions(BuildContext context, SktRecordModel record) {
    final status = record.statusAt(DateTime.now());
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(status, colors);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(record.productName),
                subtitle: Text('Barkod: ${record.barcode}'),
              ),
              ListTile(
                leading: const Icon(Icons.store),
                title: Text(record.branchName),
                subtitle: const Text('Şube'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text('Durum: ${_statusLabel(status)}'),
                subtitle: Text(
                  'SKT: ${_formatDate(record.expiryDate)}',
                  style: TextStyle(color: statusColor),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Kaydı düzenle'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Düzenleme prototip aşamasında.')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('Alarm ayarları'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alarm yönetimi yakında.')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Kaydı sil'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${record.productName} silinecek.'),
                    ),
                  );
                },
              ),
              if (record.notes != null && record.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    record.notes!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showCreateRecordSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Yeni SKT Kaydı',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Barkodu arama alanına yazarak veya okutma entegrasyonu ile '
                'Supabase üzerinde yeni kayıt oluşturacağız. Bu adım için '
                'gerekli servisler hazırlanıyor.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg =
        selected ? (color ?? colors.primary) : colors.surfaceContainerHighest;
    final fg = selected ? colors.onPrimary : colors.onSurfaceVariant;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: bg,
      backgroundColor: colors.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: selected ? fg : colors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.status,
    required this.colors,
    required this.onTap,
  });

  final SktRecordModel record;
  final SktRecordStatus status;
  final ColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status, colors);
    final now = DateTime.now();
    final daysLeft = record.daysUntil(now);
    final statusText = _statusLabel(status);
    final dateText = _formatDate(record.expiryDate);

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.productName,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.store, size: 16, color: colors.outline),
                  const SizedBox(width: 4),
                  Text(record.branchName),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.qr_code, size: 16, color: colors.outline),
                  const SizedBox(width: 4),
                  Text(record.barcode),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: statusColor),
                  const SizedBox(width: 4),
                  Text('SKT: $dateText', style: TextStyle(color: statusColor)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 16, color: colors.outline),
                  const SizedBox(width: 4),
                  Text('Adet: ${record.quantity}'),
                  const Spacer(),
                  Text(
                    daysLeft < 0
                        ? '${daysLeft.abs()} gün gecikmiş'
                        : '$daysLeft gün kaldı',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              if (record.productStatus != null &&
                  record.productStatus!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.assignment_outlined,
                        size: 16, color: colors.outline),
                    const SizedBox(width: 4),
                    Text(record.productStatus!),
                  ],
                ),
              ],
              if (record.notes != null && record.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  record.notes!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inventory_outlined, size: 48, color: colors.outline),
        const SizedBox(height: 12),
        Text(
          'Kayıt bulunamadı',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          'Filtreleri değiştirerek yeniden deneyebilirsiniz.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: colors.error),
          const SizedBox(height: 12),
          Text(
            'Veriler alınamadı',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(SktRecordStatus status) {
  switch (status) {
    case SktRecordStatus.normal:
      return 'Normal';
    case SktRecordStatus.upcoming:
      return 'Yaklaşan';
    case SktRecordStatus.expired:
      return 'Süresi dolmuş';
  }
}

Color _statusColor(SktRecordStatus status, ColorScheme colors) {
  switch (status) {
    case SktRecordStatus.normal:
      return colors.primary;
    case SktRecordStatus.upcoming:
      return colors.tertiary;
    case SktRecordStatus.expired:
      return colors.error;
  }
}

String _timelineLabel(SktTimelineFilter filter) {
  switch (filter) {
    case SktTimelineFilter.all:
      return 'Tümü';
    case SktTimelineFilter.week1:
      return '1 hafta';
    case SktTimelineFilter.week2:
      return '2 hafta';
    case SktTimelineFilter.week3:
      return '3 hafta';
    case SktTimelineFilter.month1:
      return '1 ay';
    case SktTimelineFilter.month2:
      return '2 ay';
    case SktTimelineFilter.month3:
      return '3 ay';
  }
}

Color? _timelineColor(SktTimelineFilter filter, ColorScheme colors) {
  switch (filter) {
    case SktTimelineFilter.week1:
      return colors.error;
    case SktTimelineFilter.week2:
      return colors.tertiary;
    case SktTimelineFilter.week3:
      return colors.secondary;
    default:
      return null;
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
