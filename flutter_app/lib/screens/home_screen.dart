import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../models/fall_event.dart';
import '../services/mjpeg_stream.dart';
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
  late final PageController _pageCtrl;
  final _guardianKey = GlobalKey<GuardianScreenState>();
  final _eventsKey  = GlobalKey<EventsScreenState>();
  final _reportsKey = GlobalKey<ReportsScreenState>();

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeWs();
      _loadEvents();
      _refreshCameraDemoMode();
    });
  }

  // Tabs are kept alive (never re-initState), so data would silently go stale
  // when the user switches pages — refresh whichever tab just became visible.
  void _onTabVisible(int i) {
    if (i == 0) {
      _loadEvents();
      _refreshCameraDemoMode();
    }
    if (i == 1) _eventsKey.currentState?.reload();
    if (i == 2) _reportsKey.currentState?.reload();
  }

  // Always re-checks the server rather than trusting a cached value — camera
  // demo mode being silently left on (real monitoring paused) is a safety
  // issue, not just a UI staleness one.
  Future<void> _refreshCameraDemoMode() async {
    try {
      final api = context.read<AuthProvider>().api;
      final enabled = await api.getCameraDemoMode();
      if (mounted) context.read<SettingsProvider>().setCameraDemoModeLocal(enabled);
    } catch (_) {}
  }

  void _goToTab(int i) {
    _pageCtrl.animateToPage(i,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  void _subscribeWs() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    _wsSub = auth.ws?.events.listen((event) {
      if (!mounted) return;
      setState(() => _activeAlert = event);
      if (event.isFallDetected) {
        final demoTtsStt = context.read<SettingsProvider>().demoTtsSttEnabled;
        if (user?.role == 'user' || (user?.isGuardian == true && demoTtsStt)) {
          setState(() => _overlayEvent = event);
        }
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted && _activeAlert?.eventId == event.eventId) {
            setState(() => _activeAlert = null);
          }
        });
        _loadEvents();
        _guardianKey.currentState?.reload();
        _eventsKey.currentState?.reload();
        _reportsKey.currentState?.reload();
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
          _recentEvents = events.take(1).toList();
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
    _pageCtrl.dispose();
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
          ? GuardianScreen(
              key: _guardianKey,
              fallDetected: _activeAlert?.isFallDetected == true,
              onOpenHistory: () => _goToTab(1),
            )
          : _DashboardTab(
              user: user,
              activeAlert: _activeAlert,
              recentEvents: _recentEvents,
              eventsLoading: _eventsLoading,
              streamVisible: _tabIndex == 0,
              onRefresh: _loadEvents,
              onDismissAlert: () => setState(() => _activeAlert = null),
              onGoToEvents: () => _goToTab(1),
            ),
      EventsScreen(key: _eventsKey),
      ReportsScreen(key: _reportsKey),
      const AppSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (i) {
                setState(() => _tabIndex = i);
                _onTabVisible(i);
              },
              children: tabs,
            ),
          ),
          if (_overlayEvent != null)
            Positioned.fill(
              child: FallResponseOverlay(
                eventId: _overlayEvent!.eventId,
                demoMode: user.isGuardian,
                onDismiss: () => setState(() => _overlayEvent = null),
              ),
            ),
        ],
      ),
      // Floating-style bottom bar: rounded top corners + a soft upward shadow
      // lift it off the content plane; the active item gets a tinted pill.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: border.withOpacity(0.6))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: s.home,
                    selected: _tabIndex == 0,
                    primary: primary,
                    inactive: textTer,
                    tint: isDark ? DarkColors.primaryTint : AppColors.primaryTint,
                    onTap: () => _goToTab(0),
                  ),
                  _NavItem(
                    icon: Icons.history_outlined,
                    activeIcon: Icons.history_rounded,
                    label: s.records,
                    selected: _tabIndex == 1,
                    primary: primary,
                    inactive: textTer,
                    tint: isDark ? DarkColors.primaryTint : AppColors.primaryTint,
                    onTap: () => _goToTab(1),
                  ),
                  _NavItem(
                    icon: Icons.bar_chart_outlined,
                    activeIcon: Icons.bar_chart_rounded,
                    label: s.report,
                    selected: _tabIndex == 2,
                    primary: primary,
                    inactive: textTer,
                    tint: isDark ? DarkColors.primaryTint : AppColors.primaryTint,
                    onTap: () => _goToTab(2),
                  ),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    label: s.settings,
                    selected: _tabIndex == 3,
                    primary: primary,
                    inactive: textTer,
                    tint: isDark ? DarkColors.primaryTint : AppColors.primaryTint,
                    onTap: () => _goToTab(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom nav item ───────────────────────────────────────────────────────────
// Animated pill: the tint grows behind the active icon (200ms ease-out), and
// the label only renders for the active tab so the bar stays visually quiet.

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color primary;
  final Color inactive;
  final Color tint;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.primary,
    required this.inactive,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // heightFactor keeps Center from expanding: Scaffold hands the
        // bottomNavigationBar loose height constraints, and an unbounded
        // Center would claim the full screen, squeezing the body to 0.
        child: Center(
          heightFactor: 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
                horizontal: selected ? 16 : 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? tint : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? activeIcon : icon,
                    size: 22, color: selected ? primary : inactive),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(
                              color: primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
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
  final bool streamVisible;
  final VoidCallback onRefresh;
  final VoidCallback onDismissAlert;
  final VoidCallback onGoToEvents;

  const _DashboardTab({
    required this.user,
    required this.activeAlert,
    required this.recentEvents,
    required this.eventsLoading,
    required this.streamVisible,
    required this.onRefresh,
    required this.onDismissAlert,
    required this.onGoToEvents,
  });

  @override
  Widget build(BuildContext context) {
    final cameraDemoMode = context.watch<SettingsProvider>().cameraDemoMode;
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => onRefresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          children: [
            if (cameraDemoMode) ...[
              const _CameraDemoModeBanner(),
              const SizedBox(height: 18),
            ],
            _Header(user: user),
            const SizedBox(height: 18),
            _StatusHeroBanner(activeAlert: activeAlert, onDismiss: onDismissAlert),
            const SizedBox(height: 18),
            _LiveStreamCard(visible: streamVisible),
            const SizedBox(height: 18),
            _EmergencyButtons(activeAlert: activeAlert, onDismiss: onDismissAlert),
            const SizedBox(height: 26),
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

// ── Camera demo mode banner ──────────────────────────────────────────────────
// Unmissable on purpose: while camera demo mode is on, real fall detection is
// NOT running on the live feed. Tapping jumps straight to Settings to turn it
// back off.

class _CameraDemoModeBanner extends StatelessWidget {
  const _CameraDemoModeBanner();

  @override
  Widget build(BuildContext context) {
    final s      = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warn     = isDark ? DarkColors.warning     : AppColors.warning;
    final warnText = isDark ? DarkColors.warningText : AppColors.warningText;
    final warnTint = isDark ? DarkColors.warningTint : AppColors.warningTint;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warnTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: warn, width: 1.5),
        ),
        child: Row(
          children: [
            Container(width: 4, height: 34,
                decoration: BoxDecoration(color: warn, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.cameraDemoModeActive,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: warnText)),
                  const SizedBox(height: 2),
                  Text(s.cameraDemoModeBannerBody,
                      style: TextStyle(fontSize: 12, color: warnText, height: 1.3)),
                ],
              ),
            ),
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
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: textPri,
          ),
        ),
        const SizedBox(height: 3),
        Text(dateStr, style: TextStyle(color: textSec, fontSize: 14)),
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
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final hasAlert = activeAlert != null;
    final isSevere = activeAlert?.category == 'severe';
    final dangerTint  = isDark ? DarkColors.dangerTint  : AppColors.dangerTint;
    final successTint = isDark ? DarkColors.successTint : AppColors.successTint;
    final danger  = isDark ? DarkColors.danger  : AppColors.danger;
    final warning = isDark ? DarkColors.warning : AppColors.warning;
    final success = isDark ? DarkColors.success : AppColors.success;
    final bg = hasAlert ? dangerTint : successTint;
    final color = hasAlert ? (isSevere ? danger : warning) : success;
    final headlineColor = hasAlert
        ? (isDark ? DarkColors.danger : AppColors.dangerPressed)
        : success;
    final headline = hasAlert
        ? (isSevere ? s.needsAttention : s.fallSuspected)
        : s.normal;
    final sub = hasAlert
        ? (isSevere ? s.severeFallMsg : s.fallDetectedMsg)
        : s.safeNote;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              hasAlert ? Icons.event_note_outlined : Icons.check_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: headlineColor,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 13,
                    color: headlineColor.withOpacity(0.82),
                  ),
                ),
              ],
            ),
          ),
          if (hasAlert)
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, color: danger, size: 18),
            ),
        ],
      ),
    );
  }
}

