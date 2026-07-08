import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/fall_event.dart';
import '../strings.dart';
import '../widgets/app_toast.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        AppToast.show(context, s.acknowledgedMsg, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, e.toString(), type: ToastType.error);
      }
    }
  }

  // provider quota/limit errors get a friendly localized message instead of the
  // raw API payload — a plain user can't act on "SolAPI 오류 403: {...}"
  bool _isSmsLimitError(String detail) {
    final d = detail.toLowerCase();
    return d.contains('403') || d.contains('429') ||
        d.contains('limit') || d.contains('quota') ||
        d.contains('balance') || d.contains('insufficient') || d.contains('credit') ||
        detail.contains('한도') || detail.contains('잔액');
  }

  Future<void> _sendSms() async {
    setState(() => _smsLoading = true);
    final s = S.read(context);
    try {
      final result = await context.read<AuthProvider>().api.notifyGuardianSms(widget.eventId);
      if (!mounted) return;
      if (result['ok'] == true) {
        AppToast.show(context, s.smsSentMsg, type: ToastType.success);
      } else {
        final detail = result['detail']?.toString() ?? '';
        AppToast.show(
          context,
          _isSmsLimitError(detail) ? s.smsLimitMsg : s.smsFailedFriendly,
          type: ToastType.warning,
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, s.smsFailedFriendly, type: ToastType.warning);
      }
    } finally {
      if (mounted) setState(() => _smsLoading = false);
    }
  }

  Future<void> _delete() async {
    final s = S.read(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? DarkColors.surface : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.deleteEventTitle,
            style: TextStyle(
                color: isDark ? DarkColors.textPrimary : AppColors.textPrimary)),
        content: Text(s.deleteEventBody,
            style: TextStyle(
                color: isDark ? DarkColors.textSecondary : AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel,
                style: TextStyle(
                    color: isDark ? DarkColors.textSecondary : AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete,
                style: TextStyle(
                    color: isDark ? DarkColors.danger : AppColors.danger)),
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
        AppToast.show(context, e.toString(), type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s       = S.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? DarkColors.bg      : AppColors.bg;
    final surface = isDark ? DarkColors.surface  : AppColors.surface;
    final textPri = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final danger  = isDark ? DarkColors.danger   : AppColors.danger;
    final primary = isDark ? DarkColors.primary  : AppColors.primary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: textPri,
        elevation: 0,
        centerTitle: false,
        title: Text(s.eventDetailTitle,
            style: TextStyle(color: textPri, fontWeight: FontWeight.w700)),
        actions: [
          if (_event != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: danger),
              onPressed: _delete,
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary, strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: TextStyle(color: danger),
                      textAlign: TextAlign.center))
              : _buildBody(s, isDark),
    );
  }

  Widget _buildBody(S s, bool isDark) {
    final event   = _event!;
    final isSevere = event.isSevere;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final danger  = isDark ? DarkColors.danger  : AppColors.danger;
    final success = isDark ? DarkColors.success : AppColors.success;

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
                        color: const Color(0xFF1A1A1A),
                        child: Center(
                          child: CircularProgressIndicator(color: primary, strokeWidth: 2),
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
                bg: isSevere
                    ? (isDark ? DarkColors.dangerTint  : AppColors.dangerTint)
                    : (isDark ? DarkColors.warningTint : AppColors.warningTint),
                fg: isSevere
                    ? danger
                    : (isDark ? DarkColors.warningText : AppColors.warningText),
              ),
              const SizedBox(width: 8),
              if (event.isAcknowledged)
                _Pill(
                  label: s.confirmed,
                  icon: Icons.check_circle,
                  bg: isDark ? DarkColors.successTint : AppColors.successTint,
                  fg: success,
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
              child: ElevatedButton(
                onPressed: _acknowledge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(s.acknowledgeBtn,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _smsLoading ? null : _sendSms,
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _smsLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                    )
                  : Text(s.sendSmsBtn,
                      style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
            ),
          ),

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
    final s       = S.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final border  = isDark ? DarkColors.border      : AppColors.border;
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
      decoration: cardDeco(radius: 16, dark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.emergencyReportTitle,
              style: TextStyle(
                  color: textPri, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          Divider(color: border, height: 1),
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
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final textTer = isDark ? DarkColors.textTertiary : AppColors.textTertiary;
    final textPri = isDark ? DarkColors.textPrimary  : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: textTer, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: textPri, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Body region visualization ─────────────────────────────────────────────────

class _BodyRegionCard extends StatelessWidget {
  final Map<String, dynamic>? report;
  final bool isSevere;

  const _BodyRegionCard({required this.report, required this.isSevere});

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
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final textPri     = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textSec     = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final border      = isDark ? DarkColors.border        : AppColors.border;
    final primary     = isDark ? DarkColors.primary       : AppColors.primary;
    final danger      = isDark ? DarkColors.danger        : AppColors.danger;
    final dangerTint  = isDark ? DarkColors.dangerTint    : AppColors.dangerTint;
    final warningTint = isDark ? DarkColors.warningTint   : AppColors.warningTint;
    final warningText = isDark ? DarkColors.warningText   : AppColors.warningText;
    final chip        = isDark ? DarkColors.chip          : AppColors.chip;

    final highlighted   = _highlighted();
    final injKey        = _injuryKey();
    final dirRaw        = (report?['direction'] ?? '') as String;
    final dirLabel      = s.fallDirections[dirRaw] ?? (_koDirections[dirRaw] ?? '');
    final isEstimate    = (report?['estimated_injury'] ?? '').toString().isEmpty;
    final displayLabels = s.bodyRegions;

    String injDisplay = injKey;
    for (int i = 0; i < _koRegions.length; i++) {
      if (_koRegions[i] == injKey || injKey.contains(_koRegions[i].split('/').first)) {
        injDisplay = displayLabels[i];
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDeco(radius: 16, dark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.accessibility_new_rounded, color: primary, size: 18),
              const SizedBox(width: 8),
              Text(s.impactZoneTitle,
                  style: TextStyle(
                      color: textPri, fontWeight: FontWeight.w700, fontSize: 15)),
              if (isEstimate) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: warningTint,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(s.estimateLabel,
                      style: TextStyle(
                          color: warningText,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 180,
                child: CustomPaint(
                  painter: _BodyFigurePainter(
                      highlighted: highlighted,
                      regions: _koRegions,
                      isDark: isDark),
                ),
              ),
              const SizedBox(width: 16),
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
                              color: isHit ? danger : chip,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: TextStyle(
                              color: isHit ? danger : textSec,
                              fontSize: 13,
                              fontWeight: isHit ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                          if (isHit) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: dangerTint,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(s.impactBadge,
                                  style: TextStyle(
                                      color: danger,
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
          Divider(color: border, height: 1),
          const SizedBox(height: 12),

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
    required this.icon,
    required this.label,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final danger     = isDark ? DarkColors.danger      : AppColors.danger;
    final dangerTint = isDark ? DarkColors.dangerTint  : AppColors.dangerTint;
    final chip       = isDark ? DarkColors.chip        : AppColors.chip;
    final textTer    = isDark ? DarkColors.textTertiary : AppColors.textTertiary;
    final textPri    = isDark ? DarkColors.textPrimary  : AppColors.textPrimary;
    final dangerPre  = isDark ? DarkColors.danger       : AppColors.dangerPressed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? dangerTint : chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 13,
                  color: highlight ? danger : textTer),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: highlight ? dangerPre : textTer, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: highlight ? dangerPre : textPri,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Stick figure painter ──────────────────────────────────────────────────────

class _BodyFigurePainter extends CustomPainter {
  final Set<String> highlighted;
  final List<String> regions;
  final bool isDark;

  const _BodyFigurePainter({
    required this.highlighted,
    required this.regions,
    required this.isDark,
  });

  Paint _paint(bool active, {bool fill = false}) => Paint()
    ..color = active
        ? (isDark ? DarkColors.danger : AppColors.danger)
        : (isDark ? DarkColors.border : AppColors.border)
    ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
    ..strokeWidth = active ? 2.5 : 2.0
    ..strokeCap = StrokeCap.round;

  bool _hit(String region) => highlighted.contains(region);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final headCY    = size.height * 0.07;
    final shldrY    = size.height * 0.19;
    final torsoMidY = size.height * 0.40;
    final hipY      = size.height * 0.52;
    final kneeY     = size.height * 0.68;
    final ankleY    = size.height * 0.85;
    final headR     = size.width  * 0.18;

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
      canvas.drawCircle(Offset(cx - size.width * 0.18, kneeY), 4,
          _paint(true, fill: true));
      canvas.drawCircle(Offset(cx + size.width * 0.18, kneeY), 4,
          _paint(true, fill: true));
    }

    canvas.drawLine(Offset(cx - size.width * 0.18, ankleY),
        Offset(cx - size.width * 0.35, ankleY), _paint(_hit('발목/발')));
    canvas.drawLine(Offset(cx + size.width * 0.18, ankleY),
        Offset(cx + size.width * 0.35, ankleY), _paint(_hit('발목/발')));
  }

  @override
  bool shouldRepaint(_BodyFigurePainter old) =>
      old.highlighted != highlighted || old.isDark != isDark;
}

// ── Screenshot widget ─────────────────────────────────────────────────────────

class _ScreenshotWidget extends StatelessWidget {
  final String eventId;
  const _ScreenshotWidget({required this.eventId});

  @override
  Widget build(BuildContext context) {
    final auth    = context.read<AuthProvider>();
    final url     = auth.api.screenshotUrl(eventId);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final chip    = isDark ? DarkColors.chip        : AppColors.chip;
    final textTer = isDark ? DarkColors.textTertiary : AppColors.textTertiary;
    return Image.network(
      url,
      headers: {'Authorization': 'Bearer ${auth.token}'},
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 160,
        color: chip,
        child: Center(
          child: Icon(Icons.image_not_supported_outlined, color: textTer, size: 48),
        ),
      ),
    );
  }
}
