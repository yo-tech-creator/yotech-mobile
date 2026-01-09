import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/features/announcements/data/models/announcement.dart';

final announcementsRepositoryProvider =
    Provider<AnnouncementsRepository>((ref) {
  return AnnouncementsRepository(Supabase.instance.client);
});

class AnnouncementsRepository {
  AnnouncementsRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Announcement>> watchAnnouncements(String tenantId) {
    return _client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('published_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) =>
                  Announcement.fromJson(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }
}
