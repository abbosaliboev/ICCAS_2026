import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../models/fall_event.dart';
import '../services/ws_service.dart';
import '../strings.dart';
import '../widgets/fall_response_overlay.dart';
import 'event_detail_screen.dart';
import 'events_screen.dart';
import 'stream_screen.dart';
import 'reports_screen.dart';
import 'app_settings_screen.dart';
import 'guardian_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  WsEvent? _activeAlert;
  StreamSubscription? _wsSub;
  List<FallEvent> _recentEvents = [];
  bool _eventsLoading = true;
  WsEvent? _overlayEvent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeWs();
      _loadEvents();
    });
  }

  void _subscribeWs() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    _wsSub = auth.ws?.events.listen((event) {
      if (!mounted) return;
      setState(() => _activeAlert = event);
      if (event.isFallDetected) {
        if (user?.role == 'user' && event.eventId != null) {
          setState(() => _overlayEvent = event);
        }
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted && _activeAlert?.eventId == event.eventId) {
            setState(() => _activeAlert = null);
          }
        });
        _loadEvents();
      } else if (event.isFallResolved) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _activeAlert = null);
        });
      }
    });
  }

  Future<void> _loadEvents() async {
    final api = context.read<AuthProvider>().api;
    try {
      final events = await api.getFallEvents();
      if (mounted) {
        setState(() {
          _recentEvents = events.take(2).toList();
          _eventsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s    = S.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? DarkColors.bg      : AppColors.bg;
    final surface = isDark ? DarkColors.surface  : AppColors.surface;
    final border  = isDark ? DarkColors.border   : AppColors.border;
    final primary = isDark ? DarkColors.primary  : AppColors.primary;
    final textTer = isDark ? DarkColors.textTertiary : AppColors.textTertiary;

    final tabs = [
      user.isGuardian
          ? const GuardianScreen()
          : _DashboardTab(
              user: user,
              activeAlert: _activeAlert,
              recentEvents: _recentEvents,
              eventsLoading: _eventsLoading,
              onRefresh: _loadEvents,
              onDismissAlert: () => setState(() => _activeAlert = null),
              onGoToEvents: () => setState(() => _tabIndex = 1),
            ),
      const EventsScreen(),
      const ReportsScreen(),
      const AppSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          IndexedStack(index: _tabIndex, children: tabs),
          if (_overlayEvent != null)
            Positioned.fill(
              child: FallResponseOverlay(
                eventId: _overlayEvent!.eventId!,
                onDismiss: () => setState(() => _overlayEvent = null),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surface,
          border: Border(top: BorderSide(color: border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          backgroundColor: surface,
          selectedItemColor: primary,
          unselectedItemColor: textTer,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home_rounded),
              label: s.home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history_outlined),
              activeIcon: const Icon(Icons.history_rounded),
              label: s.records,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.bar_chart_outlined),
              activeIcon: const Icon(Icons.bar_chart_rounded),
              label: s.report,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings_rounded),
              label: s.settings,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard tab ─────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final dynamic user;
  final WsEvent? activeAlert;
  final List<FallEvent> recentEvents;
  final bool eventsLoading;
  final VoidCallback onRefresh;
  final VoidCallback onDismissAlert;
  final VoidCallback onGoToEvents;

  const _DashboardTab({
    required this.user,
    required this.activeAlert,
    required this.recentEvents,
    required this.eventsLoading,
    required this.onRefresh,
    required this.onDismissAlert,
    required this.onGoToEvents,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => onRefresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            _Header(user: user),
            const SizedBox(height: 16),
            _StatusHeroBanner(activeAlert: activeAlert, onDismiss: onDismissAlert),
            const SizedBox(height: 16),
            _StreamCard(),
            const SizedBox(height: 16),
            _EmergencyButtons(activeAlert: activeAlert, onDismiss: onDismissAlert),
            const SizedBox(height: 24),
            _RecentEventsSection(
              recentEvents: recentEvents,
              loading: eventsLoading,
              onViewAll: onGoToEvents,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final dynamic user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final s     = S.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final isKo = context.watch<SettingsProvider>().localeCode == 'ko';
    final now  = DateTime.now();

    final String dateStr;
    if (isKo) {
      final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      final ampm = now.hour >= 12 ? '오후' : '오전';
      final h    = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      dateStr =
          '${now.year}년 ${now.month}월 ${now.day}일 (${weekdays[now.weekday - 1]}) · '
          '$ampm $h:${now.minute.toString().padLeft(2, '0')}';
    } else {
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      final ampm = now.hour >= 12 ? 'PM' : 'AM';
      final h    = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      dateStr =
          '${months[now.month - 1]} ${now.day}, ${now.year} (${weekdays[now.weekday - 1]}) · '
          '$ampm $h:${now.minute.toString().padLeft(2, '0')}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.greeting(user.displayName.isNotEmpty ? user.displayName : user.username),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textPri,
          ),
        ),
        const SizedBox(height: 2),
        Text(dateStr, style: TextStyle(color: textSec, fontSize: 13)),
      ],
    );
  }
}

// ── Status hero banner ────────────────────────────────────────────────────────

class _StatusHeroBanner extends StatelessWidget {
  final WsEvent? activeAlert;
  final VoidCallback onDismiss;
  const _StatusHeroBanner({required this.activeAlert, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final s        = S.of(context);
    final hasAlert = activeAlert != null;
    final isSevere = activeAlert?.category == 'severe';
    final bg = hasAlert ? AppColors.dangerTint : AppColors.successTint;
    final color = hasAlert
        ? (isSevere ? AppColors.danger : AppColors.warning)
        : AppColors.success;
    final headline = hasAlert
        ? (isSevere ? s.needsAttention : s.fallSuspected)
        : s.normal;
    final sub = hasAlert
        ? (isSevere ? s.severeFallMsg : s.fallDetectedMsg)
        : s.safeNote;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              hasAlert ? Icons.warning_rounded : Icons.check_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: hasAlert ? AppColors.dangerPressed : AppColors.success,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasAlert
                        ? AppColors.dangerPressed.withOpacity(0.8)
                        : AppColors.success.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          if (hasAlert)
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, color: AppColors.danger, size: 20),
            ),
        ],
      ),
    );
  }
}

