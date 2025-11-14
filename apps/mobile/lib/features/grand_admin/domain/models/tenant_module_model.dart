/// Tenant (firma) - modül ilişkisinin model temsili.
///
/// `moduleCode`: modül kodu.
/// `isEnabled`: ilgili tenant için modülün aktif olup olmadığı.
class TenantModuleModel {
  final String moduleCode;
  final bool isEnabled;

  TenantModuleModel({required this.moduleCode, required this.isEnabled});

  /// API/veritabanı cevabından model oluşturur.
  factory TenantModuleModel.fromMap(Map<String, dynamic> m) =>
      TenantModuleModel(
        moduleCode: m['module_code'] as String,
        isEnabled: (m['is_enabled'] == true),
      );
}
