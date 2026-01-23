import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/core/localization/localization_extensions.dart';
import 'package:yotech_mobile/features/merch/data/models/merch_person.dart';
import 'package:yotech_mobile/features/merch/presentation/providers/merch_providers.dart';

class MerchScreen extends ConsumerStatefulWidget {
  const MerchScreen({super.key});

  @override
  ConsumerState<MerchScreen> createState() => _MerchScreenState();
}

class _MerchScreenState extends ConsumerState<MerchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  MerchRank _selectedRank = MerchRank.merch;
  String _searchQuery = '';
  MerchPerson? _editingPerson;
  MerchRank? _filterRank;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(merchPeopleProvider);
    final groups = ref.watch(merchGroupsProvider);
    final filteredGroups = _applySearch(groups);
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    // İstatistikler
    final allPeople = groups.expand((g) => g.people).toList();
    final totalCount = allPeople.length;
    final companyCount = groups.length;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: _buildHeader(
              context,
              totalCount: totalCount,
              companyCount: companyCount,
            ),
          ),
        ],
        body: Column(
          children: [
            // Arama ve filtre alanı
            Container(
              color: cs.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  // Arama
                  TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: l10n.merchSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor:
                          cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.trim()),
                  ),
                  const SizedBox(height: 10),
                  // Rank filtreleri
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRankChip(null, 'Tümü'),
                        const SizedBox(width: 8),
                        ...MerchRank.values.map(
                          (rank) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildRankChip(
                              rank,
                              rank.localizedLabel(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Liste
            Expanded(
              child: peopleAsync.when(
                data: (_) {
                  if (filteredGroups.isEmpty) {
                    return _EmptyState(
                      isFiltered:
                          _searchQuery.isNotEmpty || _filterRank != null,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(merchPeopleProvider.notifier).refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filteredGroups.length,
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
                        return _CompanyGroupCard(
                          group: group,
                          onPersonTap: _handlePersonTap,
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _MerchErrorState(
                  message: l10n.merchLoadError('$error'),
                  onRetry: () =>
                      ref.read(merchPeopleProvider.notifier).refresh(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required int totalCount,
    required int companyCount,
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
                      Icons.groups_rounded,
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
                          'Mörş Yönetimi',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          'Tedarikçi ve personel listesi',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Kişi Ekle butonu
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openAddPersonSheet(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add_alt_1,
                                size: 18, color: cs.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Ekle',
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
              // İstatistik kartları
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.person,
                      label: 'Toplam Kişi',
                      value: totalCount.toString(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.business,
                      label: 'Firma',
                      value: companyCount.toString(),
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.badge,
                      label: 'Unvan',
                      value: MerchRank.values.length.toString(),
                      color: Colors.green,
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

  Widget _buildRankChip(MerchRank? rank, String label) {
    final isSelected = _filterRank == rank;
    final cs = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterRank = selected ? rank : null);
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

  Future<void> _openAddPersonSheet({MerchPerson? person}) async {
    if (person != null) {
      _editingPerson = person;
      _firstNameCtrl.text = person.firstName;
      _lastNameCtrl.text = person.lastName;
      _companyCtrl.text = person.companyName;
      _phoneCtrl.text = person.phoneNumber;
      _selectedRank = person.rank;
    }

    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: bottomInset + 20,
            ),
            child: SingleChildScrollView(
              child: _buildForm(
                sheetContext,
                isEditing: person != null,
              ),
            ),
          ),
        );
      },
    );

    _editingPerson = null;
    _resetForm();
  }

  Widget _buildForm(BuildContext sheetContext, {required bool isEditing}) {
    final l10n = sheetContext.l10n;
    final cs = Theme.of(sheetContext).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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
          // Başlık
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEditing ? Icons.edit : Icons.person_add_alt_1,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? l10n.merchEditTitle : l10n.merchCreateTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      isEditing
                          ? 'Kişi bilgilerini düzenleyin'
                          : 'Yeni kişi ekleyin',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Form alanları
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _firstNameCtrl,
                  l10n.merchFieldFirstName,
                  sheetContext,
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  _lastNameCtrl,
                  l10n.merchFieldLastName,
                  sheetContext,
                  icon: Icons.person_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTextField(
            _companyCtrl,
            l10n.merchFieldCompany,
            sheetContext,
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.merchFieldPhone,
              prefixText: '+90 ',
              prefixIcon: const Icon(Icons.phone_outlined),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return l10n.merchPhoneRequired;
              if (trimmed.length < 9) return l10n.merchPhoneInvalid;
              return null;
            },
          ),
          const SizedBox(height: 14),
          // Rank seçimi - modern chips
          Text(
            l10n.merchFieldRank,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MerchRank.values.map((rank) {
              final isSelected = _selectedRank == rank;
              return ChoiceChip(
                label: Text(rank.localizedLabel(sheetContext)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedRank = rank);
                  }
                },
                selectedColor: cs.primaryContainer,
                labelStyle: TextStyle(
                  color:
                      isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Butonlar
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
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
                  onPressed: () => _handleSubmit(sheetContext),
                  icon: Icon(isEditing ? Icons.save : Icons.person_add_alt),
                  label: Text(
                    isEditing ? l10n.merchUpdateButton : l10n.merchAddButton,
                  ),
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
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    BuildContext context, {
    IconData? icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.l10n.merchFieldRequired(label);
        }
        return null;
      },
    );
  }

  Future<void> _handleSubmit(BuildContext sheetContext) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(merchPeopleProvider.notifier);
    final isEditing = _editingPerson != null;

    // Aynı isim/telefon kontrolü (sadece yeni kayıt için)
    if (!isEditing) {
      final peopleAsync = ref.read(merchPeopleProvider);
      final existingPeople = peopleAsync.valueOrNull ?? [];

      final newFirstName = _firstNameCtrl.text.trim().toLowerCase();
      final newLastName = _lastNameCtrl.text.trim().toLowerCase();
      final newPhone = _phoneCtrl.text.trim();

      // Aynı telefonda kişi var mı? - varsa eklemeye izin verme
      final samePhonePerson = existingPeople.firstWhereOrNull(
        (p) => p.phoneNumber == newPhone,
      );

      if (samePhonePerson != null) {
        await _showPhoneExistsError(sheetContext, samePhonePerson);
        return; // Eklemeye izin verme
      }

      // Aynı isimde kişi var mı? - varsa uyarı göster ama izin ver
      final sameNamePerson = existingPeople.firstWhereOrNull(
        (p) =>
            p.firstName.toLowerCase() == newFirstName &&
            p.lastName.toLowerCase() == newLastName,
      );

      if (sameNamePerson != null) {
        final shouldContinue = await _showDuplicateWarning(
          sheetContext,
          sameNamePerson: sameNamePerson,
        );
        if (!shouldContinue) return;
      }
    }

    final id =
        _editingPerson?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final person = MerchPerson(
      id: id,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      companyName: _companyCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      rank: _selectedRank,
    );

    try {
      if (isEditing) {
        await notifier.updatePerson(person);
      } else {
        await notifier.addPerson(person);
      }
      if (!sheetContext.mounted) return;
      Navigator.of(sheetContext).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? context.l10n.merchUpdateSuccess
                : context.l10n.merchCreateSuccess,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.commonActionFailed('$e'))),
      );
    }
  }

  /// Aynı telefon numarası varsa hata göster - eklemeye izin verme
  Future<void> _showPhoneExistsError(
    BuildContext sheetContext,
    MerchPerson existingPerson,
  ) async {
    final cs = Theme.of(sheetContext).colorScheme;

    await showDialog<void>(
      context: sheetContext,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.error_outline,
            color: cs.error,
            size: 48,
          ),
          title: const Text('Telefon Numarası Kullanımda'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, color: cs.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu numara zaten kayıtlı:',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            existingPerson.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            existingPerson.companyName,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Tel: +90 ${existingPerson.phoneNumber}',
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
              ),
              const SizedBox(height: 12),
              Text(
                'Aynı telefon numarasıyla farklı bir kişi ekleyemezsiniz.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  /// Aynı isimde kişi varsa uyarı göster
  Future<bool> _showDuplicateWarning(
    BuildContext sheetContext, {
    MerchPerson? sameNamePerson,
  }) async {
    final cs = Theme.of(sheetContext).colorScheme;

    final result = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: cs.error,
            size: 48,
          ),
          title: const Text('Benzer Kayıt Bulundu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sameNamePerson != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: cs.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aynı isimde kişi mevcut:',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${sameNamePerson.fullName} (${sameNamePerson.companyName})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Tel: +90 ${sameNamePerson.phoneNumber}',
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
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Yine de kaydetmek istiyor musunuz?',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
              ),
              child: const Text('Yine de Kaydet'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _handlePersonTap(MerchPerson person) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Kişi bilgisi
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          person.firstName.isNotEmpty
                              ? person.firstName.substring(0, 1).toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              person.companyName,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getRankColor(person.rank)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                person.rank.localizedLabel(context),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getRankColor(person.rank),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.edit_outlined,
                          label: context.l10n.commonEdit,
                          color: cs.primary,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _openAddPersonSheet(person: person);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.phone_outlined,
                          label: 'Ara',
                          color: Colors.green,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            // TODO: Telefon arama
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.delete_outline,
                          label: context.l10n.commonDelete,
                          color: cs.error,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _confirmDelete(person);
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
      },
    );
  }

  Color _getRankColor(MerchRank rank) {
    switch (rank) {
      case MerchRank.merch:
        return Colors.blue;
      case MerchRank.plasiyer:
        return Colors.orange;
      case MerchRank.sevkiyat:
        return Colors.purple;
      case MerchRank.sef:
        return Colors.teal;
      case MerchRank.yonetici:
        return Colors.red;
    }
  }

  Future<void> _confirmDelete(MerchPerson person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
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
          title: Text(context.l10n.merchDeleteTitle),
          content: Text(
            context.l10n.merchDeleteMessage(person.fullName),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonDismiss),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(context.l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(merchPeopleProvider.notifier).removePerson(person.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.merchDeleteSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.merchDeleteFailure('$e'))),
      );
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _firstNameCtrl.clear();
    _lastNameCtrl.clear();
    _companyCtrl.clear();
    _phoneCtrl.clear();
    if (mounted) {
      setState(() => _selectedRank = MerchRank.merch);
    } else {
      _selectedRank = MerchRank.merch;
    }
  }

  List<MerchCompanyGroup> _applySearch(List<MerchCompanyGroup> groups) {
    final query = _searchQuery.trim().toLowerCase();

    final List<MerchCompanyGroup> filtered = [];
    for (final group in groups) {
      final companyMatches =
          query.isEmpty || group.companyName.toLowerCase().contains(query);
      var people = companyMatches
          ? group.people
          : group.people.where((person) {
              final fullName = person.fullName.toLowerCase();
              final phone = person.phoneNumber.toLowerCase();
              return fullName.contains(query) ||
                  phone.contains(query) ||
                  person.companyName.toLowerCase().contains(query);
            }).toList();

      // Rank filtresi uygula
      if (_filterRank != null) {
        people = people.where((p) => p.rank == _filterRank).toList();
      }

      if (people.isNotEmpty) {
        filtered.add(
          MerchCompanyGroup(companyName: group.companyName, people: people),
        );
      }
    }
    return filtered;
  }
}

// İstatistik kartı
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
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
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// Action tile
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyGroupCard extends StatelessWidget {
  const _CompanyGroupCard({
    required this.group,
    required this.onPersonTap,
  });

  final MerchCompanyGroup group;
  final void Function(MerchPerson person) onPersonTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Firma başlığı
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.business,
                    size: 20,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.companyName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${group.people.length} kişi',
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
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // Kişi listesi
            ...group.people.map(
              (person) => _PersonTile(
                person: person,
                onTap: () => onPersonTap(person),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.onTap,
  });

  final MerchPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rankColor = _getRankColor(person.rank);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primaryContainer,
              child: Text(
                person.firstName.isNotEmpty
                    ? person.firstName.substring(0, 1).toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: rankColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          person.rank.localizedLabel(context),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: rankColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.phone_outlined,
                        size: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+90 ${person.phoneNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(MerchRank rank) {
    switch (rank) {
      case MerchRank.merch:
        return Colors.blue;
      case MerchRank.plasiyer:
        return Colors.orange;
      case MerchRank.sevkiyat:
        return Colors.purple;
      case MerchRank.sef:
        return Colors.teal;
      case MerchRank.yonetici:
        return Colors.red;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final message = isFiltered
        ? context.l10n.merchEmptyFiltered
        : context.l10n.merchEmptyDefault;
    final subtitle = isFiltered
        ? 'Farklı bir arama deneyin'
        : 'Yeni kişi ekleyerek başlayın';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                isFiltered ? Icons.search_off : Icons.group_add,
                size: 48,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
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
        ),
      ),
    );
  }
}

class _MerchErrorState extends StatelessWidget {
  const _MerchErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 42,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

extension on MerchRank {
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case MerchRank.merch:
        return l10n.merchRankMerch;
      case MerchRank.plasiyer:
        return l10n.merchRankPlasiyer;
      case MerchRank.sevkiyat:
        return l10n.merchRankSevkiyat;
      case MerchRank.sef:
        return l10n.merchRankSef;
      case MerchRank.yonetici:
        return l10n.merchRankYonetici;
    }
  }
}
