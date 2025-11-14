/// Modül bilgisini temsil eden model.
///
/// `code`: modülün benzersiz kodu (ör. "skt").
/// `title`: gösterim başlığı.
/// `description`: opsiyonel açıklama.
class ModuleModel {
  final String code;
  final String title;
  final String? description;

  ModuleModel({required this.code, required this.title, this.description});

  /// Veritabanından gelen map'ten model üretir.
  /// modules tablosu: code, name, description, ...
  factory ModuleModel.fromMap(Map<String, dynamic> m) => ModuleModel(
        code: m['code'] as String,
        title: (m['name'] ?? m['code']) as String,
        description: m['description'] as String?,
      );
}
