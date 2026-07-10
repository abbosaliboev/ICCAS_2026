import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/fall_event.dart';
import '../strings.dart';

enum _ReportFilter { week, month, threeMonths, range }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<FallEvent> _all = [];
  bool _loading = true;
  int _callCount = 0;
  _ReportFilter _filter = _ReportFilter.week;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final events = await api.getFallEvents(limit: 100);
      final callCount = await api.getReportCallCount();
      if (mounted) {
        setState(() {
          _all = events;
          _callCount = callCount;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FallEvent> get _filtered {
    final now = DateTime.now();
    return _all.where((e) {
      final dt = DateTime.tryParse(e.timestamp)?.toLocal();
      if (dt == null) return false;
      return switch (_filter) {
        _ReportFilter.week => now.difference(dt).inDays < 7,
        _ReportFilter.month => dt.year == now.year && dt.month == now.month,
        _ReportFilter.threeMonths => now.difference(dt).inDays < 92,
        _ReportFilter.range => _range == null
            ? true
            : !dt.isBefore(_dayStart(_range!.start)) &&
                dt.isBefore(_dayStart(_range!.end).add(const Duration(days: 1))),
      };
    }).toList();
  }

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  int get _totalCount => _filtered.length;

  String _filterLabel(S s) {
    String ymd(DateTime d) =>
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    return switch (_filter) {
      _ReportFilter.week => s.thisWeek,
      _ReportFilter.month => s.thisMonth,
      _ReportFilter.threeMonths => s.isKorean ? '최근 3개월' : '3 months',
      _ReportFilter.range => _range == null
          ? (s.isKorean ? '기간 선택' : 'Custom range')
          : '${ymd(_range!.start)} - ${ymd(_range!.end)}',
    };
  }

  String _peakHour({required bool isKo}) {
    if (_filtered.isEmpty) return '-';
    final hourCounts = <int, int>{};
    for (final e in _filtered) {
      final h = DateTime.tryParse(e.timestamp)?.toLocal().hour;
      if (h != null) hourCounts[h] = (hourCounts[h] ?? 0) + 1;
    }
    if (hourCounts.isEmpty) return '-';
    final peak = hourCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final end = (peak + 2).clamp(0, 23);
    if (isKo) return '${peak >= 12 ? "오후" : "오전"} $peak~$end시';
    final ampm = peak >= 12 ? 'PM' : 'AM';
    final h = peak > 12 ? peak - 12 : (peak == 0 ? 12 : peak);
    return '$h $ampm - ${end > 12 ? end - 12 : end} ${end >= 12 ? 'PM' : 'AM'}';
  }

  String _lastOccurrence({required bool isKo}) {
    if (_filtered.isEmpty) return '-';
    final sorted = [..._filtered]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final dt = DateTime.tryParse(sorted.first.timestamp)?.toLocal();
    if (dt == null) return '-';
    final diff = DateTime.now().difference(dt);
    if (isKo) {
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  List<_DayBar> get _chartData {
    final now = DateTime.now();
    final days = switch (_filter) {
      _ReportFilter.week => 7,
      _ReportFilter.month => DateUtils.getDaysInMonth(now.year, now.month),
      _ReportFilter.threeMonths => 92,
      _ReportFilter.range => _range == null
          ? 14
          : max(1, _dayStart(_range!.end).difference(_dayStart(_range!.start)).inDays + 1),
    };
    final end = switch (_filter) {
      _ReportFilter.range => _range?.end ?? now,
      _ => now,
    };
    return List.generate(days, (i) {
      final d = _dayStart(end).subtract(Duration(days: days - 1 - i));
      final count = _all.where((e) {
        final dt = DateTime.tryParse(e.timestamp)?.toLocal();
        return dt != null && dt.year == d.year && dt.month == d.month && dt.day == d.day;
      }).length;
      return _DayBar(d, count);
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range ?? DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      helpText: S.read(context).isKorean ? '기간 선택' : 'Select range',
    );
    if (picked != null && mounted) {
      setState(() {
        _range = picked;
        _filter = _ReportFilter.range;
      });
    }
  }

  Future<void> _openFilterSheet() async {
    final s = S.read(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? DarkColors.surface
          : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.isKorean ? '리포트 필터' : 'Report filter',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _ReportFilterTile(
                label: s.thisWeek,
                selected: _filter == _ReportFilter.week,
                onTap: () {
                  setState(() => _filter = _ReportFilter.week);
                  Navigator.pop(ctx);
                },
              ),
              _ReportFilterTile(
                label: s.thisMonth,
                selected: _filter == _ReportFilter.month,
                onTap: () {
                  setState(() => _filter = _ReportFilter.month);
                  Navigator.pop(ctx);
                },
              ),
              _ReportFilterTile(
                label: s.isKorean ? '최근 3개월' : '3 months',
                selected: _filter == _ReportFilter.threeMonths,
                onTap: () {
                  setState(() => _filter = _ReportFilter.threeMonths);
                  Navigator.pop(ctx);
                },
              ),
              _ReportFilterTile(
                label: s.isKorean ? '기간 선택' : 'Custom range',
                value: _filter == _ReportFilter.range ? _filterLabel(s) : null,
                selected: _filter == _ReportFilter.range,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickRange();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final isKo = s.isKorean;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DarkColors.bg : AppColors.bg;
    final textPri = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final textTer = isDark ? DarkColors.textTertiary : AppColors.textTertiary;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final chip = isDark ? DarkColors.chip : AppColors.chip;
    final peakHour = _peakHour(isKo: isKo);
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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.reportsTitle,
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPri)),
                              const SizedBox(height: 3),
                              Text(_filterLabel(s),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSec)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.tune_rounded, color: textSec),
                          onPressed: _openFilterSheet,
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh_rounded, color: textSec),
                          onPressed: _load,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _StatCard(label: s.totalFalls, value: s.countEntries(_totalCount), valueColor: primary, isDark: isDark),
                        const SizedBox(width: 10),
                        _StatCard(
                          label: s.isKorean ? 'Call 횟수' : 'Calls',
                          value: s.countEntries(_callCount),
                          valueColor: _callCount > 0
                              ? (isDark ? DarkColors.danger : AppColors.danger)
                              : (isDark ? DarkColors.success : AppColors.success),
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StatCard(label: s.peakTime, value: peakHour, valueColor: isDark ? DarkColors.warning : AppColors.warning, isDark: isDark, smallValue: true),
                        const SizedBox(width: 10),
                        _StatCard(label: s.lastEvent, value: lastOccurrence, valueColor: textPri, isDark: isDark, smallValue: true),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(s.dailyChart,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPri)),
                    const SizedBox(height: 10),
                    Container(
                      height: 170,
                      padding: const EdgeInsets.all(14),
                      decoration: cardDeco(radius: 16, dark: isDark),
                      child: _BarChart(
                        data: _chartData,
                        isKo: isKo,
                        chipColor: chip,
                        textSecColor: textSec,
                        textTerColor: textTer,
                        barColor: primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ReportFilterTile extends StatelessWidget {
  final String label;
  final String? value;
  final bool selected;
  final VoidCallback onTap;

  const _ReportFilterTile({
    required this.label,
    this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final textPri = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final textTer = isDark ? DarkColors.textTertiary : AppColors.textTertiary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(label, style: TextStyle(color: textPri, fontWeight: FontWeight.w700)),
      subtitle: value == null ? null : Text(value!, style: TextStyle(color: textTer, fontSize: 12)),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: primary)
          : Icon(Icons.chevron_right_rounded, color: textTer),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isDark;
  final bool smallValue;

  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isDark,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: cardDeco(radius: 16, dark: isDark, bordered: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: textSec, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontSize: smallValue ? 19 : 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  final Color barColor;
  const _BarChart({
    required this.data,
    required this.isKo,
    required this.chipColor,
    required this.textSecColor,
    required this.textTerColor,
    required this.barColor,
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
        barColor: barColor,
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
  final Color barColor;

  _BarChartPainter({
    required this.data,
    required this.maxCount,
    required this.isKo,
    required this.chipColor,
    required this.textSecColor,
    required this.textTerColor,
    required this.barColor,
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
      final barPaintColor = d.count == 0
          ? chipColor
          : Color.lerp(barColor.withOpacity(0.45), barColor, ratio)!;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - barW / 2, chartH - barH, barW, barH.clamp(3.0, chartH)),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, d.count > 0 ? (Paint()..color = barPaintColor) : zeroPaint);

      if (d.count > 0) {
        final tp = TextPainter(
          text: TextSpan(text: '${d.count}', style: TextStyle(color: textSecColor, fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chartH - barH - 14));
      }

      final showLabel = data.length <= 10 || i % (data.length ~/ 7 + 1) == 0;
      if (showLabel) {
        final label = data.length <= 7 ? '${d.date.month}/${d.date.day}' : (isKo ? '${d.date.day}일' : '${d.date.day}');
        final tp = TextPainter(
          text: TextSpan(text: label, style: TextStyle(color: textTerColor, fontSize: 9)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chartH + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data ||
      old.maxCount != maxCount ||
      old.chipColor != chipColor ||
      old.textSecColor != textSecColor ||
      old.barColor != barColor;
}






