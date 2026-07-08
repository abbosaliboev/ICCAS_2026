import 'dart:async';
import 'package:flutter/material.dart';
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
  late final PageController _pageCtrl;
  final _eventsKey  = GlobalKey<EventsScreenState>();
  final _reportsKey = GlobalKey<ReportsScreenState>();

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeWs();
      _loadEvents();
    });
  }

  // Tabs are kept alive (never re-initState), so data would silently go stale
  // when the user switches pages — refresh whichever tab just became visible.
  void _onTabVisible(int i) {
    if (i == 0) _loadEvents();
    if (i == 1) _eventsKey.currentState?.reload();
    if (i == 2) _reportsKey.currentState?.reload();
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
          ? const GuardianScreen()
          : _DashboardTab(
              user: user,
              activeAlert: _activeAlert,
              recentEvents: _recentEvents,
              eventsLoading: _eventsLoading,
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
          PageView(
            controller: _pageCtrl,
            onPageChanged: (i) {
              setState(() => _tabIndex = i);
              _onTabVisible(i);
            },
            children: tabs,
          ),
          if (_overlayEvent != null)
            Positioned.fill(
              child: FallResponseOverlay(
                eventId: _overlayEvent!.eventId!,
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
        child: Center(
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              hasAlert ? Icons.warning_rounded : Icons.check_rounded,
              color: Colors.white,
              size: 16,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: hasAlert ? AppColors.dangerPressed : AppColors.success,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
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
              child: const Icon(Icons.close, color: AppColors.danger, size: 18),
            ),
        ],
      ),
    );
  }
}

// ── Live stream card ──────────────────────────────────────────────────────────

// Static entry card — intentionally makes NO network requests. The old live
// preview polled a snapshot every 400ms and, because dashboard tabs stay alive,
// kept competing with the full-screen stream for the weak edge↔backend WiFi
// link. The live video lives only in StreamScreen now; the tiny pulsing dot is
// a quiet "monitoring is on" cue without pulling any frames.
class _StreamCard extends StatefulWidget {
  const _StreamCard();
  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.3).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s       = S.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final textPri = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final textTer = isDark ? DarkColors.textTertiary : AppColors.textTertiary;
    final success = isDark ? DarkColors.success : AppColors.success;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StreamScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDeco(radius: 18, dark: isDark),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? DarkColors.primaryTint : AppColors.primaryTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.videocam_outlined, color: primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.liveCam,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: textPri),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      FadeTransition(
                        opacity: _pulseAnim,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.aiAnalyzing,
                        style: TextStyle(fontSize: 12, color: textSec),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textTer, size: 20),
          ],
        ),
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
                  const SizedBox(height: 2),
                  Text(
                    event.isAcknowledged ? s.confirmed : s.needsConfirm,
                    style: TextStyle(fontSize: 12, color: textTer),
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
