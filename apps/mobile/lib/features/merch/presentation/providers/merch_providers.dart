import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/merch/data/models/merch_person.dart';
import 'package:yotech_mobile/features/merch/data/repositories/merch_repository.dart';

final merchPeopleProvider =
    AsyncNotifierProvider<MerchPeopleNotifier, List<MerchPerson>>(() {
  return MerchPeopleNotifier();
});

class MerchPeopleNotifier extends AsyncNotifier<List<MerchPerson>> {
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;
  RealtimeChannel? _syncChannel;
  String? _subscribedTenant;

  @override
  Future<List<MerchPerson>> build() async {
    final user =
        ref.watch(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null) return const [];

    _ensureRealtime(user.tenantId);
    final repository = ref.read(merchRepositoryProvider);
    return repository.fetchPeople(user.tenantId);
  }

  void _ensureRealtime(String tenantId) {
    if (_subscribedTenant == tenantId && _streamSubscription != null) return;
    _streamSubscription?.cancel();
    _syncChannel?.unsubscribe();
    _syncChannel = null;

    final client = Supabase.instance.client;

    _streamSubscription = client
        .from('merch_people')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('company_name')
        .listen((rows) {
          final people = rows
              .map(
                  (row) => MerchPerson.fromJson(Map<String, dynamic>.from(row)))
              .toList();
          state = AsyncValue.data(people);
        });

    _syncChannel = client.channel('merch_people_sync:$tenantId')
      ..onBroadcast(
        event: 'sync',
        callback: (payload) {
          final sourceId = payload['source'] as String?;
          final currentUser =
              ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
          if (currentUser == null) return;
          if (sourceId != null && sourceId == currentUser.id) return;
          unawaited(_syncFromServer());
        },
      )
      ..subscribe();

    _subscribedTenant = tenantId;

    ref.onDispose(() {
      _streamSubscription?.cancel();
      _streamSubscription = null;
      _syncChannel?.unsubscribe();
      _syncChannel = null;
      _subscribedTenant = null;
    });
  }

  Future<void> addPerson(MerchPerson person) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }
    final repository = ref.read(merchRepositoryProvider);
    final created = await repository.createPerson(
      person: person,
      tenantId: user.tenantId,
      userId: user.id,
    );

    state = state.whenData((people) {
      final next = [...people, created]..sort(_sortComparator);
      return next;
    });
    await _syncFromServer();
    await _sendSyncSignal(user.tenantId);
  }

  Future<void> updatePerson(MerchPerson person) async {
    final repository = ref.read(merchRepositoryProvider);
    await repository.updatePerson(person);

    state = state.whenData((people) {
      final index = people.indexWhere((item) => item.id == person.id);
      if (index == -1) return people;
      final next = [...people]..[index] = person;
      next.sort(_sortComparator);
      return next;
    });
    await _syncFromServer();
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user != null) {
      await _sendSyncSignal(user.tenantId);
    }
  }

  Future<void> removePerson(String id) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    final repository = ref.read(merchRepositoryProvider);
    await repository.deletePerson(
      id: id,
      tenantId: user.tenantId,
    );

    state = state.whenData((people) {
      final next = people.where((item) => item.id != id).toList();
      return next;
    });
    await _syncFromServer();
    await _sendSyncSignal(user.tenantId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> _syncFromServer() async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    if (user == null) return;
    final repository = ref.read(merchRepositoryProvider);
    try {
      final remote = await repository.fetchPeople(user.tenantId);
      state = AsyncValue.data(remote);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<void> _sendSyncSignal(String tenantId) async {
    final channel = _syncChannel;
    if (channel == null) return;
    final userId =
        ref.read(authProvider).mapOrNull(authenticated: (s) => s.user.id);
    await channel.sendBroadcastMessage(
      event: 'sync',
      payload: {'tenantId': tenantId, 'source': userId},
    );
  }
}

int _sortComparator(MerchPerson a, MerchPerson b) {
  final companyCompare = a.companyName.compareTo(b.companyName);
  if (companyCompare != 0) return companyCompare;
  return a.fullName.compareTo(b.fullName);
}

class MerchCompanyGroup {
  const MerchCompanyGroup({required this.companyName, required this.people});

  final String companyName;
  final List<MerchPerson> people;
}

final merchGroupsProvider = Provider<List<MerchCompanyGroup>>((ref) {
  final peopleAsync = ref.watch(merchPeopleProvider);
  final people = peopleAsync.maybeWhen(
    data: (value) => value,
    orElse: () => const <MerchPerson>[],
  );
  if (people.isEmpty) return const [];

  final Map<String, List<MerchPerson>> grouped = {};
  for (final person in people) {
    grouped.putIfAbsent(person.companyName.trim(), () => []).add(person);
  }

  final groups = grouped.entries.map((entry) {
    final sortedPeople = [...entry.value]
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return MerchCompanyGroup(companyName: entry.key, people: sortedPeople);
  }).toList()
    ..sort((a, b) => a.companyName.compareTo(b.companyName));

  return groups;
});
