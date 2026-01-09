class ManagedBranch {
  const ManagedBranch({
    required this.id,
    required this.name,
    this.city,
    this.code,
    this.managerId,
  });

  final String id;
  final String name;
  final String? city;
  final String? code;
  final String? managerId;

  factory ManagedBranch.fromMap(Map<String, dynamic> map) {
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
    );
  }
}
