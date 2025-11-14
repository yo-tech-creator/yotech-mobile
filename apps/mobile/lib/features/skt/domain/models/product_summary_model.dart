class ProductSummaryModel {
  const ProductSummaryModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.altBarcodes,
  });

  final String id;
  final String name;
  final String barcode;
  final List<String> altBarcodes;

  factory ProductSummaryModel.fromMap(Map<String, dynamic> map) {
    List<String> parseAltBarcodes(dynamic value) {
      if (value is List) {
        return value
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const <String>[];
    }

    return ProductSummaryModel(
      id: map['id'] as String,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Isimsiz urun',
      barcode: (map['barcode'] as String?)?.trim() ?? '-',
      altBarcodes: parseAltBarcodes(map['alt_barcodes']),
    );
  }
}
