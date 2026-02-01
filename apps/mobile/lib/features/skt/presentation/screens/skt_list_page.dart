import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/shared.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../domain/models/product_summary_model.dart';
import '../../domain/models/skt_record_model.dart';
import '../../domain/providers/skt_providers.dart';
import 'skt_date_scanner_page.dart';
import 'skt_live_scanner_page.dart';

const List<int> _alarmDayOptions = [1, 2, 3, 5, 7, 14];
const List<String> _requestTypeOptions = <String>[
  'İndirimli fiyat talebi',
  'Teşhir kurulumu talebi',
  'Distribütör iletişim talebi',
];

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
    final selectedCategory = ref.watch(sktCategoryFilterProvider);
    final categoriesAsync = ref.watch(sktCategoriesProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: 'Ürün adı, barkod veya alt barkod',
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
            categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: 'Tümü',
                            selected: selectedCategory == null,
                            onSelected: () => ref
                                .read(sktCategoryFilterProvider.notifier)
                                .state = null,
                          ),
                        ),
                        for (final category in categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: category,
                              selected: selectedCategory == category,
                              onSelected: () {
                                final notifier = ref
                                    .read(sktCategoryFilterProvider.notifier);
                                notifier.state = selectedCategory == category
                                    ? null
                                    : category;
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Kategoriler yüklenemedi: $error',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.error),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: recordsAsync.when(
                data: (records) => _buildRecordsList(records, colors),
                loading: () => const AppLoading(),
                error: (error, stackTrace) => AppErrorState(
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
            AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'SKT Kaydı Bulunamadı',
              subtitle:
                  'Seçili filtrelere uygun kayıt yok.\nFiltreleri değiştirmeyi veya yeni kayıt eklemeyi deneyin.',
              showContainer: true,
            ),
          ],
        ),
      );
    }

    // Durum istatistikleri
    final now = DateTime.now();
    final expiredCount =
        records.where((r) => r.statusAt(now) == SktRecordStatus.expired).length;
    final upcomingCount = records
        .where((r) => r.statusAt(now) == SktRecordStatus.upcoming)
        .length;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(sktRecordsProvider.future),
      child: ListView.builder(
        itemCount: records.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            // Header with stats
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _MiniStatBadge(
                    count: records.length,
                    label: 'Toplam',
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  if (expiredCount > 0)
                    _MiniStatBadge(
                      count: expiredCount,
                      label: 'Geçmiş',
                      color: colors.error,
                    ),
                  if (expiredCount > 0) const SizedBox(width: 8),
                  if (upcomingCount > 0)
                    _MiniStatBadge(
                      count: upcomingCount,
                      label: 'Yaklaşan',
                      color: colors.tertiary,
                    ),
                ],
              ),
            );
          }

          final record = records[index - 1];
          final status = record.statusAt(now);
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == records.length ? 16 : 12,
            ),
            child: _RecordCard(
              record: record,
              status: status,
              colors: colors,
              onTap: () => _showRecordActions(context, record),
            ),
          );
        },
      ),
    );
  }

  void _showRecordActions(BuildContext context, SktRecordModel record) {
    final status = record.statusAt(DateTime.now());
    final colors = Theme.of(context).colorScheme;
    final daysLeft = record.daysUntil(DateTime.now());
    final expiryColor = _getExpiryColor(daysLeft, colors);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(record.productName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Barkod: ${record.barcode}'),
                      if (record.altBarcodes.isNotEmpty)
                        Text(
                          'Alt barkodlar: ${record.altBarcodes.join(', ')}',
                        ),
                    ],
                  ),
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
                    style: TextStyle(color: expiryColor),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Kaydı düzenle'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditRecordSheet(context, record);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: const Text('Alarm ayarları'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAlarmSettingsSheet(context, record);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.send, color: colors.primary),
                  title: const Text('Yöneticiye Talep İlet'),
                  subtitle: record.productStatus != null
                      ? Text('Mevcut: ${record.productStatus}')
                      : const Text('İndirim, teşhir veya tedarik talebi'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRequestSheet(context, record);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Kaydı sil'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteRecord(context, record);
                  },
                ),
                if (record.notes != null && record.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
        );
      },
    );
  }

  void _showCreateRecordSheet(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return const _SktCreateSheet();
      },
    ).then((created) {
      if (created == true && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('SKT kaydı oluşturuldu.')),
        );
      }
    });
  }

  Future<void> _showEditRecordSheet(
      BuildContext context, SktRecordModel record) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _SktEditSheet(record: record),
    );

    if (updated == true && mounted) {
      ref.invalidate(sktRecordsProvider);
      await ref.read(sktRecordsProvider.future);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('${record.productName} güncellendi.')),
      );
    }
  }

  Future<void> _showAlarmSettingsSheet(
      BuildContext context, SktRecordModel record) async {
    final messenger = ScaffoldMessenger.of(context);
    final updatedDays = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _AlarmSettingsSheet(record: record),
    );

    if (updatedDays == null || !mounted) {
      return;
    }

    ref.invalidate(sktRecordsProvider);
    await ref.read(sktRecordsProvider.future);
    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Alarm ${_alarmLabelForDays(updatedDays)} önce tetiklenecek.',
        ),
      ),
    );
  }

  Future<void> _showRequestSheet(
      BuildContext context, SktRecordModel record) async {
    final messenger = ScaffoldMessenger.of(context);
    final selectedRequest = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _RequestTypeSheet(
        record: record,
        currentRequest: record.productStatus,
      ),
    );

    if (selectedRequest == null || !mounted) {
      return;
    }

    // Update the record with the new request
    try {
      await ref.read(sktRepositoryProvider).updateRecord(
            recordId: record.id,
            expiryDate: record.expiryDate,
            quantity: record.quantity,
            productStatus: selectedRequest,
            notes: record.notes,
            alarmDaysBefore: record.alarmDaysBefore,
          );
      ref.invalidate(sktRecordsProvider);
      await ref.read(sktRecordsProvider.future);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Talep iletildi: $selectedRequest')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  String _alarmLabelForDays(int days) {
    switch (days) {
      case 1:
        return '1 gün';
      case 2:
        return '2 gün';
      case 3:
        return '3 gün';
      case 5:
        return '5 gün';
      case 7:
        return '1 hafta';
      case 14:
        return '2 hafta';
      default:
        return '$days gün';
    }
  }

  Future<void> _confirmDeleteRecord(
      BuildContext context, SktRecordModel record) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: Text(
            '${record.productName} için oluşturulmuş SKT kaydını silmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final success = await ref
          .read(sktRepositoryProvider)
          .deleteRecord(recordId: record.id);
      if (!mounted) {
        return;
      }
      if (success) {
        ref.invalidate(sktRecordsProvider);
        await ref.read(sktRecordsProvider.future);
        if (!mounted) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text('${record.productName} silindi.')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${record.productName} kaydı bulunamadı, silinemedi.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Silme sırasında hata oluştu: $e')),
      );
    }
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

