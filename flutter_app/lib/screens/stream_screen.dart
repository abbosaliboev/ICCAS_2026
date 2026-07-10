import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/mjpeg_stream.dart';
import '../strings.dart';

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});
  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  late final MjpegStreamController _ctrl;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _ctrl = MjpegStreamController(
      url: () => auth.api.streamUrl(),
      headers: () => {'Authorization': 'Bearer ${auth.token}'},
    );
    _ctrl.start();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          ValueListenableBuilder<MjpegStatus>(
            valueListenable: _ctrl.status,
            builder: (_, st, __) {
              final active = st != MjpegStatus.idle;
              return IconButton(
                icon: Icon(
                  active
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  color: Colors.white,
                ),
                onPressed: () => active ? _ctrl.stop() : _ctrl.start(),
                tooltip: active ? s.pauseStream : s.resumeStream,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              // Per-frame repaints stay inside this builder; the rest of the
              // screen (app bar, status bar) never rebuilds.
              child: RepaintBoundary(
                child: ValueListenableBuilder<MjpegStatus>(
                  valueListenable: _ctrl.status,
                  builder: (_, st, __) {
                    if (st == MjpegStatus.error) return _errorWidget(s);
                    return ValueListenableBuilder<Uint8List?>(
                      valueListenable: _ctrl.frame,
                      builder: (_, frame, __) => frame != null
                          ? Image.memory(
                              frame,
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
                                  style: const TextStyle(
                                      color: subColor, fontSize: 14),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
          // ── Status bar ───────────────────────────────────────────────────
          Container(
            color: barBg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ValueListenableBuilder<MjpegStatus>(
              valueListenable: _ctrl.status,
              builder: (_, st, __) {
                final live = st == MjpegStatus.live;
                return Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // status bar is always dark-toned regardless of theme
                        color: live ? DarkColors.success : DarkColors.danger,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      live
                          ? s.streamConnected
                          : st == MjpegStatus.error
                              ? s.streamDisconnected
                              : st == MjpegStatus.connecting
                                  ? s.connecting
                                  : s.pauseStream,
                      style: const TextStyle(color: subColor, fontSize: 13),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<int>(
                      valueListenable: _ctrl.fps,
                      builder: (_, fps, __) => Text(
                        live && fps > 0 ? '$fps fps' : '',
                        style: const TextStyle(color: dimColor, fontSize: 12),
                      ),
                    ),
                  ],
                );
              },
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
        onPressed: () {
          _ctrl.stop();
          _ctrl.start();
        },
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
