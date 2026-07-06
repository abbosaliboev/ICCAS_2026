import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});
  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> with AutomaticKeepAliveClientMixin {
  Timer? _timer;
  Uint8List? _frame;
  bool _error = false;
  bool _active = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  void _startStream() {
    setState(() {
      _active = true;
      _error = false;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) => _fetchFrame());
  }

  void _stopStream() {
    _timer?.cancel();
    setState(() => _active = false);
  }

  Future<void> _fetchFrame() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final url = auth.api.snapshotUrl();
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _frame = res.bodyBytes;
          _error = false;
        });
      } else if (mounted) {
        setState(() => _error = true);
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('라이브 카메라', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_active ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: _active ? _stopStream : _startStream,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _error
                  ? _errorWidget()
                  : _frame != null
                      ? Image.memory(
                          _frame!,
                          gaplessPlayback: true,
                          fit: BoxFit.contain,
                          width: double.infinity,
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF4FC3F7)),
                            SizedBox(height: 16),
                            Text('스트림 연결 중...', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
            ),
          ),
          Container(
            color: const Color(0xFF16213E),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _active && !_error ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _active && !_error ? '라이브 스트리밍 중' : _error ? '스트림 연결 실패' : '일시 정지',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Spacer(),
                const Text('~8fps', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorWidget() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text('스트림에 연결할 수 없습니다', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          const Text(
            '엣지 서버가 실행 중인지 확인하세요',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _startStream,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4FC3F7)),
            child: const Text('재연결', style: TextStyle(color: Colors.black87)),
          ),
        ],
      );
}
