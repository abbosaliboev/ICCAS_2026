import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../models/fall_event.dart';
import 'event_detail_screen.dart';

class GuardianScreen extends StatefulWidget {
  const GuardianScreen({super.key});
  @override
  State<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends State<GuardianScreen> with AutomaticKeepAliveClientMixin {
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
      final events = await api.getFallEvents();
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('모니터링', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── 통계 요약 ─────────────────────────────────────────
                  _statsRow(),
                  const SizedBox(height: 20),
                  _sectionLabel('관리 중인 피보호자 (${_monitored.length}명)'),
                  const SizedBox(height: 8),
                  if (_monitored.isEmpty)
                    _emptyCard('연결된 피보호자가 없습니다\n피보호자가 보호자 아이디를 입력하여 연결합니다')
                  else
                    ..._monitored.map((u) => _userCard(u)),
                  const SizedBox(height: 20),
                  _sectionLabel('낙상 이벤트 전체 기록 (${_events.length}건)'),
                  const SizedBox(height: 8),
                  if (_events.isEmpty)
                    _emptyCard('낙상 이벤트가 없습니다')
                  else
                    ..._events.map((e) => _eventTile(context, e)),
                ],
              ),
            ),
    );
  }

  Widget _statsRow() {
    final now = DateTime.now();
    final todayCount = _events.where((e) {
      try {
        final dt = DateTime.parse(e.timestamp).toLocal();
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      } catch (_) { return false; }
    }).length;
    final weekCount = _events.where((e) {
      try {
        return now.difference(DateTime.parse(e.timestamp).toLocal()).inDays < 7;
      } catch (_) { return false; }
    }).length;
    final severeCount = _events.where((e) => e.isSevere).length;

    return Row(
      children: [
        _miniStat('오늘', '$todayCount건', Colors.redAccent),
        const SizedBox(width: 8),
        _miniStat('이번 주', '$weekCount건', Colors.orangeAccent),
        const SizedBox(width: 8),
        _miniStat('중증', '$severeCount건', Colors.red.shade700),
        const SizedBox(width: 8),
        _miniStat('전체', '${_events.length}건', Colors.blue.shade300),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      );

  Widget _emptyCard(String text) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, height: 1.6),
        ),
      );

  Widget _userCard(User user) {
    final userEvents = _events.where((e) => e.userId == user.id).toList();
    final now = DateTime.now();
    final monthCount = userEvents.where((e) {
      try {
        final dt = DateTime.parse(e.timestamp).toLocal();
        return dt.year == now.year && dt.month == now.month;
      } catch (_) { return false; }
    }).length;
    return _userCardWidget(user, userEvents.length, monthCount);
  }

  Widget _userCardWidget(User user, int total, int monthCount) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF4FC3F7).withOpacity(0.15),
              child: Text(
                (user.displayName.isNotEmpty ? user.displayName : user.username)[0].toUpperCase(),
                style: const TextStyle(color: Color(0xFF4FC3F7), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName.isNotEmpty ? user.displayName : user.username,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '나이: ${user.age ?? '-'} · ${user.address.isNotEmpty ? user.address : '주소 미등록'}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _badge('이번달 $monthCount건', Colors.orange),
                      const SizedBox(width: 6),
                      _badge('누적 $total건', Colors.blue.shade400),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.circle, color: Colors.greenAccent.withOpacity(0.7), size: 10),
          ],
        ),
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );

  Widget _eventTile(BuildContext context, FallEvent event) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: event.isSevere ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person_off,
                color: event.isSevere ? Colors.redAccent : Colors.orangeAccent,
                size: 20,
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
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
            ],
          ),
        ),
      );

  String _formatTs(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}