// ── Live stream card ──────────────────────────────────────────────────────────

class _StreamCard extends StatefulWidget {
  const _StreamCard();
  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard> with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  Timer? _zoneTimer;
  Uint8List? _frame;
  bool _fetching = false;
  List<Map<String, double>> _zones = [];
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.25).animate(_pulseCtrl);
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _fetch());
    _loadZones();
    _zoneTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadZones());
  }

  Future<void> _loadZones() async {
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.getSafeZone();
      final zones = (data['zones'] as List?)
          ?.map((e) {
            final m = e as Map<String, dynamic>;
            return {
              'x': (m['x'] as num).toDouble(),
              'y': (m['y'] as num).toDouble(),
              'w': (m['w'] as num).toDouble(),
              'h': (m['h'] as num).toDouble(),
            };
          }).toList() ?? <Map<String, double>>[];
      if (mounted) setState(() => _zones = zones);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _zoneTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_fetching || !mounted) return;
    _fetching = true;
    try {
      final auth = context.read<AuthProvider>();
      final res = await http
          .get(
            Uri.parse(auth.api.snapshotUrl()),
            headers: {'Authorization': 'Bearer ${auth.token}'},
          )
          .timeout(const Duration(seconds: 3));
      if (!mounted) return;
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        setState(() => _frame = res.bodyBytes);
      }
    } catch (_) {
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s      = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StreamScreen()),
      ),
      child: Container(
        decoration: cardDeco(radius: 18, dark: isDark),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Frame or placeholder — with safe zone overlay
              CustomPaint(
                foregroundPainter: _zones.isNotEmpty
                    ? _StreamZonePainter(zones: _zones)
                    : null,
                child: _frame != null
                    ? Image.memory(_frame!, fit: BoxFit.cover, gaplessPlayback: true)
                    : _StripePlaceholder(),
              ),

              // Top-left: AI badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _pulseAnim,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.aiAnalyzing,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom-left: camera label
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam, color: Colors.white70, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        s.liveCam,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),

              // Top-right: expand icon
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _StripePainter());
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF1A1A1A));
    final p = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke;
    for (double x = -size.height; x < size.width + size.height; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 160,
        height: 24,
      ),
      Paint()..color = Colors.white.withOpacity(0.06),
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: '[ MJPEG LIVE STREAM ]',
        style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_) => false;
}

