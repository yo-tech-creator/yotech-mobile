/// Talep hedef kullanıcısı modeli
class TargetUser {
  const TargetUser({
    required this.userId,
    required this.userName,
    required this.userRole,
    this.branchName,
  });

  final String userId;
  final String userName;
  final String userRole;
  final String? branchName;

  factory TargetUser.fromMap(Map<String, dynamic> map) {
    return TargetUser(
      userId: map['user_id'] as String,
      userName: map['user_name'] as String? ?? '',
      userRole: map['user_role'] as String,
      branchName: map['branch_name'] as String?,
    );
  }

  String get roleLabel {
    switch (userRole) {
      case 'firma_admin':
        return 'Firma Yöneticisi';
      case 'bolge_muduru':
        return 'Bölge Müdürü';
      case 'sube_muduru':
        return 'Şube Müdürü';
      default:
        return userRole;
    }
  }

  String get displayName {
    if (branchName != null && branchName!.isNotEmpty) {
      return '$userName ($roleLabel - $branchName)';
    }
    return '$userName ($roleLabel)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetUser &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}
