import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/fall_event.dart';
import '../strings.dart';
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

  String _peakHour({required bool isKo}) {
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
    if (isKo) {
      return '${peak >= 12 ? "오후" : "오전"} $peak~${end}시';
    } else {
      final ampm = peak >= 12 ? 'PM' : 'AM';
      final h = peak > 12 ? peak - 12 : (peak == 0 ? 12 : peak);
      return '$h $ampm – ${end > 12 ? end - 12 : end} ${end >= 12 ? 'PM' : 'AM'}';
    }
  }

  String _lastOccurrence({required bool isKo}) {
    if (_filtered.isEmpty) return '—';
    try {
      final sorted = [..._filtered]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final dt = DateTime.parse(sorted.first.timestamp).toLocal();
      final diff = DateTime.now().difference(dt);
      if (isKo) {
        if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
        if (diff.inHours < 24) return '${diff.inHours}시간 전';
        return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      } else {
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        return '$h:${dt.minute.toString().padLeft(2,'0')} $ampm';
      }
    } catch (_) { return '—'; }
  }

  String _generateCsv({required bool isKo}) {
    final header = isKo ? '﻿타임스탬프,유형,상태' : 'Timestamp,Type,Status';
    final rows = [header];
    for (final e in _filtered) {
      final type   = isKo ? (e.isSevere ? "중증" : "경미")   : (e.isSevere ? "Severe" : "Mild");
      final status = isKo ? (e.isAcknowledged ? "확인됨" : "미확인") : (e.isAcknowledged ? "Confirmed" : "Unconfirmed");
      rows.add('${e.timestamp},$type,$status');
    }
    return rows.join('\n');
  }

  Future<void> _exportCsv({required bool isKo}) async {
    final csv = _generateCsv(isKo: isKo);
    await Share.share(csv, subject: 'MobiCare Fall Records');
  }

  Future<void> _emailReport({required bool isKo}) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final now  = DateTime.now();
    final s    = S.read(context);
    final periodLabels = [s.today, s.thisWeek, s.thisMonth, s.allTime];
    final period = periodLabels[_period.index];
    final subject = Uri.encodeComponent('MobiCare Fall Report – $period');
    final body = Uri.encodeComponent(
      'MobiCare Fall Report\n'
      'User: ${user?.displayName ?? ""}\n'
      'Period: $period\n'
      'Generated: ${now.year}-${now.month.toString().padLeft(2,"0")}-${now.day.toString().padLeft(2,"0")}\n\n'
      'Total Falls: $_totalCount  Severe: $_severeCount\n'
      'Peak Hours: ${_peakHour(isKo: isKo)}  Last Event: ${_lastOccurrence(isKo: isKo)}\n\n'
      '--- Detail ---\n'
      '${_generateCsv(isKo: isKo)}',
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
    final s      = S.of(context);
    final isKo   = s.isKorean;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? DarkColors.bg           : AppColors.bg;
    final textPri = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final textTer = isDark ? DarkColors.textTertiary  : AppColors.textTertiary;
    final primary = isDark ? DarkColors.primary       : AppColors.primary;
    final chip    = isDark ? DarkColors.chip          : AppColors.chip;
    final filtered = _filtered;
    final peakHour     = _peakHour(isKo: isKo);
    final lastOccurrence = _lastOccurrence(isKo: isKo);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: primary, strokeWidth: 2))
            : RefreshIndicator(
                color: primary,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  children: [
                    // ── Title ───────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s.reportsTitle,
                          style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700, color: textPri),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh_rounded, color: textSec),
                          onPressed: _load,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Period segment ──────────────────────────────────────
                    _PeriodSegment(
                      selected: _period,
                      isDark: isDark,
                      labels: {
                        _Period.today: s.today,
                        _Period.week:  s.thisWeek,
                        _Period.month: s.thisMonth,
                        _Period.all:   s.allTime,
                      },
                      onChanged: (p) => setState(() => _period = p),
                    ),
                    const SizedBox(height: 20),

                    // ── Stats grid 2×2 ──────────────────────────────────────
                    Row(
                      children: [
                        _StatCard(
                          label: s.totalFalls,
                          value: s.countEntries(_totalCount),
                          valueColor: textPri,
                          isDark: isDark,
                          icon: Icons.history_rounded,
                          iconTint: isDark ? DarkColors.primaryTint : AppColors.primaryTint,
                          iconColor: isDark ? DarkColors.primary : AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          label: s.severeEvents,
                          value: s.countEntries(_severeCount),
                          valueColor: _severeCount > 0
                              ? (isDark ? DarkColors.accent : AppColors.accent)
                              : textPri,
                          isDark: isDark,
                          icon: _severeCount > 0
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                          iconTint: _severeCount > 0
                              ? (isDark ? DarkColors.accentTint : AppColors.accentTint)
                              : (isDark ? DarkColors.successTint : AppColors.successTint),
                          iconColor: _severeCount > 0
                              ? (isDark ? DarkColors.accent : AppColors.accent)
                              : (isDark ? DarkColors.success : AppColors.success),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StatCard(
                          label: s.peakTime,
                          value: peakHour,
                          valueColor: textPri,
                          isDark: isDark,
                          smallValue: true,
                          icon: Icons.schedule_rounded,
                          iconTint: isDark ? DarkColors.primaryTint : AppColors.primaryTint,
                          iconColor: isDark ? DarkColors.primary : AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          label: s.lastEvent,
                          value: lastOccurrence,
                          valueColor: textPri,
                          isDark: isDark,
                          smallValue: true,
                          icon: Icons.access_time_rounded,
                          iconTint: isDark ? DarkColors.chip : AppColors.chip,
                          iconColor: isDark ? DarkColors.textSecondary : AppColors.textSecondary,
                        ),
                      ],
                    ),
                    if (_totalCount > 0) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: _severeCount / _totalCount,
                                minHeight: 6,
                                backgroundColor: isDark ? DarkColors.chip : AppColors.chip,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    isDark ? DarkColors.accent : AppColors.accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Severe rate: ${(_severeCount / _totalCount * 100).round()}%',
                            style: TextStyle(color: textSec, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    // ── Bar chart ────────────────────────────────────────────
                    if (_period != _Period.today) ...[
                      Text(
                        s.dailyChart,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: textPri),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 160,
                        padding: const EdgeInsets.all(14),
                        decoration: cardDeco(radius: 16, dark: isDark),
                        child: _BarChart(
                          data: _chartData,
                          isKo: isKo,
                          chipColor: chip,
                          textSecColor: textSec,
                          textTerColor: textTer,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Export buttons ───────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: filtered.isEmpty ? null : () => _exportCsv(isKo: isKo),
                            icon: const Icon(Icons.download_outlined, size: 16),
                            label: Text(s.exportCsv,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary.withOpacity(0.12),
                              foregroundColor: primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: filtered.isEmpty ? null : () => _emailReport(isKo: isKo),
                            icon: const Icon(Icons.email_outlined, size: 16),
                            label: Text(s.emailReport,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary.withOpacity(0.12),
                              foregroundColor: primary,
                              elevation: 0,
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
                        Text(s.fallList,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPri)),
                        Text(s.countEntries(filtered.length),
                            style: TextStyle(color: textTer, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: cardDeco(radius: 14, dark: isDark),
                        child: Center(
                          child: Text(
                            s.noEventsInPeriod,
                            style: TextStyle(color: textSec),
                          ),
                        ),
                      )
                    else
                      ...filtered.map((e) => _EventTile(event: e, isDark: isDark)),
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
  final bool isDark;
  final Map<_Period, String> labels;
  final ValueChanged<_Period> onChanged;
  const _PeriodSegment({
    required this.selected,
    required this.isDark,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chip    = isDark ? DarkColors.chip          : AppColors.chip;
    final primary = isDark ? DarkColors.primary       : AppColors.primary;
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: chip,
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
                  color: active ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  labels[p]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : textSec,
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
  final bool isDark;
  final bool smallValue;
  final IconData icon;
  final Color iconTint;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isDark,
    required this.icon,
    required this.iconTint,
    required this.iconColor,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDeco(radius: 14, dark: isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(color: textSec, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
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
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _DayBar {
  final DateTime date;
  final int count;
  _DayBar(this.date, this.count);
}

class _BarChart extends StatelessWidget {
  final List<_DayBar> data;
  final bool isKo;
  final Color chipColor;
  final Color textSecColor;
  final Color textTerColor;
  const _BarChart({
    required this.data,
    required this.isKo,
    required this.chipColor,
    required this.textSecColor,
    required this.textTerColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxCount = data.map((d) => d.count).fold(0, max);
    return CustomPaint(
      painter: _BarChartPainter(
        data: data,
        maxCount: maxCount,
        isKo: isKo,
        chipColor: chipColor,
        textSecColor: textSecColor,
        textTerColor: textTerColor,
      ),
      size: Size.infinite,
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<_DayBar> data;
  final int maxCount;
  final bool isKo;
  final Color chipColor;
  final Color textSecColor;
  final Color textTerColor;

  _BarChartPainter({
    required this.data,
    required this.maxCount,
    required this.isKo,
    required this.chipColor,
    required this.textSecColor,
    required this.textTerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final zeroPaint = Paint()..color = chipColor;
    const labelH = 20.0;
    final chartH = size.height - labelH;
    final barW = (size.width / data.length) * 0.55;
    final gap = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final x = gap * i + gap / 2;
      final ratio = maxCount == 0 ? 0.0 : d.count / maxCount;
      final barH = (ratio * (chartH - 12)).clamp(0.0, chartH);

      final Color barColor;
      if (d.count == 0) {
        barColor = chipColor;
      } else if (ratio < 0.4) {
        barColor = textTerColor;
      } else if (ratio < 0.7) {
        barColor = AppColors.warning;
      } else {
        barColor = AppColors.accent;
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
            style: TextStyle(color: textSecColor, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chartH - barH - 14));
      }

      final showLabel = data.length <= 10 || i % (data.length ~/ 7 + 1) == 0;
      if (showLabel) {
        final label = data.length <= 7
            ? '${d.date.month}/${d.date.day}'
            : (isKo ? '${d.date.day}일' : '${d.date.day}');
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(color: textTerColor, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chartH + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data || old.maxCount != maxCount ||
      old.chipColor != chipColor || old.textSecColor != textSecColor;
}

// ── Event tile ────────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final FallEvent event;
  final bool isDark;
  const _EventTile({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final s       = S.of(context);
    final textTer = isDark ? DarkColors.textTertiary : AppColors.textTertiary;
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: event.isSevere ? AppColors.accentTint : AppColors.warningTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person_off_outlined,
                color: event.isSevere ? AppColors.accent : AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.isSevere ? s.severeFall : s.fallSuspect,
                    style: TextStyle(
                      color: event.isSevere ? AppColors.accent : AppColors.warningText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _formatTs(event.timestamp),
                    style: TextStyle(color: textTer, fontSize: 11),
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
                  color: AppColors.accentTint,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(s.unconfirmed,
                    style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: textTer, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatTs(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ts; }
  }
}
