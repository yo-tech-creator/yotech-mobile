import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/features/settings/presentation/widgets/change_password_dialog.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  late Future<_PersonalInfoData> _infoFuture;
  static const _roleStoreManager = 'sube_muduru';
  static const _roleRegionalManager = 'bolge_muduru';
  static const _roleStaff = 'personel';

  @override
  void initState() {
    super.initState();
    _infoFuture = _loadInfo();
  }

  Future<_PersonalInfoData> _loadInfo() async {
    final client = Supabase.instance.client;
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw StateError('Oturum bulunamadı.');
    }

    final metadata = Map<String, dynamic>.from(authUser.userMetadata ?? {});
    Map<String, dynamic>? userRow;
    Map<String, dynamic>? branchRow;
    Map<String, dynamic>? branchManager;
    Map<String, dynamic>? tenantRow;
    Map<String, dynamic>? regionalManager;
    String? userRole;

    Map<String, dynamic>? profileResponse;
    try {
      profileResponse = await client.rpc('get_personal_profile',
          params: {'p_user_id': authUser.id}).maybeSingle();
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'get_personal_profile RPC hatası: ${error.message} (code: ${error.code})',
      );
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      debugPrint('get_personal_profile bilinmeyen hata: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }

    if (profileResponse == null) {
      throw StateError('Profil verileri alınamadı.');
    }

    userRow = Map<String, dynamic>.from(profileResponse);
    userRole = userRow['role'] as String?;

    final branchId = userRow['branch_id'] as String?;

    if (branchId != null) {
      branchRow = {
        'id': branchId,
        'name': userRow['branch_name'],
        'code': userRow['branch_code'],
        'city': userRow['branch_city'],
        'district': userRow['branch_district'],
      }..removeWhere((key, value) => value == null);
    }

    if (userRow['branch_manager_id'] != null) {
      branchManager = {
        'id': userRow['branch_manager_id'],
        'first_name': userRow['branch_manager_first_name'],
        'last_name': userRow['branch_manager_last_name'],
        'phone': userRow['branch_manager_phone'],
      }..removeWhere((key, value) => value == null);
    }

    if ((branchManager == null || branchManager.isEmpty) && branchId != null) {
      debugPrint('Şube müdürü fallback devreye girdi. branchId=$branchId');
      branchManager = await _fetchBranchStoreManager(
        client: client,
        branchId: branchId,
      );
      debugPrint('Şube müdürü fallback sonucu: $branchManager');
    }

    if (userRow['regional_manager_id'] != null) {
      regionalManager = {
        'id': userRow['regional_manager_id'],
        'first_name': userRow['regional_manager_first_name'],
        'last_name': userRow['regional_manager_last_name'],
        'phone': userRow['regional_manager_phone'],
      }..removeWhere((key, value) => value == null);
    }

    if (userRow['tenant_name'] != null) {
      tenantRow = {'name': userRow['tenant_name']};
    }

    return _PersonalInfoData.fromSources(
      authUser: authUser,
      metadata: metadata,
      userRow: userRow,
      branchRow: branchRow,
      branchManager: branchManager,
      regionalManager: regionalManager,
      userRole: userRole,
      tenantRow: tenantRow,
    );
  }

  void _reload() {
    setState(() {
      _infoFuture = _loadInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kişisel Bilgilerim'),
      ),
      body: FutureBuilder<_PersonalInfoData>(
        future: _infoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('PersonalInfoPage hata: ${snapshot.error}');
            return _ErrorView(
              onRetry: _reload,
              message: 'Bilgiler alınırken bir sorun oluştu.',
            );
          }
          if (!snapshot.hasData) {
            return _ErrorView(
              onRetry: _reload,
              message: 'Bilgiler bulunamadı.',
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(data: data),
              const SizedBox(height: 24),
              _InfoSection(
                title: 'Genel Bilgiler',
                items: [
                  _InfoItem('Pozisyon', data.role),
                  _InfoItem('Şirket', data.company),
                  _InfoItem('Departman', data.department),
                  _InfoItem('Mağaza', data.store),
                  _InfoItem('Personel Numarası', data.staffNumber),
                  _InfoItem('İşe Başlama Tarihi', data.startDate),
                ],
              ),
              const SizedBox(height: 20),
              _InfoSection(
                title: 'Yönetici',
                items: [
                  _InfoItem('Yönetici Adı', data.managerName),
                  _InfoItem('Yönetici Telefonu', data.managerPhone),
                ],
              ),
              const SizedBox(height: 20),
              _InfoSection(
                title: 'İletişim',
                items: [
                  _InfoItem('Kurumsal E-posta', data.email),
                  _InfoItem('Telefon', data.phone),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => showChangePasswordDialog(context),
                icon: const Icon(Icons.lock_reset),
                label: const Text('Şifreyi Değiştir'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchBranchStoreManager({
    required SupabaseClient client,
    required String branchId,
  }) async {
    try {
      final response = await client
          .from('users')
          .select('id, first_name, last_name, phone')
          .eq('branch_id', branchId)
          .eq('role', _roleStoreManager)
          .limit(1)
          .maybeSingle();
      if (response == null) {
        debugPrint('Şube müdürü fallback sorgusu boş döndü.');
        return null;
      }
      return Map<String, dynamic>.from(response)
        ..removeWhere((key, value) => value == null);
    } catch (error, stackTrace) {
      debugPrint('Yedek mağaza müdürü sorgusu hata: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data});

  final _PersonalInfoData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                data.initials,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.role,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.store,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.items});

  final String title;
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.grey[600],
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                Column(
                  children: [
                    ListTile(
                      dense: true,
                      title: Text(
                        items[i].label,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          items[i].value,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    if (i != items.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value);

  final String label;
  final String value;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, required this.message});

  final VoidCallback onRetry;
  final String message;

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

class _PersonalInfoData {
  const _PersonalInfoData({
    required this.displayName,
    required this.role,
    required this.company,
    required this.department,
    required this.store,
    required this.staffNumber,
    required this.startDate,
    required this.managerName,
    required this.managerPhone,
    required this.email,
    required this.phone,
  });

  final String displayName;
  final String role;
  final String company;
  final String department;
  final String store;
  final String staffNumber;
  final String startDate;
  final String managerName;
  final String managerPhone;
  final String email;
  final String phone;

  String get initials {
    if (displayName.isEmpty || displayName == '-') {
      return '?';
    }
    final parts = displayName.trim().split(' ');
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static _PersonalInfoData fromSources({
    required User authUser,
    required Map<String, dynamic> metadata,
    Map<String, dynamic>? userRow,
    Map<String, dynamic>? branchRow,
    Map<String, dynamic>? branchManager,
    Map<String, dynamic>? regionalManager,
    Map<String, dynamic>? tenantRow,
    String? userRole,
  }) {
    final displayName = _resolveDisplayName(
      authUser,
      userRow,
      metadata,
    );
    final role = _valueOrDash(
      userRow?['position'] as String? ??
          userRow?['role'] as String? ??
          metadata['position'] as String? ??
          metadata['role'] as String?,
    );
    final company = _valueOrDash(
      tenantRow?['name'] as String? ?? metadata['company'] as String?,
    );
    final department = _valueOrDash(
      _branchDepartment(branchRow) ?? metadata['department'] as String?,
    );
    final store = _valueOrDash(
      _branchName(branchRow) ??
          metadata['store_name'] as String? ??
          metadata['branch'] as String? ??
          metadata['location'] as String?,
    );
    final staffNumber = _valueOrDash(
      userRow?['employee_code'] as String? ??
          metadata['staff_no'] as String? ??
          metadata['employee_id'] as String?,
    );
    final startDate = _formatDate(
      (userRow?['hire_date'] as String?) ??
          metadata['start_date'] as String? ??
          metadata['employment_date'] as String?,
    );
    final selectedManager = _managerForRole(
      userRole,
      branchManager,
      regionalManager,
    );
    final managerName = _valueOrDash(
      _combineName(
            selectedManager?['first_name'] as String?,
            selectedManager?['last_name'] as String?,
          ) ??
          metadata['manager_name'] as String?,
    );
    final managerPhone = _valueOrDash(
      selectedManager?['phone'] as String? ??
          metadata['manager_phone'] as String?,
    );
    final email = _valueOrDash(
      userRow?['email'] as String? ?? authUser.email,
    );
    final phone = _valueOrDash(
      userRow?['phone'] as String? ??
          metadata['phone'] as String? ??
          metadata['phone_number'] as String? ??
          authUser.phone,
    );

    return _PersonalInfoData(
      displayName: displayName,
      role: role,
      company: company,
      department: department,
      store: store,
      staffNumber: staffNumber,
      startDate: startDate,
      managerName: managerName,
      managerPhone: managerPhone,
      email: email,
      phone: phone,
    );
  }

  static String _resolveDisplayName(
    User authUser,
    Map<String, dynamic>? userRow,
    Map<String, dynamic> metadata,
  ) {
    final name = _combineName(
      userRow?['first_name'] as String?,
      userRow?['last_name'] as String?,
    );
    if (name != null) {
      return name;
    }
    final metaName = _combineName(
      metadata['first_name'] as String?,
      metadata['last_name'] as String?,
    );
    if (metaName != null) {
      return metaName;
    }
    final fullMeta =
        metadata['full_name'] as String? ?? metadata['name'] as String?;
    if (fullMeta != null && fullMeta.trim().isNotEmpty) {
      return fullMeta.trim();
    }
    return authUser.email ?? 'YOTECH Kullanıcısı';
  }

  static String? _branchName(Map<String, dynamic>? branchRow) {
    if (branchRow == null) {
      return null;
    }
    final name = branchRow['name'] as String?;
    final code = branchRow['code'] as String?;
    if (name == null || name.isEmpty) {
      return code;
    }
    if (code == null || code.isEmpty) {
      return name;
    }
    return '$name ($code)';
  }

  static String? _branchDepartment(Map<String, dynamic>? branchRow) {
    if (branchRow == null) {
      return null;
    }
    final city = branchRow['city'] as String?;
    final district = branchRow['district'] as String?;
    final parts = [city, district]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' / ');
  }

  static String _valueOrDash(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }
    return value.trim();
  }

  static String? _combineName(String? first, String? last) {
    final parts = [first, last]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' ');
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return '-';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day.$month.${parsed.year}';
  }

  static Map<String, dynamic>? _managerForRole(
    String? rawRole,
    Map<String, dynamic>? branchManager,
    Map<String, dynamic>? regionalManager,
  ) {
    final normalizedRole = rawRole?.toLowerCase();
    if (normalizedRole == _PersonalInfoPageState._roleStoreManager) {
      return regionalManager ?? branchManager;
    }
    if (normalizedRole == _PersonalInfoPageState._roleStaff) {
      return branchManager ?? regionalManager;
    }
    if (normalizedRole == _PersonalInfoPageState._roleRegionalManager) {
      return regionalManager ?? branchManager;
    }
    return branchManager ?? regionalManager;
  }
}
