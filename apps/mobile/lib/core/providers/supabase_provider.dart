import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for Supabase client access.
///
/// Use this provider instead of directly accessing `Supabase.instance.client`.
/// This enables easier testing and mocking.
///
/// Usage:
/// ```dart
/// final client = ref.watch(supabaseClientProvider);
/// final user = ref.watch(supabaseUserProvider);
/// ```
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for current authenticated user.
///
/// Returns null if not authenticated.
final supabaseUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

/// Provider for auth state changes stream.
final supabaseAuthStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// Provider to check if user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(supabaseUserProvider) != null;
});
