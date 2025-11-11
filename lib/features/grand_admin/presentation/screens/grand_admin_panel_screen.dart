import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/features/settings/presentation/screens/settings_page.dart';
import 'package:yotech_mobile/features/grand_admin/domain/providers/grand_admin_providers.dart';
import '../../../auth/domain/providers/auth_provider.dart';

class GrandAdminPanelScreen extends ConsumerWidget {
  const GrandAdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    Future<bool> onBackPressed() async {
      if (Navigator.of(context).canPop()) {
        return true; // normal pop
      }
      final exit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Çıkış'),
          content: const Text('Uygulamadan çıkmak istiyor musunuz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hayır'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Evet'),
            ),
          ],
        ),
      );
      return exit == true;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Future<void>(() async {
          final allow = await onBackPressed();
          if (!context.mounted || !allow) {
            return;
          }
          Navigator.of(context).maybePop(result);
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grand Admin Panel'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final allow = await onBackPressed();
              if (!context.mounted) {
                return;
              }
              if (allow) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  // kullanıcı onay verdiyse uygulamadan çıkılabilir, burada hiçbir şey yapmıyoruz
                }
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
        body: authState.when(
          authenticated: (user) {
            final tenantsAsync = ref.watch(tenantsProvider);
            return RefreshIndicator(
              onRefresh: () async {
                // force refresh
                ref.invalidate(tenantsProvider);
                await ref.read(tenantsProvider.future);
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.purple,
                            child: Text(
                              '${user.name[0]}${user.surname[0]}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${user.name} ${user.surname}',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text('Grand Admin',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(user.email,
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 13)),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Firmalar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  tenantsAsync.when(
                    data: (tenants) {
                      if (tenants.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('Hiç firma bulunamadı.')),
                          ),
                        );
                      }
                      return SliverList.separated(
                        itemBuilder: (ctx, index) {
                          final t = tenants[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueGrey.shade100,
                              child: Text(
                                (t['name'] as String?)?.substring(0, 1) ?? '?',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(t['name'] ?? '—'),
                            subtitle: Text(t['code'] ?? ''),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TenantModulesScreen(
                                    tenantId: t['id'] as String,
                                    tenantName: t['name'] as String? ?? 'Firma',
                                    actorUserId: user.id,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemCount: tenants.length,
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (e, st) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'Firma Listesi Yüklenemedi',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              e.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => ref.invalidate(tenantsProvider),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tekrar Dene'),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            );
          },
          initial: () => const Center(child: CircularProgressIndicator()),
          loading: () => const Center(child: CircularProgressIndicator()),
          unauthenticated: () =>
              const Center(child: Text('Lütfen giriş yapın')),
          error: (error) => Center(child: Text('Hata: $error')),
        ),
      ),
    );
  }
}

class TenantModulesScreen extends ConsumerWidget {
  final String tenantId;
  final String tenantName;
  final String actorUserId;
  const TenantModulesScreen({
    super.key,
    required this.tenantId,
    required this.tenantName,
    required this.actorUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerState = ref.watch(grandAdminControllerProvider(tenantId));
    final controller =
        ref.read(grandAdminControllerProvider(tenantId).notifier);
    final modulesAsync = ref.watch(modulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('$tenantName Modüller'),
        actions: [
          IconButton(
            tooltip: 'Kaydet',
            icon: const Icon(Icons.save),
            onPressed: controllerState.isLoading
                ? null
                : () async {
                    try {
                      await controller.save(actorUserId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Değişiklikler kaydedildi'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Kaydetme hatası: $e'),
                          ),
                        );
                      }
                    }
                  },
          )
        ],
      ),
      body: controllerState.when(
        data: (map) {
          return modulesAsync.when(
            data: (modules) {
              final moduleByCode = {
                for (final module in modules) module.code: module
              };
              final orderedCodes = [
                ...modules.map((m) => m.code),
                ...map.keys.where((code) => !moduleByCode.containsKey(code)),
              ];
              return ListView.separated(
                itemCount: orderedCodes.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (ctx, i) {
                  final code = orderedCodes[i];
                  final enabled = map[code] ?? true;
                  final module = moduleByCode[code];
                  final title = module?.title ?? code;
                  final subtitle = module?.description;
                  return SwitchListTile(
                    title: Text(title),
                    subtitle: subtitle == null || subtitle.isEmpty
                        ? null
                        : Text(subtitle),
                    value: enabled,
                    onChanged: (v) => controller.toggle(code),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Modül listesi getirilemedi: $e'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(modulesProvider),
                    child: const Text('Yeniden dene'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(height: 8),
              Text('Hata: $e'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => controller.load(),
                child: const Text('Tekrar dene'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
