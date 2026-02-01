import 'package:flutter/material.dart';

/// Shows a confirmation dialog and returns true if confirmed.
///
/// Usage:
/// ```dart
/// final confirmed = await showConfirmDialog(
///   context,
///   title: 'Silmek istediğinize emin misiniz?',
///   message: 'Bu işlem geri alınamaz.',
///   isDestructive: true,
/// );
/// if (confirmed) {
///   // Delete logic
/// }
/// ```
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmText = 'Evet',
  String cancelText = 'Hayır',
  bool isDestructive = false,
  IconData? icon,
}) async {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              color: isDestructive ? colors.error : colors.primary,
              size: 32,
            )
          : null,
      title: Text(title),
      content: message != null
          ? Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                )
              : null,
          child: Text(confirmText),
        ),
      ],
    ),
  );

  return result == true;
}

/// Shows a delete confirmation dialog with warning icon.
///
/// Convenience wrapper for common delete operations.
Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  String title = 'Silmek istediğinize emin misiniz?',
  String? itemName,
  String confirmText = 'Sil',
  String cancelText = 'İptal',
}) async {
  return showConfirmDialog(
    context,
    title: title,
    message: itemName != null
        ? '"$itemName" silinecek. Bu işlem geri alınamaz.'
        : 'Bu işlem geri alınamaz.',
    confirmText: confirmText,
    cancelText: cancelText,
    isDestructive: true,
    icon: Icons.delete_outline,
  );
}

/// Shows a logout confirmation dialog.
Future<bool> showLogoutConfirmDialog(BuildContext context) async {
  return showConfirmDialog(
    context,
    title: 'Çıkış Yap',
    message: 'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
    confirmText: 'Çıkış Yap',
    cancelText: 'İptal',
    isDestructive: true,
    icon: Icons.logout,
  );
}

/// Shows a discard changes confirmation dialog.
Future<bool> showDiscardChangesDialog(BuildContext context) async {
  return showConfirmDialog(
    context,
    title: 'Değişiklikler Kaydedilmedi',
    message: 'Değişiklikleri kaydetmeden çıkmak istediğinize emin misiniz?',
    confirmText: 'Çık',
    cancelText: 'İptal',
    isDestructive: true,
    icon: Icons.warning_amber_outlined,
  );
}

/// Shows an info dialog with single OK button.
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonText = 'Tamam',
  IconData? icon,
}) async {
  final theme = Theme.of(context);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 32,
            )
          : null,
      title: Text(title),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(buttonText),
        ),
      ],
    ),
  );
}
