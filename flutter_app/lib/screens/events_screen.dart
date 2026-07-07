import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/fall_event.dart';
import '../strings.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with AutomaticKeepAliveClientMixin {
  List<FallEvent> _events = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // 'all' | 'severe' | 'mild'

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final events = await context.read<AuthProvider>().api.getFallEvents();
      if (mounted) setState(() => _events = events);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FallEvent> get _filtered {
    if (_filter == 'severe') return _events.where((e) => e.isSevere).toList();
    if (_filter == 'mild') return _events.where((e) => !e.isSevere).toList();
    return _events;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s      = S.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? DarkColors.bg           : AppColors.bg;
    final textPri = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final primary = isDark ? DarkColors.primary       : AppColors.primary;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.fallRecords,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textPri,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: textSec),
                    onPressed: _load,
                  ),
                ],
              ),
            ),

            // ── Filter chips ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  _FilterChip(label: s.all, value: 'all', selected: _filter, isDark: isDark,
                      onTap: () => setState(() => _filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterChip(label: s.severe, value: 'severe', selected: _filter, isDark: isDark,
                      onTap: () => setState(() => _filter = 'severe')),
                  const SizedBox(width: 8),
                  _FilterChip(label: s.mild, value: 'mild', selected: _filter, isDark: isDark,
                      onTap: () => setState(() => _filter = 'mild')),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: primary, strokeWidth: 2))
                  : _error != null
                      ? _ErrorView(error: _error!, onRetry: _load)
                      : filtered.isEmpty
                          ? _EmptyView(message: _filter == 'all' ? s.noFalls : s.noFiltered)
                          : RefreshIndicator(
                              color: primary,
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) => _EventCard(
                                  event: filtered[i],
                                  isDark: isDark,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EventDetailScreen(eventId: filtered[i].id),
                                      ),
                                    );
                                    _load();
                                  },
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive  = value == selected;
    final primary   = isDark ? DarkColors.primary       : AppColors.primary;
    final chip      = isDark ? DarkColors.chip          : AppColors.chip;
    final textSec   = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? primary : chip,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : textSec,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final FallEvent event;
  final bool isDark;
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s        = S.of(context);
    final textPri  = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textTer  = isDark ? DarkColors.textTertiary  : AppColors.textTertiary;
    final isSevere = event.isSevere;
    final badgeBg  = isSevere ? AppColors.dangerTint : AppColors.warningTint;
    final badgeFg  = isSevere ? AppColors.danger     : AppColors.warningText;
    final label    = isSevere ? s.severe : s.mild;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(radius: 16, dark: isDark),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSevere ? AppColors.dangerTint : AppColors.warningTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.personal_injury_outlined,
                color: isSevere ? AppColors.danger : AppColors.warningText,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTs(event.timestamp),
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPri, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
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
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: badgeFg)),
                ),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right, size: 16, color: textTer),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTs(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} · '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}

// ── Error & empty states ──────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s       = S.of(context);
    final textSec = Theme.of(context).brightness == Brightness.dark
        ? DarkColors.textSecondary
        : AppColors.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            const SizedBox(height: 12),
            Text(error, style: TextStyle(color: textSec), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(s.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    final textSec = Theme.of(context).brightness == Brightness.dark
        ? DarkColors.textSecondary
        : AppColors.textSecondary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 56),
          const SizedBox(height: 14),
          Text(
            message,
            style: TextStyle(color: textSec, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
