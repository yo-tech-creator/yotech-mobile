class BranchSummaryModel {
  const BranchSummaryModel({required this.id, required this.name});

  final String id;
  final String name;

  factory BranchSummaryModel.fromMap(Map<String, dynamic> map) {
    return BranchSummaryModel(
      id: map['id'] as String,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Isimsiz sube',
    );
  }
}
