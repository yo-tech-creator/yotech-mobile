import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/inventory_transfer/data/models/inventory_transfer_model.dart';
import 'package:yotech_mobile/features/inventory_transfer/data/repositories/inventory_transfer_repository.dart';

final inventoryTransferListProvider =
    AsyncNotifierProvider<InventoryTransferNotifier, List<DepotNotice>>(() {
  return InventoryTransferNotifier();
});

class InventoryTransferNotifier extends AsyncNotifier<List<DepotNotice>> {
  RealtimeChannel? _channel;
  Timer? _pollTimer;
  String? _subscribedTenant;

  @override
  Future<List<DepotNotice>> build() async {
    final user =
        ref.watch(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null) return [];

    _ensureRealtime(user.tenantId);
    return _fetchTenantNotices(user.tenantId);
  }

  void _ensureRealtime(String tenantId) {
    if (_subscribedTenant == tenantId && _channel != null) return;
    _channel?.unsubscribe();
    _pollTimer?.cancel();

    final client = Supabase.instance.client;
    final channel = client.channel('inventory_transfer_$tenantId');
    void handleChange(PostgresChangePayload payload) {
      final newRecord = payload.newRecord as Map<String, dynamic>?;
      final oldRecord = payload.oldRecord as Map<String, dynamic>?;
      final newTenant = newRecord?['tenant_id'];
      final oldTenant = oldRecord?['tenant_id'];
      if (newTenant == tenantId || oldTenant == tenantId) {
        ref.invalidateSelf();
      }
    }

    for (final table in const ['depot_notices', 'depot_notice_offers']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: handleChange,
      );
    }

    channel.subscribe();
    _channel = channel;
    _subscribedTenant = tenantId;

    _pollTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => ref.invalidateSelf());

    ref.onDispose(() {
      _channel?.unsubscribe();
      _pollTimer?.cancel();
      _channel = null;
      _pollTimer = null;
      _subscribedTenant = null;
    });
  }

  Future<List<DepotNotice>> _fetchTenantNotices(String tenantId) {
    final repository = ref.read(inventoryTransferRepositoryProvider);
    return repository.getNotices(tenantId: tenantId);
  }

  Future<void> _reloadFromSource() async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null) return;
    final notices = await _fetchTenantNotices(user.tenantId);
    state = AsyncValue.data(notices);
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
    if (user == null || user.branchId == null) {
      throw Exception('Kullanıcı veya şube bilgisi eksik');
    }

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

    await _reloadFromSource();
  }

  Future<void> createOffer({
    required String noticeId,
    required double quantity,
    String? message,
  }) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null || user.branchId == null) {
      throw Exception('Kullanıcı veya şube bilgisi eksik');
    }

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

    await _reloadFromSource();
  }

  Future<void> acceptOffer({
    required NoticeOffer offer,
    required DepotNotice notice,
  }) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null) throw Exception('Kullanıcı bilgisi eksik');

    final repository = ref.read(inventoryTransferRepositoryProvider);

    // 1. Accept the offer
    await repository.updateOfferStatus(
      offerId: offer.id,
      status: DepotOfferStatus.accepted,
      decisionBy: user.id,
    );

    final remainingBefore = notice.remainingQuantity;
    if (remainingBefore <= 0) {
      throw Exception('Bu ilan için kalan miktar bulunmuyor');
    }
    if (offer.quantity > remainingBefore) {
      throw Exception('Talep edilen miktar kalan miktardan fazla');
    }

    final reservedAfter = notice.reservedQuantity + offer.quantity;
    final updatedStatus = reservedAfter >= notice.quantity
        ? DepotNoticeStatus.fulfilled
        : DepotNoticeStatus.inTransfer;

    await repository.updateNoticeStatus(
      noticeId: notice.id,
      status: updatedStatus,
    );

    await _reloadFromSource();
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

    await _reloadFromSource();
  }

  Future<void> updateOwnOffer({
    required NoticeOffer offer,
    required double quantity,
    String? message,
  }) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null || offer.offeredBy != user.id) {
      throw Exception('Sadece kendi taleplerinizi güncelleyebilirsiniz');
    }

    final repository = ref.read(inventoryTransferRepositoryProvider);
    await repository.updateOwnOffer(
      offerId: offer.id,
      quantity: quantity,
      message: message,
    );
    await _reloadFromSource();
  }

  Future<void> cancelOwnOffer(NoticeOffer offer) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null || offer.offeredBy != user.id) {
      throw Exception('Sadece kendi taleplerinizi iptal edebilirsiniz');
    }

    final repository = ref.read(inventoryTransferRepositoryProvider);
    await repository.updateOfferStatus(
      offerId: offer.id,
      status: DepotOfferStatus.cancelled,
    );
    await _reloadFromSource();
  }

  Future<void> markOfferDelivered(NoticeOffer offer) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null || offer.offeredBy != user.id) {
      throw Exception('Sadece kendi taleplerinizi güncelleyebilirsiniz');
    }

    final repository = ref.read(inventoryTransferRepositoryProvider);
    await repository.updateOfferStatus(
      offerId: offer.id,
      status: DepotOfferStatus.delivered,
    );
    await _reloadFromSource();
  }

  Future<void> deleteNotice(String noticeId) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null) throw Exception('Kullanıcı bilgisi eksik');

    DepotNotice? notice;
    final currentNotices = state.value;
    if (currentNotices != null) {
      for (final item in currentNotices) {
        if (item.id == noticeId) {
          notice = item;
          break;
        }
      }
    }

    if (notice != null && notice.createdBy != user.id) {
      throw Exception('Yalnızca kendi ilanınızı silebilirsiniz');
    }

    final repository = ref.read(inventoryTransferRepositoryProvider);
    await repository.deleteNotice(noticeId);
    await _reloadFromSource();
  }
}

