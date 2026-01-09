enum RequestStatus {
  pending,
  inProgress,
  resolved,
  cancelled,
}

extension RequestStatusX on RequestStatus {
  String get value {
    switch (this) {
      case RequestStatus.pending:
        return 'pending';
      case RequestStatus.inProgress:
        return 'in_progress';
      case RequestStatus.resolved:
        return 'resolved';
      case RequestStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case RequestStatus.pending:
        return 'Beklemede';
      case RequestStatus.inProgress:
        return 'İşlemde';
      case RequestStatus.resolved:
        return 'Tamamlandı';
      case RequestStatus.cancelled:
        return 'İptal Edildi';
    }
  }

  static RequestStatus fromValue(String raw) {
    switch (raw) {
      case 'pending':
        return RequestStatus.pending;
      case 'in_progress':
        return RequestStatus.inProgress;
      case 'resolved':
        return RequestStatus.resolved;
      case 'cancelled':
        return RequestStatus.cancelled;
      default:
        return RequestStatus.pending;
    }
  }
}
