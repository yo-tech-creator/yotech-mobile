enum RequestStatus {
  pending,
  inProgress,
  resolved,
  cancelled,
  rejected,
  failed,
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
      case RequestStatus.rejected:
        return 'rejected';
      case RequestStatus.failed:
        return 'failed';
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
      case RequestStatus.rejected:
        return 'Reddedildi';
      case RequestStatus.failed:
        return 'Tamamlanamadı';
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
      case 'rejected':
        return RequestStatus.rejected;
      case 'failed':
        return RequestStatus.failed;
      default:
        return RequestStatus.pending;
    }
  }
}
