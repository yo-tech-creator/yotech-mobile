import 'package:flutter/material.dart';

enum RequestCategory {
  malfunction,
  equipment,
  leave,
  other,
}

extension RequestCategoryX on RequestCategory {
  String get value {
    switch (this) {
      case RequestCategory.malfunction:
        return 'malfunction';
      case RequestCategory.equipment:
        return 'equipment';
      case RequestCategory.leave:
        return 'leave';
      case RequestCategory.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case RequestCategory.malfunction:
        return 'Arıza Kaydı';
      case RequestCategory.equipment:
        return 'Ekipman Talebi';
      case RequestCategory.leave:
        return 'İzin Talebi';
      case RequestCategory.other:
        return 'Diğer';
    }
  }

  IconData get icon {
    switch (this) {
      case RequestCategory.malfunction:
        return Icons.build_circle_outlined;
      case RequestCategory.equipment:
        return Icons.handyman_outlined;
      case RequestCategory.leave:
        return Icons.event_available_outlined;
      case RequestCategory.other:
        return Icons.lightbulb_outline;
    }
  }

  Color get accentColor {
    switch (this) {
      case RequestCategory.malfunction:
        return Colors.redAccent;
      case RequestCategory.equipment:
        return Colors.blueAccent;
      case RequestCategory.leave:
        return Colors.green;
      case RequestCategory.other:
        return Colors.deepPurpleAccent;
    }
  }

  static RequestCategory fromValue(String raw) {
    switch (raw) {
      case 'malfunction':
        return RequestCategory.malfunction;
      case 'equipment':
        return RequestCategory.equipment;
      case 'leave':
        return RequestCategory.leave;
      default:
        return RequestCategory.other;
    }
  }
}
