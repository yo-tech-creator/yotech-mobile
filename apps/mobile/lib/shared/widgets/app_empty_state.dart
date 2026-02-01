import 'package:flutter/material.dart';

/// Reusable empty state widget for lists and data views.
///
/// Use this widget when there's no data to display.
/// Supports icons, title, subtitle, and optional action button.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel,
    this.isError = false,
    this.iconSize = 48,
    this.showContainer = false,
  });

  /// Icon to display
  final IconData icon;

  /// Main title text
  final String title;

  /// Optional subtitle/description
  final String? subtitle;

  /// Callback for action button (e.g., retry)
  final VoidCallback? onAction;

  /// Label for action button
  final String? actionLabel;

  /// If true, uses error color scheme
  final bool isError;

  /// Size of the icon
  final double iconSize;

  /// If true, wraps content in a decorated container
  final bool showContainer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final primaryColor = isError ? colors.error : colors.primary;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon container
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: primaryColor.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),

        // Subtitle
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        // Action button
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );

    if (showContainer) {
      return Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: content,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: content,
      ),
    );
  }
}

/// Simple empty state for filtered lists
class AppFilteredEmptyState extends StatelessWidget {
  const AppFilteredEmptyState({
    super.key,
    this.message = 'Seçili filtrelere uygun sonuç bulunamadı.',
    this.onClearFilters,
  });

  final String message;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: 'Sonuç Bulunamadı',
      subtitle: message,
      onAction: onClearFilters,
      actionLabel: onClearFilters != null ? 'Filtreleri Temizle' : null,
    );
  }
}
