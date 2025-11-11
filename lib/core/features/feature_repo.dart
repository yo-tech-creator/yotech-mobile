import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final effectiveFeaturesProvider =
    FutureProvider<Map<String, bool>>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    developer.log('📱 DEBUG: userId = $userId', name: 'feature_repo');

    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    // RPC fonksiyonu ile kullanıcı verisi al (RLS bypass)
    final userData = await supabase.rpc('get_user_data_by_id',
        params: {'p_user_id': userId}).maybeSingle();

    developer.log('📱 DEBUG: userData = $userData', name: 'feature_repo');

    if (userData == null) {
      throw Exception('Kullanıcı verisi bulunamadı - RPC fonksiyonu başarısız');
    }

    final tenantId = userData['tenant_id'] as String?;
    if (tenantId == null || tenantId.isEmpty) {
      throw Exception('Tenant ID bulunamadı');
    }

    developer.log('📱 DEBUG: tenantId = $tenantId', name: 'feature_repo');

    final modulesRes =
        await supabase.from('modules').select('code, active, is_core');

    developer.log('📱 DEBUG: modules = $modulesRes', name: 'feature_repo');

    final tenantModulesRes = await supabase
        .from('tenant_modules')
        .select('module_code, is_enabled')
        .eq('tenant_id', tenantId);

    developer.log('📱 DEBUG: tenantModules = $tenantModulesRes',
        name: 'feature_repo');

    final overrides = <String, bool>{};
    for (final item in (tenantModulesRes as List? ?? [])) {
      final map = (item as Map<String, dynamic>);
      final code = map['module_code'] as String?;
      if (code == null) continue;
      final value = map['is_enabled'];
      overrides[code] = value == true;
    }

    final moduleStates = <String, bool>{};
    for (final item in (modulesRes as List)) {
      final map = item as Map<String, dynamic>;
      final code = map['code'] as String;
      final isCore = map['is_core'] == true;
      final globallyActive = map['active'] != false;
      final override = overrides[code];
      var enabled = override ?? globallyActive;
      if (isCore) enabled = true;
      moduleStates[code] = enabled;
    }

    bool enabled(String code) => moduleStates[code] ?? false;

    return {
      'skt': enabled('skt'),
      'forms': enabled('form_management'),
      'shifts': enabled('shift_management') || enabled('takvim'),
      'announcements': enabled('announcements'),
      'tasks': enabled('task_management'),
      'interbranch_transfer': enabled('inventory_transfers'),
      'leave_request': enabled('talep'),
      'break_tracking': enabled('break_tracking'),
      'it_ticket': enabled('malfunction_reports'),
      'instore_shortage': enabled('stoksuz'),
      'time_attendance': enabled('puantaj'),
      'merchandising': enabled('merchandising'),
      'profile': true,
    };
  } on PostgrestException catch (e) {
    developer.log('❌ DEBUG: PostgrestException - ${e.message}',
        name: 'feature_repo');
    throw Exception('Veritabanı hatası: ${e.message}');
  } catch (e) {
    developer.log('❌ DEBUG: Exception - $e', name: 'feature_repo');
    // Geliştirme sırasında fallback - tüm özellikleri aktif et
    developer.log('⚠️ FALLBACK: Tüm özellikler aktif edildi (geliştirme modu)',
        name: 'feature_repo');
    return {
      'skt': true,
      'forms': true,
      'shifts': true,
      'announcements': true,
      'tasks': true,
      'interbranch_transfer': true,
      'leave_request': true,
      'break_tracking': true,
      'it_ticket': true,
      'instore_shortage': true,
      'time_attendance': true,
      'merchandising': true,
      'profile': true,
    };
  }
});
