class ManagedBranch {
  const ManagedBranch({
    required this.id,
    required this.name,
    this.city,
    this.code,
    this.managerId,
    this.regionName,
  });

  final String id;
  final String name;
  final String? city;
  final String? code;
  final String? managerId;
  final String? regionName;

  factory ManagedBranch.fromMap(Map<String, dynamic> map) {
    // Try to get region name from nested region object
    String? regionName;
    final regionData = map['region'] ?? map['regions'];
    if (regionData is Map<String, dynamic>) {
      regionName = regionData['name'] as String?;
    }

    return ManagedBranch(
      id: map['id'] as String,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'İsimsiz Şube',
      city: (map['city'] as String?)?.trim().isNotEmpty == true
          ? (map['city'] as String).trim()
          : null,
      code: (map['code'] as String?)?.trim().isNotEmpty == true
          ? (map['code'] as String).trim()
          : null,
      managerId: map['manager_id'] as String?,
      regionName: regionName,
    );
  }
}
