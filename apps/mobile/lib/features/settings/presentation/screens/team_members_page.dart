import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamMembersPage extends StatefulWidget {
  const TeamMembersPage({super.key});

  @override
  State<TeamMembersPage> createState() => _TeamMembersPageState();
}

class _TeamMembersPageState extends State<TeamMembersPage> {
  late Future<_TeamData> _teamFuture;

  @override
  void initState() {
    super.initState();
    _teamFuture = _loadTeamData();
  }

  Future<_TeamData> _loadTeamData() async {
    final client = Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw StateError('Oturum bulunamadı.');
    }

    try {
      final userRow = await client
          .from('users')
          .select('branch_id')
          .eq('id', authUser.id)
          .maybeSingle();
      if (userRow == null) {
        throw StateError('Kullanıcı kaydı bulunamadı.');
      }

      final branchId = userRow['branch_id'] as String?;
      if (branchId == null) {
        throw StateError('Herhangi bir şubeye bağlı değilsiniz.');
      }

      final branchResponse = await client
          .from('branches')
          .select('id, name, code, city, district, manager_id, region_id')
          .eq('id', branchId)
          .maybeSingle();
      final branch = branchResponse != null
          ? Map<String, dynamic>.from(branchResponse)
          : null;

      final rosterResponse = await client.rpc(
        'get_branch_team_members',
        params: {'p_user_id': authUser.id},
      );

      final rosterData = rosterResponse is PostgrestResponse
          ? rosterResponse.data
          : rosterResponse;

      final members = ((rosterData as List?) ?? []).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        return {
          'id': map['member_id'],
          'first_name': map['first_name'],
          'last_name': map['last_name'],
          'position': map['position'],
          'role': map['role'],
          'phone': map['phone'],
          'email': map['email'],
          'employee_code': map['employee_code'],
          'is_branch_manager': map['is_branch_manager'] ?? false,
        };
      }).toList();

      Map<String, dynamic>? branchManager;
      if (branch?['manager_id'] != null) {
        final managerResponse = await client
            .from('users')
            .select('id, first_name, last_name, phone, email')
            .eq('id', branch!['manager_id'])
            .maybeSingle();
        if (managerResponse != null) {
          branchManager = Map<String, dynamic>.from(managerResponse);
        }
      }

      Map<String, dynamic>? region;
      Map<String, dynamic>? regionalManager;
      if (branch?['region_id'] != null) {
        final regionResponse = await client
            .from('regions')
            .select('id, name, manager_id')
            .eq('id', branch!['region_id'])
            .maybeSingle();
        if (regionResponse != null) {
          region = Map<String, dynamic>.from(regionResponse);
          final regionalManagerId = region['manager_id'] as String?;
          if (regionalManagerId != null) {
            final regionalManagerResponse = await client
                .from('users')
                .select('id, first_name, last_name, phone, email')
                .eq('id', regionalManagerId)
                .maybeSingle();
            if (regionalManagerResponse != null) {
              regionalManager =
                  Map<String, dynamic>.from(regionalManagerResponse);
            }
          }
        }
      }

      Map<String, dynamic>? fallbackManager;
      try {
        fallbackManager = members.firstWhere(
          (member) => member['is_branch_manager'] == true,
        );
      } catch (_) {
        fallbackManager = null;
      }

      branchManager ??= fallbackManager == null
          ? null
          : {
              'id': fallbackManager['id'],
              'first_name': fallbackManager['first_name'],
              'last_name': fallbackManager['last_name'],
              'phone': fallbackManager['phone'],
              'email': fallbackManager['email'],
            };

      return _TeamData(
        branch: branch,
        members: members,
        branchManager: branchManager,
        region: region,
        regionalManager: regionalManager,
      );
    } catch (error, stackTrace) {
      debugPrint('TeamMembersPage::_loadTeamData hata: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  void _reload() {
    setState(() {
      _teamFuture = _loadTeamData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Takım arkadaşlarım'),
      ),
      body: FutureBuilder<_TeamData>(
        future: _teamFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _TeamErrorView(
              onRetry: _reload,
              message: 'Takım bilgileri alınamadı.',
              error: snapshot.error,
            );
          }
          if (!snapshot.hasData) {
            return _TeamErrorView(
              onRetry: _reload,
              message: 'Takım verisi bulunamadı.',
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data.branch != null) _BranchSummaryCard(branch: data.branch!),
              if (data.regionalManager != null)
                _ManagerCard(
                  title: 'Bölge Müdürü',
                  name: _formatName(data.regionalManager!),
                  phone: data.regionalManager!['phone'] as String?,
                  email: data.regionalManager!['email'] as String?,
                  subtitle: data.region?['name'] as String?,
                ),
              const SizedBox(height: 12),
              const _SectionTitle('Takım Listesi'),
              if (data.members.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Bu şubeye ait personel bulunamadı.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey[700]),
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < data.members.length; i++)
                        Column(
                          children: [
                            _MemberTile(
                              member: data.members[i],
                              highlightManager:
                                  data.members[i]['is_branch_manager'] == true,
                            ),
                            if (i != data.members.length - 1)
                              const Divider(
                                  height: 1, indent: 16, endIndent: 16),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _formatName(Map<String, dynamic> row) {
    final first = row['first_name'] as String?;
    final last = row['last_name'] as String?;
    final parts = [first, last]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return row['email'] as String? ?? '-';
    }
    return parts.join(' ');
  }
}

class _BranchSummaryCard extends StatelessWidget {
  const _BranchSummaryCard({required this.branch});

  final Map<String, dynamic> branch;

  @override
  Widget build(BuildContext context) {
    final name = branch['name'] as String? ?? 'Şube';
    final code = branch['code'] as String?;
    final city = branch['city'] as String?;
    final district = branch['district'] as String?;

    final subtitleParts = [
      if (code != null && code.isNotEmpty) '#$code',
      if (city != null && city.isNotEmpty) city,
      if (district != null && district.isNotEmpty) district,
    ];

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(Icons.store_mall_directory,
              color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(name),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' • '),
                style: TextStyle(color: Colors.grey[700]),
              ),
      ),
    );
  }
}

