import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/providers/auth_provider.dart';
import '../../domain/models/branch_summary_model.dart';
import '../../domain/models/product_summary_model.dart';
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

class _SktCreateSheet extends ConsumerStatefulWidget {
  const _SktCreateSheet();

  @override
  ConsumerState<_SktCreateSheet> createState() => _SktCreateSheetState();
}

class _SktCreateSheetState extends ConsumerState<_SktCreateSheet> {
  late final TextEditingController _searchCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _statusCtrl;
  late final TextEditingController _notesCtrl;
  String _searchQuery = '';
  ProductSummaryModel? _selectedProduct;
  BranchSummaryModel? _selectedBranch;
  DateTime? _expiryDate;
  bool _isSubmitting = false;
  String? _errorMessage;
  final int _defaultAlarmDays = 7;
  final FocusNode _searchFocus = FocusNode();
  String? _lockedBranchId;
  String? _lockedBranchName;

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
    _statusCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _quantityCtrl.dispose();
    _statusCtrl.dispose();
    _notesCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final branchesAsync = ref.watch(sktBranchesProvider);
    final searchTerm = _searchQuery.trim();
    final searching = searchTerm.length >= 3;
    final AsyncValue<List<ProductSummaryModel>> searchAsync = searching
        ? ref.watch(sktProductSearchProvider(searchTerm))
        : const AsyncData<List<ProductSummaryModel>>(<ProductSummaryModel>[]);

    branchesAsync.whenData(_syncLockedBranch);

    final quantityValue = int.tryParse(_quantityCtrl.text.trim());
    final resolvedBranchId = _selectedBranch?.id ?? _lockedBranchId;
    final canSubmit = !_isSubmitting &&
        _selectedProduct != null &&
        resolvedBranchId != null &&
        _expiryDate != null &&
        quantityValue != null &&
        quantityValue > 0;

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
                'Barkodu veya ürün adını arayın, kaydı tamamlayın.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Barkod veya ürün adı',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
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
                    subtitle: Text('Barkod: ${_selectedProduct!.barcode}'),
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
              branchesAsync.when(
                data: (branches) {
                  final items = branches
                      .map((b) => DropdownMenuItem<String>(
                            value: b.id,
                            child: Text(b.name),
                          ))
                      .toList();
                  if (_lockedBranchId != null) {
                    final display = _lockedBranchName ?? 'Şubeniz (yükleniyor)';
                    return InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Şube',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(display),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedBranch?.id,
                    decoration: const InputDecoration(
                      labelText: 'Şube',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: items,
                    onChanged: (value) {
                      setState(() {
                        _selectedBranch =
                            branches.firstWhere((b) => b.id == value);
                      });
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Şube',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(
                    'Şubeler alınamadı: $error',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickExpiryDate,
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
              TextField(
                controller: _statusCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ürün durumu (opsiyonel)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
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
                'Alarm $_defaultAlarmDays gün önce tetiklenecek.',
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

  void _syncLockedBranch(List<BranchSummaryModel> branches) {
    if (_lockedBranchId == null) {
      return;
    }
    if (_lockedBranchName != null) {
      return;
    }
    final match = branches.where((b) => b.id == _lockedBranchId).toList();
    if (match.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lockedBranchName = match.first.name;
      });
    });
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final initial = _expiryDate ?? now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(
        () => _expiryDate = DateTime(picked.year, picked.month, picked.day));
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
    final branchId = _selectedBranch?.id ?? _lockedBranchId;
    final expiry = _expiryDate;
    final quantity = int.tryParse(_quantityCtrl.text.trim());

    if (product == null ||
        branchId == null ||
        expiry == null ||
        quantity == null ||
        quantity <= 0) {
      setState(() {
        _errorMessage = 'Gerekli alanları doldurun.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final statusText =
        _statusCtrl.text.trim().isEmpty ? null : _statusCtrl.text.trim();
    final notesText =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    try {
      await ref.read(sktRepositoryProvider).createRecord(
            tenantId: user.tenantId,
            branchId: branchId,
            productId: product.id,
            userId: user.id,
            expiryDate: expiry,
            quantity: quantity,
            productStatus: statusText,
            notes: notesText,
            alarmDaysBefore: _defaultAlarmDays,
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
                subtitle: Text('Barkod: ${product.barcode}'),
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
