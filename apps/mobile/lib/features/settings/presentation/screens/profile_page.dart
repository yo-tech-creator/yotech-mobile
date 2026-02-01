import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yotech_mobile/core/localization/locale_controller.dart';
import 'package:yotech_mobile/core/localization/localization_extensions.dart';
import 'package:yotech_mobile/core/theme/app_theme.dart';
import 'package:yotech_mobile/core/theme/theme_controller.dart';
import 'package:yotech_mobile/features/settings/presentation/screens/notification_settings_page.dart';
import 'package:yotech_mobile/features/settings/presentation/widgets/change_password_dialog.dart';

/// Modern profil sayfası - glassmorphism ve gradient destekli
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool _isLoading = true;
  _ProfileData? _profileData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadProfile();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final authUser = client.auth.currentUser;
      if (authUser == null) throw StateError('Oturum bulunamadı');

      final profileResponse = await client.rpc('get_personal_profile',
          params: {'p_user_id': authUser.id}).maybeSingle();

      if (profileResponse == null) {
        throw StateError('Profil verileri alınamadı');
      }

      final data = Map<String, dynamic>.from(profileResponse);

      setState(() {
        _profileData = _ProfileData(
          id: authUser.id,
          firstName: data['first_name'] as String? ?? '',
          lastName: data['last_name'] as String? ?? '',
          email: authUser.email ?? '',
          phone: data['phone'] as String?,
          role: data['role'] as String? ?? 'personel',
          position: data['position'] as String?,
          employeeCode: data['employee_code'] as String?,
          branchName: data['branch_name'] as String?,
          branchCity: data['branch_city'] as String?,
          branchDistrict: data['branch_district'] as String?,
          tenantName: data['tenant_name'] as String?,
          managerFirstName: data['branch_manager_first_name'] as String?,
          managerLastName: data['branch_manager_last_name'] as String?,
          managerPhone: data['branch_manager_phone'] as String?,
          regionalManagerFirstName:
              data['regional_manager_first_name'] as String?,
          regionalManagerLastName:
              data['regional_manager_last_name'] as String?,
          startDate: data['created_at'] as String?,
        );
        _isLoading = false;
      });
      _animController.forward();
    } catch (e) {
      debugPrint('Profil yükleme hatası: $e');
      setState(() {
        _errorMessage = 'Profil yüklenemedi';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = theme.extension<AppThemeTokens>() ?? AppThemeTokens.vibrant;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: _isLoading
            ? _buildLoadingState(cs)
            : _errorMessage != null
                ? _buildErrorState(cs)
                : _buildContent(theme, cs, tokens),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.primary.withOpacity(0.7)],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildErrorState(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.primary.withOpacity(0.7)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Bir hata oluştu',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme cs, AppThemeTokens tokens) {
    final profile = _profileData!;
    final l10n = context.l10n;

    return FadeTransition(
      opacity: _fadeAnim,
      child: CustomScrollView(
        slivers: [
          // Gradient Header
          SliverToBoxAdapter(
            child: _ProfileHeader(
              profile: profile,
              tokens: tokens,
              cs: cs,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),

          // Stats Cards
          SliverToBoxAdapter(
            child: _QuickStatsSection(profile: profile, cs: cs),
          ),

          // Menu Sections
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Account Section
                _SectionHeader(title: l10n.settingsSectionAccount),
                _MenuCard(
                  children: [
                    _MenuTile(
                      icon: Icons.person_outline,
                      iconColor: cs.primary,
                      title: 'Kişisel Bilgiler',
                      subtitle: 'Ad, soyad, iletişim bilgileri',
                      onTap: () => _showPersonalInfoSheet(profile),
                    ),
                    _MenuDivider(),
                    _MenuTile(
                      icon: Icons.business_outlined,
                      iconColor: Colors.teal,
                      title: 'Şube Bilgileri',
                      subtitle: profile.branchName ?? 'Şube atanmamış',
                      onTap: () => _showBranchInfoSheet(profile),
                    ),
                    _MenuDivider(),
                    _MenuTile(
                      icon: Icons.supervisor_account_outlined,
                      iconColor: Colors.orange,
                      title: 'Yöneticilerim',
                      subtitle: 'Şube ve bölge müdürü bilgileri',
                      onTap: () => _showManagersSheet(profile),
                    ),
                    _MenuDivider(),
                    _MenuTile(
                      icon: Icons.lock_outline,
                      iconColor: Colors.red,
                      title: 'Şifre Değiştir',
                      subtitle: 'Hesap güvenliğini güncelle',
                      onTap: () => showChangePasswordDialog(context),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Preferences Section
                _SectionHeader(title: l10n.settingsSectionOther),
                _MenuCard(
                  children: [
                    _ThemeMenuTile(ref: ref),
                    _MenuDivider(),
                    _LanguageMenuTile(ref: ref),
                    _MenuDivider(),
                    _MenuTile(
                      icon: Icons.notifications_outlined,
                      iconColor: Colors.purple,
                      title: l10n.settingsNotificationsTitle,
                      subtitle: l10n.settingsNotificationsSubtitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NotificationSettingsPage()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // About Section
                const _SectionHeader(title: 'Uygulama'),
                _MenuCard(
                  children: [
                    _MenuTile(
                      icon: Icons.description_outlined,
                      iconColor: Colors.blueGrey,
                      title: 'Sözleşmeler',
                      subtitle: 'Kullanım koşulları ve gizlilik',
                      onTap: () {},
                    ),
                    _MenuDivider(),
                    _MenuTile(
                      icon: Icons.help_outline,
                      iconColor: Colors.green,
                      title: 'Yardım & Destek',
                      subtitle: 'SSS ve iletişim',
                      onTap: () => _showHelpSheet(),
                    ),
                    _MenuDivider(),
                    _MenuTile(
                      icon: Icons.info_outline,
                      iconColor: Colors.grey,
                      title: 'Uygulama Hakkında',
                      subtitle: 'Versiyon 3.0.2',
                      onTap: () => _showAboutSheet(),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Logout Button
                _LogoutButton(onLogout: _handleLogout),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showPersonalInfoSheet(_ProfileData profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PersonalInfoSheet(profile: profile),
    );
  }

  void _showBranchInfoSheet(_ProfileData profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BranchInfoSheet(profile: profile),
    );
  }

  void _showManagersSheet(_ProfileData profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManagersSheet(profile: profile),
    );
  }

  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HelpSheet(),
    );
  }

  void _showAboutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AboutSheet(),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Oturumunuzu kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;

    // Login ekranına yönlendir ve tüm geçmişi temizle
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.tokens,
    required this.cs,
    required this.onBack,
  });

  final _ProfileData profile;
  final AppThemeTokens tokens;
  final ColorScheme cs;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // Header için koyu gradient kullan - her temada görünür olacak
    final headerGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        cs.primary,
        cs.primary.withOpacity(0.8),
      ],
    );
    final textColor = cs.onPrimary;

    return Container(
      decoration: BoxDecoration(
        gradient: headerGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                  ),
                  Expanded(
                    child: Text(
                      'Profilim',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.edit_outlined,
                        color: textColor.withOpacity(0.7)),
                  ),
                ],
              ),
            ),

            // Avatar and info
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                children: [
                  // Avatar with glow
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: textColor,
                      child: Text(
                        profile.initials,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name
                  Text(
                    profile.displayName,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Role badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      profile.roleLabel,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Company & Branch
                  if (profile.tenantName != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      profile.tenantName!,
                      style: TextStyle(
                        color: textColor.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// QUICK STATS
// ═══════════════════════════════════════════════════════════════════════════

class _QuickStatsSection extends StatelessWidget {
  const _QuickStatsSection({required this.profile, required this.cs});

  final _ProfileData profile;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.badge_outlined,
              label: 'Personel No',
              value: profile.employeeCode ?? '-',
              color: cs.primary,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _StatItem(
              icon: Icons.store_outlined,
              label: 'Şube',
              value: profile.branchName ?? '-',
              color: Colors.teal,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _StatItem(
              icon: Icons.calendar_today_outlined,
              label: 'Başlangıç',
              value: profile.formattedStartDate,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MENU COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 62,
      endIndent: 16,
      color: Colors.grey.withOpacity(0.15),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// THEME & LANGUAGE TILES
// ═══════════════════════════════════════════════════════════════════════════

class _ThemeMenuTile extends ConsumerWidget {
  const _ThemeMenuTile({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(appThemeControllerProvider);
    final themeLabel = _getThemeLabel(currentTheme);

    return _MenuTile(
      icon: Icons.palette_outlined,
      iconColor: Colors.deepPurple,
      title: 'Tema',
      subtitle: themeLabel,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              gradient: _getThemeGradient(currentTheme),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
        ],
      ),
      onTap: () => _showThemeSheet(context, ref, currentTheme),
    );
  }

  String _getThemeLabel(AppTheme theme) {
    switch (theme) {
      case AppTheme.vibrant:
        return 'Vibrant Gradient';
      case AppTheme.minimal:
        return 'Modern Minimalist';
      case AppTheme.sunset:
        return 'Sunset Glow';
      case AppTheme.ocean:
        return 'Ocean Breeze';
      case AppTheme.forest:
        return 'Forest Dew';
    }
  }

  LinearGradient _getThemeGradient(AppTheme theme) {
    switch (theme) {
      case AppTheme.vibrant:
        return AppThemeTokens.vibrant.accentGradient;
      case AppTheme.minimal:
        return AppThemeTokens.minimal.accentGradient;
      case AppTheme.sunset:
        return AppThemeTokens.sunset.accentGradient;
      case AppTheme.ocean:
        return AppThemeTokens.ocean.accentGradient;
      case AppTheme.forest:
        return AppThemeTokens.forest.accentGradient;
    }
  }

  void _showThemeSheet(
      BuildContext context, WidgetRef ref, AppTheme currentTheme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ThemeSelectionSheet(currentTheme: currentTheme, ref: ref),
    );
  }
}

class _LanguageMenuTile extends ConsumerWidget {
  const _LanguageMenuTile({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final l10n = context.l10n;
    final languageLabel = locale.languageCode == 'en'
        ? l10n.languageNameEnglish
        : l10n.languageNameTurkish;

    return _MenuTile(
      icon: Icons.language,
      iconColor: Colors.blue,
      title: l10n.settingsLanguageTitle,
      subtitle: languageLabel,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            locale.languageCode.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
        ],
      ),
      onTap: () => _showLanguageSheet(context, ref, locale),
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref, Locale locale) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _LanguageSelectionSheet(currentLocale: locale, ref: ref),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOGOUT BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.red[400], size: 22),
              const SizedBox(width: 12),
              Text(
                'Çıkış Yap',
                style: TextStyle(
                  color: Colors.red[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM SHEETS
// ═══════════════════════════════════════════════════════════════════════════

class _BottomSheetContainer extends StatelessWidget {
  const _BottomSheetContainer({required this.child, this.maxHeight = 0.85});
  final Widget child;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeight,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class _PersonalInfoSheet extends StatelessWidget {
  const _PersonalInfoSheet({required this.profile});
  final _ProfileData profile;

  @override
  Widget build(BuildContext context) {
    return _BottomSheetContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kişisel Bilgiler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _InfoRow(icon: Icons.person, label: 'Ad', value: profile.firstName),
            _InfoRow(
                icon: Icons.person_outline,
                label: 'Soyad',
                value: profile.lastName),
            _InfoRow(
                icon: Icons.email_outlined,
                label: 'E-posta',
                value: profile.email),
            _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Telefon',
                value: profile.phone ?? '-'),
            _InfoRow(
                icon: Icons.work_outline,
                label: 'Pozisyon',
                value: profile.position ?? '-'),
            _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Personel No',
                value: profile.employeeCode ?? '-'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _BranchInfoSheet extends StatelessWidget {
  const _BranchInfoSheet({required this.profile});
  final _ProfileData profile;

  @override
  Widget build(BuildContext context) {
    return _BottomSheetContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Şube Bilgileri',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _InfoRow(
                icon: Icons.store,
                label: 'Şube Adı',
                value: profile.branchName ?? '-'),
            _InfoRow(
                icon: Icons.location_city,
                label: 'Şehir',
                value: profile.branchCity ?? '-'),
            _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'İlçe',
                value: profile.branchDistrict ?? '-'),
            _InfoRow(
                icon: Icons.business,
                label: 'Şirket',
                value: profile.tenantName ?? '-'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ManagersSheet extends StatelessWidget {
  const _ManagersSheet({required this.profile});
  final _ProfileData profile;

  @override
  Widget build(BuildContext context) {
    final hasManager = profile.managerFirstName != null;
    final hasRegionalManager = profile.regionalManagerFirstName != null;

    return _BottomSheetContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yöneticilerim',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Şube Müdürü
            _ManagerCard(
              title: 'Şube Müdürü',
              icon: Icons.store,
              iconColor: Colors.teal,
              name: hasManager
                  ? '${profile.managerFirstName} ${profile.managerLastName ?? ''}'
                  : 'Atanmamış',
              phone: profile.managerPhone,
            ),

            const SizedBox(height: 16),

            // Bölge Müdürü
            _ManagerCard(
              title: 'Bölge Müdürü',
              icon: Icons.domain,
              iconColor: Colors.orange,
              name: hasRegionalManager
                  ? '${profile.regionalManagerFirstName} ${profile.regionalManagerLastName ?? ''}'
                  : 'Atanmamış',
              phone: null, // Bölge müdürü telefonu genelde gizli
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ManagerCard extends StatelessWidget {
  const _ManagerCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.name,
    this.phone,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final String name;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (phone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    phone!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (phone != null)
            IconButton(
              onPressed: () async {
                final phoneNumber = phone!.replaceAll(RegExp(r'[^0-9+]'), '');
                final uri = Uri.parse('tel:$phoneNumber');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              icon: Icon(Icons.phone, color: iconColor),
            ),
        ],
      ),
    );
  }
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    return _BottomSheetContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yardım & Destek',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _HelpItem(
              icon: Icons.email_outlined,
              title: 'E-posta ile İletişim',
              subtitle: 'destek@yotech.com',
              onTap: () async {
                final uri = Uri.parse('mailto:destek@yotech.com');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            _HelpItem(
              icon: Icons.phone_outlined,
              title: 'Telefon Desteği',
              subtitle: '+90 850 123 45 67',
              onTap: () async {
                final uri = Uri.parse('tel:+908501234567');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            _HelpItem(
              icon: Icons.question_answer_outlined,
              title: 'Sıkça Sorulan Sorular',
              subtitle: 'Hızlı cevaplar bul',
              onTap: () {},
            ),
            _HelpItem(
              icon: Icons.bug_report_outlined,
              title: 'Hata Bildir',
              subtitle: 'Sorun veya öneri bildir',
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const _BugReportSheet(),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _BottomSheetContainer(
      maxHeight: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.storefront, size: 48, color: cs.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Yotech Mobile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Versiyon 3.0.2',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Text(
              'Perakende sektörü için geliştirilmiş\nkapsamlı iş yönetim platformu',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
            const Spacer(),
            Text(
              '© 2026 Yotech. Tüm hakları saklıdır.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BUG REPORT SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _BugReportSheet extends StatefulWidget {
  const _BugReportSheet();

  @override
  State<_BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<_BugReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final client = Supabase.instance.client;

      // Cihaz bilgilerini topla
      final deviceInfo = {
        'platform': Theme.of(context).platform.name,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await client.rpc('create_bug_report', params: {
        'p_title': _titleController.text.trim(),
        'p_description': _descriptionController.text.trim(),
        'p_device_info': deviceInfo,
        'p_app_version': '3.0.2',
      });

      if (!mounted) return;
      Navigator.pop(context);

      // Güzel başarı dialog'u göster
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Colors.green, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Teşekkürler! 🎉',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bildiriminiz başarıyla alındı.\nEn kısa sürede incelenecektir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tamam',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Hata bildirimi gönderme hatası: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gönderilirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return _BottomSheetContainer(
      maxHeight: 0.9,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: bottomInset + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bug_report,
                        color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hata Bildir',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Karşılaştığınız sorunu bize bildirin',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Başlık
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Başlık',
                  hintText: 'Sorunu kısaca özetleyin',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen bir başlık girin';
                  }
                  if (value.trim().length < 5) {
                    return 'Başlık en az 5 karakter olmalı';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Açıklama
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Açıklama',
                  hintText:
                      'Hatanın ne zaman ve nasıl oluştuğunu detaylı açıklayın...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 80),
                    child: Icon(Icons.description),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen bir açıklama girin';
                  }
                  if (value.trim().length < 20) {
                    return 'Açıklama en az 20 karakter olmalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              Text(
                'İpucu: Hangi adımları uyguladığınızı ve ne olmasını beklediğinizi de yazarsanız daha hızlı çözüm üretebiliriz.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 24),

              // Gönder Butonu
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitReport,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'Gönderiliyor...' : 'Gönder'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════
// THEME & LANGUAGE SELECTION SHEETS
// ═══════════════════════════════════════════════════════════════════════════

class _ThemeSelectionSheet extends StatelessWidget {
  const _ThemeSelectionSheet({required this.currentTheme, required this.ref});
  final AppTheme currentTheme;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return _BottomSheetContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tema Seç',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Uygulamanın görünümünü özelleştir',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ...AppTheme.values.map((theme) => _ThemeOption(
                  theme: theme,
                  isSelected: theme == currentTheme,
                  onSelect: () async {
                    await ref
                        .read(appThemeControllerProvider.notifier)
                        .setTheme(theme);
                    if (context.mounted) Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.theme,
    required this.isSelected,
    required this.onSelect,
  });

  final AppTheme theme;
  final bool isSelected;
  final VoidCallback onSelect;

  String get _label {
    switch (theme) {
      case AppTheme.vibrant:
        return 'Vibrant Gradient';
      case AppTheme.minimal:
        return 'Modern Minimalist';
      case AppTheme.sunset:
        return 'Sunset Glow';
      case AppTheme.ocean:
        return 'Ocean Breeze';
      case AppTheme.forest:
        return 'Forest Dew';
    }
  }

  String get _description {
    switch (theme) {
      case AppTheme.vibrant:
        return 'Canlı gradientler ve glassmorphism';
      case AppTheme.minimal:
        return 'Temiz ve yumuşak görünüm';
      case AppTheme.sunset:
        return 'Sıcak turuncu-pembe tonlar';
      case AppTheme.ocean:
        return 'Ferah mavi-yeşil tonlar';
      case AppTheme.forest:
        return 'Doğal yeşil harmonisi';
    }
  }

  AppThemeTokens get _tokens {
    switch (theme) {
      case AppTheme.vibrant:
        return AppThemeTokens.vibrant;
      case AppTheme.minimal:
        return AppThemeTokens.minimal;
      case AppTheme.sunset:
        return AppThemeTokens.sunset;
      case AppTheme.ocean:
        return AppThemeTokens.ocean;
      case AppTheme.forest:
        return AppThemeTokens.forest;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _tokens.cardHighlight
                : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: _tokens.accentGradient,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(_description,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_off,
              color: isSelected ? _tokens.cardHighlight : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSelectionSheet extends StatelessWidget {
  const _LanguageSelectionSheet(
      {required this.currentLocale, required this.ref});
  final Locale currentLocale;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _BottomSheetContainer(
      maxHeight: 0.4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsLanguageSheetTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _LanguageOption(
              flag: '🇹🇷',
              label: l10n.languageNameTurkish,
              isSelected: currentLocale.languageCode == 'tr',
              onSelect: () async {
                await ref
                    .read(localeControllerProvider.notifier)
                    .setLocale(const Locale('tr'));
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _LanguageOption(
              flag: '🇬🇧',
              label: l10n.languageNameEnglish,
              isSelected: currentLocale.languageCode == 'en',
              onSelect: () async {
                await ref
                    .read(localeControllerProvider.notifier)
                    .setLocale(const Locale('en'));
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.isSelected,
    required this.onSelect,
  });

  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cs.primary : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 16)),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_off,
              color: isSelected ? cs.primary : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA MODEL
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileData {
  _ProfileData({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.phone,
    this.position,
    this.employeeCode,
    this.branchName,
    this.branchCity,
    this.branchDistrict,
    this.tenantName,
    this.managerFirstName,
    this.managerLastName,
    this.managerPhone,
    this.regionalManagerFirstName,
    this.regionalManagerLastName,
    this.startDate,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String? phone;
  final String? position;
  final String? employeeCode;
  final String? branchName;
  final String? branchCity;
  final String? branchDistrict;
  final String? tenantName;
  final String? managerFirstName;
  final String? managerLastName;
  final String? managerPhone;
  final String? regionalManagerFirstName;
  final String? regionalManagerLastName;
  final String? startDate;

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    if (firstName.isNotEmpty) return firstName[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  String get roleLabel {
    switch (role) {
      case 'grand_admin':
        return 'Sistem Yöneticisi';
      case 'firma_admin':
        return 'Firma Yöneticisi';
      case 'bolge_muduru':
        return 'Bölge Müdürü';
      case 'sube_muduru':
        return 'Şube Müdürü';
      case 'personel':
        return 'Personel';
      default:
        return role;
    }
  }

  String get formattedStartDate {
    if (startDate == null) return '-';
    try {
      final date = DateTime.parse(startDate!);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return '-';
    }
  }
}