final inventoryTransferIndicatorsProvider =
    Provider<InventoryTransferIndicators>((ref) {
  final user = ref.watch(authProvider).mapOrNull(authenticated: (s) => s.user);
  final noticesAsync = ref.watch(inventoryTransferListProvider);
  final alertStatus = ref.watch(
    inventoryTransferAlertStatusProvider(user?.id ?? 'anonymous'),
  );

  return noticesAsync.maybeWhen(
    data: (notices) {
      if (user == null) return InventoryTransferIndicators.empty;

      final incomingOffers = <NoticeOffer>[];
      final decisionSignals = <NoticeOffer>[];
      final notifications = <InventoryTransferQuickNotification>[];
      final now = DateTime.now();
      final branchId = user.branchId;
      for (final notice in notices) {
        final offers = notice.offers ?? const <NoticeOffer>[];
        final ownsNotice =
            notice.createdBy == user.id || notice.branchId == branchId;

        if (ownsNotice) {
          for (final offer in offers) {
            if (offer.status == DepotOfferStatus.pending) {
              incomingOffers.add(offer);
              notifications.add(
                InventoryTransferQuickNotification(
                  type: InventoryTransferNotificationType.incomingOffer,
                  title: 'Yeni talep var',
                  description:
                      '${offer.branchName ?? 'Bilinmeyen şube'} ${notice.productName} ilanına ${offer.quantity} ${notice.unit} talep gönderdi.',
                  createdAt: offer.createdAt,
                  targetTabIndex: 1,
                  noticeId: notice.id,
                ),
              );
            }
            if (offer.status == DepotOfferStatus.cancelled) {
              notifications.add(
                InventoryTransferQuickNotification(
                  type: InventoryTransferNotificationType.offerCancelled,
                  title:
                      '${offer.branchName ?? 'Bir şube'} talebini geri çekti',
                  description:
                      '${notice.productName} için ayrılan ${offer.quantity} ${notice.unit} tekrar ilanınıza eklendi.',
                  createdAt: offer.decisionAt ?? offer.createdAt,
                  targetTabIndex: 1,
                  noticeId: notice.id,
                ),
              );
            }
          }
        }

        for (final offer in offers) {
          final hasDecision = offer.status == DepotOfferStatus.accepted ||
              offer.status == DepotOfferStatus.rejected;
          if (offer.offeredBy == user.id && hasDecision) {
            decisionSignals.add(offer);
            notifications.add(
              InventoryTransferQuickNotification(
                type: offer.status == DepotOfferStatus.accepted
                    ? InventoryTransferNotificationType.offerAccepted
                    : InventoryTransferNotificationType.offerRejected,
                title: offer.status == DepotOfferStatus.accepted
                    ? 'Talebin onaylandı'
                    : 'Talebin reddedildi',
                description:
                    '${notice.branchName ?? 'İlgili şube'} ${notice.productName} için ${offer.quantity} ${notice.unit} talebine yanıt verdi.',
                createdAt: offer.decisionAt ?? offer.createdAt,
                targetTabIndex: 2,
                noticeId: notice.id,
              ),
            );
          }
        }
      }

      final generalWindow = now.subtract(const Duration(days: 5));
      final sortedNotices = notices
          .where((notice) => notice.createdAt.isAfter(generalWindow))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (final notice in sortedNotices.take(4)) {
        final type = notice.type == DepotNoticeType.shortage
            ? InventoryTransferNotificationType.shortageNotice
            : InventoryTransferNotificationType.surplusNotice;
        final verb =
            notice.type == DepotNoticeType.shortage ? 'eksik' : 'fazla';
        notifications.add(
          InventoryTransferQuickNotification(
            type: type,
            title: '${notice.branchName ?? 'Bir şube'} $verb ürün bildirdi',
            description:
                '${notice.productName} (${notice.quantity} ${notice.unit}) ilan edildi.',
            createdAt: notice.createdAt,
            targetTabIndex: 0,
            noticeId: notice.id,
          ),
        );
      }

      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final limitedNotifications = notifications.take(6).toList();
      final unseenNotifications = limitedNotifications
          .where(
            (n) => n.createdAt.isAfter(alertStatus.notificationsSeenAt),
          )
          .toList();

      final decisionWindow = now.subtract(const Duration(days: 3));
      final decisionCount = decisionSignals.where(
        (offer) {
          final eventTime = offer.decisionAt ?? offer.createdAt;
          return eventTime.isAfter(decisionWindow) &&
              eventTime.isAfter(alertStatus.decisionSeenAt);
        },
      ).length;

      final incomingCount = incomingOffers
          .where(
            (offer) => offer.createdAt.isAfter(alertStatus.incomingSeenAt),
          )
          .length;

      return InventoryTransferIndicators(
        incomingOfferCount: incomingCount,
        awaitingDecisionCount: decisionCount,
        quickNotifications: unseenNotifications,
      );
    },
    orElse: () => InventoryTransferIndicators.empty,
  );
});

