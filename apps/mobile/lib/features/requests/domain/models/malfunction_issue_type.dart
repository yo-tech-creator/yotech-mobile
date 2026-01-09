enum MalfunctionIssueType {
  electronics,
  plumbing,
  shelving,
  structural,
  electrical,
  other,
}

extension MalfunctionIssueTypeX on MalfunctionIssueType {
  String get value {
    switch (this) {
      case MalfunctionIssueType.electronics:
        return 'electronics';
      case MalfunctionIssueType.plumbing:
        return 'plumbing';
      case MalfunctionIssueType.shelving:
        return 'shelving';
      case MalfunctionIssueType.structural:
        return 'structural';
      case MalfunctionIssueType.electrical:
        return 'electrical';
      case MalfunctionIssueType.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case MalfunctionIssueType.electronics:
        return 'Elektronik / POS';
      case MalfunctionIssueType.plumbing:
        return 'Su Tesisatı';
      case MalfunctionIssueType.shelving:
        return 'Raf / Mobilya';
      case MalfunctionIssueType.structural:
        return 'Yapısal (Duvar & Zemin)';
      case MalfunctionIssueType.electrical:
        return 'Elektrik Tesisatı';
      case MalfunctionIssueType.other:
        return 'Diğer / Açıklamada Belirt';
    }
  }

  String? get description {
    switch (this) {
      case MalfunctionIssueType.electronics:
        return 'POS, kasa, bilgisayar ve benzer cihaz arızaları';
      case MalfunctionIssueType.plumbing:
        return 'Lavabo, sifon, vanalar veya su kaçakları';
      case MalfunctionIssueType.shelving:
        return 'Raf, stand, dolap, askı gibi ekipman hasarları';
      case MalfunctionIssueType.structural:
        return 'Duvar, zemin, tavan veya kapı hasarları';
      case MalfunctionIssueType.electrical:
        return 'Priz, aydınlatma, sigorta veya kablo sorunları';
      case MalfunctionIssueType.other:
        return 'Listede yoksa açıklamada detaylandırın';
    }
  }

  static MalfunctionIssueType fromValue(String raw) {
    return maybeFromValue(raw) ?? MalfunctionIssueType.other;
  }

  static MalfunctionIssueType? maybeFromValue(String? raw) {
    if (raw == null) {
      return null;
    }
    for (final type in MalfunctionIssueType.values) {
      if (type.value == raw) {
        return type;
      }
    }
    return null;
  }
}
