import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'log_detail_page.dart';

const piIp = '192.168.198.122:5000'; // Flask JSON 로그 서버

class LogEntry {
  final String time, msg, img;
  LogEntry(this.time, this.msg, this.img);

  factory LogEntry.fromJson(Map<String, dynamic> j) =>
      LogEntry(j['time'], j['message'], j['image_url']);
}

class LogPage extends StatefulWidget {
  const LogPage({super.key});
  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  List<LogEntry> logs = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await http.get(Uri.parse('http://$piIp/logs'));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        setState(() => logs = list.map((e) => LogEntry.fromJson(e)).toList());
      }
    } catch (_) {/* 무시 */}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('로그 확인')),
    body: logs.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (c, i) {
        final l = logs[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.history),
            title: Text('${l.time} - ${l.msg}'),
            trailing: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network('http://$piIp${l.img}',
                  width: 80, height: 60, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LogDetailPage(entry: l)),
            ),
          ),
        );
      },
    ),
  );
}
