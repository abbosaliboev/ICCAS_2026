import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/user.dart';
import '../models/fall_event.dart';
import '../services/mjpeg_stream.dart';
import '../strings.dart';

class GuardianScreen extends StatefulWidget {
  final VoidCallback? onOpenHistory;
  final bool fallDetected;
  const GuardianScreen({
    super.key,
    this.onOpenHistory,
    this.fallDetected = false,
  });
  @override
  State<GuardianScreen> createState() => GuardianScreenState();
}

class GuardianScreenState extends State<GuardianScreen>
    with AutomaticKeepAliveClientMixin {
  List<User> _monitored = [];
  List<FallEvent> _events = [];
  bool _loading = true;
@override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final users = await api.getMonitoredUsers();
      final events = await api.getFallEvents(limit: 100);
      if (mounted) {
        setState(() {
          _monitored = users;
          _events = events;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> reload() => _load();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? DarkColors.bg : AppColors.bg;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final textPrimary = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final allFine = !widget.fallDetected;
return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: primary,
                  strokeWidth: 2,
                ),
              )
            : RefreshIndicator(
                color: primary,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  children: [
                    _GuardianHeader(
                      onRefresh: _load,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _GuardianStatusBanner(
                      allFine: allFine,
                      isDark: isDark,
                      onTap: widget.onOpenHistory,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.monitoredStatusTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _GuardianLiveCarousel(users: _monitored, isDark: isDark),
                    const SizedBox(height: 12),
                    const _GuardianEmergencyButton(),
                    const SizedBox(height: 14),
                    Text(
                      s.isKorean ? '피보호자' : 'Care Recipients',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_monitored.isEmpty)
                      _EmptyLinkedUsers(s: s, isDark: isDark)
                    else
                      _LinkedUserList(
                        users: _monitored,
                        events: _events,
                        isDark: isDark,
                        onUserTap: widget.onOpenHistory,
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }
}

class _GuardianHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool isDark;
  const _GuardianHeader({
    required this.onRefresh,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/logo/logo.png',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'MobiCare',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: textSecondary),
            onPressed: onRefresh,
          ),
        ],
      );
  }

}

class _GuardianStatusBanner extends StatelessWidget {
  final bool allFine;
  final bool isDark;
  final VoidCallback? onTap;

  const _GuardianStatusBanner({
    required this.allFine,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = allFine
        ? (isDark ? DarkColors.success : AppColors.success)
        : (isDark ? DarkColors.danger : AppColors.danger);
    final background = allFine
        ? (isDark ? DarkColors.successTint : AppColors.successTint)
        : (isDark ? DarkColors.dangerTint : AppColors.dangerTint);
    final title = allFine ? 'All Fine' : 'Fall Detected!';
    final subtitle = allFine ? 'No fall detected' : 'Please check the live fall status';

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  allFine ? Icons.check_rounded : Icons.priority_high_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color.withOpacity(isDark ? 0.85 : 0.78),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuardianEmergencyButton extends StatelessWidget {
  const _GuardianEmergencyButton();

  Future<void> _openDialer() async {
    final uri = Uri(scheme: 'tel', path: '010-1234-5678');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = context.watch<ThemeProvider>().isDark;
    final danger = isDark ? DarkColors.danger : AppColors.danger;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _openDialer,
        icon: const Icon(Icons.phone_outlined, size: 18),
        label: Text(s.emergencyCall, style: const TextStyle(fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: danger,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
class _GuardianLiveCarousel extends StatefulWidget {
  final List<User> users;
  final bool isDark;
  const _GuardianLiveCarousel({required this.users, required this.isDark});

  @override
  State<_GuardianLiveCarousel> createState() => _GuardianLiveCarouselState();
}

class _GuardianLiveCarouselState extends State<_GuardianLiveCarousel>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  MjpegStreamController? _ctrl;
  int _index = 0;
  String? _activeUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startForIndex(0));
  }

  @override
  void didUpdateWidget(covariant _GuardianLiveCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextId = widget.users.isEmpty ? null : widget.users[_index.clamp(0, widget.users.length - 1)].id;
    if (nextId != _activeUserId) _startForIndex(_index.clamp(0, widget.users.length - 1));
  }

  void _startForIndex(int index) {
    if (!mounted || widget.users.isEmpty) return;
    final safeIndex = index.clamp(0, widget.users.length - 1);
    final user = widget.users[safeIndex];
    final auth = context.read<AuthProvider>();
    _ctrl?.dispose();
    _ctrl = MjpegStreamController(
      url: () => auth.api.streamUrl(userId: user.id),
      headers: () => {'Authorization': 'Bearer ${auth.token}'},
    )..start();
    setState(() {
      _index = safeIndex;
      _activeUserId = user.id;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ctrl?.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _ctrl?.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (widget.users.isEmpty) {
      final textTertiary = widget.isDark ? DarkColors.textTertiary : AppColors.textTertiary;
      return Container(
        height: 230,
        decoration: cardDeco(radius: 18, dark: widget.isDark),
        child: Center(
          child: Icon(Icons.videocam_off_outlined, color: textTertiary, size: 42),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.users.length,
        onPageChanged: _startForIndex,
        itemBuilder: (context, index) {
          final user = widget.users[index];
          return Padding(
            padding: EdgeInsets.only(right: index == widget.users.length - 1 ? 0 : 8),
            child: _LiveUserCard(
              user: user,
              controller: index == _index ? _ctrl : null,
              current: index + 1,
              total: widget.users.length,
              s: s,
            ),
          );
        },
      ),
    );
  }
}

class _LiveUserCard extends StatelessWidget {
  final User user;
  final MjpegStreamController? controller;
  final int current;
  final int total;
  final S s;
  const _LiveUserCard({
    required this.user,
    required this.controller,
    required this.current,
    required this.total,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    final name = user.displayName.isNotEmpty ? user.displayName : user.username;
    return Container(
      decoration: cardDeco(radius: 18, dark: context.watch<ThemeProvider>().isDark, bordered: false),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: const Color(0xFF10151F),
            child: ctrl == null
                ? const SizedBox.shrink()
                : RepaintBoundary(
                    child: ValueListenableBuilder<Uint8List?>(
                      valueListenable: ctrl.frame,
                      builder: (_, frame, __) => frame == null
                          ? _GuardianStreamPlaceholder(ctrl: ctrl, s: s)
                          : Image.memory(frame, gaplessPlayback: true, fit: BoxFit.cover),
                    ),
                  ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: _GlassPill(
              text: name,
              icon: Icons.person_rounded,
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _GlassPill(text: '$current/$total'),
          ),
          if (ctrl != null)
            Positioned(
              bottom: 10,
              left: 10,
              child: ValueListenableBuilder<MjpegStatus>(
                valueListenable: ctrl.status,
                builder: (_, st, __) {
                  final live = st == MjpegStatus.live;
                  final connecting = st == MjpegStatus.connecting;
                  return _GlassPill(
                    text: live
                        ? 'LIVE'
                        : connecting
                            ? s.connecting
                            : s.streamDisconnected,
                    dotColor: live
                        ? DarkColors.success
                        : connecting
                            ? DarkColors.warning
                            : DarkColors.danger,
                  );
                },
              ),
            ),
          if (ctrl != null)
            Positioned(
              bottom: 10,
              right: 10,
              child: ValueListenableBuilder<int>(
                valueListenable: ctrl.fps,
                builder: (_, fps, __) => fps > 0 ? _GlassPill(text: '$fps FPS') : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuardianStreamPlaceholder extends StatelessWidget {
  final MjpegStreamController ctrl;
  final S s;
  const _GuardianStreamPlaceholder({required this.ctrl, required this.s});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<MjpegStatus>(
        valueListenable: ctrl.status,
        builder: (_, st, __) => Center(
          child: st == MjpegStatus.error
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 34),
                    const SizedBox(height: 8),
                    Text(s.cameraOffline, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                )
              : const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
                ),
        ),
      );
}

class _GlassPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? dotColor;
  const _GlassPill({required this.text, this.icon, this.dotColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.48),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 5),
            ],
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

class _EmptyLinkedUsers extends StatelessWidget {
  final S s;
  final bool isDark;
  const _EmptyLinkedUsers({required this.s, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final textTertiary = isDark ? DarkColors.textTertiary : AppColors.textTertiary;
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: cardDeco(radius: 14, dark: isDark),
        child: Column(
          children: [
            Icon(Icons.person_add_outlined, size: 32, color: textTertiary),
            const SizedBox(height: 8),
            Text(s.noLinkedRecipients, style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(s.linkByGuardianId, textAlign: TextAlign.center, style: TextStyle(color: textTertiary, fontSize: 12)),
          ],
        ),
      );
  }
}

class _LinkedUserList extends StatelessWidget {
  final List<User> users;
  final List<FallEvent> events;
  final bool isDark;
  final VoidCallback? onUserTap;
  const _LinkedUserList({
    required this.users,
    required this.events,
    required this.isDark,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: users.map((user) {
          final userEvents = events.where((e) => e.userId == user.id).toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _WardCard(
              user: user,
              events: userEvents,
              isDark: isDark,
              onTap: onUserTap,
            ),
          );
        }).toList(),
      );
}

class _WardCard extends StatelessWidget {
  final User user;
  final List<FallEvent> events;
  final bool isDark;
  final VoidCallback? onTap;
  const _WardCard({
    required this.user,
    required this.events,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPending = events.any((e) => !e.isAcknowledged);
    final statusOk = !hasPending;
    final name = user.displayName.isNotEmpty ? user.displayName : user.username;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final primaryTint = isDark ? DarkColors.primaryTint : AppColors.primaryTint;
    final danger = isDark ? DarkColors.danger : AppColors.danger;
    final dangerTint = isDark ? DarkColors.dangerTint : AppColors.dangerTint;
    final textPrimary = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: cardDeco(radius: 14, dark: isDark),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusOk ? primaryTint : dangerTint,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: statusOk ? primary : danger,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ).copyWith(color: textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              _RecipientEventCount(count: events.length, isDark: isDark),
              const SizedBox(width: 8),
              _StatusPulse(ok: statusOk, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}
class _RecipientEventCount extends StatelessWidget {
  final int count;
  final bool isDark;
  const _RecipientEventCount({required this.count, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final primaryTint = isDark ? DarkColors.primaryTint : AppColors.primaryTint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: primaryTint,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        s.countEntries(count),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: primary),
      ),
    );
  }
}
class _StatusPulse extends StatefulWidget {
  final bool ok;
  final bool isDark;
  const _StatusPulse({required this.ok, required this.isDark});

  @override
  State<_StatusPulse> createState() => _StatusPulseState();
}

class _StatusPulseState extends State<_StatusPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.72,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.ok
        ? (widget.isDark ? DarkColors.success : AppColors.success)
        : (widget.isDark ? DarkColors.danger : AppColors.danger);
    return ScaleTransition(
      scale: _controller,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10)],
        ),
      ),
    );
  }
}








