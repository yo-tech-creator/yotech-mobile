import 'package:flutter/material.dart';
import 'package:yotech_mobile/shared/shared.dart';

class LeaveRequestsPage extends StatelessWidget {
  const LeaveRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İzin Talepleri')),
      body: const AppEmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Çok Yakında',
        subtitle: 'İzin talepleri modülü yakında aktif olacaktır.',
        showContainer: true,
      ),
    );
  }
}
