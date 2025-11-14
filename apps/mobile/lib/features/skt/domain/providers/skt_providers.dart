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
  ({int? minDays, int? maxDays}) get _dayRange {
    switch (this) {
      case SktTimelineFilter.all:
        return (minDays: null, maxDays: null);
      case SktTimelineFilter.week1:
        return (minDays: 0, maxDays: 7);
      case SktTimelineFilter.week2:
        return (minDays: 8, maxDays: 14);
      case SktTimelineFilter.week3:
        return (minDays: 15, maxDays: 21);
      case SktTimelineFilter.month1:
        return (minDays: 22, maxDays: 30);
      case SktTimelineFilter.month2:
        return (minDays: 31, maxDays: 60);
      case SktTimelineFilter.month3:
        return (minDays: 61, maxDays: 90);
    }
  }

  bool includesDaysLeft(int daysLeft) {
    final range = _dayRange;
    final minDays = range.minDays;
    final maxDays = range.maxDays;

    if (this == SktTimelineFilter.all) {
      return true;
    }

    if (daysLeft < 0) {
      return false;
    }

    if (minDays != null && daysLeft < minDays) {
      return false;
    }

    if (maxDays != null && daysLeft > maxDays) {
      return false;
    }

    return true;
  }
}

final sktRepositoryProvider = Provider<SktRepository>((ref) {
  return SktRepository(Supabase.instance.client);
});

final sktTimelineFilterProvider =
    StateProvider<SktTimelineFilter>((ref) => SktTimelineFilter.all);

final sktSearchQueryProvider = StateProvider<String>((ref) => '');

final sktCategoryFilterProvider = StateProvider<String?>((ref) => null);

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
  final categoryFilter = ref.watch(sktCategoryFilterProvider);

  return recordsAsync.whenData((records) {
    final query = searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    final selectedCategory = categoryFilter?.trim();

    final filtered = records.where((record) {
      final daysLeft = record.daysUntil(now);
      final matchesTimeline = timelineFilter.includesDaysLeft(daysLeft);
      final matchesQuery = query.isEmpty ||
          record.productName.toLowerCase().contains(query) ||
          record.barcode.toLowerCase().contains(query) ||
          record.altBarcodes.any((code) => code.toLowerCase().contains(query));
      final matchesCategory = selectedCategory == null ||
          selectedCategory.isEmpty ||
          (record.productCategory != null &&
              record.productCategory!.toLowerCase() ==
                  selectedCategory.toLowerCase());
      return matchesTimeline && matchesQuery && matchesCategory;
    }).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return filtered;
  });
});

final sktCategoriesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final recordsAsync = ref.watch(sktRecordsProvider);

  return recordsAsync.whenData((records) {
    final categories = <String>{};
    for (final record in records) {
      final category = record.productCategory;
      if (category != null && category.trim().isNotEmpty) {
        categories.add(category.trim());
      }
    }
    final sorted = categories.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  });
});
