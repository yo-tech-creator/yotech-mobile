import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/grand_admin/presentation/screens/grand_admin_panel_screen.dart';
import '../../features/home/presentation/screens/home_shell.dart';
import '../../features/region_manager/presentation/screens/region_manager_dashboard_screen.dart';

/// Auth işlemleri sonrası navigation yardımcı fonksiyonları.
/// DRY prensibine uygun olarak tüm logout/login sonrası navigasyonlar buradan yapılır.
class AuthNavigationHelper {
  /// Logout sonrası login ekranına yönlendirir.
  /// Tüm navigation stack'i temizler.
  static Future<void> navigateToLogin(BuildContext context) async {
    if (!context.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    });
  }

  /// Login başarılı olduktan sonra role göre ana ekrana yönlendirir.
  static Future<void> navigateToHome(
      BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;

    final authState = ref.read(authProvider);

    authState.whenOrNull(
      authenticated: (user) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;

          Widget homeScreen;
          switch (user.role) {
            case 'grand_admin':
              homeScreen = const GrandAdminPanelScreen();
              break;
            case 'bolge_muduru':
              homeScreen = const RegionManagerDashboardScreen();
              break;
            case 'firma_admin':
            case 'sube_muduru':
            case 'personel':
            default:
              homeScreen = const HomeShell();
              break;
          }

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => homeScreen),
            (route) => false,
          );
        });
      },
    );
  }

  /// Logout işlemini yapar ve login ekranına yönlendirir.
  /// Onay dialog'u gösterir.
  static Future<void> confirmAndLogout({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: const Text('Oturum kapatılıp giriş ekranına dönülecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Çıkış'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(authProvider.notifier).logout();
    await navigateToLogin(context);
  }
}
