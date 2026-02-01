import 'package:intl/intl.dart';

/// Centralized date formatting utility for consistent date display.
///
/// All date formats use Turkish locale ('tr_TR') by default.
///
/// Usage:
/// ```dart
/// AppDateFormatter.fullDateTime(DateTime.now()); // "24 Ocak 2026, 14:30"
/// AppDateFormatter.fullDate(DateTime.now());     // "24 Ocak 2026"
/// AppDateFormatter.shortDate(DateTime.now());    // "24 Oca"
/// AppDateFormatter.numericDate(DateTime.now());  // "24.01.2026"
/// ```
class AppDateFormatter {
  AppDateFormatter._(); // Prevent instantiation

  static const String _locale = 'tr_TR';

  // ============= Full Formats =============

  /// Full date and time: "24 Ocak 2026, 14:30"
  static String fullDateTime(DateTime dateTime) {
    return DateFormat('dd MMMM yyyy, HH:mm', _locale).format(dateTime);
  }

  /// Full date only: "24 Ocak 2026"
  static String fullDate(DateTime dateTime) {
    return DateFormat('dd MMMM yyyy', _locale).format(dateTime);
  }

  /// Full date with day name: "Cuma, 24 Ocak 2026"
  static String fullDateWithDay(DateTime dateTime) {
    return DateFormat('EEEE, dd MMMM yyyy', _locale).format(dateTime);
  }

  // ============= Short Formats =============

  /// Short date: "24 Oca"
  static String shortDate(DateTime dateTime) {
    return DateFormat('dd MMM', _locale).format(dateTime);
  }

  /// Short month and year: "Oca 2026"
  static String shortMonthYear(DateTime dateTime) {
    return DateFormat('MMM yyyy', _locale).format(dateTime);
  }

  /// Day and short month: "24 Ocak"
  static String dayMonth(DateTime dateTime) {
    return DateFormat('dd MMMM', _locale).format(dateTime);
  }

  // ============= Numeric Formats =============

  /// Numeric date: "24.01.2026"
  static String numericDate(DateTime dateTime) {
    return DateFormat('dd.MM.yyyy').format(dateTime);
  }

  /// Numeric date and time: "24.01.2026 14:30"
  static String numericDateTime(DateTime dateTime) {
    return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
  }

  /// ISO date: "2026-01-24"
  static String isoDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  // ============= Time Only =============

  /// Time only: "14:30"
  static String time(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Time with seconds: "14:30:45"
  static String timeWithSeconds(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(dateTime);
  }

  // ============= Relative Formats =============

  /// Relative time description (e.g., "5 dakika önce", "2 saat önce")
  static String relative(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative) {
      // Future date
      final futureDiff = dateTime.difference(now);
      if (futureDiff.inDays > 0) {
        return '${futureDiff.inDays} gün sonra';
      } else if (futureDiff.inHours > 0) {
        return '${futureDiff.inHours} saat sonra';
      } else if (futureDiff.inMinutes > 0) {
        return '${futureDiff.inMinutes} dakika sonra';
      } else {
        return 'Az sonra';
      }
    }

    // Past date
    if (difference.inDays > 30) {
      return fullDate(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  // ============= Date Ranges =============

  /// Date range: "24 Oca - 28 Oca 2026"
  static String dateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      // Same month
      return '${start.day} - ${DateFormat('dd MMM yyyy', _locale).format(end)}';
    } else if (start.year == end.year) {
      // Same year, different month
      return '${DateFormat('dd MMM', _locale).format(start)} - ${DateFormat('dd MMM yyyy', _locale).format(end)}';
    } else {
      // Different years
      return '${DateFormat('dd MMM yyyy', _locale).format(start)} - ${DateFormat('dd MMM yyyy', _locale).format(end)}';
    }
  }

  // ============= Expiry Dates =============

  /// Days until expiry with color indication
  static ({String text, ExpiryStatus status}) expiryStatus(
      DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final daysUntil = expiry.difference(today).inDays;

    if (daysUntil < 0) {
      return (
        text: '${-daysUntil} gün geçmiş',
        status: ExpiryStatus.expired,
      );
    } else if (daysUntil == 0) {
      return (
        text: 'Bugün',
        status: ExpiryStatus.today,
      );
    } else if (daysUntil <= 7) {
      return (
        text: '$daysUntil gün kaldı',
        status: ExpiryStatus.critical,
      );
    } else if (daysUntil <= 30) {
      return (
        text: '$daysUntil gün kaldı',
        status: ExpiryStatus.warning,
      );
    } else {
      return (
        text: '$daysUntil gün kaldı',
        status: ExpiryStatus.safe,
      );
    }
  }
}

/// Expiry status for color coding
enum ExpiryStatus {
  expired, // Red
  today, // Red
  critical, // Orange
  warning, // Yellow
  safe, // Green
}
