enum MerchRank {
  merch('Mörş'),
  plasiyer('Plasiyer'),
  sevkiyat('Sevkiyat'),
  sef('Şef'),
  yonetici('Yönetici');

  const MerchRank(this.label);
  final String label;
}

class MerchPerson {
  const MerchPerson({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.companyName,
    required this.phoneNumber,
    required this.rank,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String companyName;
  final String phoneNumber;
  final MerchRank rank;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName => '$firstName $lastName';

  MerchPerson copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? companyName,
    String? phoneNumber,
    MerchRank? rank,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MerchPerson(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      companyName: companyName ?? this.companyName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      rank: rank ?? this.rank,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MerchPerson.fromJson(Map<String, dynamic> json) {
    return MerchPerson(
      id: json['id'].toString(),
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      rank: MerchRank.values.firstWhere(
        (rank) => rank.name == json['rank'],
        orElse: () => MerchRank.merch,
      ),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'company_name': companyName,
      'phone_number': phoneNumber,
      'rank': rank.name,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }
}
