import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/fall_event.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  FallEvent? _event;
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;
  VideoPlayerController? _vpCtrl;
  ChewieController? _chewieCtrl;
  bool _videoInitialized = false;
  bool _smsLoading = false;
  String? _smsResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthProvider>().api;
    try {
      final event = await api.getFallEvent(widget.eventId);
      if (event == null) throw Exception('이벤트를 찾을 수 없습니다');
      Map<String, dynamic>? report;
      try {
        report = await api.getEmergencyReport(widget.eventId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _event = event;
          _report = report;
          _loading = false;
        });
        if (event.hasVideo) _initVideo(api.videoUrl(widget.eventId));
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _initVideo(String url) async {
    _vpCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
    await _vpCtrl!.initialize();
    _chewieCtrl = ChewieController(
      videoPlayerController: _vpCtrl!,
      autoPlay: false,
      looping: false,
      aspectRatio: _vpCtrl!.value.aspectRatio,
    );
    if (mounted) setState(() => _videoInitialized = true);
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _vpCtrl?.dispose();
    super.dispose();
  }

  Future<void> _acknowledge() async {
    final api = context.read<AuthProvider>().api;
    try {
      await api.acknowledgeEvent(widget.eventId);
      setState(() => _event = FallEvent(
            id: _event!.id,
            deviceId: _event!.deviceId,
            userId: _event!.userId,
            timestamp: _event!.timestamp,
            category: _event!.category,
            videoPath: _event!.videoPath,
            thumbnailPath: _event!.thumbnailPath,
            isAcknowledged: true,
          ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('확인 처리되었습니다'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _sendSms() async {
    setState(() { _smsLoading = true; _smsResult = null; });
    try {
      final result = await context.read<AuthProvider>().api.notifyGuardianSms(widget.eventId);
      setState(() => _smsResult = result['ok'] == true ? '문자 전송 완료' : '문자 전송 실패: ${result['detail']}');
    } catch (e) {
      setState(() => _smsResult = '오류: $e');
    } finally {
      setState(() => _smsLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('이벤트 삭제', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('이 이벤트와 관련 영상을 삭제할까요?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AuthProvider>().api.deleteEvent(widget.eventId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        title: const Text('이벤트 상세',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          if (_event != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.danger),
                      textAlign: TextAlign.center))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final event = _event!;
    final isSevere = event.isSevere;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Media (video or screenshot) ──────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: event.hasVideo
                ? (_videoInitialized
                    ? AspectRatio(
                        aspectRatio: _vpCtrl!.value.aspectRatio,
                        child: Chewie(controller: _chewieCtrl!),
                      )
                    : Container(
                        height: 220,
                        color: AppColors.textPrimary,
                        child: const Center(
                          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                        ),
                      ))
                : _ScreenshotWidget(eventId: event.id),
          ),
          const SizedBox(height: 16),

          // ── Status chips ─────────────────────────────────────────────────
          Row(
            children: [
              _Pill(
                label: isSevere ? '심각한 낙상' : '낙상 의심',
                icon: Icons.warning_rounded,
                bg: isSevere ? AppColors.dangerTint : AppColors.warningTint,
                fg: isSevere ? AppColors.danger : AppColors.warningText,
              ),
              const SizedBox(width: 8),
              if (event.isAcknowledged)
                const _Pill(
                  label: '확인됨',
                  icon: Icons.check_circle,
                  bg: AppColors.successTint,
                  fg: AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Body region card ─────────────────────────────────────────────
          _BodyRegionCard(report: _report, isSevere: isSevere),
          const SizedBox(height: 14),

          // ── Emergency report card ────────────────────────────────────────
          if (_report != null) _ReportCard(report: _report!),
          const SizedBox(height: 20),

          // ── Actions ──────────────────────────────────────────────────────
          if (!event.isAcknowledged) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _acknowledge,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('확인 처리',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _smsLoading ? null : _sendSms,
              icon: _smsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.sms_outlined, color: AppColors.primary),
              label: const Text('보호자에게 문자 전송',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          if (_smsResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _smsResult!,
              style: TextStyle(
                color: _smsResult!.contains('완료') ? AppColors.success : AppColors.danger,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Small pill badge ──────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;

  const _Pill({required this.label, required this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      );
}

// ── Emergency report card ─────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final r = report;
    String tsFormatted = r['timestamp'] ?? '-';
    try {
      final dt = DateTime.parse(r['timestamp'] ?? '').toLocal();
      tsFormatted =
          '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDeco(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('긴급 리포트',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          _Row(label: '이름', value: r['name'] ?? '-'),
          _Row(label: '나이', value: r['age']?.toString() ?? '-'),
          _Row(label: '주소', value: r['address'] ?? '-'),
          _Row(label: '연락처', value: r['phone'] ?? '-'),
          _Row(label: '발생 시각', value: tsFormatted),
          _Row(label: '영상', value: r['has_video'] == true ? '있음' : '없음'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(label,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            ),
          ],
        ),
      );
}

// ── Body region visualization ─────────────────────────────────────────────────

class _BodyRegionCard extends StatelessWidget {
  final Map<String, dynamic>? report;
  final bool isSevere;

  const _BodyRegionCard({required this.report, required this.isSevere});

  static const _directions = {
    'forward':        '앞으로 넘어짐',
    'backward':       '뒤로 넘어짐',
    'sideways_left':  '왼쪽으로 넘어짐',
    'sideways_right': '오른쪽으로 넘어짐',
  };

  // The 6 body regions displayed top-to-bottom
  static const _regions = [
    '머리/목',
    '어깨',
    '손목/팔꿈치',
    '골반/고관절',
    '무릎',
    '발목/발',
  ];

  String get _injury {
    final raw = (report?['estimated_injury'] ?? '') as String;
    if (raw.isNotEmpty) return raw;
    // Fallback: infer from category
    return isSevere ? '골반/고관절' : '무릎/손목';
  }

  String get _directionLabel {
    final raw = (report?['direction'] ?? '') as String;
    return _directions[raw] ?? '';
  }

  // Which regions to highlight
  Set<String> get _highlighted {
    final inj = _injury.toLowerCase();
    final hits = <String>{};
    for (final r in _regions) {
      if (inj.contains(r.split('/').first.toLowerCase()) ||
          inj.contains(r.split('/').last.toLowerCase())) {
        hits.add(r);
      }
    }
    // If nothing matched exactly, highlight the full raw string if it appears
    if (hits.isEmpty) {
      for (final r in _regions) {
        if (r.toLowerCase().contains(inj) || inj.contains(r.toLowerCase().split('/').first)) {
          hits.add(r);
        }
      }
    }
    return hits;
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = _highlighted;
    final injLabel = _injury;
    final dirLabel = _directionLabel;
    final isEstimate = (report?['estimated_injury'] ?? '').toString().isEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDeco(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.accessibility_new_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('충격 부위 분석',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              if (isEstimate) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warningTint,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text('추정',
                      style: TextStyle(
                          color: AppColors.warningText, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Body figure + region list
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Stick figure
              SizedBox(
                width: 80,
                height: 180,
                child: CustomPaint(
                  painter: _BodyFigurePainter(highlighted: highlighted, regions: _regions),
                ),
              ),
              const SizedBox(width: 16),

              // Region labels
              Expanded(
                child: Column(
                  children: _regions.map((r) {
                    final isHit = highlighted.contains(r);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isHit ? AppColors.danger : AppColors.chip,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            r,
                            style: TextStyle(
                              color: isHit ? AppColors.danger : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: isHit ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                          if (isHit) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.dangerTint,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text('충격',
                                  style: TextStyle(
                                      color: AppColors.danger,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Summary row
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.location_on_outlined,
                  label: '추정 충격 부위',
                  value: injLabel,
                  highlight: true,
                ),
              ),
              if (dirLabel.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryItem(
                    icon: Icons.turn_slight_right,
                    label: '낙상 방향',
                    value: dirLabel,
                    highlight: false,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  const _SummaryItem({
    required this.icon, required this.label, required this.value, required this.highlight,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? AppColors.dangerTint : AppColors.chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 13,
                    color: highlight ? AppColors.danger : AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: highlight ? AppColors.dangerPressed : AppColors.textTertiary,
                        fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: highlight ? AppColors.dangerPressed : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ── Stick figure painter ──────────────────────────────────────────────────────

class _BodyFigurePainter extends CustomPainter {
  final Set<String> highlighted;
  final List<String> regions;

  const _BodyFigurePainter({required this.highlighted, required this.regions});

  static const _activeColor = AppColors.danger;
  static const _inactiveColor = Color(0xFFD5D0C8);

  Paint _paint(bool active, {bool fill = false}) => Paint()
    ..color = active ? _activeColor : _inactiveColor
    ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
    ..strokeWidth = active ? 2.5 : 2.0
    ..strokeCap = StrokeCap.round;

  bool _hit(String region) => highlighted.contains(region);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Distribute 6 regions evenly across the canvas height
    // Region Y centers (rough anatomical proportions):
    // head: 8%, shoulders: 20%, wrists: 35%, hips: 52%, knees: 68%, ankles: 85%
    final headCY   = size.height * 0.07;
    final shldrY   = size.height * 0.19;
    final torsoTopY = size.height * 0.19;
    final torsoMidY = size.height * 0.40;
    final hipY     = size.height * 0.52;
    final kneeY    = size.height * 0.68;
    final ankleY   = size.height * 0.85;
    final headR    = size.width * 0.18;

    // Head
    canvas.drawCircle(
      Offset(cx, headCY),
      headR,
      _paint(_hit('머리/목'), fill: _hit('머리/목')),
    );

    // Neck
    canvas.drawLine(
      Offset(cx, headCY + headR),
      Offset(cx, shldrY),
      _paint(_hit('머리/목')),
    );

    // Shoulders
    canvas.drawLine(
      Offset(cx - size.width * 0.38, shldrY),
      Offset(cx + size.width * 0.38, shldrY),
      _paint(_hit('어깨')),
    );

    // Torso
    canvas.drawLine(
      Offset(cx, torsoTopY),
      Offset(cx, hipY),
      _paint(_hit('골반/고관절')),
    );

    // Left arm (shoulder → elbow → wrist)
    final elbowLX = cx - size.width * 0.38;
    final wristLX = cx - size.width * 0.45;
    canvas.drawLine(
      Offset(cx - size.width * 0.38, shldrY),
      Offset(elbowLX, torsoMidY),
      _paint(_hit('손목/팔꿈치')),
    );
    canvas.drawLine(
      Offset(elbowLX, torsoMidY),
      Offset(wristLX, torsoMidY + size.height * 0.08),
      _paint(_hit('손목/팔꿈치')),
    );

    // Right arm
    final elbowRX = cx + size.width * 0.38;
    final wristRX = cx + size.width * 0.45;
    canvas.drawLine(
      Offset(cx + size.width * 0.38, shldrY),
      Offset(elbowRX, torsoMidY),
      _paint(_hit('손목/팔꿈치')),
    );
    canvas.drawLine(
      Offset(elbowRX, torsoMidY),
      Offset(wristRX, torsoMidY + size.height * 0.08),
      _paint(_hit('손목/팔꿈치')),
    );

    // Hips
    canvas.drawLine(
      Offset(cx - size.width * 0.22, hipY),
      Offset(cx + size.width * 0.22, hipY),
      _paint(_hit('골반/고관절')),
    );
    // Hip highlight circle
    if (_hit('골반/고관절')) {
      canvas.drawCircle(Offset(cx, hipY), 5, _paint(true, fill: true));
    }

    // Left leg
    canvas.drawLine(
      Offset(cx - size.width * 0.18, hipY),
      Offset(cx - size.width * 0.18, kneeY),
      _paint(_hit('무릎')),
    );
    canvas.drawLine(
      Offset(cx - size.width * 0.18, kneeY),
      Offset(cx - size.width * 0.18, ankleY),
      _paint(_hit('발목/발')),
    );

    // Right leg
    canvas.drawLine(
      Offset(cx + size.width * 0.18, hipY),
      Offset(cx + size.width * 0.18, kneeY),
      _paint(_hit('무릎')),
    );
    canvas.drawLine(
      Offset(cx + size.width * 0.18, kneeY),
      Offset(cx + size.width * 0.18, ankleY),
      _paint(_hit('발목/발')),
    );

    // Knee highlights
    if (_hit('무릎')) {
      canvas.drawCircle(Offset(cx - size.width * 0.18, kneeY), 4, _paint(true, fill: true));
      canvas.drawCircle(Offset(cx + size.width * 0.18, kneeY), 4, _paint(true, fill: true));
    }

    // Feet
    canvas.drawLine(
      Offset(cx - size.width * 0.18, ankleY),
      Offset(cx - size.width * 0.35, ankleY),
      _paint(_hit('발목/발')),
    );
    canvas.drawLine(
      Offset(cx + size.width * 0.18, ankleY),
      Offset(cx + size.width * 0.35, ankleY),
      _paint(_hit('발목/발')),
    );
  }

  @override
  bool shouldRepaint(_BodyFigurePainter old) => old.highlighted != highlighted;
}

// ── Screenshot widget ─────────────────────────────────────────────────────────

class _ScreenshotWidget extends StatelessWidget {
  final String eventId;
  const _ScreenshotWidget({required this.eventId});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final url = auth.api.screenshotUrl(eventId);
    return Image.network(
      url,
      headers: {'Authorization': 'Bearer ${auth.token}'},
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 160,
        color: AppColors.chip,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: AppColors.textTertiary, size: 48),
        ),
      ),
    );
  }
}
