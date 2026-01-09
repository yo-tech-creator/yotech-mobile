import 'package:flutter/material.dart';

import '../../domain/models/request_category.dart';

class RequestCategoryThemeData {
  const RequestCategoryThemeData({
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final RequestCategory category;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

class RequestCategoryThemes {
  static const List<RequestCategoryThemeData> values = [
    RequestCategoryThemeData(
      category: RequestCategory.malfunction,
      title: 'Arıza Kaydı',
      description: 'Teknik ekipten destek isteyin, fotoğraf ekleyin.',
      icon: Icons.build_circle_outlined,
      color: Color(0xFFEF5350),
    ),
    RequestCategoryThemeData(
      category: RequestCategory.equipment,
      title: 'Ekipman Talebi',
      description: 'Yeni kasalar, POS cihazları veya raf ekipmanları isteyin.',
      icon: Icons.handyman_outlined,
      color: Color(0xFF42A5F5),
    ),
    RequestCategoryThemeData(
      category: RequestCategory.leave,
      title: 'İzin Talebi',
      description: 'Yıllık izin ya da mazeret izinlerini tek tıkla iletin.',
      icon: Icons.event_available_outlined,
      color: Color(0xFF66BB6A),
    ),
    RequestCategoryThemeData(
      category: RequestCategory.other,
      title: 'Diğer',
      description: 'Liste dışındaki ihtiyaçları serbest metinle yazın.',
      icon: Icons.lightbulb_outline,
      color: Color(0xFF7E57C2),
    ),
  ];

  static RequestCategoryThemeData of(RequestCategory category) {
    return values.firstWhere((item) => item.category == category);
  }
}
