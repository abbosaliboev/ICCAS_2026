import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/fall_event.dart';
import '../services/ws_service.dart';
import '../widgets/fall_response_overlay.dart';
import 'events_screen.dart';
import 'stream_screen.dart';
import 'profile_screen.dart';
import 'guardian_screen.dart';
import 'reports_screen.dart';

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
  WsEvent? _overlayEvent; // non-null → show full-screen TTS/STT overlay

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
        // 피보호자(user role)에게만 full-screen TTS/STT overlay 표시
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
          _recentEvents = events.take(5).toList();
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
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;

    final tabs = [
      _DashboardTab(
        user: user,
        activeAlert: _activeAlert,
        recentEvents: _recentEvents,
        eventsLoading: _eventsLoading,
        onRefresh: _loadEvents,
        onDismissAlert: () => setState(() => _activeAlert = null),
      ),
      const StreamScreen(),
      const EventsScreen(),
      const ReportsScreen(),
      user.isGuardian ? const GuardianScreen() : const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: const Color(0xFF16213E),
        selectedItemColor: const Color(0xFF4FC3F7),
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          const BottomNavigationBarItem(icon: Icon(Icons.videocam), label: '라이브'),
          const BottomNavigationBarItem(icon: Icon(Icons.history), label: '이벤트'),
          const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '리포트'),
          BottomNavigationBarItem(
            icon: Icon(user.isGuardian ? Icons.people : Icons.person),
            label: user.isGuardian ? '모니터링' : '프로필',
          ),
        ],
      ),
    );
  }
}

// ── Dashboard tab ────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final dynamic user;
  final WsEvent? activeAlert;
  final List<FallEvent> recentEvents;
  final bool eventsLoading;
  final VoidCallback onRefresh;
  final VoidCallback onDismissAlert;

  const _DashboardTab({
    required this.user,
    required this.activeAlert,
    required this.recentEvents,
    required this.eventsLoading,
    required this.onRefresh,
    required this.onDismissAlert,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _header(context),
            const SizedBox(height: 20),
            if (activeAlert != null) ...[
              _FallAlertBanner(event: activeAlert!, onDismiss: onDismissAlert),
              const SizedBox(height: 16),
            ],
            _statusCard(context),
            const SizedBox(height: 20),
            _quickActions(context),
            const SizedBox(height: 20),
            _recentEventsSection(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '안녕하세요, ${user.displayName.isNotEmpty ? user.displayName : user.username}님',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                user.isGuardian ? '보호자 모드' : '피보호자 모드',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      );

  Widget _statusCard(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F3460), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: activeAlert != null
                    ? Colors.red.withOpacity(0.2)
                    : Colors.green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                activeAlert != null ? Icons.warning_rounded : Icons.shield_outlined,
                color: activeAlert != null ? Colors.redAccent : Colors.greenAccent,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeAlert != null ? '낙상 감지됨!' : '정상 모니터링 중',
                    style: TextStyle(
                      color: activeAlert != null ? Colors.redAccent : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activeAlert != null
                        ? activeAlert!.category == 'severe' ? '심각한 낙상이 감지되었습니다' : '낙상 의심 감지'
                        : '24시간 카메라 감시 활성화',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _quickActions(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('빠른 메뉴', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              _actionBtn(context, Icons.videocam, '라이브 보기', const Color(0xFF4FC3F7), () {
                // Tab switch handled by parent
              }),
              const SizedBox(width: 12),
              _actionBtn(context, Icons.history, '이벤트 기록', const Color(0xFFCE93D8), () {}),
            ],
          ),
        ],
      );

  Widget _actionBtn(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );

  Widget _recentEventsSection(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('최근 이벤트', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          if (eventsLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (recentEvents.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('감지된 낙상 이벤트가 없습니다', style: TextStyle(color: Colors.white38)),
              ),
            )
          else
            ...recentEvents.map((e) => _EventTile(event: e)),
        ],
      );
}

// ── Fall alert banner ────────────────────────────────────────────────────────

class _FallAlertBanner extends StatelessWidget {
  final WsEvent event;
  final VoidCallback onDismiss;

  const _FallAlertBanner({required this.event, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isSevere = event.category == 'severe';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSevere ? Colors.red.shade900 : Colors.orange.shade900,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: (isSevere ? Colors.red : Colors.orange).withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSevere ? '심각한 낙상 감지!' : '낙상 의심 감지!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (event.monitoredUserName != null)
                  Text(
                    '${event.monitoredUserName}님',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ── Event tile ────────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final FallEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: event.isSevere
              ? Colors.red.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_off,
            color: event.isSevere ? Colors.redAccent : Colors.orangeAccent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.isSevere ? '심각한 낙상' : '낙상 의심',
                  style: TextStyle(
                    color: event.isSevere ? Colors.redAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _formatTs(event.timestamp),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          if (event.isAcknowledged)
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('미확인', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  String _formatTs(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}
