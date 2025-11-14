import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/module_model.dart';
import '../domain/models/tenant_module_model.dart';

class GrandAdminRepository {
  final SupabaseClient _supabase;

  GrandAdminRepository(this._supabase);

  Future<List<ModuleModel>> fetchModules() async {
    final res = await _supabase
        .from('modules')
        .select('code, name, description, display_order')
        .order('display_order');
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(ModuleModel.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> fetchTenants() async {
    dynamic rpcResult;

    try {
      rpcResult = await _supabase.rpc('grand_admin_list_tenants');
      developer.log('fetchTenants rpc result: $rpcResult',
          name: 'grand_admin_repo');
    } on PostgrestException catch (e) {
      // RPC yetkisi yoksa loglayıp REST sorgusuna düş
      developer.log('fetchTenants rpc error: ${e.message} (${e.code})',
          error: e, name: 'grand_admin_repo');
    } catch (e) {
      developer.log('fetchTenants rpc unexpected error: $e',
          name: 'grand_admin_repo');
    }

    if (rpcResult is List) {
      final list = rpcResult.cast<Map<String, dynamic>>();
      developer.log('fetchTenants rpc count: ${list.length}',
          name: 'grand_admin_repo');
      return list;
    }

    try {
      final res = await _supabase
          .from('tenants')
          .select('id, name, code, active')
          .order('name');

      developer.log('fetchTenants REST raw response: $res',
          name: 'grand_admin_repo');

      final list = (res as List).cast<Map<String, dynamic>>();
      final active = list.where((t) {
        final value = t['active'];
        if (value is bool) return value;
        if (value is String) {
          return value.toLowerCase() == 'true' || value.toLowerCase() == 't';
        }
        if (value is num) {
          return value != 0;
        }
        return false;
      }).toList();

      developer.log('fetchTenants REST active count: ${active.length}',
          name: 'grand_admin_repo');
      return active;
    } catch (e) {
      developer.log('fetchTenants REST error: $e', name: 'grand_admin_repo');
      rethrow;
    }
  }

  Future<List<TenantModuleModel>> fetchTenantModules(String tenantId) async {
    // Normalleştirilmiş tenant_modules tablosunu tercih ederiz. Bu tablo,
    // tenant -> module ilişkinin durumunu (is_enabled) saklar ve genişlemeye
    // daha uygundur.
    final res = await _supabase
        .from('tenant_modules')
        .select('module_code, is_enabled')
        .eq('tenant_id', tenantId);
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(TenantModuleModel.fromMap).toList();
  }

  Future<void> setTenantModule({
    required String tenantId,
    required String moduleCode,
    required bool isEnabled,
    String? enabledByUserId,
  }) async {
    // tenant_modules tablosuna upsert yapar (yeni kayıt ekler veya var olanı günceller).
    final payload = {
      'tenant_id': tenantId,
      'module_code': moduleCode,
      'is_enabled': isEnabled,
      'enabled_by': enabledByUserId,
    };
    // onConflict parametresi virgülle ayrılmış kolon listesi bekler.
    await _supabase
        .from('tenant_modules')
        .upsert(payload, onConflict: 'tenant_id,module_code');
  }
}
