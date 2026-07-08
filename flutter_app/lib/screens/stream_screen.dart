import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../strings.dart';

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});
  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen>
    with AutomaticKeepAliveClientMixin {
  Uint8List? _frame;
  bool _error = false;
  bool _active = false;
  int _failures = 0;
  int _fps = 0;
  int _generation = 0; // bumped on stop/dispose so stale reconnect loops exit
  http.Client? _client;
  int _frameCountThisSecond = 0;
  DateTime _fpsWindowStart = DateTime.now();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  void _startStream() {
    _active = true;
    _error = false;
    _failures = 0;
    _generation++;
    setState(() {});
    _connectMjpeg(_generation);
  }

  void _stopStream() {
    _generation++; // invalidates any in-flight connect/reconnect loop
    _client?.close();
    _client = null;
    setState(() => _active = false);
  }

  // Reads the backend's multipart MJPEG proxy as a single persistent
  // connection (instead of polling a snapshot every ~150ms) — frames arrive
  // at whatever rate the edge server produces them, no per-frame HTTP
  // handshake overhead. Falls back to reconnecting on drop.
  Future<void> _connectMjpeg(int myGen) async {
    if (!mounted || _generation != myGen) return;
    final auth = context.read<AuthProvider>();
    final client = http.Client();
    _client = client;
    try {
      final req = http.Request('GET', Uri.parse(auth.api.streamUrl()));
      req.headers['Authorization'] = 'Bearer ${auth.token}';
      final res = await client.send(req).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final buffer = BytesBuilder(copy: false);
      await for (final chunk in res.stream) {
        if (!mounted || _generation != myGen) {
          client.close();
          return;
        }
        buffer.add(chunk);
        final bytes = buffer.toBytes();
        final start = _findBytes(bytes, const [0xFF, 0xD8]);
        if (start == -1) continue;
        final end = _findBytes(bytes, const [0xFF, 0xD9], start + 2);
        if (end == -1) continue;
        _onFrame(Uint8List.fromList(bytes.sublist(start, end + 2)));
        buffer.clear();
        if (end + 2 < bytes.length) buffer.add(bytes.sublist(end + 2));
      }
      throw Exception('stream ended');
    } catch (_) {
      if (!mounted || _generation != myGen) return;
      _markFailure();
    }
    // reconnect after a short backoff if this is still the active attempt
    if (mounted && _active && _generation == myGen) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted && _generation == myGen) _connectMjpeg(myGen);
    }
  }

  void _onFrame(Uint8List frame) {
    if (!mounted) return;
    _frameCountThisSecond++;
    final elapsed = DateTime.now().difference(_fpsWindowStart);
    if (elapsed.inMilliseconds >= 1000) {
      _fps = (_frameCountThisSecond * 1000 / elapsed.inMilliseconds).round();
      _frameCountThisSecond = 0;
      _fpsWindowStart = DateTime.now();
    }
    setState(() {
      _frame = frame;
      _failures = 0;
      _error = false;
    });
  }

  int _findBytes(Uint8List haystack, List<int> needle, [int start = 0]) {
    for (int i = start; i <= haystack.length - needle.length; i++) {
      var match = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  void _markFailure() {
    _failures += 1;
    if (_failures >= 3 && mounted) {
      setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _active = false;
    _generation++;
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? DarkColors.bg : Colors.black;
    final barBg = isDark ? DarkColors.surface : const Color(0xFF1A1A2E);
    const subColor = Colors.white70;
    const dimColor = Colors.white38;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: barBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          s.liveViewTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _active ? Icons.pause_circle_outline : Icons.play_circle_outline,
              color: Colors.white,
            ),
            onPressed: _active ? _stopStream : _startStream,
            tooltip: _active ? s.pauseStream : s.resumeStream,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _error
                  ? _errorWidget(s)
                  : _frame != null
                  ? Image.memory(
                      _frame!,
                      gaplessPlayback: true,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: isDark
                              ? DarkColors.primary
                              : AppColors.primary,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.connecting,
                          style: const TextStyle(color: subColor, fontSize: 14),
                        ),
                      ],
                    ),
            ),
          ),
          // ── Status bar ───────────────────────────────────────────────────
          Container(
            color: barBg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // status bar is always dark-toned regardless of app theme
                    color: _active && !_error
                        ? DarkColors.success
                        : DarkColors.danger,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _active && !_error
                      ? s.streamConnected
                      : _error
                      ? s.streamDisconnected
                      : s.pauseStream,
                  style: const TextStyle(color: subColor, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  _active && !_error && _fps > 0 ? '$_fps fps' : '',
                  style: const TextStyle(color: dimColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorWidget(S s) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.videocam_off, color: Colors.white38, size: 64),
      const SizedBox(height: 16),
      Text(
        s.cameraOffline,
        style: const TextStyle(color: Colors.white54, fontSize: 14),
      ),
      const SizedBox(height: 8),
      Text(
        s.isKorean
            ? '엣지 서버가 실행 중인지 확인하세요'
            : 'Check that the edge server is running',
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _startStream,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(s.reconnect),
      ),
    ],
  );
}
