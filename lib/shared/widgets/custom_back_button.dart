// lib/shared/widgets/custom_back_button.dart

import 'package:flutter/material.dart';

/// DRY prensibine uygun merkezi geri butonu yönetimi
/// 
/// Kullanım:
/// ```dart
/// CustomBackButton(
///   child: Scaffold(...),
/// )
/// ```
class CustomBackButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBackPressed;

  const CustomBackButton({
    Key? key,
    required this.child,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: onBackPressed == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && onBackPressed != null) {
          onBackPressed!();
        }
      },
      child: child,
    );
  }
}

/// Login sayfası için özel geri butonu davranışı
class LoginBackButton extends StatelessWidget {
  final Widget child;

  const LoginBackButton({
    Key? key,
    required this.child,
  }) : super(key: key);

  Future<void> _showExitDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış'),
        content: const Text('Uygulamadan çıkmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Evet'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitDialog(context);
        }
      },
      child: child,
    );
  }
}
