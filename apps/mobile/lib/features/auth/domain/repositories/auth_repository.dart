import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  // Cache key for user data
  static const String _userCacheKey = 'cached_user_data';

  AuthRepository(this._supabase);

  /// Cache user data to SharedPreferences
  Future<void> _cacheUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(user.toJson());
      debugPrint('🔍 [Repository] Caching user: ${user.id} - ${user.name}');
      debugPrint('🔍 [Repository] JSON length: ${jsonStr.length}');
      await prefs.setString(_userCacheKey, jsonStr);
      // Verify it was saved
      final verify = prefs.getString(_userCacheKey);
      debugPrint(
          '🔍 [Repository] User cached successfully, verified: ${verify != null}');
    } catch (e) {
      debugPrint('🔍 [Repository] Cache yazma hatası: $e');
    }
  }

  /// Get cached user from SharedPreferences
  Future<UserModel?> _getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_userCacheKey);
      debugPrint(
          '🔍 [Repository] Cache jsonStr: ${jsonStr != null ? "VAR (${jsonStr.length} chars)" : "NULL"}');
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        debugPrint('🔍 [Repository] User loaded from cache: ${json['name']}');
        return UserModel.fromJson(json);
      }
    } catch (e) {
      debugPrint('🔍 [Repository] Cache okuma hatası: $e');
    }
    return null;
  }

  /// Clear user cache (on logout)
  Future<void> _clearUserCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userCacheKey);
      debugPrint('🔍 [Repository] User cache cleared');
    } catch (e) {
      debugPrint('🔍 [Repository] Cache silme hatası: $e');
    }
  }

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
      final isActive = emailResponse['is_active'] as bool? ?? false;
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
      final user = UserModel(
        id: userResponse['id'] as String,
        email: userResponse['email'] as String,
        name: userResponse['first_name'] as String,
        surname: userResponse['last_name'] as String,
        role: userResponse['role'] as String,
        tenantId: userResponse['tenant_id'] as String,
        branchId: userResponse['branch_id'] as String?,
        regionId: null, // Users tablosunda region_id yok
        sicilNo: userResponse['employee_code'] as String?,
        departmentId: userResponse['department_id'] as String?,
      );

      // Cache'e kaydet
      await _cacheUser(user);

      return user;
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
      if (e.code == 'PGRST116') {
        throw Exception('Kullanıcı bulunamadı');
      }
      throw Exception('Veritabanı hatası: ${e.message}');
    } catch (e) {
      // Eğer Exception içindeyse mesajını çıkar
      final msg = e.toString();
      if (msg.startsWith('Exception: ')) {
        throw Exception(msg.substring(11));
      }
      throw Exception(msg);
    }
  }

  // Get current user
  Future<UserModel?> getCurrentUser() async {
    try {
      debugPrint('🔍 [Repository] getCurrentUser başladı');

      // Session'ın recover edilmesini bekle (bildirimden açılınca gerekli)
      // Supabase session recovery async olabilir - birkaç deneme yap
      User? currentUser;
      for (int i = 0; i < 15; i++) {
        currentUser = _supabase.auth.currentUser;
        if (currentUser != null) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (currentUser == null) {
        debugPrint('🔍 [Repository] ❌ currentUser null after 15 retries');
        return null;
      }

      debugPrint('🔍 [Repository] ✅ currentUser found: ${currentUser.id}');

      // Session ve token durumunu kontrol et
      final session = _supabase.auth.currentSession;
      final tokenPreview =
          session != null ? session.accessToken.substring(0, 20) : "NULL";
      debugPrint(
          '🔍 [Repository] session: ${session != null}, accessToken: $tokenPreview...');

      // RPC çağrısını dene - network hatası olabilir
      UserModel? user;
      bool networkError = false;

      try {
        // Session token'ının hazır olması için biraz bekle
        await Future.delayed(const Duration(milliseconds: 300));

        // RPC çağrısını retry ile yap
        Map<String, dynamic>? response;
        for (int i = 0; i < 2; i++) {
          debugPrint('🔍 [Repository] RPC çağrısı ${i + 1}/2...');
          try {
            response = await _supabase.rpc('get_user_data_by_id',
                params: {'p_user_id': currentUser.id}).maybeSingle();
            debugPrint(
                '🔍 [Repository] RPC response: ${response != null ? "VAR" : "NULL"}');
            if (response != null) break;
          } catch (rpcError) {
            debugPrint('🔍 [Repository] RPC hatası: $rpcError');
            // Network hatası mı kontrol et
            if (rpcError.toString().contains('SocketException') ||
                rpcError.toString().contains('Failed host lookup')) {
              networkError = true;
              break;
            }
          }
          await Future.delayed(const Duration(milliseconds: 300));
        }

        if (response != null) {
          user = UserModel(
            id: response['id'] as String,
            email: response['email'] as String,
            name: response['first_name'] as String,
            surname: response['last_name'] as String,
            role: response['role'] as String,
            tenantId: response['tenant_id'] as String,
            branchId: response['branch_id'] as String?,
            regionId: null,
            sicilNo: response['employee_code'] as String?,
            departmentId: response['department_id'] as String?,
          );

          // Başarılı oldu, cache'e kaydet
          await _cacheUser(user);
          debugPrint('🔍 [Repository] ✅ User from network: ${user.name}');
          return user;
        }
      } catch (e) {
        debugPrint('🔍 [Repository] Network hatası: $e');
        networkError = true;
      }

      // Network hatası varsa cache'ten oku
      if (networkError) {
        debugPrint(
            '🔍 [Repository] 🔄 Network hatası - cache kontrol ediliyor...');
        final cachedUser = await _getCachedUser();
        debugPrint(
            '🔍 [Repository] cachedUser: ${cachedUser != null ? cachedUser.id : "NULL"}');
        debugPrint('🔍 [Repository] currentUser.id: ${currentUser.id}');
        if (cachedUser != null && cachedUser.id == currentUser.id) {
          debugPrint('🔍 [Repository] ✅ User from cache: ${cachedUser.name}');
          return cachedUser;
        } else {
          debugPrint('🔍 [Repository] ❌ Cache uyumsuz veya boş');
        }
      }

      debugPrint('🔍 [Repository] ❌ User bulunamadı');
      return null;
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
    await _clearUserCache();
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
          departmentId: userData['department_id'] as String?,
        );
      } catch (e) {
        return null;
      }
    });
  }
}
