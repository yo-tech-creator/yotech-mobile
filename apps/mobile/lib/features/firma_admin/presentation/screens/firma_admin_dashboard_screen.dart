import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_navigation_helper.dart';
import '../../../../shared/widgets/custom_back_button.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../settings/presentation/screens/personal_info_page.dart';
import '../../../settings/presentation/screens/settings_page.dart';
import '../../../announcements/presentation/screens/announcements_page.dart';
import '../../../requests/presentation/screens/requests_hub_page.dart';
import '../../../forms/presentation/screens/forms_hub_page.dart';
import '../../../visual_audit/visual_audit.dart';
import '../../../requests/presentation/screens/department_management_page.dart';
import '../../domain/providers/firma_admin_providers.dart';

class FirmaAdminDashboardScreen extends ConsumerStatefulWidget {
  const FirmaAdminDashboardScreen({super.key});

  @override
  ConsumerState<FirmaAdminDashboardScreen> createState() =>
      _FirmaAdminDashboardScreenState();
}

class _FirmaAdminDashboardScreenState
    extends ConsumerState<FirmaAdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentTabIndex = 0;
  String? _tenantName;

  @override
  void initState() {
    super.initState();
    _loadTenantName();
  }

  Future<void> _loadTenantName() async {
    final user = ref.read(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('tenants')
          .select('name')
          .eq('id', user.tenantId)
          .maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _tenantName = response['name'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Tenant name yüklenemedi: $e');
    }
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

  void _openAnnouncements() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
    );
  }

  void _openRequests() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RequestsHubPage()),
    );
  }

  void _openForms() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FormsHubPage()),
    );
  }

  void _openVisualAudit() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VisualAuditPage()),
    );
  }

  void _openDepartments() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DepartmentManagementPage()),
    );
  }

  Future<void> _handleBackPressed() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Oturumu kapatmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        await AuthNavigationHelper.navigateToLogin(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );
    final userName =
        user != null ? '${user.name} ${user.surname}'.trim() : 'Yönetici';

    return CustomBackButton(
      onBackPressed: _handleBackPressed,
      child: Scaffold(
        drawer: _FirmaAdminDrawer(
          userName: userName,
          tenantName: _tenantName ?? 'Firma',
          onNavigateToProfile: _openProfile,
          onNavigateToSettings: _openSettings,
          onNavigateToAnnouncements: _openAnnouncements,
          onNavigateToRequests: _openRequests,
          onNavigateToForms: _openForms,
          onNavigateToVisualAudit: _openVisualAudit,
          onNavigateToDepartments: _openDepartments,
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
          title: Text(_tenantName ?? 'Firma Yönetimi'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Bildirimler',
              icon: const Badge(
                isLabelVisible: true,
                label: Text(''),
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentTabIndex,
          onDestinationSelected: (index) {
            setState(() => _currentTabIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Genel Bakış',
            ),
            NavigationDestination(
              icon: Icon(Icons.store_outlined),
              selectedIcon: Icon(Icons.store),
              label: 'Şubeler',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outlined),
              selectedIcon: Icon(Icons.people),
              label: 'Personel',
            ),
            NavigationDestination(
              icon: Icon(Icons.inbox_outlined),
              selectedIcon: Icon(Icons.inbox),
              label: 'Talepler',
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentTabIndex,
          children: [
            _buildOverviewTab(context),
            _buildBranchesTab(context),
            _buildPersonnelTab(context),
            _buildRequestsTab(context),
          ],
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Bildirimler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: const [
                  _NotificationItem(
                    icon: Icons.inbox,
                    title: 'Yeni Talep',
                    subtitle: 'Merkez şubeden ekipman talebi',
                    time: '2 saat önce',
                  ),
                  _NotificationItem(
                    icon: Icons.person_add,
                    title: 'Yeni Personel',
                    subtitle: 'Ali Yılmaz sisteme eklendi',
                    time: '5 saat önce',
                  ),
                  _NotificationItem(
                    icon: Icons.assignment,
                    title: 'Form Tamamlandı',
                    subtitle: 'Günlük kontrol formu dolduruldu',
                    time: 'Dün',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 1: Genel Bakış
  // ============================================================================

  Widget _buildOverviewTab(BuildContext context) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(firmaStatsProvider);
    final pendingRequestsAsync = ref.watch(firmaPendingRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(firmaStatsProvider);
        ref.invalidate(firmaPendingRequestsProvider);
      },
      child: CustomScrollView(
        slivers: [
          // İstatistik Kartları
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: statsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => _ErrorCard(
                  message: 'İstatistikler yüklenemedi',
                  onRetry: () => ref.invalidate(firmaStatsProvider),
                ),
                data: (stats) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Firma Özeti',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _StatsGrid(stats: stats),
                  ],
                ),
              ),
            ),
          ),

          // Hızlı Erişim
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hızlı Erişim',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuickAccessGrid(
                    onDepartments: _openDepartments,
                    onAnnouncements: _openAnnouncements,
                    onForms: _openForms,
                    onVisualAudit: _openVisualAudit,
                  ),
                ],
              ),
            ),
          ),

          // Bekleyen Talepler
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bekleyen Talepler',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: _openRequests,
                        child: const Text('Tümünü Gör'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          pendingRequestsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: _ErrorCard(
                message: 'Talepler yüklenemedi',
                onRetry: () => ref.invalidate(firmaPendingRequestsProvider),
              ),
            ),
            data: (requests) => requests.isEmpty
                ? const SliverToBoxAdapter(
                    child: _EmptyCard(
                      icon: Icons.inbox_outlined,
                      title: 'Bekleyen Talep Yok',
                      subtitle: 'Tüm talepler işlenmiş durumda',
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final request = requests[index];
                          return _RequestCard(
                            request: request,
                            onTap: _openRequests,
                          );
                        },
                        childCount: math.min(requests.length, 5),
                      ),
                    ),
                  ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: Şubeler
  // ============================================================================

  Widget _buildBranchesTab(BuildContext context) {
    final theme = Theme.of(context);
    final branchesAsync = ref.watch(firmaBranchesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(firmaBranchesProvider);
      },
      child: branchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: _ErrorCard(
            message: 'Şubeler yüklenemedi',
            onRetry: () => ref.invalidate(firmaBranchesProvider),
          ),
        ),
        data: (branches) {
          if (branches.isEmpty) {
            return const Center(
              child: _EmptyCard(
                icon: Icons.store_outlined,
                title: 'Şube Bulunamadı',
                subtitle: 'Henüz şube eklenmemiş',
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${branches.length} Şube',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          // TODO: Search
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final branch = branches[index];
                      return _BranchCard(branch: branch);
                    },
                    childCount: branches.length,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
      ),
    );
  }

  // ============================================================================
  // TAB 3: Personel
  // ============================================================================

  Widget _buildPersonnelTab(BuildContext context) {
    final theme = Theme.of(context);
    final personnelAsync = ref.watch(firmaPersonnelProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(firmaPersonnelProvider);
      },
      child: personnelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: _ErrorCard(
            message: 'Personel listesi yüklenemedi',
            onRetry: () => ref.invalidate(firmaPersonnelProvider),
          ),
        ),
        data: (personnel) {
          if (personnel.isEmpty) {
            return const Center(
              child: _EmptyCard(
                icon: Icons.people_outlined,
                title: 'Personel Bulunamadı',
                subtitle: 'Henüz personel eklenmemiş',
              ),
            );
          }

          // Role'e göre grupla
          final grouped = <String, List<FirmaPersonnel>>{};
          for (final p in personnel) {
            grouped.putIfAbsent(p.role, () => []).add(p);
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${personnel.length} Personel',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          // TODO: Search
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () {
                          // TODO: Filter
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Rol özeti kartları
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RoleChip(
                        label: 'Tümü',
                        count: personnel.length,
                        isSelected: true,
                      ),
                      ...grouped.entries.map((entry) => _RoleChip(
                            label: _getRoleLabel(entry.key),
                            count: entry.value.length,
                          )),
                    ],
                  ),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(top: 16)),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final person = personnel[index];
                      return _PersonnelCard(
                        personnel: person,
                        onTap: () => _showPersonnelDetail(context, person),
                      );
                    },
                    childCount: personnel.length,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'firma_admin':
        return 'Yönetici';
      case 'bolge_muduru':
        return 'Bölge Md.';
      case 'sube_muduru':
        return 'Şube Md.';
      case 'personel':
        return 'Personel';
      default:
        return role;
    }
  }

  void _showPersonnelDetail(BuildContext context, FirmaPersonnel person) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                person.firstName.isNotEmpty
                    ? person.firstName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              person.fullName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              person.roleLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 24),
            _DetailRow(
              icon: Icons.store,
              label: 'Şube',
              value: person.branchName ?? 'Atanmamış',
            ),
            _DetailRow(
              icon: Icons.business,
              label: 'Departman',
              value: person.departmentName ?? 'Atanmamış',
            ),
            if (person.email != null)
              _DetailRow(
                icon: Icons.email,
                label: 'E-posta',
                value: person.email!,
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Edit personnel
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Düzenle'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openDepartments();
                    },
                    icon: const Icon(Icons.business),
                    label: const Text('Departman'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 4: Talepler
  // ============================================================================

  Widget _buildRequestsTab(BuildContext context) {
    // RequestsHubPage'i burada gömülü olarak göster
    return const RequestsHubPage();
  }
}

