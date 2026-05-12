import 'package:flutter/material.dart';
import 'log_page.dart';

class LogDetailPage extends StatelessWidget {
  final LogEntry entry;
  const LogDetailPage({super.key, required this.entry});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('상세 로그')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(entry.time, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(entry.msg),
          const SizedBox(height: 20),
          Expanded(
            child: Image.network(
              'http://${Uri.base.host.isEmpty ? "192.168.198.122:5000" : Uri.base.host}${entry.img}',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100),
            ),
          ),
        ],
      ),
    ),
  );
}
