import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/fall_event.dart';
import '../strings.dart';

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
  bool _smsSuccess = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthProvider>().api;
    try {
      final event = await api.getFallEvent(widget.eventId);
      if (event == null) throw Exception('Event not found');
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
    final s   = S.read(context);
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
          SnackBar(content: Text(s.acknowledgedMsg), backgroundColor: AppColors.success),
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
      final s      = S.read(context);
      final result = await context.read<AuthProvider>().api.notifyGuardianSms(widget.eventId);
      final ok = result['ok'] == true;
      setState(() {
        _smsSuccess = ok;
        _smsResult  = ok ? s.smsSentMsg : s.smsFailed(result['detail']?.toString() ?? '');
      });
    } catch (e) {
      setState(() { _smsSuccess = false; _smsResult = e.toString(); });
    } finally {
      setState(() => _smsLoading = false);
    }
  }

  Future<void> _delete() async {
    final s = S.read(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.deleteEventTitle,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(s.deleteEventBody,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete, style: const TextStyle(color: AppColors.danger)),
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
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        title: Text(s.eventDetailTitle,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
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
              : _buildBody(s),
    );
  }

  Widget _buildBody(S s) {
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
                label: isSevere ? s.severeFall : s.fallSuspect,
                icon: Icons.warning_rounded,
                bg: isSevere ? AppColors.dangerTint : AppColors.warningTint,
                fg: isSevere ? AppColors.danger : AppColors.warningText,
              ),
              const SizedBox(width: 8),
              if (event.isAcknowledged)
                _Pill(
                  label: s.confirmed,
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
                label: Text(s.acknowledgeBtn,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
              label: Text(s.sendSmsBtn,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
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
                color: _smsSuccess ? AppColors.success : AppColors.danger,
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
    final s = S.of(context);
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
          Text(s.emergencyReportTitle,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          _Row(label: s.nameLabel,    value: r['name'] ?? '-'),
          _Row(label: s.ageLabel,     value: r['age']?.toString() ?? '-'),
          _Row(label: s.addressLabel, value: r['address'] ?? '-'),
          _Row(label: s.contactField, value: r['phone'] ?? '-'),
          _Row(label: s.timeLabel,    value: tsFormatted),
          _Row(label: s.footageLabel, value: r['has_video'] == true ? s.available : s.none),
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
              width: 80,
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

  // Korean internal keys — must match backend data
  static const _koRegions = [
    '머리/목', '어깨', '손목/팔꿈치', '골반/고관절', '무릎', '발목/발',
  ];

  static const _koDirections = {
    'forward':        '앞으로 넘어짐',
    'backward':       '뒤로 넘어짐',
    'sideways_left':  '왼쪽으로 넘어짐',
    'sideways_right': '오른쪽으로 넘어짐',
  };

  String _injuryKey() {
    final raw = (report?['estimated_injury'] ?? '') as String;
    if (raw.isNotEmpty) return raw;
    return isSevere ? '골반/고관절' : '무릎/손목';
  }

  Set<String> _highlighted() {
    final inj = _injuryKey().toLowerCase();
    final hits = <String>{};
    for (final r in _koRegions) {
      if (inj.contains(r.split('/').first.toLowerCase()) ||
          inj.contains(r.split('/').last.toLowerCase())) {
        hits.add(r);
      }
    }
    if (hits.isEmpty) {
      for (final r in _koRegions) {
        if (r.toLowerCase().contains(inj) ||
            inj.contains(r.toLowerCase().split('/').first)) {
          hits.add(r);
        }
      }
    }
    return hits;
  }

  @override
  Widget build(BuildContext context) {
    final s           = S.of(context);
    final highlighted = _highlighted();
    final injKey      = _injuryKey();
    final dirRaw      = (report?['direction'] ?? '') as String;
    final dirLabel    = s.fallDirections[dirRaw] ?? (_koDirections[dirRaw] ?? '');
    final isEstimate  = (report?['estimated_injury'] ?? '').toString().isEmpty;
    final displayLabels = s.bodyRegions; // localized, same order as _koRegions

    // Build a localized injury label: find matching Korean key, use its English equivalent
    String injDisplay = injKey;
    for (int i = 0; i < _koRegions.length; i++) {
      if (_koRegions[i] == injKey || injKey.contains(_koRegions[i].split('/').first)) {
        injDisplay = displayLabels[i];
        break;
      }
    }

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
              Text(s.impactZoneTitle,
                  style: const TextStyle(
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
                  child: Text(s.estimateLabel,
                      style: const TextStyle(
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
              // Stick figure (uses internal Korean keys for highlight logic)
              SizedBox(
                width: 80,
                height: 180,
                child: CustomPaint(
                  painter: _BodyFigurePainter(
                      highlighted: highlighted, regions: _koRegions),
                ),
              ),
              const SizedBox(width: 16),

              // Region labels (localized)
              Expanded(
                child: Column(
                  children: List.generate(_koRegions.length, (i) {
                    final koKey = _koRegions[i];
                    final isHit = highlighted.contains(koKey);
                    final label = displayLabels[i];
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
                            label,
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
                              child: Text(s.impactBadge,
                                  style: const TextStyle(
                                      color: AppColors.danger,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
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
                  label: s.estimatedImpact,
                  value: injDisplay,
                  highlight: true,
                ),
              ),
              if (dirLabel.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryItem(
                    icon: Icons.turn_slight_right,
                    label: s.fallDirectionLabel,
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

  static const _activeColor   = AppColors.danger;
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
    final headCY   = size.height * 0.07;
    final shldrY   = size.height * 0.19;
    final torsoMidY = size.height * 0.40;
    final hipY     = size.height * 0.52;
    final kneeY    = size.height * 0.68;
    final ankleY   = size.height * 0.85;
    final headR    = size.width * 0.18;

    canvas.drawCircle(Offset(cx, headCY), headR,
        _paint(_hit('머리/목'), fill: _hit('머리/목')));
    canvas.drawLine(Offset(cx, headCY + headR), Offset(cx, shldrY),
        _paint(_hit('머리/목')));
    canvas.drawLine(Offset(cx - size.width * 0.38, shldrY),
        Offset(cx + size.width * 0.38, shldrY), _paint(_hit('어깨')));
    canvas.drawLine(Offset(cx, shldrY), Offset(cx, hipY),
        _paint(_hit('골반/고관절')));

    final elbowLX = cx - size.width * 0.38;
    final wristLX = cx - size.width * 0.45;
    canvas.drawLine(Offset(cx - size.width * 0.38, shldrY),
        Offset(elbowLX, torsoMidY), _paint(_hit('손목/팔꿈치')));
    canvas.drawLine(Offset(elbowLX, torsoMidY),
        Offset(wristLX, torsoMidY + size.height * 0.08), _paint(_hit('손목/팔꿈치')));

    final elbowRX = cx + size.width * 0.38;
    final wristRX = cx + size.width * 0.45;
    canvas.drawLine(Offset(cx + size.width * 0.38, shldrY),
        Offset(elbowRX, torsoMidY), _paint(_hit('손목/팔꿈치')));
    canvas.drawLine(Offset(elbowRX, torsoMidY),
        Offset(wristRX, torsoMidY + size.height * 0.08), _paint(_hit('손목/팔꿈치')));

    canvas.drawLine(Offset(cx - size.width * 0.22, hipY),
        Offset(cx + size.width * 0.22, hipY), _paint(_hit('골반/고관절')));
    if (_hit('골반/고관절')) {
      canvas.drawCircle(Offset(cx, hipY), 5, _paint(true, fill: true));
    }

    canvas.drawLine(Offset(cx - size.width * 0.18, hipY),
        Offset(cx - size.width * 0.18, kneeY), _paint(_hit('무릎')));
    canvas.drawLine(Offset(cx - size.width * 0.18, kneeY),
        Offset(cx - size.width * 0.18, ankleY), _paint(_hit('발목/발')));
    canvas.drawLine(Offset(cx + size.width * 0.18, hipY),
        Offset(cx + size.width * 0.18, kneeY), _paint(_hit('무릎')));
    canvas.drawLine(Offset(cx + size.width * 0.18, kneeY),
        Offset(cx + size.width * 0.18, ankleY), _paint(_hit('발목/발')));

    if (_hit('무릎')) {
      canvas.drawCircle(Offset(cx - size.width * 0.18, kneeY), 4, _paint(true, fill: true));
      canvas.drawCircle(Offset(cx + size.width * 0.18, kneeY), 4, _paint(true, fill: true));
    }

    canvas.drawLine(Offset(cx - size.width * 0.18, ankleY),
        Offset(cx - size.width * 0.35, ankleY), _paint(_hit('발목/발')));
    canvas.drawLine(Offset(cx + size.width * 0.18, ankleY),
        Offset(cx + size.width * 0.35, ankleY), _paint(_hit('발목/발')));
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
    final url  = auth.api.screenshotUrl(eventId);
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