class _MiniStatBadge extends StatelessWidget {
  const _MiniStatBadge({
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
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
    final now = DateTime.now();
    final daysLeft = record.daysUntil(now);
    // Dinamik renk: gün sayısına göre mavi → turuncu → kırmızı
    final expiryColor = _getExpiryColor(daysLeft, colors);
    final statusText = _statusLabel(status);
    final dateText = _formatDate(record.expiryDate);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface,
            expiryColor.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: expiryColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: expiryColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        record.productName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            expiryColor,
                            expiryColor.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: expiryColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: colors.surface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (record.productCategory != null &&
                    record.productCategory!.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.category_outlined,
                          size: 16, color: colors.outline),
                      const SizedBox(width: 4),
                      Text(record.productCategory!),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
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
                if (record.altBarcodes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.qr_code_2, size: 16, color: colors.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Alt barkodlar: ${record.altBarcodes.join(', ')}',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                // SKT Progress Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: expiryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, size: 20, color: expiryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Son Kullanma: $dateText',
                              style: TextStyle(
                                color: expiryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              daysLeft < 0
                                  ? '${daysLeft.abs()} gün geçmiş!'
                                  : daysLeft == 0
                                      ? 'Bugün doluyor!'
                                      : '$daysLeft gün kaldı',
                              style: TextStyle(
                                color: expiryColor.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colors.outlineVariant,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2,
                                size: 14, color: colors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '${record.quantity} adet',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (record.productStatus != null &&
                    record.productStatus!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 16, color: colors.outline),
                      const SizedBox(width: 4),
                      Text('Talep: ${record.productStatus!}'),
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
      ),
    );
  }
}

class _SktCreateSheet extends ConsumerStatefulWidget {
  const _SktCreateSheet();

  @override
  ConsumerState<_SktCreateSheet> createState() => _SktCreateSheetState();
}

class _SktCreateSheetState extends ConsumerState<_SktCreateSheet> {
  late final TextEditingController _searchCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _notesCtrl;
  String _searchQuery = '';
  ProductSummaryModel? _selectedProduct;
  DateTime? _expiryDate;
  bool _isSubmitting = false;
  String? _errorMessage;
  int _alarmDaysBefore = 7;
  bool _requestEnabled = false;
  String? _selectedRequestType;
  final FocusNode _searchFocus = FocusNode();
  String? _lockedBranchId;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _lockedBranchId = authState.maybeWhen(
      authenticated: (user) => user.branchId,
      orElse: () => null,
    );
    _searchCtrl = TextEditingController();
    _quantityCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final searchTerm = _searchQuery.trim();
    final searching = searchTerm.length >= 3;
    final AsyncValue<List<ProductSummaryModel>> searchAsync = searching
        ? ref.watch(sktProductSearchProvider(searchTerm))
        : const AsyncData<List<ProductSummaryModel>>(<ProductSummaryModel>[]);

    final quantityValue = int.tryParse(_quantityCtrl.text.trim());
    final branchId = _lockedBranchId;
    final requestValid = !_requestEnabled || _selectedRequestType != null;
    final canSubmit = !_isSubmitting &&
        _selectedProduct != null &&
        branchId != null &&
        _expiryDate != null &&
        quantityValue != null &&
        quantityValue > 0 &&
        requestValid;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + viewInsets),
        curve: Curves.decelerate,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_box_outlined,
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
                            'Yeni SKT Kaydı',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Barkod veya ürün adıyla arayın',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isSubmitting)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Barkod, alt barkod veya ürün adı',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Barkodu tara',
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _isSubmitting ? null : _scanBarcode,
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          tooltip: 'Temizle',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchCtrl.clear();
                              _selectedProduct = null;
                            });
                            _searchFocus.requestFocus();
                          },
                        ),
                    ],
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_selectedProduct != null)
                Card(
                  margin: EdgeInsets.zero,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    dense: true,
                    title: Text(_selectedProduct!.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Barkod: ${_selectedProduct!.barcode}'),
                        if (_selectedProduct!.altBarcodes.isNotEmpty)
                          Text(
                            'Alt barkodlar: ${_selectedProduct!.altBarcodes.join(', ')}',
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      tooltip: 'Seçimi kaldır',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() => _selectedProduct = null);
                        _searchFocus.requestFocus();
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              ProductSearchResultsList(
                searchAsync: searchAsync,
                searching: searching,
                onSelect: (product) {
                  setState(() {
                    _selectedProduct = product;
                    _searchCtrl.text = product.barcode;
                    _searchQuery = product.barcode;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Date picker section with scan option
              Text(
                'Son Kullanma Tarihi',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _isSubmitting ? null : _pickExpiryDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _expiryDate != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: _expiryDate != null
                              ? theme.colorScheme.primary
                                  .withValues(alpha: 0.05)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month,
                              color: _expiryDate != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _expiryDate == null
                                  ? 'Tarih seçin'
                                  : _formatDate(_expiryDate!),
                              style: TextStyle(
                                color: _expiryDate != null
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: _expiryDate != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // OCR Scan Button
                  Tooltip(
                    message: 'SKT tarihini kameradan oku',
                    child: InkWell(
                      onTap: _isSubmitting ? null : _scanExpiryDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.document_scanner_outlined,
                          color: theme.colorScheme.onSecondaryContainer,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Adet',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Yöneticiye talep ilet'),
                subtitle: const Text(
                  'İndirim, teşhir veya tedarik isteği gönderin.',
                ),
                value: _requestEnabled,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _requestEnabled = value;
                          if (!value) {
                            _selectedRequestType = null;
                          }
                        });
                      },
              ),
              if (_requestEnabled) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _requestTypeOptions
                      .map(
                        (option) => ChoiceChip(
                          label: Text(option),
                          selected: _selectedRequestType == option,
                          onSelected: _isSubmitting
                              ? null
                              : (_) {
                                  setState(() => _selectedRequestType = option);
                                },
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                minLines: 3,
              ),
              const SizedBox(height: 12),
              Text(
                'Alarm hatırlatması',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _alarmDayOptions
                    .map(
                      (days) => ChoiceChip(
                        label: Text(_alarmLabel(days)),
                        selected: _alarmDaysBefore == days,
                        onSelected: _isSubmitting
                            ? null
                            : (_) {
                                setState(() => _alarmDaysBefore = days);
                              },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 4),
              Text(
                '${_alarmLabel(_alarmDaysBefore)} kala hatırlatma yapılacak.',
                style: theme.textTheme.bodySmall,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Kapat'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: canSubmit ? _submit : null,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _alarmLabel(int days) {
    switch (days) {
      case 1:
        return '1 gün';
      case 2:
        return '2 gün';
      case 3:
        return '3 gün';
      case 5:
        return '5 gün';
      case 7:
        return '1 hafta';
      case 14:
        return '2 hafta';
      default:
        return '$days gün';
    }
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final normalizedNow = DateTime(now.year, now.month, now.day);
    final initial = _expiryDate ?? normalizedNow.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      locale: Localizations.localeOf(context),
      initialDate: initial,
      firstDate: normalizedNow,
      lastDate: normalizedNow.add(const Duration(days: 730)),
      helpText: 'Son kullanma tarihi seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _expiryDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _scanExpiryDate() async {
    final colors = Theme.of(context).colorScheme;

    // Kullanıcıya tarama yöntemi seçtir
    final method = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SKT Tarihini Nasıl Okuyalım?',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                // Canlı Tarama
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.videocam, color: colors.primary),
                  ),
                  title: const Text('Canlı Tarama'),
                  subtitle:
                      const Text('Kamerayı ürüne tutun, otomatik algılansın'),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Önerilen',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, 'live'),
                ),
                const SizedBox(height: 8),
                // Fotoğraf Çek
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.camera_alt, color: colors.secondary),
                  ),
                  title: const Text('Fotoğraf Çek'),
                  subtitle: const Text('Fotoğraf çekin veya galeriden seçin'),
                  onTap: () => Navigator.pop(ctx, 'photo'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || method == null) return;

    DateTime? scannedDate;

    if (method == 'live') {
      scannedDate = await Navigator.of(context).push<DateTime>(
        MaterialPageRoute(builder: (_) => const SktLiveScannerPage()),
      );
    } else {
      scannedDate = await Navigator.of(context).push<DateTime>(
        MaterialPageRoute(builder: (_) => const SktDateScannerPage()),
      );
    }

    if (!mounted || scannedDate == null) {
      return;
    }

    setState(() {
      _expiryDate = scannedDate;
    });
  }

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    if (!mounted || scanned == null || scanned.isEmpty) {
      return;
    }

    setState(() {
      _searchQuery = scanned;
      _searchCtrl.text = scanned;
      _selectedProduct = null;
    });
    _searchFocus.unfocus();

    final user = ref.read(authProvider).maybeWhen(
          authenticated: (value) => value,
          orElse: () => null,
        );

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum bilgisi bulunamadı.')),
      );
      return;
    }

    try {
      final results = await ref.read(sktRepositoryProvider).searchProducts(
            tenantId: user.tenantId,
            query: scanned,
          );

      if (!mounted) {
        return;
      }

      ProductSummaryModel? match;
      for (final product in results) {
        if (product.barcode == scanned) {
          match = product;
          break;
        }
      }
      match ??= results.isNotEmpty ? results.first : null;

      if (match != null) {
        setState(() => _selectedProduct = match);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barkoda uygun ürün bulunamadı.')),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barkod aranırken hata oluştu: $e')),
      );
    }
  }

  Future<void> _submit() async {
    final authState = ref.read(authProvider);
    final user = authState.maybeWhen(
      authenticated: (value) => value,
      orElse: () => null,
    );
    if (user == null) {
      setState(() {
        _errorMessage = 'Oturum bilgisi bulunamadı.';
      });
      return;
    }

    final product = _selectedProduct;
    final branchId = _lockedBranchId;
    final expiry = _expiryDate;
    final quantity = int.tryParse(_quantityCtrl.text.trim());
    final requestText = _requestEnabled ? _selectedRequestType : null;
    final notesText =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    if (product == null ||
        branchId == null ||
        expiry == null ||
        quantity == null ||
        quantity <= 0 ||
        (_requestEnabled && requestText == null)) {
      setState(() {
        _errorMessage = 'Gerekli alanları doldurun.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(sktRepositoryProvider).createRecord(
            tenantId: user.tenantId,
            branchId: branchId,
            productId: product.id,
            userId: user.id,
            expiryDate: expiry,
            quantity: quantity,
            productStatus: requestText,
            notes: notesText,
            alarmDaysBefore: _alarmDaysBefore,
          );
      ref.invalidate(sktRecordsProvider);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _SktEditSheet extends ConsumerStatefulWidget {
  const _SktEditSheet({required this.record});

  final SktRecordModel record;

  @override
  ConsumerState<_SktEditSheet> createState() => _SktEditSheetState();
}

class _AlarmSettingsSheet extends ConsumerStatefulWidget {
  const _AlarmSettingsSheet({required this.record});

  final SktRecordModel record;

  @override
  ConsumerState<_AlarmSettingsSheet> createState() =>
      _AlarmSettingsSheetState();
}

class _AlarmSettingsSheetState extends ConsumerState<_AlarmSettingsSheet> {
  late final List<int> _options;
  late int _selectedDays;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final optionSet = <int>{..._alarmDayOptions};
    if (widget.record.alarmDaysBefore > 0) {
      optionSet.add(widget.record.alarmDaysBefore);
    }
    _options = optionSet.toList()..sort();
    _selectedDays = widget.record.alarmDaysBefore > 0
        ? widget.record.alarmDaysBefore
        : _options.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final alarmDate =
        widget.record.expiryDate.subtract(Duration(days: _selectedDays));

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + viewInsets),
        curve: Curves.decelerate,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.record.productName,
                    style: theme.textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Alarm kaç gün önce hatırlatsın?',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _options
                    .map(
                      (days) => ChoiceChip(
                        label: Text(_alarmLabel(days)),
                        selected: _selectedDays == days,
                        onSelected: _isSaving
                            ? null
                            : (_) {
                                setState(() => _selectedDays = days);
                              },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'Alarm ${_alarmLabel(_selectedDays)} önce (${_formatDate(alarmDate)}) tetiklenecek.',
                style: theme.textTheme.bodySmall,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref.read(sktRepositoryProvider).updateAlarmSettings(
            recordId: widget.record.id,
            expiryDate: widget.record.expiryDate,
            alarmDaysBefore: _selectedDays,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(_selectedDays);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isSaving = false;
      });
    }
  }

  String _alarmLabel(int days) {
    switch (days) {
      case 1:
        return '1 gün';
      case 2:
        return '2 gün';
      case 3:
        return '3 gün';
      case 5:
        return '5 gün';
      case 7:
        return '1 hafta';
      case 14:
        return '2 hafta';
      default:
        return '$days gün';
    }
  }
}

class _SktEditSheetState extends ConsumerState<_SktEditSheet> {
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _notesCtrl;
  DateTime? _expiryDate;
  int _alarmDaysBefore = 7;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _requestEnabled = false;
  String? _selectedRequestType;
  String? _customRequestOption;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _expiryDate = record.expiryDate;
    _alarmDaysBefore = _alarmDayOptions.contains(record.alarmDaysBefore)
        ? record.alarmDaysBefore
        : 7;
    _quantityCtrl = TextEditingController(text: record.quantity.toString());
    _notesCtrl = TextEditingController(text: record.notes ?? '');
    final status = record.productStatus?.trim();
    if (status != null && status.isNotEmpty) {
      _requestEnabled = true;
      if (_requestTypeOptions.contains(status)) {
        _selectedRequestType = status;
      } else {
        _customRequestOption = status;
        _selectedRequestType = status;
      }
    }
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final quantityValue = int.tryParse(_quantityCtrl.text.trim());
    final requestValid = !_requestEnabled || _selectedRequestType != null;
    final canSubmit = !_isSubmitting &&
        _expiryDate != null &&
        quantityValue != null &&
        quantityValue > 0 &&
        requestValid;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + viewInsets),
        curve: Curves.decelerate,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Kaydı düzenle', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  if (_isSubmitting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.surfaceContainerHighest,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  title: Text(widget.record.productName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Barkod: ${widget.record.barcode}'),
                      if (widget.record.altBarcodes.isNotEmpty)
                        Text(
                          'Alt barkodlar: ${widget.record.altBarcodes.join(', ')}',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _isSubmitting ? null : _pickExpiryDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Son kullanma tarihi',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month,
                          color: theme.colorScheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _expiryDate == null
                            ? 'Tarih seçin'
                            : _formatDate(_expiryDate!),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_calendar, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Adet',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Yöneticiye talep ilet'),
                subtitle: const Text(
                  'İndirim, teşhir veya tedarik isteği gönderin.',
                ),
                value: _requestEnabled,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _requestEnabled = value;
                          if (!value) {
                            _selectedRequestType = null;
                          } else {
                            final options = _availableRequestOptions;
                            if (options.isNotEmpty) {
                              _selectedRequestType ??= options.first;
                            }
                          }
                        });
                      },
              ),
              if (_requestEnabled) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableRequestOptions
                      .map(
                        (option) => ChoiceChip(
                          label: Text(option),
                          selected: _selectedRequestType == option,
                          onSelected: _isSubmitting
                              ? null
                              : (_) {
                                  setState(() => _selectedRequestType = option);
                                },
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                minLines: 3,
              ),
              const SizedBox(height: 12),
              Text(
                'Alarm hatırlatması',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _alarmDayOptions
                    .map(
                      (days) => ChoiceChip(
                        label: Text(_alarmLabel(days)),
                        selected: _alarmDaysBefore == days,
                        onSelected: _isSubmitting
                            ? null
                            : (_) {
                                setState(() => _alarmDaysBefore = days);
                              },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 4),
              Text(
                '${_alarmLabel(_alarmDaysBefore)} kala hatırlatma yapılacak.',
                style: theme.textTheme.bodySmall,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Kapat'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: canSubmit ? _submit : null,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _availableRequestOptions {
    final options = List<String>.from(_requestTypeOptions);
    if (_customRequestOption != null &&
        !options.contains(_customRequestOption!)) {
      options.add(_customRequestOption!);
    }
    return options;
  }

  String _alarmLabel(int days) {
    switch (days) {
      case 1:
        return '1 gün';
      case 2:
        return '2 gün';
      case 3:
        return '3 gün';
      case 5:
        return '5 gün';
      case 7:
        return '1 hafta';
      case 14:
        return '2 hafta';
      default:
        return '$days gün';
    }
  }

  Future<void> _pickExpiryDate() async {
    final current = _expiryDate ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      locale: Localizations.localeOf(context),
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() => _expiryDate = selected);
    }
  }

  Future<void> _submit() async {
    final expiry = _expiryDate;
    final quantity = int.tryParse(_quantityCtrl.text.trim());
    final notesText = _notesCtrl.text.trim();

    if (expiry == null || quantity == null || quantity <= 0) {
      setState(() {
        _errorMessage = 'Geçerli bir tarih ve adet girin.';
      });
      return;
    }

    if (_requestEnabled && _selectedRequestType == null) {
      setState(() {
        _errorMessage = 'Bir talep seçin veya talep ilet seçeneğini kapatın.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(sktRepositoryProvider).updateRecord(
            recordId: widget.record.id,
            expiryDate: expiry,
            quantity: quantity,
            productStatus: _requestEnabled ? _selectedRequestType : null,
            notes: notesText.isEmpty ? null : notesText,
            alarmDaysBefore: _alarmDaysBefore,
          );
      ref.invalidate(sktRecordsProvider);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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

/// SKT tarihine göre gradyan renk hesapla
/// 30+ gün = mavi, 14-30 arası = mavi→turuncu, 7-14 = turuncu, 0-7 = turuncu→kırmızı, <0 = kırmızı
Color _getExpiryColor(int daysLeft, ColorScheme colors) {
  const blueColor = Color(0xFF2196F3);
  const orangeColor = Color(0xFFFF9800);
  const redColor = Color(0xFFE53935);

  if (daysLeft < 0) {
    // Süresi dolmuş - kırmızı
    return redColor;
  } else if (daysLeft <= 7) {
    // 0-7 gün arası: turuncu → kırmızı
    final t = 1.0 - (daysLeft / 7.0);
    return Color.lerp(orangeColor, redColor, t)!;
  } else if (daysLeft <= 14) {
    // 7-14 gün arası: turuncu
    return orangeColor;
  } else if (daysLeft <= 30) {
    // 14-30 gün arası: mavi → turuncu
    final t = 1.0 - ((daysLeft - 14) / 16.0);
    return Color.lerp(blueColor, orangeColor, t)!;
  } else {
    // 30+ gün - mavi (normal)
    return blueColor;
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

/// Talep tipi seçim bottom sheet
class _RequestTypeSheet extends StatefulWidget {
  const _RequestTypeSheet({
    required this.record,
    this.currentRequest,
  });

  final SktRecordModel record;
  final String? currentRequest;

  @override
  State<_RequestTypeSheet> createState() => _RequestTypeSheetState();
}

class _RequestTypeSheetState extends State<_RequestTypeSheet> {
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.currentRequest;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final daysLeft = widget.record.daysUntil(DateTime.now());
    final expiryColor = _getExpiryColor(daysLeft, colors);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.send, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yöneticiye Talep İlet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.record.productName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // SKT bilgisi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: expiryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.event, size: 18, color: expiryColor),
                  const SizedBox(width: 8),
                  Text(
                    'SKT: ${_formatDate(widget.record.expiryDate)}',
                    style: TextStyle(
                      color: expiryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    daysLeft < 0
                        ? '${daysLeft.abs()} gün geçmiş'
                        : '$daysLeft gün kaldı',
                    style: TextStyle(
                      color: expiryColor.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Talep Türü Seçin',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Request type options
            ..._requestTypeOptions.map((option) => _RequestOptionTile(
                  title: option,
                  icon: _getRequestIcon(option),
                  isSelected: _selectedType == option,
                  onTap: () => setState(() => _selectedType = option),
                )),
            const SizedBox(height: 16),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _selectedType != null
                        ? () => Navigator.pop(context, _selectedType)
                        : null,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Gönder'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRequestIcon(String option) {
    if (option.contains('İndirim')) return Icons.discount;
    if (option.contains('Teşhir')) return Icons.storefront;
    if (option.contains('Distribütör')) return Icons.local_shipping;
    return Icons.info_outline;
  }
}

class _RequestOptionTile extends StatelessWidget {
  const _RequestOptionTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isSelected ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? colors.primary : colors.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? colors.primary : colors.onSurfaceVariant,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? colors.primary : colors.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: colors.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
