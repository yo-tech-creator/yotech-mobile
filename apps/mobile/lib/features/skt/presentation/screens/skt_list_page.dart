import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../auth/domain/providers/auth_provider.dart';
import '../../domain/models/product_summary_model.dart';
import '../../domain/models/skt_record_model.dart';
import '../../domain/providers/skt_providers.dart';

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
                    style: TextStyle(color: statusColor),
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
              Row(
                children: [
                  Text(
                    'Yeni SKT Kaydı',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (_isSubmitting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Barkod, alt barkod veya ürün adını arayın, kaydı tamamlayın.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
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
              _ProductSearchResults(
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
    DateTime tempDate = initial;

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Expanded(
                child: CupertinoDatePicker(
                  initialDateTime: initial,
                  minimumDate: normalizedNow,
                  maximumDate: normalizedNow.add(const Duration(days: 365)),
                  mode: CupertinoDatePickerMode.date,
                  onDateTimeChanged: (value) => tempDate = value,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('İptal'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(tempDate),
                      child: const Text('Onayla'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _expiryDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
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

class _ProductSearchResults extends StatelessWidget {
  const _ProductSearchResults({
    required this.searchAsync,
    required this.searching,
    required this.onSelect,
  });

  final AsyncValue<List<ProductSummaryModel>> searchAsync;
  final bool searching;
  final ValueChanged<ProductSummaryModel> onSelect;

  @override
  Widget build(BuildContext context) {
    if (!searching) {
      return Text(
        'En az 3 karakter girerek arama yapın.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return searchAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return Text(
            'Eşleşme bulunamadı.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return SizedBox(
          height: 180,
          child: ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Barkod: ${product.barcode}'),
                    if (product.altBarcodes.isNotEmpty)
                      Text(
                        'Alt barkodlar: ${product.altBarcodes.join(', ')}',
                      ),
                  ],
                ),
                leading: const Icon(Icons.inventory_2_outlined),
                onTap: () => onSelect(product),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Text(
        'Arama sırasında hata oluştu: $error',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _isProcessing = true;
        Navigator.of(context).pop(value);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Barkod Tara'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'torch',
                    backgroundColor: colors.primary,
                    onPressed: () => _controller.toggleTorch(),
                    child: ValueListenableBuilder<TorchState>(
                      valueListenable: _controller.torchState,
                      builder: (context, state, _) {
                        switch (state) {
                          case TorchState.off:
                            return const Icon(Icons.flash_off);
                          case TorchState.on:
                            return const Icon(Icons.flash_on);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton.small(
                    heroTag: 'switch-camera',
                    backgroundColor: colors.primary,
                    onPressed: () => _controller.switchCamera(),
                    child: const Icon(Icons.cameraswitch),
                  ),
                ],
              ),
            ),
          ),
        ],
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
