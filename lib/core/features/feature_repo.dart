import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final effectiveFeaturesProvider = FutureProvider<Map<String, bool>>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    
    print('📱 DEBUG: userId = $userId');
    
    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    // RPC fonksiyonu ile kullanıcı verisi al (RLS bypass)
    final userData = await supabase
        .rpc('get_user_data_by_id', params: {'p_user_id': userId})
        .maybeSingle();

    print('📱 DEBUG: userData = $userData');

    if (userData == null) {
      throw Exception('Kullanıcı verisi bulunamadı - RPC fonksiyonu başarısız');
    }

    final tenantId = userData['tenant_id'] as String?;
    if (tenantId == null || tenantId.isEmpty) {
      throw Exception('Tenant ID bulunamadı');
    }

    print('📱 DEBUG: tenantId = $tenantId');

    // Tenant'ın modül erişimlerini al
    final tenantData = await supabase
        .from('tenants')
        .select('module_skt, module_tasks, module_attendance, module_shifts, '
            'module_forms, module_malfunctions, module_transfers, module_performance, module_payroll')
        .eq('id', tenantId)
        .maybeSingle();

    print('📱 DEBUG: tenantData = $tenantData');

    if (tenantData == null) {
      throw Exception('Tenant modül ayarları bulunamadı - tenants tablosunda kayıt yok');
    }

    return {
      'skt': tenantData['module_skt'] == true,
      'forms': tenantData['module_forms'] == true,
      'shifts': tenantData['module_shifts'] == true,
      'announcements': true, // Her zaman aktif (ayrı modül yok)
      'tasks': tenantData['module_tasks'] == true,
      'interbranch_transfer': tenantData['module_transfers'] == true,
      'leave_request': true, // Her zaman aktif (ayrı modül yok)
      'break_tracking': true, // Her zaman aktif (ayrı modül yok)
      'it_ticket': tenantData['module_malfunctions'] == true,
      'instore_shortage': true, // Her zaman aktif (ayrı modül yok)
      'time_attendance': tenantData['module_attendance'] == true,
      'merchandising': true, // Her zaman aktif (ayrı modül yok)
      'profile': true, // Her zaman aktif
      'requests': true, // Her zaman aktif
    };
  } on PostgrestException catch (e) {
    print('❌ DEBUG: PostgrestException - ${e.message}');
    throw Exception('Veritabanı hatası: ${e.message}');
  } catch (e) {
    print('❌ DEBUG: Exception - $e');
    // Geliştirme sırasında fallback - tüm özellikleri aktif et
    print('⚠️ FALLBACK: Tüm özellikler aktif edildi (geliştirme modu)');
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
      'requests': true,
    };
  }
});
