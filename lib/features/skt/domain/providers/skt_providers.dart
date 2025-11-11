import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/domain/providers/auth_provider.dart';
import '../../data/skt_repository.dart';
import '../models/branch_summary_model.dart';
import '../models/product_summary_model.dart';
import '../models/skt_record_model.dart';

enum SktTimelineFilter {
  all,
  week1,
  week2,
  week3,
  month1,
  month2,
  month3,
}

extension SktTimelineFilterDurationX on SktTimelineFilter {
  Duration? get maxDuration {
    switch (this) {
      case SktTimelineFilter.all:
        return null;
      case SktTimelineFilter.week1:
        return const Duration(days: 7);
      case SktTimelineFilter.week2:
        return const Duration(days: 14);
      case SktTimelineFilter.week3:
        return const Duration(days: 21);
      case SktTimelineFilter.month1:
        return const Duration(days: 30);
      case SktTimelineFilter.month2:
        return const Duration(days: 60);
      case SktTimelineFilter.month3:
        return const Duration(days: 90);
    }
  }
}

final sktRepositoryProvider = Provider<SktRepository>((ref) {
  return SktRepository(Supabase.instance.client);
});

final sktTimelineFilterProvider =
    StateProvider<SktTimelineFilter>((ref) => SktTimelineFilter.all);

final sktSearchQueryProvider = StateProvider<String>((ref) => '');

final sktRecordsProvider =
    FutureProvider.autoDispose<List<SktRecordModel>>((ref) async {
  final authState = ref.watch(authProvider);
  final repository = ref.watch(sktRepositoryProvider);

  return await authState.maybeWhen(
    authenticated: (user) => repository.fetchRecords(
      tenantId: user.tenantId,
      branchId: user.branchId,
    ),
    orElse: () async => <SktRecordModel>[],
  );
});

final sktBranchesProvider =
    FutureProvider.autoDispose<List<BranchSummaryModel>>((ref) async {
  final authState = ref.watch(authProvider);
  final repository = ref.watch(sktRepositoryProvider);

  return await authState.maybeWhen(
    authenticated: (user) => repository.fetchBranches(user.tenantId),
    orElse: () async => <BranchSummaryModel>[],
  );
});

final sktProductSearchProvider =
    FutureProvider.autoDispose.family<List<ProductSummaryModel>, String>(
  (ref, query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      return <ProductSummaryModel>[];
    }
    final authState = ref.watch(authProvider);
    final repository = ref.watch(sktRepositoryProvider);

    return await authState.maybeWhen(
      authenticated: (user) => repository.searchProducts(
        tenantId: user.tenantId,
        query: trimmed,
      ),
      orElse: () async => <ProductSummaryModel>[],
    );
  },
);

final sktFilteredRecordsProvider =
    Provider<AsyncValue<List<SktRecordModel>>>((ref) {
  final recordsAsync = ref.watch(sktRecordsProvider);
  final timelineFilter = ref.watch(sktTimelineFilterProvider);
  final searchQuery = ref.watch(sktSearchQueryProvider);

  return recordsAsync.whenData((records) {
    final query = searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    final maxDuration = timelineFilter.maxDuration;

    final filtered = records.where((record) {
      final matchesTimeline = maxDuration == null
          ? true
          : record.daysUntil(now) <= maxDuration.inDays;
      final matchesQuery = query.isEmpty ||
          record.productName.toLowerCase().contains(query) ||
          record.barcode.contains(query);
      return matchesTimeline && matchesQuery;
    }).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return filtered;
  });
});
