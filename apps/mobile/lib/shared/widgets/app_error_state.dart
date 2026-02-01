import 'package:flutter/material.dart';

/// Standard error state widget with retry option.
///
/// Use this widget when an operation fails and needs user action.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Bir Hata Oluştu',
    this.icon = Icons.error_outline,
    this.retryLabel = 'Tekrar Dene',
  });

  /// Error message to display
  final String message;

  /// Callback when retry button is pressed
  final VoidCallback? onRetry;

  /// Title text
  final String title;

  /// Icon to display
  final IconData icon;

  /// Label for retry button
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.errorContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: colors.error,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            // Retry button
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
