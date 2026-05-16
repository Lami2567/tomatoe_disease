import 'package:flutter/material.dart';

class ScanCard extends StatelessWidget {
  final Map<String, dynamic> scan;
  const ScanCard({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.crop, color: Colors.green),
        title: Text(scan['disease']),
        subtitle: Text('${(scan['confidence'] * 100).toStringAsFixed(1)}% - ${scan['created_at']}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}