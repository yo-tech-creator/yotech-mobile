import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/providers/grand_admin_providers.dart';

/// Grand admin ekranı: tenant (firma) seçip o tenant için modülleri açıp/kapatma
/// işlemlerini yapabileceğiniz basit bir yönetim arayüzü.
class GrandAdminPage extends ConsumerStatefulWidget {
  const GrandAdminPage({super.key});

  @override
  ConsumerState<GrandAdminPage> createState() => _GrandAdminPageState();
}

class _GrandAdminPageState extends ConsumerState<GrandAdminPage> {
  // Seçili tenant'ın id'si
  String? _selectedTenantId;

  @override
  Widget build(BuildContext context) {
    // Tenant listesini yükleyen provider
    final tenantsAsync = ref.watch(tenantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Grand Admin - Tenant Modülleri')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            tenantsAsync.when(
              data: (tenants) {
                // Tenant seçimi için dropdown
                return DropdownButtonFormField<String>(
                  initialValue: _selectedTenantId,
                  items: tenants
                      .map((t) => DropdownMenuItem<String>(
                            value: t['id'] as String,
                            child: Text(t['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTenantId = v),
                  decoration:
                      const InputDecoration(labelText: 'Firma (Tenant)'),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => Text('Hata: $e'),
            ),
            const SizedBox(height: 12),
            if (_selectedTenantId != null)
              // Seçili tenant için modül listesi
              Expanded(child: _buildModuleList(_selectedTenantId!)),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleList(String tenantId) {
    // Controller provider: yükleme, toggle ve kaydetme işlerini yönetir
    final controller = ref.watch(grandAdminControllerProvider(tenantId));
    final modulesAsync = ref.watch(modulesProvider);

    return controller.when(
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
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: orderedCodes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final code = orderedCodes[i];
                      final module = moduleByCode[code];
                      final title = module?.title ?? code;
                      final subtitle = module?.description;
                      final value = map[code] ?? true;
                      // Her modül için aç/kapa switch'i
                      return SwitchListTile(
                        title: Text(title),
                        subtitle: subtitle == null || subtitle.isEmpty
                            ? null
                            : Text(subtitle),
                        value: value,
                        onChanged: (_) => ref
                            .read(
                                grandAdminControllerProvider(tenantId).notifier)
                            .toggle(code),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          // Kaydetme işlemi: aktif kullanıcı id'si enabled_by alanına yazılır
                          final userId =
                              Supabase.instance.client.auth.currentUser?.id ??
                                  '';
                          await ref
                              .read(grandAdminControllerProvider(tenantId)
                                  .notifier)
                              .save(userId);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kaydedildi')));
                        },
                        child: const Text('Kaydet'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(
                                grandAdminControllerProvider(tenantId).notifier)
                            .load(),
                        child: const Text('Yenile'),
                      ),
                    ],
                  ),
                ),
              ],
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
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Hata: $e')),
    );
  }
}
