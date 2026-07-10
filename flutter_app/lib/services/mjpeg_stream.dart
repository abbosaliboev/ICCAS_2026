import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum MjpegStatus { idle, connecting, live, error }

/// Persistent multipart-MJPEG client shared by the dashboard card and the
/// full-screen viewer.
///
/// Frames are published through [frame] (a ValueNotifier) instead of setState
/// so that only the small ValueListenableBuilder wrapping the Image repaints
/// per frame — the surrounding screen never rebuilds, which keeps the
/// dashboard as cheap as the dedicated stream screen. [fps] updates at most
/// once per second for the same reason.
class MjpegStreamController {
  MjpegStreamController({required this.url, required this.headers});

  final String Function() url;
  final Map<String, String> Function() headers;

  final ValueNotifier<Uint8List?> frame = ValueNotifier(null);
  final ValueNotifier<int> fps = ValueNotifier(0);
  final ValueNotifier<MjpegStatus> status = ValueNotifier(MjpegStatus.idle);

  http.Client? _client;
  int _generation = 0; // bumped on stop/dispose so stale reconnect loops exit
  bool _active = false;
  bool _disposed = false;
  int _failures = 0;
  int _frameCountThisSecond = 0;
  DateTime _fpsWindowStart = DateTime.now();

  bool get isActive => _active;

  void start() {
    if (_active || _disposed) return;
    _active = true;
    _failures = 0;
    status.value = MjpegStatus.connecting;
    _connect(++_generation);
  }

  void stop() {
    if (!_active && status.value == MjpegStatus.idle) return;
    _active = false;
    _generation++;
    _client?.close();
    _client = null;
    fps.value = 0;
    if (!_disposed) status.value = MjpegStatus.idle;
  }

  void dispose() {
    stop();
    _disposed = true;
    frame.dispose();
    fps.dispose();
    status.dispose();
  }

  // Single persistent connection to the backend's multipart MJPEG proxy —
  // frames arrive at whatever rate the edge server produces them, no
  // per-frame HTTP handshake. Reconnects with a short backoff on drop.
  Future<void> _connect(int myGen) async {
    if (_disposed || _generation != myGen) return;
    final client = http.Client();
    _client = client;
    try {
      final req = http.Request('GET', Uri.parse(url()));
      req.headers.addAll(headers());
      final res = await client.send(req).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final buffer = BytesBuilder(copy: false);
      await for (final chunk in res.stream) {
        if (_disposed || _generation != myGen) {
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
      if (_disposed || _generation != myGen) return;
      _failures += 1;
      if (_failures >= 3) status.value = MjpegStatus.error;
    }
    if (!_disposed && _active && _generation == myGen) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_disposed && _generation == myGen) _connect(myGen);
    }
  }

  void _onFrame(Uint8List data) {
    _frameCountThisSecond++;
    final elapsed = DateTime.now().difference(_fpsWindowStart);
    if (elapsed.inMilliseconds >= 1000) {
      fps.value =
          (_frameCountThisSecond * 1000 / elapsed.inMilliseconds).round();
      _frameCountThisSecond = 0;
      _fpsWindowStart = DateTime.now();
    }
    _failures = 0;
    frame.value = data;
    if (status.value != MjpegStatus.live) status.value = MjpegStatus.live;
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
}
