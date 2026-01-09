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
  bool _isSearching = false;
  String _searchQuery = '';
  MerchPerson? _editingPerson;

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

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isSearching
              ? TextField(
                  key: const ValueKey('merch-search'),
                  controller: _searchCtrl,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.merchSearchHint,
                    border: InputBorder.none,
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    setState(() => _searchQuery = value.trim());
                  },
                )
              : Text(l10n.merchTitle),
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.filter_list),
            tooltip:
                _isSearching ? l10n.merchSearchClose : l10n.merchSearchToggle,
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: l10n.merchAddPerson,
            onPressed: () => _openAddPersonSheet(),
          ),
        ],
      ),
      body: SafeArea(
        child: peopleAsync.when(
          data: (_) {
            if (filteredGroups.isEmpty) {
              return _EmptyState(isFiltered: _searchQuery.isNotEmpty);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredGroups.length,
              itemBuilder: (context, index) {
                final group = filteredGroups[index];
                return _CompanyGroupCard(
                  group: group,
                  onPersonTap: _handlePersonTap,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _MerchErrorState(
            message: l10n.merchLoadError('$error'),
            onRetry: () => ref.read(merchPeopleProvider.notifier).refresh(),
          ),
        ),
      ),
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: bottomInset + 16,
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing ? l10n.merchEditTitle : l10n.merchCreateTitle,
            style: Theme.of(sheetContext).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _firstNameCtrl,
                  l10n.merchFieldFirstName,
                  sheetContext,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  _lastNameCtrl,
                  l10n.merchFieldLastName,
                  sheetContext,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(_companyCtrl, l10n.merchFieldCompany, sheetContext),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.merchFieldPhone,
              prefixText: '+90 ',
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return l10n.merchPhoneRequired;
              if (trimmed.length < 9) return l10n.merchPhoneInvalid;
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownMenu<MerchRank>(
            initialSelection: _selectedRank,
            label: Text(l10n.merchFieldRank),
            dropdownMenuEntries: MerchRank.values
                .map(
                  (rank) => DropdownMenuEntry(
                    value: rank,
                    label: rank.localizedLabel(sheetContext),
                  ),
                )
                .toList(),
            onSelected: (rank) {
              if (rank != null) {
                setState(() => _selectedRank = rank);
              }
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleSubmit(sheetContext),
              icon: Icon(isEditing ? Icons.save : Icons.person_add_alt),
              label: Text(
                isEditing ? l10n.merchUpdateButton : l10n.merchAddButton,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    BuildContext context,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
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
    final isEditing = _editingPerson != null;
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

  void _handlePersonTap(MerchPerson person) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(context.l10n.commonEdit),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openAddPersonSheet(person: person);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(context.l10n.commonDelete),
                iconColor: Theme.of(context).colorScheme.error,
                textColor: Theme.of(context).colorScheme.error,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDelete(person);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(MerchPerson person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.merchDeleteTitle),
          content: Text(
            context.l10n.merchDeleteMessage(person.fullName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonDismiss),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
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

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _isSearching = false;
        _searchQuery = '';
        _searchCtrl.clear();
        _searchFocusNode.unfocus();
      } else {
        _isSearching = true;
        _searchFocusNode.requestFocus();
      }
    });
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
    if (query.isEmpty) return groups;

    final List<MerchCompanyGroup> filtered = [];
    for (final group in groups) {
      final companyMatches = group.companyName.toLowerCase().contains(query);
      final people = companyMatches
          ? group.people
          : group.people.where((person) {
              final fullName = person.fullName.toLowerCase();
              final phone = person.phoneNumber.toLowerCase();
              return fullName.contains(query) ||
                  phone.contains(query) ||
                  person.companyName.toLowerCase().contains(query);
            }).toList();
      if (people.isNotEmpty) {
        filtered.add(
          MerchCompanyGroup(companyName: group.companyName, people: people),
        );
      }
    }
    return filtered;
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.companyName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...group.people.map(
              (person) => InkWell(
                onTap: () => onPersonTap(person),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        child: Text(
                          person.firstName.isNotEmpty
                              ? person.firstName.substring(0, 1).toUpperCase()
                              : '?',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.fullName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(person.rank.localizedLabel(context)),
                            Text(
                              '+90 ${person.phoneNumber}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final message = isFiltered
        ? context.l10n.merchEmptyFiltered
        : context.l10n.merchEmptyDefault;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_add, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
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
