import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/shared/widgets/custom_back_button.dart';

import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../inventory_transfer/data/models/inventory_transfer_model.dart';
import '../../../inventory_transfer/presentation/providers/inventory_transfer_provider.dart';
import '../../domain/models/managed_branch.dart';
import '../../domain/models/branch_task_node.dart';
import '../../domain/models/manager_todo_node.dart';
import '../../domain/models/branch_personnel.dart';
import '../../domain/providers/region_manager_providers.dart';
import '../../data/region_manager_task_repository.dart';
import '../../../settings/presentation/screens/personal_info_page.dart';
import '../../../settings/presentation/screens/settings_page.dart';
import 'rm_forms_hub_page.dart';
import '../../../announcements/presentation/screens/announcements_page.dart';
import '../../../requests/data/request_repository.dart';
import '../../../requests/domain/models/branch_request.dart';
import '../../../requests/domain/models/request_category.dart';
import '../../../requests/domain/models/request_status.dart';
import '../../../requests/presentation/widgets/request_category_theme.dart';
import '../../../requests/domain/models/equipment_request_type.dart';
import '../../../requests/domain/models/malfunction_issue_type.dart';

class RegionManagerDashboardScreen extends ConsumerStatefulWidget {
  const RegionManagerDashboardScreen({super.key});

  @override
  ConsumerState<RegionManagerDashboardScreen> createState() =>
      _RegionManagerDashboardScreenState();
}

