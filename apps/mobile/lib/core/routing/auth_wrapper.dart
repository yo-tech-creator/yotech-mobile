import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/grand_admin/presentation/screens/grand_admin_panel_screen.dart';
import '../../features/home/presentation/screens/home_shell.dart';
import '../../features/region_manager/presentation/screens/region_manager_dashboard_screen.dart';
import '../../features/firma_admin/presentation/screens/firma_admin_dashboard_screen.dart';

/// Auth durumuna göre otomatik ekran yönlendirmesi yapan wrapper widget.
///
/// Bu widget authProvider'ı dinler ve state değiştiğinde
/// otomatik olarak doğru ekrana yönlendirir.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Her build'de state'i logla
    debugPrint('🏠 [AuthWrapper] build - state: ${authState.runtimeType}');

    // Auth state değiştiğinde tamamen yeni widget tree oluştur
    // Bu sayede logout olduğunda eski ekranlar temizlenir
    return authState.when(
      initial: () => const Scaffold(
        key: ValueKey('loading'),
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Yükleniyor...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
      loading: () => const Scaffold(
        key: ValueKey('loading'),
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Oturum kontrol ediliyor...',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
      authenticated: (user) {
        // Her kullanıcı için unique key - kullanıcı değişince widget yenilenir
        final userKey = ValueKey('auth_${user.id}');
        debugPrint('🏠 [AuthWrapper] authenticated - role: ${user.role}');
        switch (user.role) {
          case 'grand_admin':
            return GrandAdminPanelScreen(key: userKey);
          case 'bolge_muduru':
            return RegionManagerDashboardScreen(key: userKey);
          case 'firma_admin':
            return FirmaAdminDashboardScreen(key: userKey);
          case 'sube_muduru':
          case 'personel':
            return HomeShell(key: userKey);
          default:
            debugPrint(
                '🚨 [AuthWrapper] UNKNOWN ROLE: ${user.role} -> LoginScreen!');
            return const LoginScreen(key: ValueKey('login_unknown_role'));
        }
      },
      unauthenticated: () => const LoginScreen(key: ValueKey('login')),
      error: (message) => Scaffold(
        key: const ValueKey('error'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Hata: $message'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(authProvider.notifier).checkAuth(),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
