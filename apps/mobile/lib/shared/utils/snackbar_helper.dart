import 'package:flutter/material.dart';

/// Extension on BuildContext for easy SnackBar display.
///
/// Usage:
/// ```dart
/// context.showSuccessSnackBar('İşlem başarılı!');
/// context.showErrorSnackBar('Bir hata oluştu');
/// context.showInfoSnackBar('Bilgilendirme mesajı');
/// ```
extension SnackBarExtension on BuildContext {
  /// Shows a success snackbar with green background
  void showSuccessSnackBar(String message, {Duration? duration}) {
    final theme = Theme.of(this);
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.onPrimary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: duration ?? const Duration(seconds: 3),
        ),
      );
  }

  /// Shows an error snackbar with red background
  void showErrorSnackBar(String message, {Duration? duration}) {
    final theme = Theme.of(this);
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.onError,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: duration ?? const Duration(seconds: 4),
        ),
      );
  }

  /// Shows an info snackbar with primary color
  void showInfoSnackBar(String message, {Duration? duration}) {
    final theme = Theme.of(this);
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.onPrimary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: theme.colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: duration ?? const Duration(seconds: 3),
        ),
      );
  }

  /// Shows a warning snackbar with amber/orange background
  void showWarningSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                color: Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.amber.shade600,
          behavior: SnackBarBehavior.floating,
          duration: duration ?? const Duration(seconds: 3),
        ),
      );
  }

  /// Shows a snackbar with an undo action
  void showUndoSnackBar({
    required String message,
    required VoidCallback onUndo,
    String undoLabel = 'Geri Al',
    Duration? duration,
  }) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: duration ?? const Duration(seconds: 5),
          action: SnackBarAction(
            label: undoLabel,
            onPressed: onUndo,
          ),
        ),
      );
  }
}
