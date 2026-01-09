import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/core/localization/locale_controller.dart';
import 'package:yotech_mobile/core/localization/localization_extensions.dart';
import 'package:yotech_mobile/features/settings/presentation/screens/notification_settings_page.dart';
import 'package:yotech_mobile/features/settings/presentation/screens/personal_info_page.dart';
import 'package:yotech_mobile/features/settings/presentation/screens/team_members_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authUser = _client.auth.currentUser;
    final firstName = authUser?.userMetadata?['first_name'] as String?;
    final lastName = authUser?.userMetadata?['last_name'] as String?;
    final metadataName = [firstName, lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    final displayName = metadataName.isNotEmpty
        ? metadataName
        : (authUser?.userMetadata?['full_name'] as String?) ??
            authUser?.email ??
            l10n.settingsDefaultDisplayName;
    final role = authUser?.userMetadata?['role'] as String? ??
        authUser?.userMetadata?['title'] as String? ??
        l10n.settingsDefaultRole;
    final locale = ref.watch(localeControllerProvider);
    final languageLabel = _languageLabel(context, locale.languageCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName.substring(0, 1).toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          role,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.settingsSectionAccount),
          _MenuTile(
            icon: Icons.person_outline,
            title: l10n.settingsPersonalInfoTitle,
            subtitle: l10n.settingsPersonalInfoSubtitle,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PersonalInfoPage()),
              );
            },
          ),
          _MenuTile(
            icon: Icons.groups_outlined,
            title: l10n.settingsTeamTitle,
            subtitle: l10n.settingsTeamSubtitle,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TeamMembersPage()),
              );
            },
          ),
          const SizedBox(height: 24),
          _SectionTitle(l10n.settingsSectionOther),
          _MenuTile(
            icon: Icons.language,
            title: l10n.settingsLanguageTitle,
            subtitle: l10n.settingsLanguageSubtitle(languageLabel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(languageLabel),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showLanguageSheet(locale),
          ),
          _MenuTile(
            icon: Icons.notifications_outlined,
            title: l10n.settingsNotificationsTitle,
            subtitle: l10n.settingsNotificationsSubtitle,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsPage(),
                ),
              );
            },
          ),
          _MenuTile(
            icon: Icons.description_outlined,
            title: l10n.settingsContractsTitle,
            subtitle: l10n.settingsContractsSubtitle,
            onTap: () {},
          ),
          const SizedBox(height: 32),
          Text(
            l10n.settingsVersionLabel('3.0.2'),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _handleLogout,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(l10n.settingsLogoutButton),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await _client.auth.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settingsLogoutSuccess)),
    );
  }

  Future<void> _showLanguageSheet(Locale currentLocale) async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      builder: (bottomSheetContext) {
        return _LanguageBottomSheet(
          selectedLocale: currentLocale,
        );
      },
    );
    if (selected == null || selected == currentLocale) return;
    await ref.read(localeControllerProvider.notifier).setLocale(selected);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsLanguageChanged)),
    );
  }

  String _languageLabel(BuildContext context, String code) {
    final l10n = context.l10n;
    switch (code) {
      case 'en':
        return l10n.languageNameEnglish;
      case 'tr':
      default:
        return l10n.languageNameTurkish;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.grey[600],
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _LanguageBottomSheet extends ConsumerWidget {
  const _LanguageBottomSheet({required this.selectedLocale});

  final Locale selectedLocale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsLanguageSheetTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsLanguageSheetDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...supportedAppLocales.map((locale) {
              final isSelected =
                  locale.languageCode == selectedLocale.languageCode;
              final label = locale.languageCode == 'en'
                  ? l10n.languageNameEnglish
                  : l10n.languageNameTurkish;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).iconTheme.color,
                ),
                title: Text(label),
                onTap: () => Navigator.of(context).pop(locale),
              );
            }),
          ],
        ),
      ),
    );
  }
}
