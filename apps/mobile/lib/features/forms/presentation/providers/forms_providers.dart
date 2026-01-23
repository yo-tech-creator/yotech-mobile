import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/forms_repository.dart';
import '../../domain/models/form_models.dart';
import '../../../auth/domain/providers/auth_provider.dart';

/// Repository provider
final formsRepositoryProvider = Provider<FormsRepository>((ref) {
  return FormsRepository(Supabase.instance.client);
});

/// Yayınlanmış formlar provider
final publishedFormsProvider =
    FutureProvider.autoDispose<List<PublishedForm>>((ref) async {
  final authState = ref.watch(authProvider);
  final repo = ref.watch(formsRepositoryProvider);

  return authState.maybeWhen(
    authenticated: (user) async {
      return await repo.fetchPublishedForms(
        tenantId: user.tenantId,
        userRole: user.role,
      );
    },
    orElse: () => <PublishedForm>[],
  );
});

/// Belirli bir form detayı provider
final formDetailProvider = FutureProvider.autoDispose
    .family<PublishedForm?, String>((ref, versionId) async {
  final repo = ref.watch(formsRepositoryProvider);
  return await repo.fetchFormDetail(formVersionId: versionId);
});

/// Tamamlanmış oturumlar için filtre state
class CompletedSessionsFilter {
  final String? evaluatorId;
  final String? formVersionId;
  final DateTime? startDate;
  final DateTime? endDate;

  const CompletedSessionsFilter({
    this.evaluatorId,
    this.formVersionId,
    this.startDate,
    this.endDate,
  });

  CompletedSessionsFilter copyWith({
    String? evaluatorId,
    String? formVersionId,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEvaluator = false,
    bool clearForm = false,
    bool clearDates = false,
  }) {
    return CompletedSessionsFilter(
      evaluatorId: clearEvaluator ? null : (evaluatorId ?? this.evaluatorId),
      formVersionId: clearForm ? null : (formVersionId ?? this.formVersionId),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
    );
  }

  bool get hasFilter =>
      evaluatorId != null ||
      formVersionId != null ||
      startDate != null ||
      endDate != null;
}

final completedSessionsFilterProvider =
    StateProvider<CompletedSessionsFilter>((ref) {
  return const CompletedSessionsFilter();
});

/// Tamamlanmış oturumlar provider
final completedSessionsProvider =
    FutureProvider.autoDispose<List<FormSession>>((ref) async {
  final authState = ref.watch(authProvider);
  final repo = ref.watch(formsRepositoryProvider);
  final filter = ref.watch(completedSessionsFilterProvider);

  return authState.maybeWhen(
    authenticated: (user) async {
      // Personel sadece kendi formlarını görür
      final isPersonnel = user.role == 'personel';

      return await repo.fetchCompletedSessions(
        tenantId: user.tenantId,
        branchId: user.branchId, // Şube bazlı filtreleme
        evaluatorId: isPersonnel ? user.id : filter.evaluatorId,
        formVersionId: filter.formVersionId,
        startDate: filter.startDate,
        endDate: filter.endDate,
      );
    },
    orElse: () => <FormSession>[],
  );
});

/// Şube personelleri provider (filtreleme için)
final branchPersonnelProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authState = ref.watch(authProvider);
  final repo = ref.watch(formsRepositoryProvider);

  return authState.maybeWhen(
    authenticated: (user) async {
      if (user.branchId == null) return [];
      return await repo.fetchBranchPersonnel(branchId: user.branchId!);
    },
    orElse: () => <Map<String, dynamic>>[],
  );
});

/// Tenant formları provider (filtreleme için)
final tenantFormsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authState = ref.watch(authProvider);
  final repo = ref.watch(formsRepositoryProvider);

  return authState.maybeWhen(
    authenticated: (user) async {
      return await repo.fetchTenantForms(tenantId: user.tenantId);
    },
    orElse: () => <Map<String, dynamic>>[],
  );
});

/// Oturum cevapları provider
final sessionItemsProvider = FutureProvider.autoDispose
    .family<List<FormSessionItem>, String>((ref, sessionId) async {
  final repo = ref.watch(formsRepositoryProvider);
  return await repo.fetchSessionItems(sessionId: sessionId);
});
