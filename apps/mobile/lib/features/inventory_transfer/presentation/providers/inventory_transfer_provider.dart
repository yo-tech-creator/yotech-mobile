import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/inventory_transfer/data/models/inventory_transfer_model.dart';
import 'package:yotech_mobile/features/inventory_transfer/data/repositories/inventory_transfer_repository.dart';

final inventoryTransferListProvider =
    AsyncNotifierProvider<InventoryTransferNotifier, List<DepotNotice>>(() {
  return InventoryTransferNotifier();
});

class InventoryTransferNotifier extends AsyncNotifier<List<DepotNotice>> {
  @override
  Future<List<DepotNotice>> build() async {
    final user = ref.watch(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null) return [];
    
    final repository = ref.read(inventoryTransferRepositoryProvider);
    return repository.getNotices(tenantId: user.tenantId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> createNotice({
    required String productName,
    required double quantity,
    required String unit,
    required DepotNoticeType type,
    String? note,
    DateTime? expiresAt,
  }) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null || user.branchId == null) throw Exception('Kullanıcı veya şube bilgisi eksik');

    final notice = DepotNotice(
      id: '', // Supabase generates this
      tenantId: user.tenantId,
      branchId: user.branchId!,
      createdBy: user.id,
      productName: productName,
      quantity: quantity,
      unit: unit,
      type: type,
      note: note,
      expiresAt: expiresAt,
      createdAt: DateTime.now(),
    );

    final repository = ref.read(inventoryTransferRepositoryProvider);
    await repository.createNotice(notice);
    
    // Refresh list
    ref.invalidateSelf();
  }

  Future<void> createOffer({
    required String noticeId,
    required double quantity,
    String? message,
  }) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null || user.branchId == null) throw Exception('Kullanıcı veya şube bilgisi eksik');

    final offer = NoticeOffer(
      id: '',
      noticeId: noticeId,
      tenantId: user.tenantId,
      branchId: user.branchId!,
      offeredBy: user.id,
      quantity: quantity,
      message: message,
      createdAt: DateTime.now(),
    );

    final repository = ref.read(inventoryTransferRepositoryProvider);
    await repository.createOffer(offer);
    
    // Refresh list
    ref.invalidateSelf();
  }

  Future<void> acceptOffer(String offerId, String noticeId) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null) throw Exception('Kullanıcı bilgisi eksik');

    final repository = ref.read(inventoryTransferRepositoryProvider);
    
    // 1. Accept the offer
    await repository.updateOfferStatus(
      offerId: offerId,
      status: DepotOfferStatus.accepted,
      decisionBy: user.id,
    );

    // 2. Update notice status to in_transfer
    await repository.updateNoticeStatus(
      noticeId: noticeId,
      status: DepotNoticeStatus.inTransfer,
    );

    ref.invalidateSelf();
  }

  Future<void> rejectOffer(String offerId) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null) throw Exception('Kullanıcı bilgisi eksik');

    final repository = ref.read(inventoryTransferRepositoryProvider);
    await repository.updateOfferStatus(
      offerId: offerId,
      status: DepotOfferStatus.rejected,
      decisionBy: user.id,
    );

    ref.invalidateSelf();
  }
}