class _ManagerCard extends StatelessWidget {
  const _ManagerCard({
    required this.title,
    required this.name,
    this.subtitle,
    this.phone,
    this.email,
  });

  final String title;
  final String name;
  final String? subtitle;
  final String? phone;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final info = [
      if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
      if (phone != null && phone!.isNotEmpty) phone!,
      if (email != null && email!.isNotEmpty) email!,
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(Icons.badge,
              color: Theme.of(context).colorScheme.onSecondaryContainer),
        ),
        title: Text('$title · $name'),
        subtitle: info.isEmpty
            ? null
            : Text(
                info.join('\n'),
                style: TextStyle(color: Colors.grey[700]),
              ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.highlightManager});

  final Map<String, dynamic> member;
  final bool highlightManager;

  @override
  Widget build(BuildContext context) {
    final displayName = _TeamMembersPageState._formatName(member);
    final role =
        member['position'] as String? ?? member['role'] as String? ?? '-';
    final phone = member['phone'] as String?;
    final email = member['email'] as String?;

    return ListTile(
      leading: CircleAvatar(
        child: Text(
          displayName.isNotEmpty
              ? displayName.substring(0, 1).toUpperCase()
              : '?',
        ),
      ),
      title: Text(displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role),
          if (phone != null && phone.isNotEmpty)
            Text(phone, style: TextStyle(color: Colors.grey[700])),
          if (email != null && email.isNotEmpty)
            Text(email, style: TextStyle(color: Colors.grey[700])),
          if (highlightManager)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text('Mağaza Müdürü'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Colors.grey[600], letterSpacing: 0.8),
      ),
    );
  }
}

class _TeamErrorView extends StatelessWidget {
  const _TeamErrorView({
    required this.onRetry,
    required this.message,
    this.error,
  });

  final VoidCallback onRetry;
  final String message;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[700]),
          ),
          if (kDebugMode && error != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.red[700]),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}

class _TeamData {
  const _TeamData({
    required this.members,
    this.branch,
    this.branchManager,
    this.region,
    this.regionalManager,
  });

  final List<Map<String, dynamic>> members;
  final Map<String, dynamic>? branch;
  final Map<String, dynamic>? branchManager;
  final Map<String, dynamic>? region;
  final Map<String, dynamic>? regionalManager;
}
