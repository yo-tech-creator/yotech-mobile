import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/module_model.dart';
import '../models/tenant_module_model.dart';
import '../../data/grand_admin_repo.dart';

/// Grand admin için repository sağlayıcı.
/// Bu provider `GrandAdminRepository` örneğini döner ve Supabase client'i kullanır.
final grandAdminRepoProvider = Provider<GrandAdminRepository>((ref) {
  final supabase = Supabase.instance.client;
  return GrandAdminRepository(supabase);
});

/// Tüm modülleri yükleyen provider.
final modulesProvider = FutureProvider<List<ModuleModel>>((ref) async {
  final repo = ref.read(grandAdminRepoProvider);
  return repo.fetchModules();
});

/// Tenant (firma) listesini getiren provider.
final tenantsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(grandAdminRepoProvider);
  return repo.fetchTenants();
});

/// Belirli bir tenant için tenant_modules kayıtlarını dönen provider.
final tenantModulesProvider =
    FutureProvider.family<List<TenantModuleModel>, String>(
        (ref, tenantId) async {
  final repo = ref.read(grandAdminRepoProvider);
  return repo.fetchTenantModules(tenantId);
});

/// Grand admin ekranı için kontroller. Bu sınıf:
/// - Modül listesini ve tenant bazlı durumlarını yükler
/// - Kullanıcının toggle (aç/kapa) işlemlerini uygular
/// - Değişiklikleri kaydetmek için repository'yi çağırır
class GrandAdminController
    extends StateNotifier<AsyncValue<Map<String, bool>>> {
  final Ref ref;
  final String tenantId;

  GrandAdminController(this.ref, this.tenantId)
      : super(const AsyncValue.loading());

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final modules = await ref.read(grandAdminRepoProvider).fetchModules();
      final tenantMods =
          await ref.read(grandAdminRepoProvider).fetchTenantModules(tenantId);
      final map = <String, bool>{};
      for (final m in modules) {
        // Tenant için tenant_modules tablosunda bir kayıt varsa ona göre
        // değerlendir, yoksa varsayılan davranış olarak true kullan.
        final found = tenantMods.where((t) => t.moduleCode == m.code).toList();
        if (found.isNotEmpty) {
          map[m.code] = found.first.isEnabled;
        } else {
          map[m.code] = true;
        }
      }
      state = AsyncValue.data(map);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void toggle(String moduleCode) {
    final cur = state.value ?? {};
    final newMap = Map<String, bool>.from(cur);
    newMap[moduleCode] = !(newMap[moduleCode] ?? false);
    state = AsyncValue.data(newMap);
  }

  Future<void> save(String actorUserId) async {
    final cur = state.value ?? {};
    for (final entry in cur.entries) {
      await ref.read(grandAdminRepoProvider).setTenantModule(
            tenantId: tenantId,
            moduleCode: entry.key,
            isEnabled: entry.value,
            enabledByUserId: actorUserId,
          );
    }
  }
}

final grandAdminControllerProvider = StateNotifierProvider.family<
    GrandAdminController,
    AsyncValue<Map<String, bool>>,
    String>((ref, tenantId) {
  final c = GrandAdminController(ref, tenantId);
  c.load();
  return c;
});
