import 'package:flutter/material.dart';
import 'package:yotech_mobile/shared/shared.dart';

class MalfunctionListPage extends StatelessWidget {
  const MalfunctionListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arıza Raporları')),
      body: const AppEmptyState(
        icon: Icons.build_outlined,
        title: 'Çok Yakında',
        subtitle: 'Arıza raporları modülü yakında aktif olacaktır.',
        showContainer: true,
      ),
    );
  }
}
