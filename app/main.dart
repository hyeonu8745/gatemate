import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'log_page.dart';

void main() => runApp(const GateMateApp());

class GateMateApp extends StatelessWidget {
  const GateMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GateMate',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light, // 항상 밝은 테마 사용
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorSchemeSeed: Colors.teal,
    );
    return base.copyWith(
      scaffoldBackgroundColor:
      brightness == Brightness.light ? Colors.grey[100] : null,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const piIp = '192.168.198.122:5000'; // Flask (라즈베리파이)
  static const gateIp = '192.168.198.200';   // ESP32 게이트부

  bool isAutoMode = false;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _pollAutoMode();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _pollAutoMode());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _pollAutoMode() async {
    try {
      final res = await http
          .get(Uri.parse('http://$piIp/auto_mode/status'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() => isAutoMode = json['auto_mode'] as bool);
        }
      }
    } catch (_) {/* 네트워크 에러 무시 */}
  }

  void _show(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toggleAuto(bool on) async {
    final url = on ? '/auto_mode/on' : '/auto_mode/off';
    try {
      final res = await http
          .get(Uri.parse('http://$piIp$url'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        setState(() => isAutoMode = on);
        _show(on ? '자동 모드가 켜졌습니다' : '자동 모드가 꺼졌습니다');
      } else {
        _show('서버 오류: ${res.statusCode}');
      }
    } catch (e) {
      _show('연결 실패: $e');
    }
  }

  Future<void> _gateCmd(String path, String okMsg) async {
    try {
      final res = await http
          .get(Uri.parse('http://$gateIp$path'))
          .timeout(const Duration(seconds: 2));
      _show(res.statusCode == 200 ? okMsg : '실패: ${res.statusCode}');
    } catch (e) {
      _show('연결 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('GateMate 🛡️'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/gate_logo.png'),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              minHeight: height * 0.9,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Card(
                    elevation: 3,
                    shadowColor: cs.primaryContainer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        title: const Text('자동 감지 모드',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        secondary: Icon(Icons.sensors, color: cs.primary),
                        value: isAutoMode,
                        activeColor: cs.primary,
                        onChanged: _toggleAuto,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('게이트 수동 제어',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 3,
                    shadowColor: cs.primaryContainer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.door_front_door_outlined),
                              label: const Text('열기'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                              ),
                              onPressed: () =>
                                  _gateCmd('/gate/open', '게이트 열림 요청 전송'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('닫기'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.secondary,
                                foregroundColor: cs.onSecondary,
                              ),
                              onPressed: () =>
                                  _gateCmd('/gate/close', '게이트 닫힘 요청 전송'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('로그 확인'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LogPage()),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'GateMate v1.0.0',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        Text(
                          '© 2025 GateMate by JiHyun-u',
                          style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