class _StreamZonePainter extends CustomPainter {
  final List<Map<String, double>> zones;
  const _StreamZonePainter({required this.zones});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = const Color(0xFF00C850).withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF00C850)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final z in zones) {
      final rect = Rect.fromLTWH(
        (z['x']! * size.width),
        (z['y']! * size.height),
        (z['w']! * size.width),
        (z['h']! * size.height),
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
    }
  }

  @override
  bool shouldRepaint(_StreamZonePainter old) => old.zones != zones;
}

// ── Emergency buttons ─────────────────────────────────────────────────────────

class _EmergencyButtons extends StatefulWidget {
  final WsEvent? activeAlert;
  final VoidCallback onDismiss;
  const _EmergencyButtons({required this.activeAlert, required this.onDismiss});
  @override
  State<_EmergencyButtons> createState() => _EmergencyButtonsState();
}

class _EmergencyButtonsState extends State<_EmergencyButtons> {
  bool _sending = false;

  Future<void> _callEmergency() async {
    if (_sending) return;
    final s = S.read(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.emergencyDialogTitle),
        content: Text(s.emergencyDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(s.contactNow),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _sending = true);
    try {
      final auth = context.read<AuthProvider>();
      final events = await auth.api.getFallEvents();
      if (events.isNotEmpty && mounted) {
        await Future.wait([
          auth.api.notifyGuardianSms(events.first.id),
          auth.api.notifyEmergencySms(events.first.id),
        ]);
      }
      if (mounted) {
        final sNow = S.read(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sNow.guardianContactedMsg),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final sNow = S.read(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sNow.contactFailed(e.toString())), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _callEmergency,
                  icon: _sending
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('🚨', style: TextStyle(fontSize: 18)),
                  label: Text(s.emergencyCall,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.danger.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 60,
                child: OutlinedButton(
                  onPressed: widget.activeAlert != null ? widget.onDismiss : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    disabledForegroundColor: AppColors.textTertiary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ).copyWith(
                    side: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return const BorderSide(color: AppColors.border);
                      }
                      return const BorderSide(color: AppColors.success);
                    }),
                  ),
                  child: Text(s.allClearBtn,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Recent events section ─────────────────────────────────────────────────────

class _RecentEventsSection extends StatelessWidget {
  final List<FallEvent> recentEvents;
  final bool loading;
  final VoidCallback onViewAll;

  const _RecentEventsSection({
    required this.recentEvents,
    required this.loading,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final s      = S.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final primary = isDark ? DarkColors.primary       : AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              s.recentFalls,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPri),
            ),
            GestureDetector(
              onTap: onViewAll,
              child: Text(
                s.viewAll,
                style: TextStyle(fontSize: 13, color: primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(color: primary, strokeWidth: 2),
            ),
          )
        else if (recentEvents.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: cardDeco(radius: 14, dark: isDark),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 36),
                  const SizedBox(height: 8),
                  Text(s.noRecentFalls,
                      style: TextStyle(color: textSec, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          ...recentEvents.map((e) => _RecentEventTile(event: e)),
      ],
    );
  }
}

class _RecentEventTile extends StatelessWidget {
  final FallEvent event;
  const _RecentEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final s        = S.of(context);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textPri   = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textTer   = isDark ? DarkColors.textTertiary  : AppColors.textTertiary;
    final isSevere  = event.isSevere;
    final badgeBg   = isSevere ? AppColors.dangerTint  : AppColors.warningTint;
    final badgeText = isSevere ? AppColors.danger       : AppColors.warningText;
    final label     = isSevere ? s.severe : s.mild;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(radius: 14, dark: isDark),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSevere ? AppColors.dangerTint : AppColors.warningTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.personal_injury_outlined,
                color: isSevere ? AppColors.danger : AppColors.warningText,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTs(event.timestamp, context),
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPri, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.isAcknowledged ? s.confirmed : s.needsConfirm,
                    style: TextStyle(
                      fontSize: 12,
                      color: event.isAcknowledged ? textTer : AppColors.dangerPressed,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(100)),
                  child: Text(label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: badgeText)),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, size: 16, color: textTer),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTs(String ts, BuildContext context) {
    try {
      final dt   = DateTime.parse(ts).toLocal();
      final isKo = context.read<SettingsProvider>().localeCode == 'ko';
      final h    = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      if (isKo) {
        final ampm = dt.hour >= 12 ? '오후' : '오전';
        return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} · '
            '$ampm $h:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} · '
            '$ampm $h:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return ts;
    }
  }
}
