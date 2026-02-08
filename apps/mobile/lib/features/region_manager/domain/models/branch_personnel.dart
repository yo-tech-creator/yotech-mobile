class BranchPersonnel {
  const BranchPersonnel({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone,
    this.employeeCode,
    this.position,
  });

  final String id;
  final String tenantId;
  final String? branchId;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final bool isActive;
  final String? phone;
  final String? employeeCode;
  final String? position;

  String get displayName {
    final parts = <String>[
      firstName.trim(),
      lastName.trim(),
    ].where((part) => part.isNotEmpty).toList(growable: false);
    if (parts.isEmpty) {
      return email.trim().isNotEmpty ? email.trim() : 'Adsız Personel';
    }
    return parts.join(' ');
  }

  factory BranchPersonnel.fromMap(Map<String, dynamic> map) {
    return BranchPersonnel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
      firstName: (map['first_name'] as String? ?? '').trim(),
      lastName: (map['last_name'] as String? ?? '').trim(),
      email: (map['email'] as String? ?? '').trim(),
      role: (map['role'] as String? ?? 'personel').trim(),
      isActive: map['is_active'] is bool ? map['is_active'] as bool : true,
      phone: (map['phone'] as String?)?.trim(),
      employeeCode: (map['employee_code'] as String?)?.trim(),
      position: (map['position'] as String?)?.trim(),
    );
  }

  BranchPersonnel copyWith({
    String? role,
    String? branchId,
    bool? isActive,
  }) {
    return BranchPersonnel(
      id: id,
      tenantId: tenantId,
      branchId: branchId ?? this.branchId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      phone: phone,
      employeeCode: employeeCode,
      position: position,
    );
  }
}
