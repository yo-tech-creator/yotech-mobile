import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/grand_admin/presentation/screens/grand_admin_panel_screen.dart';
import '../../features/home/presentation/screens/home_shell.dart';
import '../../features/inventory_transfer/data/models/inventory_transfer_model.dart';
import '../../features/inventory_transfer/presentation/screens/create_notice_screen.dart';
import '../../features/inventory_transfer/presentation/screens/inventory_transfer_list_screen.dart';
import '../../features/inventory_transfer/presentation/screens/notice_detail_screen.dart';

final appRouterProvider = Provider<AppRouter>((ref) {
  return AppRouter(ref);
});

class AppRouter {
  final Ref _ref;

  AppRouter(this._ref);

  // Route isimleri
  static const String login = '/login';
  static const String grandAdminPanel = '/grand-admin';
  static const String home = '/home';
  static const String inventoryTransferList = '/inventory-transfer';
  static const String createInventoryTransfer = '/inventory-transfer/create';
  static const String inventoryTransferDetail = '/inventory-transfer/detail';

  // Route generator
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case grandAdminPanel:
        return MaterialPageRoute(builder: (_) => const GrandAdminPanelScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeShell());
      case inventoryTransferList:
        return MaterialPageRoute(builder: (_) => const InventoryTransferListScreen());
      case createInventoryTransfer:
        return MaterialPageRoute(builder: (_) => const CreateNoticeScreen());
      case inventoryTransferDetail:
        final notice = settings.arguments as DepotNotice;
        return MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: notice));
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }

  Widget getInitialScreen() {
    final authState = _ref.watch(authProvider);

    return authState.when(
      initial: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      authenticated: (user) {
        switch (user.role) {
          case 'grand_admin':
            return const GrandAdminPanelScreen();
          case 'firma_admin':
          case 'bolge_muduru':
          case 'sube_muduru':
          case 'personel':
            return const HomeShell();
          default:
            return const LoginScreen();
        }
      },
      unauthenticated: () => const LoginScreen(),
      error: (message) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Hata: $message'),
              ElevatedButton(
                onPressed: () => _ref.read(authProvider.notifier).checkAuth(),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
