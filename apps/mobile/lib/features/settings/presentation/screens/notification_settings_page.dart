import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final SupabaseClient _client = Supabase.instance.client;
  late Map<String, bool> _toggles;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _toggles = _initialToggles();
  }

  Map<String, bool> _initialToggles() {
    final user = _client.auth.currentUser;
    final metadata = Map<String, dynamic>.from(user?.userMetadata ?? {});
    final prefs = Map<String, dynamic>.from(
      metadata['notification_preferences'] as Map? ?? {},
    );
    return {
      'skt': _boolFromPrefs(prefs['skt'], defaultValue: true),
      'depo': _boolFromPrefs(prefs['depo'], defaultValue: true),
      'duyurular': _boolFromPrefs(prefs['duyurular'], defaultValue: true),
      'gorevler': _boolFromPrefs(prefs['gorevler'], defaultValue: true),
    };
  }

  static bool _boolFromPrefs(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return defaultValue;
  }

  Future<void> _updatePreference(String key, bool value) async {
    setState(() {
      _toggles[key] = value;
      _isSaving = true;
    });
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw StateError('Oturum bulunamadı');
      }
      final metadata = Map<String, dynamic>.from(user.userMetadata ?? {});
      final prefs = Map<String, dynamic>.from(
        metadata['notification_preferences'] as Map? ?? {},
      );
      prefs[key] = value;
      metadata['notification_preferences'] = prefs;
      await _client.auth.updateUser(UserAttributes(data: metadata));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilirken bir hata oluştu.')),
      );
      setState(() {
        _toggles[key] = !value;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Ayarları'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bildirimleri özelleştir',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SKT, depo sevk, duyuru ve görev bildirimlerini ayrı ayrı yönetebilirsin.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                  if (_isSaving) ...[
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Ayarlar kaydediliyor...'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            title: 'SKT Hatırlatmaları',
            subtitle: 'Son kullanma tarihi yaklaşan ürünler için uyarılar',
            keyName: 'skt',
          ),
          _buildSwitchTile(
            title: 'Depo Sevk Bildirimleri',
            subtitle: 'Depodan mağazaya planlanan sevk hareketleri',
            keyName: 'depo',
          ),
          _buildSwitchTile(
            title: 'Duyuru Bildirimleri',
            subtitle: 'Merkez ofis ve yönetim duyuruları',
            keyName: 'duyurular',
          ),
          _buildSwitchTile(
            title: 'Görev Hatırlatmaları',
            subtitle: 'Atanan görev ve takip bildirimleri',
            keyName: 'gorevler',
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required String keyName,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: SwitchListTile.adaptive(
        title: Text(title),
        subtitle: Text(subtitle),
        value: _toggles[keyName] ?? true,
        onChanged: (value) => _updatePreference(keyName, value),
      ),
    );
  }
}
