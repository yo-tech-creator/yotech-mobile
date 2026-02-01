import 'package:flutter/material.dart';

/// Standard loading indicator widget.
///
/// Use this widget instead of manually creating CircularProgressIndicator
/// for consistent loading UI across the app.
class AppLoading extends StatelessWidget {
  const AppLoading({
    super.key,
    this.strokeWidth = 4.0,
    this.size,
    this.color,
    this.message,
  });

  /// Width of the circular progress indicator stroke
  final double strokeWidth;

  /// Size of the loading indicator (width and height)
  final double? size;

  /// Custom color, defaults to primary color
  final Color? color;

  /// Optional message to show below the indicator
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? theme.colorScheme.primary,
      ),
    );

    if (message != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            indicator,
            const SizedBox(height: 16),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Center(child: indicator);
  }
}

/// Small inline loading indicator for buttons or compact spaces
class AppLoadingSmall extends StatelessWidget {
  const AppLoadingSmall({
    super.key,
    this.color,
  });

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}
