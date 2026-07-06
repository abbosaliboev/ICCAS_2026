import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/fall_event.dart';
import 'event_detail_screen.dart';

enum _Period { today, week, month, all }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<FallEvent> _all = [];
  bool _loading = true;
  _Period _period = _Period.week;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final events = await context.read<AuthProvider>().api.getFallEvents();
      if (mounted) setState(() { _all = events; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FallEvent> get _filtered {
    final now = DateTime.now();
    return _all.where((e) {
      try {
        final dt = DateTime.parse(e.timestamp).toLocal();
        switch (_period) {
          case _Period.today:
            return dt.year == now.year && dt.month == now.month && dt.day == now.day;
          case _Period.week:
            return now.difference(dt).inDays < 7;
          case _Period.month:
            return dt.year == now.year && dt.month == now.month;
          case _Period.all:
            return true;
        }
      } catch (_) {
        return true;
      }
    }).toList();
  }

  // ── stats ────────────────────────────────────────────────────────────────

  int get _totalCount => _filtered.length;
  int get _severeCount => _filtered.where((e) => e.isSevere).length;

  String get _peakHour {
    if (_filtered.isEmpty) return '—';
    final hourCounts = <int, int>{};
    for (final e in _filtered) {
      try {
        final h = DateTime.parse(e.timestamp).toLocal().hour;
        hourCounts[h] = (hourCounts[h] ?? 0) + 1;
      } catch (_) {}
    }
    if (hourCounts.isEmpty) return '—';
    final peak = hourCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return '$peak시';
  }

  String get _lastOccurrence {
    if (_filtered.isEmpty) return '—';
    try {
      final sorted = [..._filtered]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final dt = DateTime.parse(sorted.first.timestamp).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '${diff.inDays}일 전';
    } catch (_) {
      return '—';
    }
  }

  // ── bar chart data (daily, last N days) ──────────────────────────────────

  List<_DayBar> get _chartData {
    final days = _period == _Period.today ? 1
        : _period == _Period.week ? 7
        : _period == _Period.month ? 30
        : 14;
    final now = DateTime.now();
    return List.generate(days, (i) {
      final d = now.subtract(Duration(days: days - 1 - i));
      final count = _all.where((e) {
        try {
          final dt = DateTime.parse(e.timestamp).toLocal();
          return dt.year == d.year && dt.month == d.month && dt.day == d.day;
        } catch (_) { return false; }
      }).length;
      return _DayBar(d, count);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('리포트', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
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
                  // ── Period tabs ─────────────────────────────────────────
                  _PeriodTabs(
                    selected: _period,
                    onChanged: (p) => setState(() => _period = p),
                  ),
                  const SizedBox(height: 16),

                  // ── Stats cards ─────────────────────────────────────────
                  Row(
                    children: [
                      _StatCard('총 낙상', '$_totalCount회', Icons.warning_rounded, Colors.redAccent),
                      const SizedBox(width: 10),
                      _StatCard('위험 시간대', _peakHour, Icons.access_time, Colors.orangeAccent),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatCard('중증', '$_severeCount회', Icons.local_hospital, Colors.red.shade700),
                      const SizedBox(width: 10),
                      _StatCard('마지막 발생', _lastOccurrence, Icons.history, Colors.blue.shade300),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Bar chart ────────────────────────────────────────────
                  if (_period != _Period.today) ...[
                    _sectionLabel('일별 낙상 현황'),
                    const SizedBox(height: 10),
                    Container(
                      height: 160,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.07)),
                      ),
                      child: _BarChart(data: _chartData),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Events list ──────────────────────────────────────────
                  _sectionLabel('낙상 목록 (${filtered.length}건)'),
                  const SizedBox(height: 10),
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('해당 기간 낙상 이벤트 없음',
                            style: TextStyle(color: Colors.white38)),
                      ),
                    )
                  else
                    ...filtered.map((e) => _EventTile(event: e)),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      );
}

// ── Period tabs ───────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;
  const _PeriodTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {
      _Period.today: '오늘',
      _Period.week: '이번 주',
      _Period.month: '이번 달',
      _Period.all: '전체',
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: _Period.values.map((p) {
          final active = p == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF4FC3F7).withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: active
                      ? Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.6))
                      : null,
                ),
                child: Text(
                  labels[p]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? const Color(0xFF4FC3F7) : Colors.white38,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      color: color, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      );
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _DayBar {
  final DateTime date;
  final int count;
  _DayBar(this.date, this.count);
}

class _BarChart extends StatelessWidget {
  final List<_DayBar> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxCount = data.map((d) => d.count).fold(0, max);
    return CustomPaint(
      painter: _BarChartPainter(data: data, maxCount: maxCount),
      size: Size.infinite,
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<_DayBar> data;
  final int maxCount;
  _BarChartPainter({required this.data, required this.maxCount});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final barPaint = Paint()..color = const Color(0xFF4FC3F7).withOpacity(0.7);
    final zeroPaint = Paint()..color = Colors.white12;
    final textStyle = const TextStyle(color: Colors.white38, fontSize: 9);

    final barW = (size.width / data.length) * 0.6;
    final gap = size.width / data.length;
    const labelH = 20.0;
    final chartH = size.height - labelH;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final x = gap * i + gap / 2;
      final barH = maxCount == 0 ? 0.0 : (d.count / maxCount) * (chartH - 10);

      // bar
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - barW / 2, chartH - barH, barW, barH.clamp(2.0, chartH)),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, d.count > 0 ? barPaint : zeroPaint);

      // count label above bar
      if (d.count > 0) {
        final tp = TextPainter(
          text: TextSpan(text: '${d.count}', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chartH - barH - 14));
      }

      // date label below
      final showLabel = data.length <= 10 || i % (data.length ~/ 7 + 1) == 0;
      if (showLabel) {
        final label = data.length <= 7
            ? '${d.date.month}/${d.date.day}'
            : '${d.date.day}일';
        final tp = TextPainter(
          text: TextSpan(text: label, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chartH + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data || old.maxCount != maxCount;
}

// ── Event tile ────────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final FallEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) => GestureDetector(
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
              color: event.isSevere
                  ? Colors.red.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.person_off,
                  color: event.isSevere ? Colors.redAccent : Colors.orangeAccent,
                  size: 20),
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
                    Text(_formatTs(event.timestamp),
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              if (event.isAcknowledged)
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('미확인',
                      style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
            ],
          ),
        ),
      );

  String _formatTs(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.year}.${dt.month.toString().padLeft(2,'0')}.${dt.day.toString().padLeft(2,'0')} '
          '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return ts;
    }
  }
}