// ── Live stream card ──────────────────────────────────────────────────────────

// Embedded live monitor: streams the same persistent MJPEG connection the
// full-screen viewer uses. Per-frame updates go through ValueNotifiers so only
// the video surface repaints — the dashboard around it never rebuilds. The
// stream is stopped whenever this tab is hidden, the app is backgrounded, or
// the full-screen viewer is open, so at most ONE connection ever pulls frames
// over the weak edge↔backend WiFi link.
class _LiveStreamCard extends StatefulWidget {
  final bool visible;
  const _LiveStreamCard({required this.visible});
  @override
  State<_LiveStreamCard> createState() => _LiveStreamCardState();
}

class _LiveStreamCardState extends State<_LiveStreamCard>
    with WidgetsBindingObserver {
  MjpegStreamController? _ctrl;
  int _zoneCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      _ctrl = MjpegStreamController(
        url: () => auth.api.streamUrl(),
        headers: () => {'Authorization': 'Bearer ${auth.token}'},
      );
      if (widget.visible) _ctrl!.start();
      setState(() {});
      _loadZones(auth);
    });
  }

  Future<void> _loadZones(AuthProvider auth) async {
    try {
      final data = await auth.api.getSafeZone();
      final zones = (data['zones'] as List?) ?? const [];
      if (mounted) setState(() => _zoneCount = zones.length);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant _LiveStreamCard old) {
    super.didUpdateWidget(old);
    if (widget.visible != old.visible) {
      widget.visible ? _ctrl?.start() : _ctrl?.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.visible) _ctrl?.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _ctrl?.stop();
    }
  }

  Future<void> _openFullscreen() async {
    _ctrl?.stop(); // hand the single connection over to the viewer
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const StreamScreen()));
    if (mounted && widget.visible) _ctrl?.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s      = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl   = _ctrl;

    return GestureDetector(
      onTap: _openFullscreen,
      child: Container(
        decoration: cardDeco(radius: 18, dark: isDark, bordered: false),
        clipBehavior: Clip.antiAlias,
        // Everything lives on the video itself — no info strip below, so the
        // stream fills the whole card.
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Container(
            color: const Color(0xFF10151F),
            child: ctrl == null
                ? const SizedBox.shrink()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      // Only this subtree repaints per frame.
                      RepaintBoundary(
                        child: ValueListenableBuilder<Uint8List?>(
                          valueListenable: ctrl.frame,
                          builder: (_, frame, __) => frame == null
                              ? _StreamPlaceholder(ctrl: ctrl, s: s)
                              : Image.memory(
                                  frame,
                                  gaplessPlayback: true,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      // LIVE badge + FPS
                      Positioned(
                        top: 10, left: 10,
                        child: ValueListenableBuilder<MjpegStatus>(
                          valueListenable: ctrl.status,
                          builder: (_, st, __) =>
                              _LiveBadge(live: st == MjpegStatus.live, s: s),
                        ),
                      ),
                      Positioned(
                        top: 10, right: 10,
                        child: ValueListenableBuilder<int>(
                          valueListenable: ctrl.fps,
                          builder: (_, fps, __) => fps > 0
                              ? _GlassChip(text: '$fps FPS')
                              : const SizedBox.shrink(),
                        ),
                      ),
                      // Connection status — bottom-left, same glass style as
                      // the LIVE badge
                      Positioned(
                        bottom: 10, left: 10,
                        child: ValueListenableBuilder<MjpegStatus>(
                          valueListenable: ctrl.status,
                          builder: (_, st, __) {
                            final live = st == MjpegStatus.live;
                            final connecting = st == MjpegStatus.connecting;
                            final dotColor = live
                                ? DarkColors.success
                                : connecting
                                    ? DarkColors.warning
                                    : DarkColors.danger;
                            final label = live
                                ? s.streamConnected
                                : connecting
                                    ? s.connecting
                                    : s.streamDisconnected;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _GlassChip(text: label, dotColor: dotColor),
                                if (_zoneCount > 0) ...[
                                  const SizedBox(width: 6),
                                  _GlassChip(
                                      icon: Icons.crop_free_rounded,
                                      text: s.zonesCount(_zoneCount)),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 10, right: 10,
                        child: _GlassChip(
                          icon: Icons.fullscreen_rounded,
                          text: '',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StreamPlaceholder extends StatelessWidget {
  final MjpegStreamController ctrl;
  final S s;
  const _StreamPlaceholder({required this.ctrl, required this.s});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MjpegStatus>(
      valueListenable: ctrl.status,
      builder: (_, st, __) => Center(
        child: st == MjpegStatus.error
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_outlined,
                      color: Colors.white38, size: 36),
                  const SizedBox(height: 8),
                  Text(s.cameraOffline,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
                ],
              )
            : const SizedBox(
                width: 26, height: 26,
                child: CircularProgressIndicator(
                    color: Colors.white38, strokeWidth: 2),
              ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final bool live;
  final S s;
  const _LiveBadge({required this.live, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: live
            ? AppColors.danger.withOpacity(0.92)
            : Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            live ? 'LIVE' : s.liveCam,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? dotColor;
  const _GlassChip({required this.text, this.icon, this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: text.isEmpty ? 5 : 8, vertical: text.isEmpty ? 5 : 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 7, height: 7,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          if (icon != null)
            Icon(icon, color: Colors.white, size: 16),
          if (icon != null && text.isNotEmpty) const SizedBox(width: 4),
          if (text.isNotEmpty)
            Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
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
                      : const Icon(Icons.phone_in_talk_rounded, size: 20),
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
                child: Builder(builder: (context) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final success =
                      isDark ? DarkColors.success : AppColors.success;
                  final border = isDark ? DarkColors.border : AppColors.border;
                  final textTer =
                      isDark ? DarkColors.textTertiary : AppColors.textTertiary;
                  return OutlinedButton(
                    onPressed:
                        widget.activeAlert != null ? widget.onDismiss : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: success,
                      disabledForegroundColor: textTer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ).copyWith(
                      side: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.disabled)) {
                          return BorderSide(color: border);
                        }
                        return BorderSide(color: success);
                      }),
                    ),
                    child: Text(s.allClearBtn,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  );
                }),
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
              child: Text(s.noRecentFalls,
                  style: TextStyle(color: textSec, fontSize: 14)),
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
    final primary   = isDark ? DarkColors.primary : AppColors.primary;
    final severeColor = isDark ? DarkColors.danger : AppColors.danger;
    final severeTint  = isDark ? DarkColors.dangerTint : AppColors.dangerTint;
    final mildColor   = isDark ? DarkColors.warningText : AppColors.warningText;
    final mildTint    = isDark ? DarkColors.warningTint : AppColors.warningTint;
    final badgeBg   = isSevere ? severeTint  : mildTint;
    final badgeText = isSevere ? severeColor : mildColor;
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
            // calm blue — severity lives only in the small badge on the right
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? DarkColors.primaryTint : AppColors.primaryTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.event_note_outlined,
                color: primary,
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




