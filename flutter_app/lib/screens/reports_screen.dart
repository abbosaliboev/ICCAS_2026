import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
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
      } catch (_) { return true; }
    }).toList();
  }

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
    final end = (peak + 2).clamp(0, 23);
    return '오후 $peak~${end}시';
  }

  String get _lastOccurrence {
    if (_filtered.isEmpty) return '—';
    try {
      final sorted = [..._filtered]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final dt = DateTime.parse(sorted.first.timestamp).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '오늘 ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return '—'; }
  }

  String _generateCsv() {
    final rows = ['﻿타임스탬프,유형,상태'];
    for (final e in _filtered) {
      rows.add('${e.timestamp},${e.isSevere ? "중증" : "경미"},${e.isAcknowledged ? "확인됨" : "미확인"}');
    }
    return rows.join('\n');
  }

  Future<void> _exportCsv() async {
    final csv = _generateCsv();
    await Share.share(csv, subject: 'MobiCare 낙상 기록');
  }

  Future<void> _emailReport() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final now = DateTime.now();
    final period = ['오늘', '이번 주', '이번 달', '전체'][_period.index];
    final subject = Uri.encodeComponent('MobiCare 낙상 리포트 - $period');
    final body = Uri.encodeComponent(
      'MobiCare 낙상 리포트\n'
      '사용자: ${user?.displayName ?? ""}\n'
      '기간: $period\n'
      '생성: ${now.year}-${now.month.toString().padLeft(2,"0")}-${now.day.toString().padLeft(2,"0")}\n\n'
      '총 낙상: $_totalCount건  중증: $_severeCount건\n'
      '위험 시간대: $_peakHour  마지막 발생: $_lastOccurrence\n\n'
      '--- 상세 기록 ---\n'
      '${_generateCsv()}',
    );
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  children: [
                    // ── Title ───────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '리포트',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                          onPressed: _load,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Period segment ──────────────────────────────────────
                    _PeriodSegment(
                      selected: _period,
                      onChanged: (p) => setState(() => _period = p),
                    ),
                    const SizedBox(height: 20),

                    // ── Stats grid 2×2 ──────────────────────────────────────
                    Row(
                      children: [
                        _StatCard(
                          label: '총 낙상 수',
                          value: '$_totalCount건',
                          valueColor: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          label: '중증 이벤트',
                          value: '$_severeCount건',
                          valueColor: _severeCount > 0 ? AppColors.danger : AppColors.textPrimary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StatCard(
                          label: '위험 시간대',
                          value: _peakHour,
                          valueColor: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          label: '마지막 발생',
                          value: _lastOccurrence,
                          valueColor: AppColors.textPrimary,
                          smallValue: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Bar chart ────────────────────────────────────────────
                    if (_period != _Period.today) ...[
                      const Text(
                        '일별 낙상 현황',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 160,
                        padding: const EdgeInsets.all(14),
                        decoration: cardDeco(radius: 16),
                        child: _BarChart(data: _chartData),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Export buttons ───────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: filtered.isEmpty ? null : _exportCsv,
                            icon: const Icon(Icons.download_outlined, size: 16),
                            label: const Text('CSV 내보내기',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: filtered.isEmpty ? null : _emailReport,
                            icon: const Icon(Icons.email_outlined, size: 16),
                            label: const Text('이메일 전송',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Events list ──────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '낙상 목록',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${filtered.length}건',
                          style: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: cardDeco(radius: 14),
                        child: const Center(
                          child: Text(
                            '해당 기간 낙상 이벤트 없음',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ...filtered.map((e) => _EventTile(event: e)),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Period segment tabs ───────────────────────────────────────────────────────

class _PeriodSegment extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;
  const _PeriodSegment({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {
      _Period.today: '오늘',
      _Period.week: '이번 주',
      _Period.month: '이번 달',
      _Period.all: '전체',
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: _Period.values.map((p) {
          final active = p == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  labels[p]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.normal,
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
  final String label;
  final String value;
  final Color valueColor;
  final bool smallValue;

  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(radius: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: smallValue ? 18 : 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
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

    final zeroPaint = Paint()..color = AppColors.chip;
    const labelH = 20.0;
    final chartH = size.height - labelH;
    final barW = (size.width / data.length) * 0.55;
    final gap = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final x = gap * i + gap / 2;
      final ratio = maxCount == 0 ? 0.0 : d.count / maxCount;
      final barH = (ratio * (chartH - 12)).clamp(0.0, chartH);

      // bar color: grey → amber → red based on ratio
      final Color barColor;
      if (d.count == 0) {
        barColor = AppColors.chip;
      } else if (ratio < 0.4) {
        barColor = AppColors.textTertiary;
      } else if (ratio < 0.7) {
        barColor = AppColors.warning;
      } else {
        barColor = AppColors.danger;
      }

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - barW / 2, chartH - barH, barW, barH.clamp(3.0, chartH)),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, d.count > 0 ? (Paint()..color = barColor) : zeroPaint);

      if (d.count > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${d.count}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chartH - barH - 14));
      }

      final showLabel = data.length <= 10 || i % (data.length ~/ 7 + 1) == 0;
      if (showLabel) {
        final label = data.length <= 7
            ? '${d.date.month}/${d.date.day}'
            : '${d.date.day}일';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 9),
          ),
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
          decoration: cardDeco(radius: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: event.isSevere ? AppColors.dangerTint : AppColors.warningTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_off_outlined,
                  color: event.isSevere ? AppColors.danger : AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.isSevere ? '심각한 낙상' : '낙상 의심',
                      style: TextStyle(
                        color: event.isSevere ? AppColors.danger : AppColors.warningText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatTs(event.timestamp),
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (event.isAcknowledged)
                const Icon(Icons.check_circle, color: AppColors.success, size: 18)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.dangerTint,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text('미확인',
                      style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
            ],
          ),
        ),
      );

  String _formatTs(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ts; }
  }
}