class _RegionManagerDashboardScreenState
    extends ConsumerState<RegionManagerDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  DateTime? _checkOutTime;

  String? _activeBranchId;
  int _currentTabIndex = 0;
  int _primaryTabIndex = 0;
  final Set<String> _expandedBranchTaskIds = <String>{};

  late final List<_ChecklistItem> _checklist;
  late final TabController _tasksTabController;

  static const List<_PersonnelRoleOption> _assignableRoles = [
    _PersonnelRoleOption('personel', 'Personel'),
    _PersonnelRoleOption('sube_muduru', 'Şube Müdürü'),
  ];

  @override
  void initState() {
    super.initState();
    _tasksTabController = TabController(length: 2, vsync: this);
    _tasksTabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _checklist = [
      const _ChecklistItem(
        id: 'visual',
        title: 'Görsel düzen onaylandı',
        description: 'Vitrin, POS ve raf düzeni firma standartlarına uygun.',
        isDone: false,
      ),
      const _ChecklistItem(
        id: 'stock',
        title: 'Stok sayımı tamamlandı',
        description: 'Sayım sonucu ERP ile %98 uyumlu.',
        isDone: true,
      ),
      const _ChecklistItem(
        id: 'training',
        title: 'Ekip bilgilendirildi',
        description: 'Yeni kampanya anlatıldı ve satış scripti tekrarlandı.',
        isDone: false,
      ),
    ];
  }

  void _toggleChecklist(String id, bool? value) {
    setState(() {
      final index = _checklist.indexWhere((item) => item.id == id);
      if (index != -1) {
        _checklist[index] = _checklist[index].copyWith(isDone: value ?? false);
      }
    });
  }

  void _handleCheckInOut() {
    setState(() {
      if (_isCheckedIn) {
        _isCheckedIn = false;
        _checkOutTime = DateTime.now();
      } else {
        _isCheckedIn = true;
        _checkInTime = DateTime.now();
        _checkOutTime = null;
      }
    });
  }

  Duration? _currentVisitDuration() {
    if (_checkInTime == null) {
      return null;
    }
    final comparisonPoint =
        _isCheckedIn ? DateTime.now() : (_checkOutTime ?? DateTime.now());
    return comparisonPoint.difference(_checkInTime!);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final managerUser = authState.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );
    final managerName = managerUser != null
        ? '${managerUser.name} ${managerUser.surname}'.trim()
        : '—';
    final visitDuration = _currentVisitDuration();

    final branchesAsync = ref.watch(regionManagerBranchesProvider);
    final branchesForActions = branchesAsync.maybeWhen(
      data: (branches) => branches,
      orElse: () => const <ManagedBranch>[],
    );
    final activeBranchForAppBar = _resolveActiveBranch(branchesForActions);

    final hasBranchOptions = branchesForActions.isNotEmpty;
    final branchSelectorButton = hasBranchOptions
        ? _BranchSelectorButton(
            activeBranch: activeBranchForAppBar,
            enabled: true,
            onPressed: () => _openBranchSelector(branchesForActions),
          )
        : null;

    // Get region name from first branch if available
    final regionName = branchesForActions.isNotEmpty
        ? (branchesForActions.first.regionName ?? 'Bölge')
        : 'Bölge';

    return CustomBackButton(
      onBackPressed: _handleBackPressed,
      child: Scaffold(
        drawer: _RegionManagerNavigationDrawer(
          onNavigateToProfile: _openProfile,
          onNavigateToSettings: _openSettings,
          onNavigateToPersonnel: _openPersonnelTab,
          onNavigateToStoreScoring: _openStoreScoring,
          onNavigateToAnnouncements: _openAnnouncements,
          managerName: managerName,
          regionName: regionName,
          branchCount: branchesForActions.length,
        ),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 56,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menü',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: branchSelectorButton,
          centerTitle: true,
          actions: [
            // Notification button
            IconButton(
              tooltip: 'Bildirimler',
              icon: const Badge(
                isLabelVisible: true,
                label: Text('3'),
                child: Icon(Icons.notifications_outlined),
              ),
              onPressed: () => _showNotifications(context),
            ),
            IconButton(
              tooltip: 'Profil',
              icon: const Icon(Icons.person_outline),
              onPressed: _openProfile,
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: branchesAsync.maybeWhen(
          data: (fetchedBranches) {
            final activeBranch = _resolveActiveBranch(fetchedBranches);
            return _buildFloatingActionButton(
              context: context,
              branches: fetchedBranches,
              activeBranch: activeBranch,
            );
          },
          orElse: () => null,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _primaryTabIndex,
          onDestinationSelected: (index) {
            if (_primaryTabIndex != index || _currentTabIndex != index) {
              setState(() {
                _primaryTabIndex = index;
                _currentTabIndex = index;
              });
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Günlük',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Talepler',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check),
              label: 'Görevler',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Sevkler',
            ),
          ],
        ),
        body: branchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildInfoState(
            context,
            title: 'Şubeler yüklenemedi',
            description: '$error',
            actionLabel: 'Tekrar Dene',
            onAction: () => ref.invalidate(regionManagerBranchesProvider),
          ),
          data: (fetchedBranches) {
            _ensureActiveBranchSelection(fetchedBranches);

            if (fetchedBranches.isEmpty) {
              final tenantId = managerUser?.tenantId ?? '—';
              final managerId = managerUser?.id ?? '—';
              final roleLabel = managerUser?.role ?? '—';

              return _buildInfoState(
                context,
                title: 'Şube bulunamadı',
                description: 'Bu kullanıcıya atanmış aktif şube görünmüyor.\n\n'
                    'Oturum bilgileri: rol = $roleLabel, kullanıcı ID = $managerId, tenant ID = $tenantId.\n\n'
                    'Aşağıdaki koşulların Supabase tarafında sağlandığından emin olun:\n'
                    '- branches.tenant_id değeri $tenantId olmalı\n'
                    '- branches.active = true olmalı\n'
                    '- branches.region_id ile ilişkili regions kaydının manager_id değeri $managerId olmalı\n'
                    '- regions.tenant_id değeri de $tenantId ile eşleşmeli',
                actionLabel: 'Yenile',
                onAction: () => ref.invalidate(regionManagerBranchesProvider),
              );
            }

            final activeBranch = _resolveActiveBranch(fetchedBranches);
            final transferAsync = ref.watch(inventoryTransferListProvider);
            final tabs = [
              _buildDashboardTab(
                context: context,
                visitDuration: visitDuration,
                managerName: managerName,
                activeBranch: activeBranch,
                branches: fetchedBranches,
              ),
              _buildRequestsTab(
                context: context,
                branches: fetchedBranches,
                activeBranch: activeBranch,
              ),
              _buildTasksTab(
                context: context,
                branches: fetchedBranches,
                activeBranch: activeBranch,
              ),
              _buildTransferTab(
                context: context,
                branches: fetchedBranches,
                activeBranch: activeBranch,
                noticesAsync: transferAsync,
              ),
              _buildPersonnelTab(
                context: context,
                branches: fetchedBranches,
                activeBranch: activeBranch,
              ),
            ];

            return IndexedStack(
              index: _currentTabIndex,
              children: tabs,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransferTab({
    required BuildContext context,
    required List<ManagedBranch> branches,
    required ManagedBranch? activeBranch,
    required AsyncValue<List<DepotNotice>> noticesAsync,
  }) {
    if (branches.isEmpty) {
      return _buildInfoState(
        context,
        title: 'Şube bulunamadı',
        description:
            'Depolar arası sevk kayıtlarını görüntülemek için en az bir şube gerekir.',
        actionLabel: 'Şubeleri yenile',
        onAction: () => ref.invalidate(regionManagerBranchesProvider),
      );
    }

    return noticesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildInfoState(
        context,
        title: 'Sevk kayıtları yüklenemedi',
        description: '$error',
        actionLabel: 'Tekrar dene',
        onAction: () => ref.invalidate(inventoryTransferListProvider),
      ),
      data: (notices) {
        final scopedBranchIds = <String>{};
        if (activeBranch != null) {
          scopedBranchIds.add(activeBranch.id);
        } else {
          for (final branch in branches) {
            scopedBranchIds.add(branch.id);
          }
        }

        if (scopedBranchIds.isEmpty) {
          return _NoBranchSelectedCard(
            onSelect:
                branches.isEmpty ? null : () => _openBranchSelector(branches),
          );
        }

        final branchNameLookup = <String, String>{
          for (final branch in branches) branch.id: branch.name,
        };

        final scopedNotices = notices
            .where((notice) => scopedBranchIds.contains(notice.branchId))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final scopedOffers = <_OfferSummary>[];
        for (final notice in notices) {
          for (final offer in notice.offers ?? const <NoticeOffer>[]) {
            if (scopedBranchIds.contains(offer.branchId)) {
              scopedOffers.add(_OfferSummary(offer: offer, notice: notice));
            }
          }
        }
        scopedOffers
            .sort((a, b) => b.offer.createdAt.compareTo(a.offer.createdAt));

        final scopeLabel =
            activeBranch != null ? activeBranch.name : 'Tüm şubeleriniz';
        final scopeDescription = activeBranch != null
            ? '${activeBranch.name} şubesine ait ilan ve talepler listelenir.'
            : 'Şube seçilmedi, yönetiminizdeki tüm şubelerin kayıtları listelenir.';

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _TransferScopeCard(
                    label: scopeLabel,
                    description: scopeDescription,
                    onChangeTap: branches.length > 1
                        ? () => _openBranchSelector(branches)
                        : (activeBranch != null
                            ? () => _openBranchSelector(branches)
                            : null),
                  ),
                  const SizedBox(height: 16),
                  _TransferNoticesCard(
                    notices: scopedNotices,
                    branchNames: branchNameLookup,
                  ),
                  const SizedBox(height: 16),
                  _TransferOffersCard(
                    offers: scopedOffers,
                    branchNames: branchNameLookup,
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPersonnelTab({
    required BuildContext context,
    required List<ManagedBranch> branches,
    required ManagedBranch? activeBranch,
  }) {
    if (branches.isEmpty) {
      return _buildInfoState(
        context,
        title: 'Şube bulunamadı',
        description:
            'Personel listesi için en az bir şubeye atanmış olmanız gerekir.',
        actionLabel: 'Şubeleri yenile',
        onAction: () => ref.invalidate(regionManagerBranchesProvider),
      );
    }

    if (activeBranch == null) {
      return _NoBranchSelectedCard(
        onSelect: () => _openBranchSelector(branches),
      );
    }

    final personnelScope = BranchPersonnelScope(activeBranch.id);

    final personnelAsync = ref.watch(branchPersonnelProvider(personnelScope));

    return personnelAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildInfoState(
        context,
        title: 'Personeller yüklenemedi',
        description: '$error',
        actionLabel: 'Tekrar dene',
        onAction: () => ref.invalidate(branchPersonnelProvider(personnelScope)),
      ),
      data: (personnel) {
        return RefreshIndicator(
          onRefresh: () => _refreshPersonnel(personnelScope),
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _PersonnelScopeCard(
                branchName: activeBranch.name,
                onChangeBranch: branches.length > 1
                    ? () => _openBranchSelector(branches)
                    : null,
              ),
              const SizedBox(height: 16),
              if (personnel.isEmpty)
                const _EmptyPersonnelCard()
              else ...[
                for (var i = 0; i < personnel.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == personnel.length - 1 ? 0 : 12,
                    ),
                    child: _PersonnelCard(
                      personnel: personnel[i],
                      roleLabel: _roleLabel(personnel[i].role),
                      onChangeRole: () => _showChangePersonnelRoleSheet(
                        personnel: personnel[i],
                        scope: personnelScope,
                      ),
                      onRemove: () => _confirmRemovePersonnel(
                        personnel: personnel[i],
                        scope: personnelScope,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshPersonnel(BranchPersonnelScope scope) async {
    ref.invalidate(branchPersonnelProvider(scope));
    await ref.read(branchPersonnelProvider(scope).future);
  }

  Widget? _buildFloatingActionButton({
    required BuildContext context,
    required List<ManagedBranch> branches,
    required ManagedBranch? activeBranch,
  }) {
    if (_currentTabIndex == 2) {
      if (_tasksTabController.index == 0) {
        return FloatingActionButton(
          onPressed: () => _showCreateBranchTaskSheet(
            branches: branches,
            activeBranch: activeBranch,
          ),
          tooltip: 'Görev ekle',
          child: const Icon(Icons.add),
        );
      }
      return FloatingActionButton(
        onPressed: _showCreateTodoSheet,
        tooltip: 'To-Do ekle',
        child: const Icon(Icons.playlist_add),
      );
    }

    if (_currentTabIndex == 4) {
      final branchForCreation =
          activeBranch ?? (branches.length == 1 ? branches.first : null);
      return FloatingActionButton(
        onPressed: branchForCreation == null
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Personel eklemek için önce şube seçin.'),
                  ),
                );
              }
            : () => _showCreatePersonnelSheet(branchForCreation),
        tooltip: 'Personel ekle',
        child: const Icon(Icons.person_add),
      );
    }

    return null;
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'grand_admin':
        return 'Grand Admin';
      case 'firma_admin':
        return 'Firma Yetkilisi';
      case 'bolge_muduru':
        return 'Bölge Müdürü';
      case 'sube_muduru':
        return 'Şube Müdürü';
      case 'personel':
      default:
        return 'Personel';
    }
  }

  Future<void> _showChangePersonnelRoleSheet({
    required BranchPersonnel personnel,
    required BranchPersonnelScope scope,
  }) async {
    const options = _assignableRoles;
    final initialRole = options.any((option) => option.value == personnel.role)
        ? personnel.role
        : options.first.value;

    final selectedRole = await showModalBottomSheet<String>(
      context: context,
      builder: (modalContext) {
        var currentValue = initialRole;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rolü Güncelle',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...options.map((option) {
                    final isSelected = currentValue == option.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(option.label),
                      onTap: () => setModalState(
                        () => currentValue = option.value,
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Vazgeç'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(currentValue),
                          child: const Text('Kaydet'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (!mounted || selectedRole == null || selectedRole == personnel.role) {
      return;
    }

    try {
      await _executeWithLoading(() async {
        await ref
            .read(regionManagerStaffRepositoryProvider)
            .updatePersonnelRole(userId: personnel.id, role: selectedRole);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${personnel.displayName} rolü güncellendi.'),
        ),
      );
      await _refreshPersonnel(scope);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rol güncellenemedi: $error')),
      );
    }
  }

  Future<void> _confirmRemovePersonnel({
    required BranchPersonnel personnel,
    required BranchPersonnelScope scope,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Personeli Sil'),
        content: Text(
          '${personnel.displayName} kaydını silmek istediğinize emin misiniz?\n\nBu işlem personeli pasifleştirir ve şubeden çıkarır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _executeWithLoading(() async {
        await ref
            .read(regionManagerStaffRepositoryProvider)
            .removePersonnel(userId: personnel.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${personnel.displayName} kaydı silindi.'),
        ),
      );
      await _refreshPersonnel(scope);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Personel silinemedi: $error')),
      );
    }
  }

  Future<void> _showCreatePersonnelSheet(ManagedBranch branch) async {
    final personnelScope = BranchPersonnelScope(branch.id);
    final manager = ref.read(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );

    if (manager == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum bilgisi bulunamadı.')),
      );
      return;
    }

    final result = await showModalBottomSheet<_CreatePersonnelResult>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => _CreatePersonnelSheet(
        branch: branch,
        assignableRoles: _assignableRoles,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final snackMessage = '${result.displayName} eklendi.\nGiriş e-postası: '
        '${result.email} • Sicil: ${result.employeeCode}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(snackMessage)),
    );
    await _refreshPersonnel(personnelScope);
  }

  Future<void> _executeWithLoading(Future<void> Function() action) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BlockingLoader(),
    );

    Object? error;
    StackTrace? stackTrace;
    try {
      await action();
    } catch (err, st) {
      error = err;
      stackTrace = st;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (error != null) {
      final capturedError = error;
      final capturedStackTrace = stackTrace;
      if (capturedStackTrace != null) {
        Error.throwWithStackTrace(capturedError, capturedStackTrace);
      } else {
        throw capturedError;
      }
    }
  }

  Widget _buildRequestsTab({
    required BuildContext context,
    required List<ManagedBranch> branches,
    required ManagedBranch? activeBranch,
  }) {
    if (branches.isEmpty) {
      return _buildInfoState(
        context,
        title: 'Şube bulunamadı',
        description:
            'Talepleri listelemek için en az bir şubeye atanmış olmanız gerekir.',
        actionLabel: 'Şubeleri yenile',
        onAction: () => ref.invalidate(regionManagerBranchesProvider),
      );
    }

    final branchIds = <String>[];
    if (activeBranch != null) {
      branchIds.add(activeBranch.id);
    } else {
      branchIds.addAll(branches.map((b) => b.id));
    }

    if (branchIds.isEmpty) {
      return _NoBranchSelectedCard(
        onSelect: () => _openBranchSelector(branches),
      );
    }

    branchIds.sort();
    final filter =
        BranchRequestsFilter(branchIds: List<String>.unmodifiable(branchIds));
    final branchNameLookup = <String, String>{
      for (final branch in branches) branch.id: branch.name,
    };

    final requestsAsync = ref.watch(branchRequestsProvider(filter));

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildInfoState(
        context,
        title: 'Talepler yüklenemedi',
        description: '$error',
        actionLabel: 'Tekrar dene',
        onAction: () => ref.invalidate(branchRequestsProvider(filter)),
      ),
      data: (requests) {
        final grouped = _groupRequestsByCategory(requests);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(branchRequestsProvider(filter));
            await ref.read(branchRequestsProvider(filter).future);
          },
          child: requests.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _EmptyRequestsCard(
                      scopeLabel: activeBranch?.name ?? 'Tüm şubeleriniz',
                    ),
                  ],
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _RequestCategoryGroupCard(
                            group: grouped[index],
                            branchNames: branchNameLookup,
                            onRequestTap: (request) =>
                                _openManagerRequestDetails(
                              request: request,
                              branchNames: branchNameLookup,
                              filter: filter,
                            ),
                          ),
                          childCount: grouped.length,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _openManagerRequestDetails({
    required BranchRequest request,
    required Map<String, String> branchNames,
    required BranchRequestsFilter filter,
  }) async {
    final branchName = branchNames[request.branchId] ?? 'Bilinmeyen şube';
    final result = await showModalBottomSheet<_ManagerRequestActionResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      enableDrag: true,
      builder: (context) => _ManagerRequestDetailsSheet(
        request: request,
        branchName: branchName,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    switch (result) {
      case _ManagerRequestActionResult.approved:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talep onaylandı.')),
        );
        break;
      case _ManagerRequestActionResult.rejected:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talep reddedildi.')),
        );
        break;
      case _ManagerRequestActionResult.feedbackSent:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesaj talep sahibine iletildi.')),
        );
        break;
    }

    ref.invalidate(branchRequestsProvider(filter));
  }

  List<_RequestCategoryGroup> _groupRequestsByCategory(
      List<BranchRequest> requests) {
    final buckets = <RequestCategory, List<BranchRequest>>{};
    for (final request in requests) {
      buckets
          .putIfAbsent(request.category, () => <BranchRequest>[])
          .add(request);
    }

    final groups = <_RequestCategoryGroup>[];
    for (final theme in RequestCategoryThemes.values) {
      final items = buckets[theme.category];
      if (items == null || items.isEmpty) {
        continue;
      }
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      groups.add(_RequestCategoryGroup(theme: theme, requests: items));
    }
    return groups;
  }

  Widget _buildTasksTab({
    required BuildContext context,
    required List<ManagedBranch> branches,
    required ManagedBranch? activeBranch,
  }) {
    if (branches.isEmpty) {
      return _buildInfoState(
        context,
        title: 'Şube bulunamadı',
        description:
            'Görevleri yönetebilmek için en az bir şube atanmış olmalı.',
        actionLabel: 'Şubeleri yenile',
        onAction: () => ref.invalidate(regionManagerBranchesProvider),
      );
    }

    final scope =
        _branchTaskScope(branches: branches, activeBranch: activeBranch);

    if (scope.branchIds.isEmpty) {
      return _NoBranchSelectedCard(
        onSelect: () => _openBranchSelector(branches),
      );
    }

    final branchNameLookup = <String, String>{
      for (final branch in branches) branch.id: branch.name,
    };

    final tasksAsync = ref.watch(regionBranchTaskTreeProvider(scope));
    final todosAsync = ref.watch(regionManagerTodoTreeProvider);

    return Column(
      children: [
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: TabBar(
            controller: _tasksTabController,
            tabs: const [
              Tab(text: 'Görevler'),
              Tab(text: 'To-Do List'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tasksTabController,
            children: [
              _buildBranchTaskTreeView(
                context: context,
                tasksAsync: tasksAsync,
                branchNames: branchNameLookup,
                scope: scope,
              ),
              _buildTodoTreeView(
                context: context,
                todosAsync: todosAsync,
              ),
            ],
          ),
        ),
      ],
    );
  }

  BranchTaskScope _branchTaskScope({
    required List<ManagedBranch> branches,
    required ManagedBranch? activeBranch,
  }) {
    if (activeBranch != null) {
      return BranchTaskScope([activeBranch.id]);
    }
    if (branches.isEmpty) {
      return BranchTaskScope(const <String>[]);
    }
    return BranchTaskScope(branches.map((branch) => branch.id));
  }

  UserModel? _currentManager() {
    final authState = ref.read(authProvider);
    return authState.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildBranchTaskTreeView({
    required BuildContext context,
    required AsyncValue<List<BranchTaskNode>> tasksAsync,
    required Map<String, String> branchNames,
    required BranchTaskScope scope,
  }) {
    return tasksAsync.when(
      data: (nodes) {
        if (nodes.isEmpty) {
          return const _EmptyPlaceholder(
            icon: Icons.fact_check_outlined,
            title: 'Görev bulunmuyor',
            message: 'Bu kapsam için henüz görev eklenmedi.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            final refreshFuture =
                ref.refresh(regionBranchTaskTreeProvider(scope).future);
            await refreshFuture;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: nodes.length,
            itemBuilder: (context, index) {
              final node = nodes[index];
              return _buildBranchTaskNodeWidget(
                context: context,
                node: node,
                branchNames: branchNames,
                scope: scope,
                depth: 0,
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _AsyncErrorState(
        message: 'Görevler yüklenemedi: $error',
        onRetry: () => ref.invalidate(regionBranchTaskTreeProvider(scope)),
      ),
    );
  }

  Widget _buildTodoTreeView({
    required BuildContext context,
    required AsyncValue<List<ManagerTodoNode>> todosAsync,
  }) {
    return todosAsync.when(
      data: (nodes) {
        if (nodes.isEmpty) {
          return const _EmptyPlaceholder(
            icon: Icons.checklist_rtl,
            title: 'To-Do listesi boş',
            message: 'Yeni yapılacaklar eklemek için + butonunu kullanın.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            final refreshFuture =
                ref.refresh(regionManagerTodoTreeProvider.future);
            await refreshFuture;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: nodes.length,
            itemBuilder: (context, index) {
              final node = nodes[index];
              return _buildTodoNodeWidget(
                context: context,
                node: node,
                depth: 0,
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _AsyncErrorState(
        message: 'To-Do listesi yüklenemedi: $error',
        onRetry: () => ref.invalidate(regionManagerTodoTreeProvider),
      ),
    );
  }

  Widget _buildTodoNodeWidget({
    required BuildContext context,
    required ManagerTodoNode node,
    required int depth,
  }) {
    final theme = Theme.of(context);
    final isCompleted = node.record.status == ManagerTodoStatus.completed;
    final backgroundColor = depth == 0
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerHighest;

    return Container(
      margin: EdgeInsets.only(
        left: depth == 0 ? 0 : 16.0,
        bottom: 12,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isCompleted,
                onChanged: (value) => _updateTodoStatusRemote(
                  todoId: node.record.id,
                  status: value == true
                      ? ManagerTodoStatus.completed
                      : ManagerTodoStatus.pending,
                ),
                activeColor: _todoStatusColor(node.record.status),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  node.record.title,
                  style: (depth == 0
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.bodyLarge)
                      ?.copyWith(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sil',
                onPressed: () => _confirmDeleteTodo(node: node),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (node.record.description != null &&
              node.record.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              node.record.description!,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Oluşturma: ${_formatDateTime(node.record.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          if (node.record.updatedAt != node.record.createdAt)
            Text(
              'Son güncelleme: ${_formatDateTime(node.record.updatedAt)}',
              style: theme.textTheme.bodySmall,
            ),
          if (node.children.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: node.children
                  .map(
                    (child) => _buildTodoNodeWidget(
                      context: context,
                      node: child,
                      depth: depth + 1,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBranchTaskNodeWidget({
    required BuildContext context,
    required BranchTaskNode node,
    required Map<String, String> branchNames,
    required BranchTaskScope scope,
    required int depth,
  }) {
    final theme = Theme.of(context);
    final branchLabel = branchNames[node.record.branchId] ?? '—';
    final statusColor = _taskStatusColor(node.record.status);
    final isCompleted = node.record.status == BranchTaskStatus.completed;
    final hasChildren = node.children.isNotEmpty;
    final isExpanded =
        hasChildren && _expandedBranchTaskIds.contains(node.record.id);
    final backgroundColor = _branchTaskBackgroundColor(
      theme: theme,
      depth: depth,
      isCompleted: isCompleted,
    );
    final borderColor = _branchTaskBorderColor(
      theme: theme,
      depth: depth,
      isCompleted: isCompleted,
    );
    final progress = depth == 0 ? _branchTaskProgress(node) : null;
    final progressPercent =
        progress != null ? (progress * 100).clamp(0, 100).round() : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: EdgeInsets.only(
        left: depth == 0 ? 0 : 16.0,
        bottom: 12,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: depth == 0 ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: InkWell(
                            onTap: hasChildren
                                ? () => _toggleBranchTaskExpansion(node)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasChildren)
                                    AnimatedRotation(
                                      turns: isExpanded ? 0.25 : 0,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: const Icon(Icons.chevron_right,
                                          size: 20),
                                    )
                                  else
                                    const SizedBox(width: 20),
                                  if (hasChildren) const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      node.record.title,
                                      style: depth == 0
                                          ? theme.textTheme.titleMedium
                                              ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            )
                                          : theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        PopupMenuButton<BranchTaskStatus>(
                          tooltip: 'Durumu değiştir',
                          onSelected: (status) => _updateBranchTaskStatusRemote(
                            taskId: node.record.id,
                            status: status,
                            scope: scope,
                          ),
                          itemBuilder: (context) => BranchTaskStatus.values
                              .map(
                                (status) => PopupMenuItem<BranchTaskStatus>(
                                  value: status,
                                  child: Text(_taskStatusLabel(status)),
                                ),
                              )
                              .toList(),
                          child: Chip(
                            label: Text(_taskStatusLabel(node.record.status)),
                            backgroundColor:
                                statusColor.withValues(alpha: 0.12),
                            labelStyle: theme.textTheme.labelMedium
                                ?.copyWith(color: statusColor),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Görevi düzenle',
                          onPressed: () => _showEditBranchTaskSheet(
                            node: node,
                            scope: scope,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Görevi sil',
                          onPressed: () => _confirmDeleteBranchTask(
                            node: node,
                            scope: scope,
                          ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    if (depth == 0 && progressPercent != null) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (progress ?? 0).clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '%$progressPercent tamamlandı',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (node.record.description != null &&
              node.record.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              node.record.description!,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 6),
          if (depth == 0)
            Text(
              'Şube: $branchLabel',
              style: theme.textTheme.bodySmall,
            ),
          Text(
            'Oluşturma: ${_formatDateTime(node.record.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          if (node.record.updatedAt != node.record.createdAt)
            Text(
              'Son güncelleme: ${_formatDateTime(node.record.updatedAt)}',
              style: theme.textTheme.bodySmall,
            ),
          if (hasChildren && isExpanded) ...[
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: node.children
                  .map(
                    (child) => _buildBranchTaskNodeWidget(
                      context: context,
                      node: child,
                      branchNames: branchNames,
                      scope: scope,
                      depth: depth + 1,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateBranchTaskStatusRemote({
    required String taskId,
    required BranchTaskStatus status,
    required BranchTaskScope scope,
  }) async {
    final repository = ref.read(regionManagerTaskRepositoryProvider);
    try {
      await repository.updateBranchTaskStatus(taskId: taskId, status: status);
      final refreshFuture =
          ref.refresh(regionBranchTaskTreeProvider(scope).future);
      await refreshFuture;
    } catch (error) {
      _showSnack('Görev durumu güncellenemedi: $error');
    }
  }

  Future<void> _confirmDeleteBranchTask({
    required BranchTaskNode node,
    required BranchTaskScope scope,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Görev silinsin mi?'),
        content: const Text(
          'Bu görev ve varsa alt görevleri kalıcı olarak silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final repository = ref.read(regionManagerTaskRepositoryProvider);
    try {
      await repository.deleteBranchTaskTree(taskId: node.record.id);
      final refreshFuture =
          ref.refresh(regionBranchTaskTreeProvider(scope).future);
      await refreshFuture;
      _showSnack('Görev silindi.');
    } catch (error) {
      _showSnack('Görev silinemedi: $error');
    }
  }

  Future<void> _showEditBranchTaskSheet({
    required BranchTaskNode node,
    required BranchTaskScope scope,
  }) async {
    final result = await showModalBottomSheet<_BranchTaskEditRequest>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _BranchTaskEditSheet(
        initialTitle: node.record.title,
        initialDescription: node.record.description,
      ),
    );

    if (result == null) {
      return;
    }

    final newTitle = result.title.trim();
    final trimmedNewDescription = result.description?.trim();
    final normalizedDescription =
        trimmedNewDescription == null || trimmedNewDescription.isEmpty
            ? null
            : trimmedNewDescription;

    final previousDescription = node.record.description == null ||
            node.record.description!.trim().isEmpty
        ? null
        : node.record.description!.trim();

    final hasTitleChanged = newTitle != node.record.title;
    final hasDescriptionChanged = normalizedDescription != previousDescription;

    if (!hasTitleChanged && !hasDescriptionChanged) {
      _showSnack('Değişiklik yapılmadı.');
      return;
    }

    final repository = ref.read(regionManagerTaskRepositoryProvider);

    try {
      await repository.updateBranchTask(
        taskId: node.record.id,
        title: hasTitleChanged ? newTitle : null,
        description: normalizedDescription,
        setDescription: hasDescriptionChanged,
      );

      final refreshFuture =
          ref.refresh(regionBranchTaskTreeProvider(scope).future);
      await refreshFuture;
      ref.invalidate(
        regionBranchTaskTreeProvider(
          BranchTaskScope([node.record.branchId]),
        ),
      );

      _showSnack('Görev güncellendi.');
    } catch (error) {
      _showSnack('Görev güncellenemedi: $error');
    }
  }

  Future<void> _showCreateBranchTaskSheet({
    required List<ManagedBranch> branches,
    required ManagedBranch? activeBranch,
  }) async {
    final manager = _currentManager();
    if (manager == null) {
      _showSnack('Oturum bilgisi doğrulanamadı.');
      return;
    }
    if (branches.isEmpty) {
      _showSnack('Önce en az bir şube seçmelisiniz.');
      return;
    }

    final defaultBranchId = activeBranch?.id ?? branches.first.id;

    final request = await showModalBottomSheet<_NewBranchTaskRequest>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _BranchTaskCreationSheet(
        branches: branches,
        initialBranchId: defaultBranchId,
      ),
    );

    if (request == null) {
      return;
    }

    final repository = ref.read(regionManagerTaskRepositoryProvider);
    try {
      final createdBranchIds = <String>{};

      for (final branchId in request.branchIds) {
        final mainRecord = await repository.createBranchTask(
          tenantId: manager.tenantId,
          managerId: manager.id,
          branchId: branchId,
          title: request.title,
          description: request.description,
          priority: request.priority,
          dueDate: request.dueDate,
        );
        await _createBranchTaskSubtree(
          repository: repository,
          manager: manager,
          branchId: branchId,
          parentId: mainRecord.id,
          nodes: request.children,
        );
        createdBranchIds.add(branchId);
      }

      final currentScope = _branchTaskScope(
        branches: branches,
        activeBranch: activeBranch,
      );
      final refreshFuture = ref.refresh(
        regionBranchTaskTreeProvider(currentScope).future,
      );
      await refreshFuture;
      for (final branchId in createdBranchIds) {
        ref.invalidate(
          regionBranchTaskTreeProvider(
            BranchTaskScope([branchId]),
          ),
        );
      }
      _showSnack('Görev planı oluşturuldu.');
    } catch (error) {
      _showSnack('Görev oluşturulamadı: $error');
    }
  }

  Future<void> _createBranchTaskSubtree({
    required RegionManagerTaskRepository repository,
    required UserModel manager,
    required String branchId,
    required String parentId,
    required List<_TaskInputResult> nodes,
  }) async {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final record = await repository.createBranchTask(
        tenantId: manager.tenantId,
        managerId: manager.id,
        branchId: branchId,
        title: node.title,
        parentId: parentId,
        sortOrder: i,
      );

      if (node.children.isNotEmpty) {
        await _createBranchTaskSubtree(
          repository: repository,
          manager: manager,
          branchId: branchId,
          parentId: record.id,
          nodes: node.children,
        );
      }
    }
  }

  Future<void> _updateTodoStatusRemote({
    required String todoId,
    required ManagerTodoStatus status,
  }) async {
    final repository = ref.read(regionManagerTaskRepositoryProvider);
    try {
      await repository.updateManagerTodoStatus(
        todoId: todoId,
        status: status,
      );
      final refreshFuture = ref.refresh(regionManagerTodoTreeProvider.future);
      await refreshFuture;
    } catch (error) {
      _showSnack('To-Do durumu güncellenemedi: $error');
    }
  }

  Future<void> _confirmDeleteTodo({
    required ManagerTodoNode node,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Silmek istiyor musunuz?'),
        content: const Text(
            'Bu to-do ve varsa alt maddeleri kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final repository = ref.read(regionManagerTaskRepositoryProvider);
    try {
      await repository.deleteManagerTodoTree(todoId: node.record.id);
      final refreshFuture = ref.refresh(regionManagerTodoTreeProvider.future);
      await refreshFuture;
      _showSnack('To-Do silindi.');
    } catch (error) {
      _showSnack('To-Do silinemedi: $error');
    }
  }

  Future<void> _showCreateTodoSheet() async {
    final manager = _currentManager();
    if (manager == null) {
      _showSnack('Oturum bilgisi doğrulanamadı.');
      return;
    }

    final request = await showModalBottomSheet<_NewTodoRequest>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => const _TodoCreationSheet(),
    );

    if (request == null) {
      return;
    }

    final repository = ref.read(regionManagerTaskRepositoryProvider);
    try {
      final root = await repository.createManagerTodo(
        tenantId: manager.tenantId,
        managerId: manager.id,
        title: request.title,
      );
      for (var i = 0; i < request.children.length; i++) {
        final child = request.children[i];
        await repository.createManagerTodo(
          tenantId: manager.tenantId,
          managerId: manager.id,
          title: child.title,
          parentId: root.id,
          sortOrder: i,
        );
      }
      final refreshedTodo = ref.refresh(regionManagerTodoTreeProvider.future);
      await refreshedTodo;
      _showSnack('To-Do listesi oluşturuldu.');
    } catch (error) {
      _showSnack('To-Do oluşturulamadı: $error');
    }
  }

  Widget _buildDashboardTab({
    required BuildContext context,
    required Duration? visitDuration,
    required String managerName,
    required ManagedBranch? activeBranch,
    required List<ManagedBranch> branches,
  }) {
    final hasActiveBranch = activeBranch != null;
    final content = <Widget>[];

    // Welcome header with date
    content.addAll([
      _WelcomeHeader(managerName: managerName),
      const SizedBox(height: 16),
    ]);

    // Quick actions row
    content.addAll([
      _QuickActionsRow(
        onTapRequests: () => setState(() {
          _primaryTabIndex = 1;
          _currentTabIndex = 1;
        }),
        onTapTasks: () => setState(() {
          _primaryTabIndex = 2;
          _currentTabIndex = 2;
        }),
        onTapTransfers: () => setState(() {
          _primaryTabIndex = 3;
          _currentTabIndex = 3;
        }),
        onTapPersonnel: _openPersonnelTab,
      ),
      const SizedBox(height: 16),
    ]);

    // Branch overview stats
    if (branches.isNotEmpty) {
      content.addAll([
        _BranchOverviewCard(
          branches: branches,
          activeBranch: activeBranch,
          onSelectBranch: () => _openBranchSelector(branches),
        ),
        const SizedBox(height: 16),
      ]);
    }

    if (hasActiveBranch) {
      content.addAll([
        _VisitOverviewCard(
          branchName: activeBranch.name,
          managerName: managerName,
          scheduledWindow: '09:00 - 12:00',
          isCheckedIn: _isCheckedIn,
          visitDuration: visitDuration,
          onToggle: _handleCheckInOut,
        ),
        const SizedBox(height: 16),
        _buildScoreSection(context),
        const SizedBox(height: 16),
        _buildChecklistSection(),
        const SizedBox(height: 16),
        _buildRequestsSection(
          context: context,
          activeBranch: activeBranch,
          branches: branches,
        ),
        const SizedBox(height: 16),
        _buildVisitLogSection(),
        const SizedBox(height: 16),
      ]);
    } else {
      content.addAll([
        _NoBranchSelectedCard(
          onSelect:
              branches.isEmpty ? null : () => _openBranchSelector(branches),
        ),
        const SizedBox(height: 16),
      ]);
    }

    content.add(_buildTodoOverviewSection());

    // Add bottom padding for FAB
    content.add(const SizedBox(height: 80));

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate(content),
          ),
        ),
      ],
    );
  }

  void _handleBackPressed() {
    _showExitConfirmation();
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PersonalInfoPage()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  void _openStoreScoring() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RmFormsHubPage()),
    );
  }

  void _openPersonnelTab() {
    if (_currentTabIndex == 4) {
      return;
    }
    setState(() => _currentTabIndex = 4);
  }

  void _openAnnouncements() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _NotificationCenterSheet(),
    );
  }

  Future<void> _openBranchSelector(List<ManagedBranch> branches) async {
    if (branches.isEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (sheetContext) => _BranchSelectionSheet(
        branches: branches,
        activeBranchId: _activeBranchId,
      ),
    );
    if (selected == null) {
      return;
    }
    if (selected.isEmpty) {
      _setActiveBranch(null);
    } else {
      _setActiveBranch(selected);
    }
  }

  Future<void> _showExitConfirmation() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: const Text('Oturum kapatılıp giriş ekranına dönülecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Çıkış'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
    }
  }

  Widget _buildScoreSection(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _ScoreCard(
            label: 'Mağaza Skoru',
            subtitle: 'Kontrol listesine göre otomatik puan',
            value: 82,
            icon: Icons.store_mall_directory,
            color: Colors.indigo,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _ScoreCard(
            label: 'Yönetici Skoru',
            subtitle: 'Bölge müdürü geri bildirimi',
            value: 74,
            icon: Icons.badge_outlined,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'Kontrol Listesi',
              description: 'Mağaza denetim maddeleri ve durumları',
            ),
            const SizedBox(height: 12),
            ..._checklist.map(
              (item) => CheckboxListTile(
                value: item.isDone,
                contentPadding: EdgeInsets.zero,
                title: Text(item.title),
                subtitle: Text(item.description),
                onChanged: (value) => _toggleChecklist(item.id, value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsSection({
    required BuildContext context,
    required ManagedBranch? activeBranch,
    required List<ManagedBranch> branches,
  }) {
    final branchIds = <String>[];
    if (activeBranch != null) {
      branchIds.add(activeBranch.id);
    } else {
      branchIds.addAll(branches.map((branch) => branch.id));
    }

    if (branchIds.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'Eksik Talepler',
                description: 'Gösterim için önce bir şube seçin.',
              ),
              SizedBox(height: 12),
              Text('Şube seçimi yapılmadan talep listesi görüntülenemez.'),
            ],
          ),
        ),
      );
    }

    final scopeLabel = activeBranch?.name ?? 'Tüm şubeleriniz';
    final filter = BranchRequestsFilter(
      branchIds: List<String>.unmodifiable(branchIds),
    );
    final provider = branchRequestsProvider(filter);
    final branchNameLookup = <String, String>{
      for (final branch in branches) branch.id: branch.name,
    };

    final requestsAsync = ref.watch(provider);

    return requestsAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'Eksik Talepler',
                description: 'Son talepler yükleniyor...',
              ),
              SizedBox(height: 16),
              Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Eksik Talepler',
                description: 'Son talepler alınamadı.',
              ),
              const SizedBox(height: 12),
              Text('$error'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(provider),
                  child: const Text('Tekrar dene'),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (requests) {
        final highlights = requests.take(3).toList(growable: false);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Eksik Talepler',
                  description: '$scopeLabel için son talepler',
                ),
                const SizedBox(height: 12),
                if (highlights.isEmpty)
                  const Text('Bu kapsamda bekleyen talep bulunmuyor.')
                else
                  ...highlights.map(
                    (request) {
                      final branchName = branchNameLookup[request.branchId] ??
                          'Bilinmeyen şube';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _statusIcon(request.status),
                              color: _statusColor(request.status),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$branchName • ${request.category.label}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _requestTimingLabel(request),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _RequestStatusChip(status: request.status),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisitLogSection() {
    final visitDuration = _currentVisitDuration();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'Ziyaret Kaydı',
              description: 'Giriş/çıkış ve sistem tarafından takip edilen süre',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _VisitLogTile(
                    label: 'Giriş',
                    time: _checkInTime,
                    icon: Icons.login,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VisitLogTile(
                    label: 'Çıkış',
                    time: _checkOutTime,
                    icon: Icons.logout,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.timer, size: 18),
                  label: Text(
                    visitDuration == null
                        ? 'Süre takip edilmiyor'
                        : 'Toplam süre: ${_formatDuration(visitDuration)}',
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _handleCheckInOut,
                  icon:
                      Icon(_isCheckedIn ? Icons.stop_circle : Icons.play_arrow),
                  label: Text(_isCheckedIn ? 'Çıkış Yap' : 'Giriş Yap'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoOverviewSection() {
    final todosAsync = ref.watch(regionManagerTodoTreeProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'To-Do Özeti',
              description: 'Günlük planlanan hatırlatmaların hızlı görünümü',
            ),
            const SizedBox(height: 12),
            todosAsync.when(
              data: (nodes) {
                if (nodes.isEmpty) {
                  return Text(
                    'Henüz listede kayıt yok. To-Do sekmesinden yeni maddeler ekleyin.',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                final preview = nodes.take(3).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...preview.map(
                      (node) {
                        final total = _todoTotalCount(node);
                        final completed = _todoCompletedCount(node);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                node.record.status ==
                                        ManagerTodoStatus.completed
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: _todoStatusColor(node.record.status),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      node.record.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    Text(
                                      '$completed / $total tamamlandı',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (nodes.length > preview.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${nodes.length - preview.length} ek kayıt daha var...',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _primaryTabIndex = 2;
                            _currentTabIndex = 2;
                            _tasksTabController.index = 1;
                          });
                        },
                        child: const Text('To-Do sekmesine git'),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, _) => Text(
                'To-Do listesi alınamadı: $error',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _todoTotalCount(ManagerTodoNode node) {
    var total = 1;
    for (final child in node.children) {
      total += _todoTotalCount(child);
    }
    return total;
  }

  int _todoCompletedCount(ManagerTodoNode node) {
    var completed = node.record.status == ManagerTodoStatus.completed ? 1 : 0;
    for (final child in node.children) {
      completed += _todoCompletedCount(child);
    }
    return completed;
  }

  double _branchTaskProgress(BranchTaskNode node) {
    final total = _branchTaskDescendantCount(node);
    if (total == 0) {
      return node.record.status == BranchTaskStatus.completed ? 1 : 0;
    }
    final completed = _branchTaskCompletedDescendantCount(node);
    return completed / total;
  }

  int _branchTaskDescendantCount(BranchTaskNode node) {
    var total = node.children.length;
    for (final child in node.children) {
      total += _branchTaskDescendantCount(child);
    }
    return total;
  }

  int _branchTaskCompletedDescendantCount(BranchTaskNode node) {
    var completed = 0;
    for (final child in node.children) {
      if (child.record.status == BranchTaskStatus.completed) {
        completed += 1;
      }
      completed += _branchTaskCompletedDescendantCount(child);
    }
    return completed;
  }

  void _toggleBranchTaskExpansion(BranchTaskNode node) {
    if (node.children.isEmpty) {
      return;
    }
    setState(() {
      if (_expandedBranchTaskIds.contains(node.record.id)) {
        _expandedBranchTaskIds.remove(node.record.id);
        _collapseBranchTaskDescendants(node);
      } else {
        _expandedBranchTaskIds.add(node.record.id);
      }
    });
  }

  void _collapseBranchTaskDescendants(BranchTaskNode node) {
    for (final child in node.children) {
      _expandedBranchTaskIds.remove(child.record.id);
      _collapseBranchTaskDescendants(child);
    }
  }

  Color _branchTaskBackgroundColor({
    required ThemeData theme,
    required int depth,
    required bool isCompleted,
  }) {
    if (isCompleted) {
      return theme.colorScheme.secondaryContainer;
    }
    final baseSurface = theme.colorScheme.surface;
    if (depth == 0) {
      return Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.04),
        baseSurface,
      );
    }
    if (depth == 1) {
      return Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.08),
        baseSurface,
      );
    }
    return Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: 0.12),
      baseSurface,
    );
  }

  Color _branchTaskBorderColor({
    required ThemeData theme,
    required int depth,
    required bool isCompleted,
  }) {
    if (isCompleted) {
      return theme.colorScheme.secondary;
    }
    if (depth == 0) {
      return theme.colorScheme.primary.withValues(alpha: 0.45);
    }
    return theme.colorScheme.primary.withValues(alpha: 0.25);
  }

  static IconData _statusIcon(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Icons.hourglass_bottom;
      case RequestStatus.inProgress:
        return Icons.sync;
      case RequestStatus.resolved:
        return Icons.check_circle;
      case RequestStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  static Color _statusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Colors.amber;
      case RequestStatus.inProgress:
        return Colors.blue;
      case RequestStatus.resolved:
        return Colors.green;
      case RequestStatus.cancelled:
        return Colors.grey;
    }
  }

  String _requestTimingLabel(BranchRequest request) {
    if (request.status == RequestStatus.resolved &&
        request.resolvedAt != null) {
      return 'Tamamlandı: ${_formatRelativeTime(request.resolvedAt!)}';
    }
    if (request.status == RequestStatus.cancelled &&
        request.resolvedAt != null) {
      return 'İptal edildi: ${_formatRelativeTime(request.resolvedAt!)}';
    }
    return 'Oluşturuldu: ${_formatRelativeTime(request.createdAt)}';
  }

  String _formatRelativeTime(DateTime reference) {
    final now = DateTime.now();
    final diff = now.difference(reference);
    if (diff.inMinutes < 1) {
      return 'Az önce';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk önce';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    }
    final local = reference.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} saat';
  }

  Widget _buildInfoState(
    BuildContext context, {
    required String title,
    required String description,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _setActiveBranch(String? branchId) {
    if (_activeBranchId == branchId) {
      return;
    }
    setState(() {
      _activeBranchId = branchId;
      _isCheckedIn = false;
      _checkInTime = null;
      _checkOutTime = null;
    });
  }

  void _ensureActiveBranchSelection(List<ManagedBranch> branches) {
    if (branches.isEmpty) {
      if (_activeBranchId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _activeBranchId = null);
        });
      }
      return;
    }

    final exists = branches.any((branch) => branch.id == _activeBranchId);
    if (!exists && _activeBranchId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _activeBranchId = null);
      });
    }
  }

  ManagedBranch? _resolveActiveBranch(List<ManagedBranch> branches) {
    if (_activeBranchId == null || branches.isEmpty) {
      return null;
    }
    for (final branch in branches) {
      if (branch.id == _activeBranchId) {
        return branch;
      }
    }
    return null;
  }
}

class _TransferScopeCard extends StatelessWidget {
  final String label;
  final String description;
  final VoidCallback? onChangeTap;

  const _TransferScopeCard({
    required this.label,
    required this.description,
    this.onChangeTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.inventory_2, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (onChangeTap != null)
                  TextButton(
                    onPressed: onChangeTap,
                    child: const Text('Şube seç'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferNoticesCard extends StatelessWidget {
  final List<DepotNotice> notices;
  final Map<String, String> branchNames;

  const _TransferNoticesCard({
    required this.notices,
    required this.branchNames,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'Şube İlanları',
              description: 'Depolar arası sevk için açılan ilanlar',
            ),
            const SizedBox(height: 12),
            if (notices.isEmpty)
              const _TransferEmptyState(
                message: 'Şubeleriniz için aktif ilan bulunmuyor.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: notices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notice = notices[index];
                  final statusColor = _noticeStatusColor(notice.status);
                  final branchLabel =
                      branchNames[notice.branchId] ?? notice.branchName ?? '—';
                  final remaining =
                      _formatQuantityText(notice.remainingQuantity);
                  final total = _formatQuantityText(notice.quantity);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _noticeTypeColor(notice.type)
                            .withValues(alpha: 0.12),
                        child: Icon(
                          _noticeTypeIcon(notice.type),
                          color: _noticeTypeColor(notice.type),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notice.productName,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$branchLabel • ${_noticeTypeLabel(notice.type)}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kalan: $remaining ${notice.unit} / Toplam: $total ${notice.unit}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Oluşturma: ${_formatDateTime(notice.createdAt)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Chip(
                        label: Text(_noticeStatusLabel(notice.status)),
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        side: BorderSide(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                        labelStyle: theme.textTheme.labelMedium
                            ?.copyWith(color: statusColor),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TransferOffersCard extends StatelessWidget {
  final List<_OfferSummary> offers;
  final Map<String, String> branchNames;

  const _TransferOffersCard({
    required this.offers,
    required this.branchNames,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'Şube Talepleri',
              description: 'Şubelerinizin diğer ilanlara gönderdiği talepler',
            ),
            const SizedBox(height: 12),
            if (offers.isEmpty)
              const _TransferEmptyState(
                message: 'Şubeleriniz için kayıtlı talep bulunmuyor.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: offers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = offers[index];
                  final statusColor = _offerStatusColor(item.offer.status);
                  final branchLabel = branchNames[item.offer.branchId] ??
                      item.offer.branchName ??
                      '—';
                  final noticeOwner = branchNames[item.notice.branchId] ??
                      item.notice.branchName ??
                      '—';
                  final quantity = _formatQuantityText(item.offer.quantity);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.compare_arrows,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.notice.productName} • $quantity ${item.notice.unit}',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Talep eden şube: $branchLabel',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'İlan sahibi: $noticeOwner',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (item.offer.message != null &&
                                item.offer.message!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Not: ${item.offer.message}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Gönderim: ${_formatDateTime(item.offer.createdAt)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Chip(
                        label: Text(_offerStatusLabel(item.offer.status)),
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        side: BorderSide(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                        labelStyle: theme.textTheme.labelMedium
                            ?.copyWith(color: statusColor),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TransferEmptyState extends StatelessWidget {
  final String message;

  const _TransferEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AsyncErrorState extends StatelessWidget {
  const _AsyncErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferSummary {
  final NoticeOffer offer;
  final DepotNotice notice;

  const _OfferSummary({required this.offer, required this.notice});
}

String _noticeStatusLabel(DepotNoticeStatus status) {
  switch (status) {
    case DepotNoticeStatus.open:
      return 'İlan aşaması';
    case DepotNoticeStatus.inTransfer:
      return 'Transferde';
    case DepotNoticeStatus.fulfilled:
      return 'Tamamlandı';
    case DepotNoticeStatus.cancelled:
      return 'İptal';
  }
}

Color _noticeStatusColor(DepotNoticeStatus status) {
  switch (status) {
    case DepotNoticeStatus.open:
      return Colors.indigo;
    case DepotNoticeStatus.inTransfer:
      return Colors.orange;
    case DepotNoticeStatus.fulfilled:
      return Colors.green;
    case DepotNoticeStatus.cancelled:
      return Colors.red;
  }
}

String _noticeTypeLabel(DepotNoticeType type) {
  switch (type) {
    case DepotNoticeType.surplus:
      return 'Fazla ürün';
    case DepotNoticeType.shortage:
      return 'Eksik ürün';
  }
}

Color _noticeTypeColor(DepotNoticeType type) {
  switch (type) {
    case DepotNoticeType.surplus:
      return Colors.green;
    case DepotNoticeType.shortage:
      return Colors.red;
  }
}

IconData _noticeTypeIcon(DepotNoticeType type) {
  switch (type) {
    case DepotNoticeType.surplus:
      return Icons.north_east;
    case DepotNoticeType.shortage:
      return Icons.south_west;
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
      return 'Süresi doldu';
    case DepotOfferStatus.cancelled:
      return 'İptal edildi';
    case DepotOfferStatus.delivered:
      return 'Teslim edildi';
  }
}

Color _offerStatusColor(DepotOfferStatus status) {
  switch (status) {
    case DepotOfferStatus.pending:
      return Colors.amber;
    case DepotOfferStatus.accepted:
      return Colors.green;
    case DepotOfferStatus.rejected:
      return Colors.red;
    case DepotOfferStatus.expired:
      return Colors.grey;
    case DepotOfferStatus.cancelled:
      return Colors.blueGrey;
    case DepotOfferStatus.delivered:
      return Colors.teal;
  }
}

String _taskStatusLabel(BranchTaskStatus status) {
  switch (status) {
    case BranchTaskStatus.pending:
      return 'Bekliyor';
    case BranchTaskStatus.inProgress:
      return 'Devam ediyor';
    case BranchTaskStatus.completed:
      return 'Tamamlandı';
  }
}

Color _taskStatusColor(BranchTaskStatus status) {
  switch (status) {
    case BranchTaskStatus.pending:
      return Colors.amber;
    case BranchTaskStatus.inProgress:
      return Colors.indigo;
    case BranchTaskStatus.completed:
      return Colors.green;
  }
}

Color _todoStatusColor(ManagerTodoStatus status) {
  switch (status) {
    case ManagerTodoStatus.pending:
      return Colors.indigo;
    case ManagerTodoStatus.completed:
      return Colors.green;
  }
}

class _RequestCategoryGroup {
  const _RequestCategoryGroup({
    required this.theme,
    required this.requests,
  });

  final RequestCategoryThemeData theme;
  final List<BranchRequest> requests;
}

enum _ManagerRequestActionResult {
  approved,
  rejected,
  feedbackSent,
}

class _RequestCategoryGroupCard extends StatelessWidget {
  const _RequestCategoryGroupCard({
    required this.group,
    required this.branchNames,
    this.onRequestTap,
  });

  final _RequestCategoryGroup group;
  final Map<String, String> branchNames;
  final ValueChanged<BranchRequest>? onRequestTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: group.theme.color,
                  foregroundColor: Colors.white,
                  child: Icon(group.theme.icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.theme.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.theme.description,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text('${group.requests.length}'),
                  backgroundColor: group.theme.color.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: group.theme.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < group.requests.length; i++) ...[
              _RequestSummaryTile(
                request: group.requests[i],
                branchNames: branchNames,
                onTap: onRequestTap == null
                    ? null
                    : () => onRequestTap!(group.requests[i]),
              ),
              if (i < group.requests.length - 1)
                const Divider(height: 24, thickness: 0.7),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestSummaryTile extends StatelessWidget {
  const _RequestSummaryTile({
    required this.request,
    required this.branchNames,
    this.onTap,
  });

  final BranchRequest request;
  final Map<String, String> branchNames;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = <String>[];
    final branchName = branchNames[request.branchId] ?? 'Bilinmeyen şube';
    lines.add('$branchName • ${_formatDateTimeLabel(request.createdAt)}');

    if (request.targetDepartment != null &&
        request.targetDepartment!.isNotEmpty) {
      lines.add('Yönlendirilen birim: ${request.targetDepartment}');
    }

    if (request.category == RequestCategory.leave && request.payload != null) {
      final rangeLabel = _formatLeaveRangeFromPayload(request.payload!);
      if (rangeLabel != null) {
        lines.add('İzin Aralığı: $rangeLabel');
      }
    }

    if (request.description != null && request.description!.isNotEmpty) {
      lines.add(request.description!);
    }

    final subtitleWidget = lines.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map((line) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall,
                        ),
                      ))
                  .toList(),
            ),
          );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(request.title),
      subtitle: subtitleWidget,
      trailing: _RequestStatusChip(status: request.status),
      onTap: onTap,
    );
  }
}

class _CreatePersonnelResult {
  const _CreatePersonnelResult({
    required this.displayName,
    required this.email,
    required this.employeeCode,
  });

  final String displayName;
  final String email;
  final String employeeCode;
}

class _CreatePersonnelSheet extends ConsumerStatefulWidget {
  const _CreatePersonnelSheet({
    required this.branch,
    required this.assignableRoles,
  });

  final ManagedBranch branch;
  final List<_PersonnelRoleOption> assignableRoles;

  @override
  _CreatePersonnelSheetState createState() => _CreatePersonnelSheetState();
}

class _CreatePersonnelSheetState extends ConsumerState<_CreatePersonnelSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _employeeCodeController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _positionController;
  late final TextEditingController _passwordController;
  late String _selectedRole;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _employeeCodeController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _positionController = TextEditingController();
    _passwordController = TextEditingController();
    _selectedRole = widget.assignableRoles.first.value;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _employeeCodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _positionController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.branch.name} için personel ekle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Ad'),
                validator: (value) => _validateRequired(value, 'Ad gerekli'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Soyad'),
                validator: (value) => _validateRequired(value, 'Soyad gerekli'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _employeeCodeController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Personel Kodu',
                  helperText:
                      'Kullanıcı adı olarak da kullanılacak benzersiz kod',
                ),
                validator: (value) => _validateRequired(value, 'Kod gerekli'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: widget.assignableRoles
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.value,
                        child: Text(option.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _positionController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Pozisyon',
                  hintText: 'Örn: Kasiyer, Satış Danışmanı',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-posta (opsiyonel)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                textInputAction: TextInputAction.done,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Geçici Şifre',
                  helperText: 'En az 6 karakter olmalı',
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 6) {
                    return 'Şifre en az 6 karakter olmalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSubmitting ? 'Kaydediliyor' : 'Kaydet'),
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

  String? _validateRequired(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final trimmedEmployeeCode = _employeeCodeController.text.trim();
      final trimmedPassword = _passwordController.text.trim();
      final trimmedFirstName = _firstNameController.text.trim();
      final trimmedLastName = _lastNameController.text.trim();
      final trimmedEmail = _emailController.text.trim();
      final trimmedPhone = _phoneController.text.trim();
      final trimmedPosition = _positionController.text.trim();

      final creation =
          await ref.read(regionManagerStaffRepositoryProvider).createPersonnel(
                branchId: widget.branch.id,
                employeeCode: trimmedEmployeeCode,
                password: trimmedPassword,
                firstName: trimmedFirstName,
                lastName: trimmedLastName,
                role: _selectedRole,
                email: trimmedEmail.isEmpty ? null : trimmedEmail,
                phone: trimmedPhone.isEmpty ? null : trimmedPhone,
                position: trimmedPosition.isEmpty ? null : trimmedPosition,
              );

      if (!mounted) {
        return;
      }

      final displayParts = <String>[
        trimmedFirstName,
        trimmedLastName,
      ]..removeWhere((value) => value.isEmpty);

      final displayName =
          displayParts.isEmpty ? 'Yeni personel' : displayParts.join(' ');

      Navigator.of(context).pop(
        _CreatePersonnelResult(
          displayName: displayName,
          email: creation.email,
          employeeCode: trimmedEmployeeCode,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isSubmitting = false);
      final message =
          error is StateError ? error.message : 'Personel eklenemedi: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

class _ManagerRequestDetailsSheet extends ConsumerStatefulWidget {
  const _ManagerRequestDetailsSheet({
    required this.request,
    required this.branchName,
  });

  final BranchRequest request;
  final String branchName;

  @override
  ConsumerState<_ManagerRequestDetailsSheet> createState() =>
      _ManagerRequestDetailsSheetState();
}

enum _ManagerActionType { none, approve, reject, message }

class _ManagerRequestDetailsSheetState
    extends ConsumerState<_ManagerRequestDetailsSheet> {
  final TextEditingController _messageController = TextEditingController();
  final Map<String, Future<String?>> _attachmentUrlFutures =
      <String, Future<String?>>{};

  static const String _storageBucket = 'request-files';

  _ManagerActionType _processingAction = _ManagerActionType.none;

  bool get _isProcessing => _processingAction != _ManagerActionType.none;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  List<String> get _attachmentReferences {
    final attachments = widget.request.payload?['attachments'];
    if (attachments is List) {
      return attachments
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  List<Map<String, dynamic>> get _managerFeedbacks {
    final feedbacks = widget.request.payload?['manager_feedbacks'];
    if (feedbacks is List) {
      return feedbacks
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> _handleApprove() async {
    if (_isProcessing) {
      return;
    }
    final manager = ref.read(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );
    if (manager == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum bulunamadı. Tekrar giriş yapın.')),
      );
      return;
    }

    setState(() => _processingAction = _ManagerActionType.approve);

    try {
      final repo = ref.read(requestRepositoryProvider);
      await repo.updateStatus(
        requestId: widget.request.id,
        status: RequestStatus.resolved,
        resolvedBy: manager.id,
        resolvedAt: DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(_ManagerRequestActionResult.approved);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Talep onaylanamadı: ${error.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Talep onaylanamadı: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingAction = _ManagerActionType.none);
      }
    }
  }

  Future<void> _handleReject() async {
    if (_isProcessing) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Talebi reddet'),
        content: const Text(
          'Bu talebi reddetmek istediğinizden emin misiniz? Talep sahibi bilgilendirilecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    final manager = ref.read(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );
    if (manager == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum bulunamadı. Tekrar giriş yapın.')),
      );
      return;
    }

    setState(() => _processingAction = _ManagerActionType.reject);

    try {
      final repo = ref.read(requestRepositoryProvider);
      await repo.updateStatus(
        requestId: widget.request.id,
        status: RequestStatus.cancelled,
        resolvedBy: manager.id,
        resolvedAt: DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(_ManagerRequestActionResult.rejected);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Talep reddedilemedi: ${error.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Talep reddedilemedi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingAction = _ManagerActionType.none);
      }
    }
  }

  Future<void> _handleSendMessage() async {
    if (_isProcessing) {
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir mesaj yazın.')),
      );
      return;
    }

    final manager = ref.read(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );
    if (manager == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum bulunamadı. Tekrar giriş yapın.')),
      );
      return;
    }

    setState(() => _processingAction = _ManagerActionType.message);

    try {
      final repo = ref.read(requestRepositoryProvider);
      final payload = widget.request.payload == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(widget.request.payload!);

      final existingFeedbacks = (payload['manager_feedbacks'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList(growable: true) ??
          <Map<String, dynamic>>[];
      existingFeedbacks.add({
        'message': message,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
        'sent_by': manager.id,
        'sent_by_name': '${manager.name} ${manager.surname}'.trim(),
      });
      payload['manager_feedbacks'] = existingFeedbacks;

      await repo.updateRequest(
        requestId: widget.request.id,
        title: widget.request.title,
        description: widget.request.description,
        payload: payload,
        targetDepartment: widget.request.targetDepartment,
      );

      final statusToApply = widget.request.status == RequestStatus.resolved ||
              widget.request.status == RequestStatus.cancelled
          ? widget.request.status
          : RequestStatus.inProgress;

      await repo.updateStatus(
        requestId: widget.request.id,
        status: statusToApply,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(_ManagerRequestActionResult.feedbackSent);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: ${error.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingAction = _ManagerActionType.none);
      }
    }
  }

  Future<String?> _getAttachmentUrl(String reference) {
    return _attachmentUrlFutures.putIfAbsent(reference, () async {
      final storage = Supabase.instance.client.storage.from(_storageBucket);

      String? path;
      if (reference.startsWith('http')) {
        path = _extractStoragePath(reference);
        if (path == null) {
          return reference;
        }
      } else {
        path = reference;
      }

      try {
        return await storage.createSignedUrl(path, 60 * 60);
      } catch (_) {
        if (reference.startsWith('http')) {
          return reference;
        }
        return null;
      }
    });
  }

  String? _extractStoragePath(String reference) {
    try {
      final uri = Uri.parse(reference);
      if (!uri.pathSegments.contains(_storageBucket)) {
        return null;
      }
      final bucketIndex = uri.pathSegments.indexOf(_storageBucket);
      if (bucketIndex == -1 || bucketIndex + 1 >= uri.pathSegments.length) {
        return null;
      }
      final segments = uri.pathSegments.sublist(bucketIndex + 1);
      return segments.join('/');
    } catch (_) {
      return null;
    }
  }

  void _openImage(String url) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, _, __) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                color: Colors.white54),
                            SizedBox(height: 8),
                            Text(
                              'Görsel yüklenemedi',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    final formattedDate = _formatDate(local);
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$formattedDate $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;
    final categoryTheme = RequestCategoryThemes.of(request.category);
    final attachments = _attachmentReferences;
    final feedbacks = _managerFeedbacks;
    final payload = request.payload ?? const <String, dynamic>{};
    final malfunctionLabel = payload['malfunction_type_label'] as String? ??
        MalfunctionIssueTypeX.maybeFromValue(
                payload['malfunction_type'] as String?)
            ?.label;
    final malfunctionDescription =
        payload['malfunction_type_description'] as String?;
    final equipmentLabel = payload['equipment_type_label'] as String? ??
        EquipmentRequestTypeX.maybeFromValue(
                payload['equipment_type'] as String?)
            ?.label;
    final equipmentDescription =
        payload['equipment_type_description'] as String?;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: categoryTheme.color,
                      foregroundColor: Colors.white,
                      child: Icon(
                        categoryTheme.icon,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(widget.branchName),
                              ),
                              Chip(
                                backgroundColor:
                                    categoryTheme.color.withValues(alpha: 0.15),
                                label: Text(
                                  categoryTheme.title,
                                  style: TextStyle(
                                    color: categoryTheme.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _RequestStatusChip(status: request.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabelValue(
                  context,
                  'Oluşturma Zamanı',
                  _formatDateTime(request.createdAt),
                ),
                _buildLabelValue(
                  context,
                  'Son Güncelleme',
                  _formatDateTime(request.updatedAt),
                ),
                if (request.targetDepartment != null &&
                    request.targetDepartment!.isNotEmpty)
                  _buildLabelValue(
                    context,
                    'Yönlendirilen Birim',
                    request.targetDepartment!,
                  ),
                if (request.description != null &&
                    request.description!.isNotEmpty)
                  _buildLabelValue(
                    context,
                    'Açıklama',
                    request.description!,
                  ),
                if (request.category == RequestCategory.malfunction &&
                    malfunctionLabel != null)
                  _buildLabelValue(
                    context,
                    'Arıza Kategorisi',
                    malfunctionLabel,
                  ),
                if (request.category == RequestCategory.malfunction &&
                    malfunctionDescription != null &&
                    malfunctionDescription.isNotEmpty)
                  _buildLabelValue(
                    context,
                    'Kategori Açıklaması',
                    malfunctionDescription,
                  ),
                if (request.category == RequestCategory.equipment &&
                    equipmentLabel != null)
                  _buildLabelValue(
                    context,
                    'Ekipman Kategorisi',
                    equipmentLabel,
                  ),
                if (request.category == RequestCategory.equipment &&
                    equipmentDescription != null &&
                    equipmentDescription.isNotEmpty)
                  _buildLabelValue(
                    context,
                    'Kategori Açıklaması',
                    equipmentDescription,
                  ),
                const SizedBox(height: 12),
                if (attachments.isNotEmpty) ...[
                  Text(
                    'Görseller',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: attachments.map((reference) {
                      return FutureBuilder<String?>(
                        future: _getAttachmentUrl(reference),
                        builder: (context, snapshot) {
                          final resolvedUrl = snapshot.data;
                          Widget child;
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            child = Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          } else if (resolvedUrl == null ||
                              resolvedUrl.isEmpty) {
                            child = Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            );
                          } else {
                            child = ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                resolvedUrl,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            );
                          }

                          return GestureDetector(
                            onTap: resolvedUrl == null || resolvedUrl.isEmpty
                                ? null
                                : () => _openImage(resolvedUrl),
                            child: child,
                          );
                        },
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                ],
                if (feedbacks.isNotEmpty) ...[
                  Text(
                    'Önceki Mesajlar',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: feedbacks.map((feedback) {
                      final message = feedback['message'] as String? ?? '-';
                      final sentBy = feedback['sent_by_name'] as String? ??
                          feedback['sent_by'] as String? ??
                          'Bölge Müdürü';
                      final sentAtIso = feedback['sent_at'] as String?;
                      final sentAtLabel = sentAtIso == null
                          ? ''
                          : _formatDateTime(
                              DateTime.parse(sentAtIso).toLocal(),
                            );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sentBy,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (sentAtLabel.isNotEmpty)
                              Text(
                                sentAtLabel,
                                style: theme.textTheme.bodySmall,
                              ),
                            const SizedBox(height: 4),
                            Text(message),
                          ],
                        ),
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Talep sahibine mesaj',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  minLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Talep için geri bildirim veya ek bilgi isteyin',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_isProcessing,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            _handleSendMessage();
                          },
                    icon: _processingAction == _ManagerActionType.message
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _processingAction == _ManagerActionType.message
                          ? 'Gönderiliyor...'
                          : 'Mesajı Gönder',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _isProcessing ? null : () => _handleApprove(),
                        icon: _processingAction == _ManagerActionType.approve
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _processingAction == _ManagerActionType.approve
                              ? 'Onaylanıyor...'
                              : 'Talebi Onayla',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _handleReject(),
                        icon: _processingAction == _ManagerActionType.reject
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: Text(
                          _processingAction == _ManagerActionType.reject
                              ? 'Reddediliyor...'
                              : 'Talebi Reddet',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelValue(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EmptyRequestsCard extends StatelessWidget {
  const _EmptyRequestsCard({required this.scopeLabel});

  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_satisfied_alt_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz talep yok',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '$scopeLabel için bekleyen talep görünmüyor. Yeni talepler buraya düşecek.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestStatusChip extends StatelessWidget {
  const _RequestStatusChip({required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    late final Color background;
    late final Color foreground;

    switch (status) {
      case RequestStatus.pending:
        background = colors.secondaryContainer;
        foreground = colors.onSecondaryContainer;
        break;
      case RequestStatus.inProgress:
        background = colors.tertiaryContainer;
        foreground = colors.onTertiaryContainer;
        break;
      case RequestStatus.resolved:
        background = Colors.green.withValues(alpha: 0.16);
        foreground = Colors.green.shade800;
        break;
      case RequestStatus.cancelled:
        background = Colors.grey.withValues(alpha: 0.16);
        foreground = Colors.grey.shade700;
        break;
    }

    return Chip(
      label: Text(status.label),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
    );
  }
}

String _formatDateTimeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}

String? _formatLeaveRangeFromPayload(Map<String, dynamic> payload) {
  final start = payload['start_date'] as String?;
  final end = payload['end_date'] as String?;
  if (start == null || end == null) {
    return null;
  }
  final startDate = DateTime.tryParse(start)?.toLocal();
  final endDate = DateTime.tryParse(end)?.toLocal();
  if (startDate == null || endDate == null) {
    return null;
  }
  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  return '${formatDate(startDate)} - ${formatDate(endDate)}';
}

String _formatQuantityText(double value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  final formatted = value.toStringAsFixed(1);
  return formatted.endsWith('.0')
      ? formatted.substring(0, formatted.length - 2)
      : formatted;
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}

class _RegionManagerNavigationDrawer extends StatelessWidget {
  const _RegionManagerNavigationDrawer({
    required this.onNavigateToProfile,
    required this.onNavigateToSettings,
    required this.onNavigateToPersonnel,
    required this.onNavigateToStoreScoring,
    required this.onNavigateToAnnouncements,
    required this.managerName,
    required this.regionName,
    required this.branchCount,
  });

  final VoidCallback onNavigateToProfile;
  final VoidCallback onNavigateToSettings;
  final VoidCallback onNavigateToPersonnel;
  final VoidCallback onNavigateToStoreScoring;
  final VoidCallback onNavigateToAnnouncements;
  final String managerName;
  final String regionName;
  final int branchCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: Column(
        children: [
          // Modern gradient header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.7),
                  colorScheme.tertiary.withValues(alpha: 0.6),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile avatar with status indicator
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: Text(
                            managerName.isNotEmpty
                                ? managerName.substring(0, 1).toUpperCase()
                                : 'B',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      managerName.isNotEmpty ? managerName : 'Bölge Müdürü',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          regionName.isNotEmpty ? regionName : 'Bölge',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Stats chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DrawerStatChip(
                          icon: Icons.store,
                          label: '$branchCount Şube',
                        ),
                        const _DrawerStatChip(
                          icon: Icons.verified_user_outlined,
                          label: 'Bölge Müdürü',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerMenuItem(
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  title: 'Kontrol Paneli',
                  subtitle: 'Günlük özet ve istatistikler',
                  onTap: () => Navigator.of(context).pop(),
                ),
                _DrawerMenuItem(
                  icon: Icons.people_alt_outlined,
                  selectedIcon: Icons.people_alt,
                  title: 'Personeller',
                  subtitle: 'Şube personel yönetimi',
                  onTap: () {
                    Navigator.of(context).pop();
                    onNavigateToPersonnel();
                  },
                ),
                _DrawerMenuItem(
                  icon: Icons.fact_check_outlined,
                  selectedIcon: Icons.fact_check,
                  title: 'Mağaza Puanlama',
                  subtitle: 'Denetim ve form işlemleri',
                  onTap: () {
                    Navigator.of(context).pop();
                    onNavigateToStoreScoring();
                  },
                ),
                _DrawerMenuItem(
                  icon: Icons.campaign_outlined,
                  selectedIcon: Icons.campaign,
                  title: 'Duyurular',
                  subtitle: 'Duyurular ve anketler',
                  onTap: () {
                    Navigator.of(context).pop();
                    onNavigateToAnnouncements();
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Hesap',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _DrawerMenuItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  title: 'Profilim',
                  subtitle: 'Kişisel bilgiler',
                  onTap: () {
                    Navigator.of(context).pop();
                    onNavigateToProfile();
                  },
                ),
                _DrawerMenuItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  title: 'Ayarlar',
                  subtitle: 'Uygulama tercihleri',
                  onTap: () {
                    Navigator.of(context).pop();
                    onNavigateToSettings();
                  },
                ),
              ],
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'YoTech v2.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerStatChip extends StatelessWidget {
  const _DrawerStatChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerMenuItem extends StatelessWidget {
  const _DrawerMenuItem({
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _NoBranchSelectedCard extends StatelessWidget {
  final VoidCallback? onSelect;

  const _NoBranchSelectedCard({this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.storefront_outlined,
                color: theme.colorScheme.primary, size: 36),
            const SizedBox(height: 12),
            Text(
              'Şube seçilmedi',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Bir şube seçerek skor, kontrol listesi ve talepleri görüntüleyebilirsiniz.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onSelect,
              child: const Text('Şube seç'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchSelectorButton extends StatelessWidget {
  final ManagedBranch? activeBranch;
  final bool enabled;
  final VoidCallback onPressed;

  const _BranchSelectorButton({
    required this.activeBranch,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = enabled
        ? IconTheme.of(context).color ?? theme.colorScheme.onSurface
        : theme.disabledColor;
    final labelStyle = (theme.textTheme.labelLarge ?? const TextStyle())
        .copyWith(color: iconColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store_outlined, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Text(activeBranch?.name ?? 'Şube seç', style: labelStyle),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, color: iconColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchSelectionSheet extends StatelessWidget {
  final List<ManagedBranch> branches;
  final String? activeBranchId;

  const _BranchSelectionSheet({
    required this.branches,
    required this.activeBranchId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Şube seçimi',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              for (final branch in branches) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.store_outlined),
                  title: Text(branch.name),
                  trailing: branch.id == activeBranchId
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(branch.id),
                ),
              ],
              const Divider(height: 0),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.clear),
                title: const Text('Seçimi temizle'),
                onTap: () => Navigator.of(context).pop(''),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitOverviewCard extends StatelessWidget {
  final String branchName;
  final String managerName;
  final String scheduledWindow;
  final bool isCheckedIn;
  final Duration? visitDuration;
  final VoidCallback onToggle;

  const _VisitOverviewCard({
    required this.branchName,
    required this.managerName,
    required this.scheduledWindow,
    required this.isCheckedIn,
    required this.visitDuration,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isCheckedIn
              ? Colors.green.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isCheckedIn ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isCheckedIn
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.withValues(alpha: 0.08),
                    Colors.green.withValues(alpha: 0.02),
                  ],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch avatar with status indicator
                  Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.storefront,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      if (isCheckedIn)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branchName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Şube Müdürü: $managerName',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Planlanan: $scheduledWindow',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Status badges row
              Row(
                children: [
                  const _VisitBadge(
                    icon: Icons.route,
                    label: 'Günlük rota',
                    value: '3. ziyaret',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _VisitBadge(
                    icon: Icons.timer_outlined,
                    label: 'Süre',
                    value: visitDuration == null
                        ? 'Başlamadı'
                        : '${visitDuration!.inMinutes} dk',
                    color: isCheckedIn ? Colors.green : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Action button
              SizedBox(
                width: double.infinity,
                child: isCheckedIn
                    ? OutlinedButton.icon(
                        onPressed: onToggle,
                        icon: const Icon(Icons.logout),
                        label: const Text('Ziyareti Sonlandır'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: onToggle,
                        icon: const Icon(Icons.login),
                        label: const Text('Ziyareti Başlat'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitBadge extends StatelessWidget {
  const _VisitBadge({
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
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitLogTile extends StatelessWidget {
  final String label;
  final DateTime? time;
  final IconData icon;

  const _VisitLogTile({
    required this.label,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              Text(time == null ? '—' : _formatTime(time!),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

class _ScoreCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final int value;
  final IconData icon;
  final Color color;

  const _ScoreCard({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine score color based on value
    Color scoreColor;
    String scoreLabel;
    if (value >= 80) {
      scoreColor = Colors.green;
      scoreLabel = 'Mükemmel';
    } else if (value >= 60) {
      scoreColor = Colors.orange;
      scoreLabel = 'İyi';
    } else {
      scoreColor = Colors.red;
      scoreLabel = 'Gelişmeli';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.08),
              color.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    scoreLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$value',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  ' / 100',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 100,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String description;

  const _SectionHeader({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ChecklistItem {
  final String id;
  final String title;
  final String description;
  final bool isDone;

  const _ChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.isDone,
  });

  _ChecklistItem copyWith({bool? isDone}) {
    return _ChecklistItem(
      id: id,
      title: title,
      description: description,
      isDone: isDone ?? this.isDone,
    );
  }
}

class _TaskInputResult {
  const _TaskInputResult({
    required this.title,
    this.children = const <_TaskInputResult>[],
  });

  final String title;
  final List<_TaskInputResult> children;
}

enum _BranchSelectionMode { single, multiple, all }

class _NewBranchTaskRequest {
  const _NewBranchTaskRequest({
    required this.branchIds,
    required this.title,
    this.description,
    this.priority,
    this.dueDate,
    required this.children,
  });

  final List<String> branchIds;
  final String title;
  final String? description;
  final String? priority;
  final DateTime? dueDate;
  final List<_TaskInputResult> children;
}

enum _PersonnelMenuAction {
  changeRole,
  delete,
}

class _PersonnelRoleOption {
  const _PersonnelRoleOption(this.value, this.label);

  final String value;
  final String label;
}

class _PersonnelScopeCard extends StatelessWidget {
  const _PersonnelScopeCard({
    required this.branchName,
    this.onChangeBranch,
  });

  final String branchName;
  final VoidCallback? onChangeBranch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(Icons.storefront, color: colorScheme.primary),
        ),
        title: Text(branchName),
        subtitle: const Text(
          'Personel listesi seçtiğiniz şubeye göre gösterilir.',
        ),
        trailing: onChangeBranch == null
            ? null
            : TextButton(
                onPressed: onChangeBranch,
                child: const Text('Şube Değiştir'),
              ),
      ),
    );
  }
}

class _EmptyPersonnelCard extends StatelessWidget {
  const _EmptyPersonnelCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bu şubeye ait kayıtlı personel bulunmuyor.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Sağ alt köşedeki buton üzerinden hızlıca yeni personel ekleyebilirsiniz.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonnelCard extends StatelessWidget {
  const _PersonnelCard({
    required this.personnel,
    required this.roleLabel,
    required this.onChangeRole,
    required this.onRemove,
  });

  final BranchPersonnel personnel;
  final String roleLabel;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.hintColor,
    );

    final avatarSource = personnel.displayName.trim();
    final avatarText =
        avatarSource.isEmpty ? '?' : avatarSource.substring(0, 1).toUpperCase();

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          child: Text(avatarText),
        ),
        title: Text(personnel.displayName),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                roleLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (personnel.position?.isNotEmpty == true)
                Text(personnel.position!, style: subtitleStyle),
              if (personnel.employeeCode?.isNotEmpty == true)
                Text('Kod: ${personnel.employeeCode}', style: subtitleStyle),
              if (personnel.phone?.isNotEmpty == true)
                Text(personnel.phone!, style: subtitleStyle),
              if (personnel.email.isNotEmpty)
                Text(personnel.email, style: subtitleStyle),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<_PersonnelMenuAction>(
          tooltip: 'İşlemler',
          onSelected: (action) {
            switch (action) {
              case _PersonnelMenuAction.changeRole:
                onChangeRole();
                break;
              case _PersonnelMenuAction.delete:
                onRemove();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<_PersonnelMenuAction>(
              value: _PersonnelMenuAction.changeRole,
              child: Text('Rolü değiştir'),
            ),
            PopupMenuItem<_PersonnelMenuAction>(
              value: _PersonnelMenuAction.delete,
              child: Text('Personeli sil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockingLoader extends StatelessWidget {
  const _BlockingLoader();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: SizedBox(
          height: 48,
          width: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _EditableTaskDraft {
  _EditableTaskDraft() : controller = TextEditingController();

  final TextEditingController controller;
  final List<_EditableTaskDraft> children = <_EditableTaskDraft>[];

  void dispose() {
    controller.dispose();
    for (final child in children) {
      child.dispose();
    }
  }
}

class _BranchTaskEditRequest {
  const _BranchTaskEditRequest({
    required this.title,
    this.description,
  });

  final String title;
  final String? description;
}

class _BranchTaskEditSheet extends StatefulWidget {
  const _BranchTaskEditSheet({
    required this.initialTitle,
    this.initialDescription,
  });

  final String initialTitle;
  final String? initialDescription;

  @override
  State<_BranchTaskEditSheet> createState() => _BranchTaskEditSheetState();
}

class _BranchTaskEditSheetState extends State<_BranchTaskEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Başlık zorunlu');
      return;
    }

    final description = _descriptionController.text.trim();

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _BranchTaskEditRequest(
        title: title,
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Görevi düzenle',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                onChanged: (_) {
                  if (_titleError != null) {
                    setState(() => _titleError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Görev başlığı',
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Görev açıklaması',
                  helperText: 'Boş bırakılırsa açıklama gösterilmez',
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Görevi güncelle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchTaskCreationSheet extends StatefulWidget {
  const _BranchTaskCreationSheet({
    required this.branches,
    required this.initialBranchId,
  });

  final List<ManagedBranch> branches;
  final String initialBranchId;

  @override
  State<_BranchTaskCreationSheet> createState() =>
      _BranchTaskCreationSheetState();
}

class _BranchTaskCreationSheetState extends State<_BranchTaskCreationSheet> {
  late String _selectedBranchId;
  late _BranchSelectionMode _selectionMode;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _priority = 'orta';
  DateTime? _dueDate;
  late final List<_EditableTaskDraft> _childDrafts;
  final Set<_EditableTaskDraft> _invalidDrafts = <_EditableTaskDraft>{};
  String? _titleError;
  final Set<String> _selectedBranchIds = <String>{};
  String? _branchSelectionError;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.initialBranchId;
    _selectionMode = widget.branches.length > 1
        ? _BranchSelectionMode.single
        : _BranchSelectionMode.single;
    _childDrafts = <_EditableTaskDraft>[];
    _selectedBranchIds.add(_selectedBranchId);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    for (final draft in _childDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _addRootChild() {
    setState(() {
      _childDrafts.add(_EditableTaskDraft());
    });
  }

  void _addNestedChild(_EditableTaskDraft parent, int depth) {
    if (depth >= 1) {
      return;
    }
    setState(() {
      parent.children.add(_EditableTaskDraft());
    });
  }

  void _removeDraft(List<_EditableTaskDraft> siblings, int index) {
    setState(() {
      final removed = siblings.removeAt(index);
      _removeInvalidSubtree(removed);
      removed.dispose();
    });
  }

  void _removeInvalidSubtree(_EditableTaskDraft draft) {
    _invalidDrafts.remove(draft);
    for (final child in draft.children) {
      _removeInvalidSubtree(child);
    }
  }

  List<_TaskInputResult> _collectChildren(List<_EditableTaskDraft> drafts) {
    final results = <_TaskInputResult>[];
    for (final draft in drafts) {
      final title = draft.controller.text.trim();
      final nested = _collectChildren(draft.children);
      if (title.isEmpty) {
        _invalidDrafts.add(draft);
        continue;
      }
      results.add(
        _TaskInputResult(
          title: title,
          children: nested,
        ),
      );
    }
    return results;
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Başlık zorunlu');
      return;
    }

    _invalidDrafts.clear();
    final children = _collectChildren(_childDrafts);

    List<String> branchIds;
    switch (_selectionMode) {
      case _BranchSelectionMode.single:
        branchIds = <String>[_selectedBranchId];
        break;
      case _BranchSelectionMode.multiple:
        branchIds = _selectedBranchIds.toList();
        break;
      case _BranchSelectionMode.all:
        branchIds = widget.branches.map((branch) => branch.id).toList();
        break;
    }

    branchIds = (branchIds.toSet().toList()..sort());

    if (branchIds.isEmpty) {
      setState(() => _branchSelectionError = 'En az bir şube seçmelisiniz');
      return;
    }

    if (_invalidDrafts.isNotEmpty) {
      setState(() {});
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _NewBranchTaskRequest(
        branchIds: branchIds,
        title: title,
        description: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        priority: _priority,
        dueDate: _dueDate,
        children: children,
      ),
    );
  }

  List<Widget> _buildDraftList(List<_EditableTaskDraft> drafts, int depth) {
    return drafts.asMap().entries.map((entry) {
      final index = entry.key;
      final draft = entry.value;
      return _buildDraftNode(
        draft: draft,
        siblings: drafts,
        index: index,
        depth: depth,
      );
    }).toList();
  }

  Widget _buildDraftNode({
    required _EditableTaskDraft draft,
    required List<_EditableTaskDraft> siblings,
    required int index,
    required int depth,
  }) {
    final theme = Theme.of(context);
    final paddingLeft = depth == 0 ? 0.0 : 16.0 * depth;
    final label = depth == 0 ? 'Alt görev başlığı' : 'Görev detayı';
    final canAddNested = depth < 1;

    return Container(
      margin: EdgeInsets.only(left: paddingLeft, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: draft.controller,
            onChanged: (_) {
              if (_invalidDrafts.remove(draft)) {
                setState(() {});
              }
            },
            decoration: InputDecoration(
              labelText: label,
              errorText:
                  _invalidDrafts.contains(draft) ? 'Başlık zorunlu' : null,
            ),
          ),
          const SizedBox(height: 8),
          if (draft.children.isNotEmpty) ...[
            ..._buildDraftList(draft.children, depth + 1),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (canAddNested)
                TextButton.icon(
                  onPressed: () => _addNestedChild(draft, depth),
                  icon: const Icon(Icons.subdirectory_arrow_right),
                  label: const Text('Alt görev ekle'),
                )
              else
                const SizedBox.shrink(),
              const Spacer(),
              IconButton(
                tooltip: 'Sil',
                onPressed: () => _removeDraft(siblings, index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Yeni görev planı',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.branches.length > 1) ...[
                DropdownButtonFormField<_BranchSelectionMode>(
                  initialValue: _selectionMode,
                  items: const [
                    DropdownMenuItem(
                      value: _BranchSelectionMode.single,
                      child: Text('Tek şube'),
                    ),
                    DropdownMenuItem(
                      value: _BranchSelectionMode.multiple,
                      child: Text('Birden çok şube'),
                    ),
                    DropdownMenuItem(
                      value: _BranchSelectionMode.all,
                      child: Text('Tüm şubeler'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode == null) {
                      return;
                    }
                    setState(() {
                      _selectionMode = mode;
                      _branchSelectionError = null;
                      switch (_selectionMode) {
                        case _BranchSelectionMode.single:
                          if (!_selectedBranchIds.contains(_selectedBranchId)) {
                            _selectedBranchId = widget.initialBranchId;
                          }
                          _selectedBranchIds
                            ..clear()
                            ..add(_selectedBranchId);
                          break;
                        case _BranchSelectionMode.multiple:
                          if (_selectedBranchIds.isEmpty) {
                            _selectedBranchIds.add(_selectedBranchId);
                          }
                          break;
                        case _BranchSelectionMode.all:
                          _selectedBranchIds
                            ..clear()
                            ..addAll(
                              widget.branches.map((branch) => branch.id),
                            );
                          break;
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Gönderim kapsamı',
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectionMode == _BranchSelectionMode.single)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBranchId,
                    items: widget.branches
                        .map(
                          (branch) => DropdownMenuItem<String>(
                            value: branch.id,
                            child: Text(branch.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedBranchId = value;
                        _selectedBranchIds
                          ..clear()
                          ..add(value);
                        _branchSelectionError = null;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Şube',
                    ),
                  )
                else if (_selectionMode == _BranchSelectionMode.multiple)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...widget.branches.map(
                        (branch) => CheckboxListTile(
                          value: _selectedBranchIds.contains(branch.id),
                          onChanged: (isChecked) {
                            setState(() {
                              if (isChecked == true) {
                                _selectedBranchIds.add(branch.id);
                              } else {
                                _selectedBranchIds.remove(branch.id);
                              }
                              _branchSelectionError = _selectedBranchIds.isEmpty
                                  ? 'En az bir şube seçmelisiniz'
                                  : null;
                            });
                          },
                          title: Text(branch.name),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'Tüm şubeler seçili. Görev planı her biri için oluşturulacak.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ] else
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Şube'),
                  child: Text(widget.branches.first.name),
                ),
              if (_branchSelectionError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _branchSelectionError!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                onChanged: (_) {
                  if (_titleError != null) {
                    setState(() => _titleError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Ana görev başlığı',
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                items: const [
                  DropdownMenuItem(
                      value: 'dusuk', child: Text('Düşük öncelik')),
                  DropdownMenuItem(value: 'orta', child: Text('Orta öncelik')),
                  DropdownMenuItem(
                      value: 'yuksek', child: Text('Yüksek öncelik')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _priority = value);
                },
                decoration: const InputDecoration(labelText: 'Öncelik'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  hintText: 'Detay, beklenen çıktı, link vb.',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? now,
                    firstDate: now.subtract(const Duration(days: 1)),
                    lastDate: now.add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Son tarih (opsiyonel)'),
                  child: Text(
                    _dueDate == null
                        ? 'Seçilmedi'
                        : '${_dueDate!.day.toString().padLeft(2, '0')}.${_dueDate!.month.toString().padLeft(2, '0')}.${_dueDate!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Alt görevler',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_childDrafts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Alt görevler isteğe bağlıdır. En fazla iki seviye oluşturabilirsiniz.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ..._buildDraftList(_childDrafts, 0),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addRootChild,
                  icon: const Icon(Icons.add),
                  label: const Text('Alt görev başlığı ekle'),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Görevi oluştur'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewTodoRequest {
  const _NewTodoRequest({
    required this.title,
    required this.children,
  });

  final String title;
  final List<_TaskInputResult> children;
}

class _TodoCreationSheet extends StatefulWidget {
  const _TodoCreationSheet();

  @override
  State<_TodoCreationSheet> createState() => _TodoCreationSheetState();
}

class _TodoCreationSheetState extends State<_TodoCreationSheet> {
  final TextEditingController _titleController = TextEditingController();
  late final List<TextEditingController> _childControllers;
  String? _titleError;
  String? _childError;

  @override
  void initState() {
    super.initState();
    _childControllers = [TextEditingController()];
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _childControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addChildField() {
    setState(() {
      _childControllers.add(TextEditingController());
      _childError = null;
    });
  }

  void _removeChildField(int index) {
    if (_childControllers.length == 1) {
      return;
    }
    setState(() {
      final controller = _childControllers.removeAt(index);
      controller.dispose();
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Başlık zorunlu');
      return;
    }

    final children = _childControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .map((value) => _TaskInputResult(title: value))
        .toList();

    if (children.isEmpty) {
      setState(() => _childError = 'En az bir alt madde ekleyin');
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _NewTodoRequest(
        title: title,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Yeni To-Do listesi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Ana başlık',
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 16),
              Text(
                'Alt To-Do maddeleri',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_childError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _childError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _childControllers.length,
                itemBuilder: (context, index) {
                  final controller = _childControllers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: 'Alt madde ${index + 1}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _removeChildField(index),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addChildField,
                  icon: const Icon(Icons.add),
                  label: const Text('Alt madde ekle'),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('To-Do oluştur'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== NEW ENHANCED UI WIDGETS =====

/// Welcome header with greeting and date
class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.managerName});

  final String managerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final firstName = managerName.split(' ').first;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting 👋',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  firstName.isNotEmpty ? firstName : 'Bölge Müdürü',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(now),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Animated icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sunny,
              size: 32,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 6) return 'İyi geceler';
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  String _formatDate(DateTime date) {
    const days = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName';
  }
}

/// Quick action buttons row
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onTapRequests,
    required this.onTapTasks,
    required this.onTapTransfers,
    required this.onTapPersonnel,
  });

  final VoidCallback onTapRequests;
  final VoidCallback onTapTasks;
  final VoidCallback onTapTransfers;
  final VoidCallback onTapPersonnel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionButton(
            icon: Icons.assignment_outlined,
            label: 'Talepler',
            color: Colors.blue,
            onTap: onTapRequests,
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            icon: Icons.fact_check_outlined,
            label: 'Görevler',
            color: Colors.orange,
            onTap: onTapTasks,
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            icon: Icons.local_shipping_outlined,
            label: 'Sevkler',
            color: Colors.green,
            onTap: onTapTransfers,
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            icon: Icons.people_outlined,
            label: 'Personel',
            color: Colors.purple,
            onTap: onTapPersonnel,
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
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
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 85,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Branch overview card with stats
class _BranchOverviewCard extends StatelessWidget {
  const _BranchOverviewCard({
    required this.branches,
    required this.activeBranch,
    required this.onSelectBranch,
  });

  final List<ManagedBranch> branches;
  final ManagedBranch? activeBranch;
  final VoidCallback onSelectBranch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.store,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Şube Özeti',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        activeBranch != null
                            ? '${activeBranch!.name} seçili'
                            : 'Tüm şubeler',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onSelectBranch,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Değiştir'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Branch stats grid
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.store_outlined,
                    value: '${branches.length}',
                    label: 'Toplam Şube',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.people_outlined,
                    value: '${branches.length * 5}', // Placeholder
                    label: 'Personel',
                    color: Colors.purple,
                  ),
                ),
                const Expanded(
                  child: _StatItem(
                    icon: Icons.pending_actions,
                    value: '12', // Placeholder
                    label: 'Bekleyen',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            if (branches.length > 1) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Mini branch list
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: math.min(branches.length, 5),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final branch = branches[index];
                    final isActive = activeBranch?.id == branch.id;
                    return ActionChip(
                      label: Text(branch.name),
                      avatar: isActive
                          ? Icon(
                              Icons.check_circle,
                              size: 16,
                              color: colorScheme.primary,
                            )
                          : null,
                      backgroundColor:
                          isActive ? colorScheme.primaryContainer : null,
                      onPressed: onSelectBranch,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Notification center bottom sheet
class _NotificationCenterSheet extends StatelessWidget {
  const _NotificationCenterSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Sample notifications
    const notifications = [
      _NotificationItem(
        icon: Icons.assignment,
        title: 'Yeni talep geldi',
        message: 'Merkez şubesinden malzeme talebi',
        time: '5 dk önce',
        color: Colors.blue,
        isUnread: true,
      ),
      _NotificationItem(
        icon: Icons.check_circle,
        title: 'Görev tamamlandı',
        message: 'Stok sayımı başarıyla tamamlandı',
        time: '1 saat önce',
        color: Colors.green,
        isUnread: true,
      ),
      _NotificationItem(
        icon: Icons.local_shipping,
        title: 'Sevk onaylandı',
        message: 'Batı şubesine sevk onayınız alındı',
        time: '3 saat önce',
        color: Colors.orange,
        isUnread: false,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Bildirimler',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${notifications.where((n) => n.isUnread).length} yeni',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text('Tümünü oku'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...notifications.map((notification) => _NotificationTile(
                  notification: notification,
                )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tüm bildirimleri gör'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.color,
    required this.isUnread,
  });

  final IconData icon;
  final String title;
  final String message;
  final String time;
  final Color color;
  final bool isUnread;
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final _NotificationItem notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: notification.isUnread
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: notification.isUnread
            ? Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: notification.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              notification.icon,
              color: notification.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: notification.isUnread
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (notification.isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.time,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
