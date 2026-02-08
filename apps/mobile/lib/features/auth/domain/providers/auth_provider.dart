import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../models/auth_state.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  StreamSubscription? _authSubscription;
  bool _isAuthenticating = false; // Race condition önlemek için

  AuthNotifier(this._repository) : super(const AuthState.loading()) {
    // ÖNCE listener'ı kur ki initialSession event'ini yakalayalım
    _setupAuthListener();
    // Sonra session check yap
    _init();
  }

  Future<void> _init() async {
    debugPrint('🔐 AuthNotifier._init() başladı');

    // Session varsa ve listener henüz auth yapmadıysa bekle
    // Listener'ın initialSession event'i ile auth yapmasını tercih ediyoruz
    // Çünkü o event session'ın gerçekten hazır olduğunu garantiliyor
    final currentSession = Supabase.instance.client.auth.currentSession;
    debugPrint('🔐 İlk kontrol - session: ${currentSession != null ? "VAR" : "YOK"}');
    
    if (currentSession == null) {
      // Session yok, listener'dan initialSession event'ini bekle
      debugPrint('🔐 Session yok, initialSession event bekleniyor (max 2s)...');
      await Future.delayed(const Duration(milliseconds: 2000));
      
      // Delay sonrası kontrol - belki listener auth yaptı
      final alreadyAuth = state.maybeWhen(
        authenticated: (_) => true,
        orElse: () => false,
      );
      
      if (!alreadyAuth && mounted) {
        debugPrint('🔐 2s sonra hala auth değil, unauthenticated');
        state = const AuthState.unauthenticated();
      }
    }
    // Session varsa listener'ın initialSession event'i ile auth yapmasını bekle
    // _init burada hiçbir şey yapmıyor, tüm iş listener'da
  }
  
  Future<void> _authenticateWithSession() async {
    // Race condition önleme - sadece bir kere auth yapsın
    if (_isAuthenticating) {
      debugPrint('🔐 Zaten auth işlemi devam ediyor, atlanıyor');
      return;
    }
    
    // Zaten authenticated ise yapma
    final alreadyAuth = state.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );
    if (alreadyAuth) {
      debugPrint('🔐 Zaten authenticated, atlanıyor');
      return;
    }
    
    _isAuthenticating = true;
    debugPrint('🔐 Session bulundu, user çekiliyor...');
    
    try {
      debugPrint('🔐 _repository.getCurrentUser() çağrılıyor...');
      final user = await _repository.getCurrentUser();
      debugPrint('🔐 _repository.getCurrentUser() döndü: ${user?.name ?? "NULL"}');
      
      if (user != null && mounted) {
        state = AuthState.authenticated(user);
        debugPrint('🔐 ✅ Authenticated: ${user.name}');
      } else if (mounted) {
        state = const AuthState.unauthenticated();
        debugPrint('🔐 ❌ User null, unauthenticated');
      }
    } catch (e, stackTrace) {
      debugPrint('🔐 ❌ User fetch EXCEPTION: $e');
      debugPrint('🔐 ❌ Stack trace: $stackTrace');
      if (mounted) {
        state = const AuthState.unauthenticated();
      }
    } finally {
      _isAuthenticating = false;
    }
  }

  void _setupAuthListener() {
    // Sadece gerçek login/logout event'lerini dinle
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        debugPrint('🔐 Auth event: ${data.event}');

        // initialSession - session yüklendi, auth yap
        if (data.event == AuthChangeEvent.initialSession) {
          debugPrint('🔐 initialSession event geldi');
          final session = data.session;
          if (session != null) {
            // _authenticateWithSession race condition korumalı
            await _authenticateWithSession();
          } else {
            debugPrint('🔐 initialSession ama session null');
          }
          return;
        }
        
        // Token yenileme - state değiştirme
        if (data.event == AuthChangeEvent.tokenRefreshed) {
          debugPrint('🔐 Token yenilendi');
          return;
        }
        
        // SIGNED_IN - Kullanıcı login() ile giriş yaptı
        if (data.event == AuthChangeEvent.signedIn) {
          // login() fonksiyonu zaten state'i ayarlıyor, burada bir şey yapma
          debugPrint('🔐 signedIn event - login() halletti');
          return;
        }
        
        // SIGNED_OUT - Kullanıcı çıkış yaptı
        if (data.event == AuthChangeEvent.signedOut) {
          debugPrint('🔐 signedOut - unauthenticated');
          state = const AuthState.unauthenticated();
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> login({
    required String sicilNo,
    required String password,
  }) async {
    try {
      final user = await _repository.login(
        sicilNo: sicilNo,
        password: password,
      );
      state = AuthState.authenticated(user);
    } catch (e) {
      state = const AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState.unauthenticated();
  }

  Future<void> checkAuth() async {
    state = const AuthState.loading();
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      state = const AuthState.unauthenticated();
    }
  }
}
