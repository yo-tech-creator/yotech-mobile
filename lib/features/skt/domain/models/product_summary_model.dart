class ProductSummaryModel {
  const ProductSummaryModel({
    required this.id,
    required this.name,
    required this.barcode,
  });

  final String id;
  final String name;
  final String barcode;

  factory ProductSummaryModel.fromMap(Map<String, dynamic> map) {
    return ProductSummaryModel(
      id: map['id'] as String,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Isimsiz urun',
      barcode: (map['barcode'] as String?)?.trim() ?? '-',
    );
  }
}
