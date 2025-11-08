import 'package:flutter/material.dart';

class SktListPage extends StatelessWidget {
  const SktListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SKT Takip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Yeni SKT kaydı ekleme özelliği gelecek
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Yeni SKT kaydı ekleme özelliği yakında gelecek')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withAlpha((0.3 * 255).round()),
            ),
            const SizedBox(height: 16),
            Text(
              'SKT kayıtları burada görüntülenecek',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.6 * 255).round()),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