// ============================================================================
// Drawer
// ============================================================================

class _FirmaAdminDrawer extends StatelessWidget {
  final String userName;
  final String tenantName;
  final VoidCallback onNavigateToProfile;
  final VoidCallback onNavigateToSettings;
  final VoidCallback onNavigateToAnnouncements;
  final VoidCallback onNavigateToRequests;
  final VoidCallback onNavigateToForms;
  final VoidCallback onNavigateToVisualAudit;
  final VoidCallback onNavigateToDepartments;

  const _FirmaAdminDrawer({
    required this.userName,
    required this.tenantName,
    required this.onNavigateToProfile,
    required this.onNavigateToSettings,
    required this.onNavigateToAnnouncements,
    required this.onNavigateToRequests,
    required this.onNavigateToForms,
    required this.onNavigateToVisualAudit,
    required this.onNavigateToDepartments,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: colors.onPrimary,
                  child: Icon(
                    Icons.business,
                    size: 32,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tenantName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  userName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimary.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.campaign_outlined,
                  label: 'Duyurular & Anketler',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToAnnouncements();
                  },
                ),
                _DrawerItem(
                  icon: Icons.business_outlined,
                  label: 'Departmanlar',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToDepartments();
                  },
                ),
                _DrawerItem(
                  icon: Icons.camera_alt_outlined,
                  label: 'Görsel Denetim',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToVisualAudit();
                  },
                ),
                _DrawerItem(
                  icon: Icons.assignment_outlined,
                  label: 'Formlar',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToForms();
                  },
                ),
                const Divider(),
                _DrawerItem(
                  icon: Icons.person_outline,
                  label: 'Profil',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToProfile();
                  },
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Ayarlar',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToSettings();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Firma Yöneticisi',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}

