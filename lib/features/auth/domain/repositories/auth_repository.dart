import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // Sicil No ile login
  Future<UserModel> login({
    required String sicilNo,
    required String password,
  }) async {
    try {
      // 1. RPC ile employee_code'dan email ve aktiflik bilgisini al (RLS bypass)
      final emailResponse = await _supabase.rpc('get_user_email_by_sicil',
          params: {'p_sicil_no': sicilNo}).maybeSingle();

      if (emailResponse == null) {
        throw Exception('Kullanıcı bulunamadı');
      }

      // Kullanıcı aktif mi kontrol et
      final isActive = emailResponse['active'] as bool? ?? false;
      if (!isActive) {
        throw Exception('Kullanıcı hesabı aktif değil');
      }

      final email = emailResponse['email'] as String;

      // 2. Supabase auth ile email/password ile giriş yap
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Giriş başarısız - Şifre hatalı');
      }

      // 3. Login başarılı - RPC ile kullanıcı bilgilerini al (enum-safe)
      final userResponse = await _supabase.rpc('get_user_data_by_id',
          params: {'p_user_id': authResponse.user!.id}).maybeSingle();

      if (userResponse == null) {
        // RPC döndü ancak kayıt bulunamadı
        throw Exception(
            'Kullanıcı verisi bulunamadı (get_user_data_by_id returned no rows)');
      }

      // 4. UserModel oluştur
      return UserModel(
        id: userResponse['id'] as String,
        email: userResponse['email'] as String,
        name: userResponse['first_name'] as String,
        surname: userResponse['last_name'] as String,
        role: userResponse['role'] as String,
        tenantId: userResponse['tenant_id'] as String,
        branchId: userResponse['branch_id'] as String?,
        regionId: null, // Users tablosunda region_id yok
        sicilNo: userResponse['employee_code'] as String?,
      );
    } on AuthException catch (e) {
      // Supabase auth hataları
      if (e.message.contains('Invalid login credentials')) {
        throw Exception('Şifre hatalı');
      } else if (e.message.contains('Email not confirmed')) {
        throw Exception('Email onaylanmamış');
      } else {
        throw Exception('Giriş hatası: ${e.message}');
      }
    } on PostgrestException catch (e) {
      // Database hataları
      throw Exception('Veritabanı hatası: ${e.message}');
    } catch (e) {
      throw Exception('Giriş hatası: ${e.toString()}');
    }
  }

  // Get current user
  Future<UserModel?> getCurrentUser() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return null;

      final response = await _supabase.rpc('get_user_data_by_id',
          params: {'p_user_id': currentUser.id}).maybeSingle();

      if (response == null) {
        // RPC fonksiyonu bulunamadı veya veri yok
        developer.log('⚠️ DEBUG: get_user_data_by_id RPC response null',
            name: 'auth_repository');
        return null;
      }

      return UserModel(
        id: response['id'] as String,
        email: response['email'] as String,
        name: response['first_name'] as String,
        surname: response['last_name'] as String,
        role: response['role'] as String,
        tenantId: response['tenant_id'] as String,
        branchId: response['branch_id'] as String?,
        regionId: null,
        sicilNo: response['employee_code'] as String?,
      );
    } on PostgrestException catch (e) {
      developer.log('⚠️ DEBUG: PostgrestException - ${e.message}',
          name: 'auth_repository');
      return null;
    } catch (e) {
      developer.log('⚠️ DEBUG: Exception - $e', name: 'auth_repository');
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // Auth state changes stream
  Stream<UserModel?> authStateChanges() {
    return _supabase.auth.onAuthStateChange.asyncMap((data) async {
      if (data.session?.user == null) return null;

      try {
        final userData = await _supabase.rpc('get_user_data_by_id',
            params: {'p_user_id': data.session!.user.id}).maybeSingle();

        if (userData == null) return null;

        return UserModel(
          id: userData['id'] as String,
          email: userData['email'] as String,
          name: userData['first_name'] as String,
          surname: userData['last_name'] as String,
          role: userData['role'] as String,
          tenantId: userData['tenant_id'] as String,
          branchId: userData['branch_id'] as String?,
          regionId: null,
          sicilNo: userData['employee_code'] as String?,
        );
      } catch (e) {
        return null;
      }
    });
  }
}
