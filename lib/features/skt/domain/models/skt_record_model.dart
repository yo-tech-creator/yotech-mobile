class SktRecordModel {
  const SktRecordModel({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.expiryDate,
    required this.quantity,
    this.productStatus,
    this.notes,
    this.status,
  });

  final String id;
  final String branchId;
  final String branchName;
  final String productId;
  final String productName;
  final String barcode;
  final DateTime expiryDate;
  final int quantity;
  final String? productStatus;
  final String? notes;
  final String? status;

  factory SktRecordModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value.toLocal();
      if (value is String && value.isNotEmpty) {
        return DateTime.parse(value).toLocal();
      }
      throw ArgumentError('expiry_date değeri çözümlenemedi: $value');
    }

    int parseQuantity(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final branch = map['branches'] as Map<String, dynamic>?;
    final product = map['products'] as Map<String, dynamic>?;

    final productName =
        map['product_name'] as String? ?? product?['name'] as String?;
    final barcode = map['barcode'] as String? ?? product?['barcode'] as String?;
    final branchName =
        map['branch_name'] as String? ?? branch?['name'] as String?;

    return SktRecordModel(
      id: map['id'] as String,
      branchId: map['branch_id'] as String,
      branchName: branchName ?? 'Bilinmeyen şube',
      productId: map['product_id'] as String,
      productName: productName ?? 'İsimsiz ürün',
      barcode: barcode ?? '-',
      expiryDate: parseDate(map['expiry_date']),
      quantity: parseQuantity(map['quantity']),
      productStatus: map['product_status'] as String?,
      notes: map['notes'] as String?,
      status: map['status'] as String?,
    );
  }

  int daysUntil(DateTime date) => expiryDate.difference(date).inDays;

  SktRecordStatus statusAt(DateTime date) {
    final daysLeft = daysUntil(date);
    if (daysLeft < 0) return SktRecordStatus.expired;
    if (daysLeft <= 7) return SktRecordStatus.upcoming;
    return SktRecordStatus.normal;
  }
}

enum SktRecordStatus { normal, upcoming, expired }