// ============================================================================
// Yardımcı Widget'lar
// ============================================================================

class _StatsGrid extends StatelessWidget {
  final FirmaStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          icon: Icons.store,
          label: 'Şube',
          value: stats.branchCount.toString(),
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.people,
          label: 'Personel',
          value: stats.personnelCount.toString(),
          color: Colors.green,
        ),
        _StatCard(
          icon: Icons.inbox,
          label: 'Bekleyen Talep',
          value: stats.pendingRequests.toString(),
          color: Colors.orange,
        ),
        _StatCard(
          icon: Icons.business,
          label: 'Departman',
          value: stats.departmentCount.toString(),
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: color.withAlpha(25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  final VoidCallback onDepartments;
  final VoidCallback onAnnouncements;
  final VoidCallback onForms;
  final VoidCallback onVisualAudit;

  const _QuickAccessGrid({
    required this.onDepartments,
    required this.onAnnouncements,
    required this.onForms,
    required this.onVisualAudit,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _QuickAccessItem(
          icon: Icons.business,
          label: 'Departman',
          color: Colors.purple,
          onTap: onDepartments,
        ),
        _QuickAccessItem(
          icon: Icons.campaign,
          label: 'Duyurular',
          color: Colors.blue,
          onTap: onAnnouncements,
        ),
        _QuickAccessItem(
          icon: Icons.assignment,
          label: 'Formlar',
          color: Colors.green,
          onTap: onForms,
        ),
        _QuickAccessItem(
          icon: Icons.camera_alt,
          label: 'Denetim',
          color: Colors.orange,
          onTap: onVisualAudit,
        ),
      ],
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final FirmaRequest request;
  final VoidCallback onTap;

  const _RequestCard({
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(request.category).withAlpha(25),
          child: Icon(
            _getCategoryIcon(request.category),
            color: _getCategoryColor(request.category),
            size: 20,
          ),
        ),
        title: Text(
          request.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${request.creatorName} • ${request.branchName ?? ""}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: theme.hintColor),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            request.statusLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'malfunction':
        return Colors.red;
      case 'equipment':
        return Colors.blue;
      case 'leave':
        return Colors.green;
      default:
        return Colors.purple;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'malfunction':
        return Icons.build;
      case 'equipment':
        return Icons.inventory_2;
      case 'leave':
        return Icons.event_available;
      default:
        return Icons.help_outline;
    }
  }
}

class _BranchCard extends StatelessWidget {
  final FirmaBranch branch;

  const _BranchCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.store,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (branch.regionName != null)
                    Text(
                      branch.regionName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: branch.isActive
                        ? Colors.green.withAlpha(25)
                        : Colors.grey.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    branch.isActive ? 'Aktif' : 'Pasif',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: branch.isActive ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${branch.personnelCount} personel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonnelCard extends StatelessWidget {
  final FirmaPersonnel personnel;
  final VoidCallback onTap;

  const _PersonnelCard({
    required this.personnel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Text(
            personnel.firstName.isNotEmpty
                ? personnel.firstName[0].toUpperCase()
                : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          personnel.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${personnel.roleLabel} • ${personnel.branchName ?? "Şube yok"}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: theme.hintColor),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;

  const _RoleChip({
    required this.label,
    required this.count,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: isSelected,
      label: Text('$label ($count)'),
      onSelected: (_) {
        // TODO: Filter
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 32),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.hintColor),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          time,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.hintColor,
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.hintColor),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: theme.hintColor),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
