import 'package:flutter/material.dart';

enum LeaveRequestType {
  paid,
  unpaid,
  annual,
  official,
}

extension LeaveRequestTypeX on LeaveRequestType {
  String get value {
    switch (this) {
      case LeaveRequestType.paid:
        return 'paid';
      case LeaveRequestType.unpaid:
        return 'unpaid';
      case LeaveRequestType.annual:
        return 'annual';
      case LeaveRequestType.official:
        return 'official';
    }
  }

  String get label {
    switch (this) {
      case LeaveRequestType.paid:
        return 'Ücretli İzin';
      case LeaveRequestType.unpaid:
        return 'Ücretsiz İzin';
      case LeaveRequestType.annual:
        return 'Yıllık İzin';
      case LeaveRequestType.official:
        return 'Resmi Tatil İzni';
    }
  }

  String? get description {
    switch (this) {
      case LeaveRequestType.paid:
        return 'Ücretli mazeret izinleri, rapor veya refakat talepleri.';
      case LeaveRequestType.unpaid:
        return 'Ücretsiz izin veya idari izin talepleri.';
      case LeaveRequestType.annual:
        return 'Yıllık izin kotasından düşecek tatil talebi.';
      case LeaveRequestType.official:
        return 'Resmi tatil günlerinde çalışma/izin planı.';
    }
  }

  IconData get icon {
    switch (this) {
      case LeaveRequestType.paid:
        return Icons.attach_money;
      case LeaveRequestType.unpaid:
        return Icons.money_off_outlined;
      case LeaveRequestType.annual:
        return Icons.beach_access_outlined;
      case LeaveRequestType.official:
        return Icons.flag_outlined;
    }
  }

  static LeaveRequestType fromValue(String raw) {
    switch (raw) {
      case 'paid':
        return LeaveRequestType.paid;
      case 'unpaid':
        return LeaveRequestType.unpaid;
      case 'annual':
        return LeaveRequestType.annual;
      case 'official':
        return LeaveRequestType.official;
      default:
        return LeaveRequestType.paid;
    }
  }

  static LeaveRequestType? maybeFromValue(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return fromValue(raw);
  }
}