class InventoryTransferIndicators {
  const InventoryTransferIndicators({
    required this.incomingOfferCount,
    required this.awaitingDecisionCount,
    required this.quickNotifications,
  });

  final int incomingOfferCount;
  final int awaitingDecisionCount;
  final List<InventoryTransferQuickNotification> quickNotifications;

  static const empty = InventoryTransferIndicators(
    incomingOfferCount: 0,
    awaitingDecisionCount: 0,
    quickNotifications: <InventoryTransferQuickNotification>[],
  );
}

enum InventoryTransferNotificationType {
  incomingOffer,
  offerAccepted,
  offerRejected,
  offerCancelled,
  shortageNotice,
  surplusNotice,
}

class InventoryTransferQuickNotification {
  const InventoryTransferQuickNotification({
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.targetTabIndex,
    this.noticeId,
  });

  final InventoryTransferNotificationType type;
  final String title;
  final String description;
  final DateTime createdAt;
  final int targetTabIndex;
  final String? noticeId;
}

final inventoryTransferAlertStatusProvider = StateNotifierProvider.family<
    InventoryTransferAlertStatusNotifier, InventoryTransferAlertStatus, String>(
  (ref, _) => InventoryTransferAlertStatusNotifier(),
);

class InventoryTransferAlertStatusNotifier
    extends StateNotifier<InventoryTransferAlertStatus> {
  InventoryTransferAlertStatusNotifier()
      : super(InventoryTransferAlertStatus.initial());

  void markIncomingSeen() {
    state = state.copyWith(incomingSeenAt: DateTime.now());
  }

  void markDecisionSeen() {
    state = state.copyWith(decisionSeenAt: DateTime.now());
  }

  void markNotificationSeen(DateTime timestamp) {
    if (!timestamp.isBefore(state.notificationsSeenAt)) {
      state = state.copyWith(notificationsSeenAt: timestamp);
    }
  }

  void markAllNotificationsSeen() {
    state = state.copyWith(notificationsSeenAt: DateTime.now());
  }
}

class InventoryTransferAlertStatus {
  const InventoryTransferAlertStatus({
    required this.incomingSeenAt,
    required this.decisionSeenAt,
    required this.notificationsSeenAt,
  });

  final DateTime incomingSeenAt;
  final DateTime decisionSeenAt;
  final DateTime notificationsSeenAt;

  InventoryTransferAlertStatus copyWith({
    DateTime? incomingSeenAt,
    DateTime? decisionSeenAt,
    DateTime? notificationsSeenAt,
  }) {
    return InventoryTransferAlertStatus(
      incomingSeenAt: incomingSeenAt ?? this.incomingSeenAt,
      decisionSeenAt: decisionSeenAt ?? this.decisionSeenAt,
      notificationsSeenAt: notificationsSeenAt ?? this.notificationsSeenAt,
    );
  }

  static InventoryTransferAlertStatus initial() => InventoryTransferAlertStatus(
        incomingSeenAt: DateTime.fromMillisecondsSinceEpoch(0),
        decisionSeenAt: DateTime.fromMillisecondsSinceEpoch(0),
        notificationsSeenAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
}
