import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class _Zone {
  final double x, y, w, h;
  _Zone(this.x, this.y, this.w, this.h);
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};
  static _Zone fromJson(Map<String, dynamic> j) => _Zone(
        (j['x'] as num).toDouble(),
        (j['y'] as num).toDouble(),
        (j['w'] as num).toDouble(),
        (j['h'] as num).toDouble(),
      );
}

class SafeZoneScreen extends StatefulWidget {
  const SafeZoneScreen({super.key});
  @override
  State<SafeZoneScreen> createState() => _SafeZoneScreenState();
}

class _SafeZoneScreenState extends State<SafeZoneScreen> {
  List<_Zone> _zones = [];
  Uint8List? _snapshot;
  bool _loadingSnapshot = true;
  bool _saving = false;
  String _cameraType = 'front';
  String? _message;

  // drawing state
  Offset? _drawStart;
  Offset? _drawCurrent;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthProvider>().api;
    // load saved zones + camera type
    try {
      final data = await api.getSafeZone();
      final zones = (data['zones'] as List?)
              ?.map((e) => _Zone.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final cam = data['camera_type'] as String? ?? 'front';
      if (mounted) setState(() { _zones = zones; _cameraType = cam; });
    } catch (_) {}

    // load snapshot
    await _fetchSnapshot();
  }

  Future<void> _fetchSnapshot() async {
    if (mounted) setState(() => _loadingSnapshot = true);
    try {
      final baseUrl = context.read<AuthProvider>().baseUrl;
      final r = await http.get(Uri.parse('$baseUrl/api/stream/snapshot'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200 && mounted) {
        setState(() { _snapshot = r.bodyBytes; _loadingSnapshot = false; });
      } else {
        if (mounted) setState(() => _loadingSnapshot = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSnapshot = false);
    }
  }

  Size get _canvasSize {
    final ctx = _canvasKey.currentContext;
    if (ctx == null) return Size.zero;
    final rb = ctx.findRenderObject() as RenderBox?;
    return rb?.size ?? Size.zero;
  }

  void _onPanStart(DragStartDetails d) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() {
      _drawStart = box.globalToLocal(d.globalPosition);
      _drawCurrent = _drawStart;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _drawCurrent = box.globalToLocal(d.globalPosition));
  }

  void _onPanEnd(DragEndDetails _) {
    final size = _canvasSize;
    if (size == Size.zero || _drawStart == null || _drawCurrent == null) return;
    final x1 = _drawStart!.dx.clamp(0.0, size.width);
    final y1 = _drawStart!.dy.clamp(0.0, size.height);
    final x2 = _drawCurrent!.dx.clamp(0.0, size.width);
    final y2 = _drawCurrent!.dy.clamp(0.0, size.height);
    final rw = (x2 - x1).abs() / size.width;
    final rh = (y2 - y1).abs() / size.height;
    if (rw > 0.01 && rh > 0.01) {
      setState(() {
        _zones.add(_Zone(
          x1.min(x2) / size.width,
          y1.min(y2) / size.height,
          rw,
          rh,
        ));
      });
    }
    setState(() { _drawStart = null; _drawCurrent = null; });
  }

  Future<void> _save() async {
    setState(() { _saving = true; _message = null; });
    try {
      final api = context.read<AuthProvider>().api;
      await api.setSafeZone(_zones.map((z) => z.toJson()).toList());
      await api.setCameraType(_cameraType);
      setState(() => _message = '안전 구역이 저장되었습니다');
    } catch (e) {
      setState(() => _message = '저장 실패: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    try {
      await context.read<AuthProvider>().api.clearSafeZone();
      setState(() { _zones.clear(); _message = '구역이 삭제되었습니다'; });
    } catch (e) {
      setState(() => _message = '삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('안전 구역 설정', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _fetchSnapshot,
            tooltip: '스냅샷 새로고침',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // description
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '침대나 소파 등 낙상 감지를 제외할 구역을\n카메라 화면 위에 드래그하여 지정하세요.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // camera type selector
            const Text('카메라 유형', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                _camChip('front', Icons.videocam, '정면 카메라'),
                const SizedBox(width: 10),
                _camChip('top', Icons.camera_alt, 'CCTV (천장)'),
              ],
            ),
            const SizedBox(height: 20),

            // snapshot + drawing canvas
            const Text('구역 그리기', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _loadingSnapshot
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : GestureDetector(
                        key: _canvasKey,
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          painter: _ZonePainter(
                            zones: _zones,
                            drawStart: _drawStart,
                            drawCurrent: _drawCurrent,
                          ),
                          child: _snapshot != null
                              ? Image.memory(
                                  _snapshot!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.videocam_off, color: Colors.white24, size: 40),
                                      SizedBox(height: 8),
                                      Text('카메라 연결 없음\n구역 그리기는 가능합니다',
                                          style: TextStyle(color: Colors.white24, fontSize: 12),
                                          textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _zones.isEmpty ? '구역 없음' : '${_zones.length}개 구역 지정됨',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                if (_zones.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _zones.removeLast()),
                    child: const Text('마지막 구역 취소',
                        style: TextStyle(color: Colors.orange, fontSize: 12)),
                  ),
              ],
            ),

            if (_message != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _message!.contains('실패')
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.contains('실패') ? Colors.redAccent : Colors.greenAccent,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _clear,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    label: const Text('구역 삭제', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                        : const Icon(Icons.save),
                    label: Text(_saving ? '저장 중...' : '저장'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4FC3F7),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _camChip(String value, IconData icon, String label) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _cameraType = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _cameraType == value
                  ? const Color(0xFF4FC3F7).withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _cameraType == value
                    ? const Color(0xFF4FC3F7)
                    : Colors.white12,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    color: _cameraType == value
                        ? const Color(0xFF4FC3F7)
                        : Colors.white38,
                    size: 22),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                      color: _cameraType == value
                          ? const Color(0xFF4FC3F7)
                          : Colors.white38,
                      fontSize: 12,
                    )),
              ],
            ),
          ),
        ),
      );
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _ZonePainter extends CustomPainter {
  final List<_Zone> zones;
  final Offset? drawStart;
  final Offset? drawCurrent;

  _ZonePainter({required this.zones, this.drawStart, this.drawCurrent});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Colors.blue.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.blue.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final z in zones) {
      final rect = Rect.fromLTWH(
        z.x * size.width,
        z.y * size.height,
        z.w * size.width,
        z.h * size.height,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
    }

    // in-progress drawing
    if (drawStart != null && drawCurrent != null) {
      final rect = Rect.fromPoints(drawStart!, drawCurrent!);
      final dFill = Paint()
        ..color = Colors.orange.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      final dStroke = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawRect(rect, dFill);
      canvas.drawRect(rect, dStroke);
    }
  }

  @override
  bool shouldRepaint(_ZonePainter old) =>
      old.zones != zones ||
      old.drawStart != drawStart ||
      old.drawCurrent != drawCurrent;
}

extension _DoubleMin on double {
  double min(double other) => this < other ? this : other;
}
