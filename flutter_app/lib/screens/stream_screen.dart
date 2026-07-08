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
    setState(() {});
    _fetchLoop();
  }

  void _stopStream() {
    setState(() => _active = false);
  }

  Future<void> _fetchLoop() async {
    while (mounted && _active) {
      await _fetchFrame();
      if (mounted && _active) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
  }

  Future<void> _fetchFrame() async {
    if (!mounted || !_active) return;
    final auth = context.read<AuthProvider>();
    final url = auth.api.snapshotUrl();
    try {
      final res = await http
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer ${auth.token}'},
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _frame = res.bodyBytes;
          _failures = 0;
          _error = false;
        });
      } else if (mounted) {
        _markFailure();
      }
    } catch (_) {
      if (mounted) _markFailure();
    }
  }

  void _markFailure() {
    _failures += 1;
    if (_failures >= 3) {
      setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _active = false;
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
                const Text(
                  '~8fps',
                  style: TextStyle(color: dimColor, fontSize: 12),
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
