import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../models/fall_event.dart';
import '../strings.dart';
import 'event_detail_screen.dart';

class GuardianScreen extends StatefulWidget {
  const GuardianScreen({super.key});
  @override
  State<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends State<GuardianScreen>
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
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.monitoredStatusTitle,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.monitoredStatusSubtitle(_monitored.length),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: _load,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Stats row ────────────────────────────────────────────
                    _StatsRow(events: _events),
                    const SizedBox(height: 24),

                    // ── Ward list ────────────────────────────────────────────
                    if (_monitored.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: cardDeco(radius: 16),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.person_add_outlined,
                              size: 40,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.noLinkedRecipients,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.linkByGuardianId,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ..._monitored.map(
                        (u) => _WardCard(
                          user: u,
                          events: _events
                              .where((e) => e.userId == u.id)
                              .toList(),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── All events ───────────────────────────────────────────
                    if (_events.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            s.allFallRecords,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            s.countEntries(_events.length),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._events.take(5).map((e) => _EventTile(event: e)),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<FallEvent> events;
  const _StatsRow({required this.events});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayCount = events.where((e) {
      try {
        final dt = DateTime.parse(e.timestamp).toLocal();
        return dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day;
      } catch (_) {
        return false;
      }
    }).length;
    final severeCount = events.where((e) => e.isSevere).length;
    final s = S.of(context);

    return Row(
      children: [
        _MiniStat(
          label: s.today,
          value: s.countEntries(todayCount),
          color: todayCount > 0 ? AppColors.danger : AppColors.success,
          bg: todayCount > 0 ? AppColors.dangerTint : AppColors.successTint,
        ),
        const SizedBox(width: 8),
        _MiniStat(
          label: s.thisWeek,
          value: s.countEntries(
            events.where((e) {
              try {
                return now
                        .difference(DateTime.parse(e.timestamp).toLocal())
                        .inDays <
                    7;
              } catch (_) {
                return false;
              }
            }).length,
          ),
          color: AppColors.warningText,
          bg: AppColors.warningTint,
        ),
        const SizedBox(width: 8),
        _MiniStat(
          label: s.severe,
          value: s.countEntries(severeCount),
          color: severeCount > 0 ? AppColors.danger : AppColors.textSecondary,
          bg: severeCount > 0 ? AppColors.dangerTint : AppColors.chip,
        ),
        const SizedBox(width: 8),
        _MiniStat(
          label: s.all,
          value: s.countEntries(events.length),
          color: AppColors.primary,
          bg: AppColors.primaryTint,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

// ── Ward card ─────────────────────────────────────────────────────────────────

class _WardCard extends StatelessWidget {
  final User user;
  final List<FallEvent> events;
  const _WardCard({required this.user, required this.events});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hasRecentAlert =
        events.isNotEmpty &&
        now
                .difference(
                  DateTime.tryParse(events.first.timestamp)?.toLocal() ?? now,
                )
                .inHours <
            24;
    final statusOk = !hasRecentAlert;
    final initial =
        (user.displayName.isNotEmpty ? user.displayName : user.username)[0]
            .toUpperCase();
    final s = S.of(context);

    String recentNote = events.isEmpty ? s.noRecords : s.confirmed;
    if (events.isNotEmpty && !events.first.isAcknowledged) {
      recentNote = hasRecentAlert ? s.justNowFallNeedsCheck : s.needsConfirm;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(radius: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: statusOk
                ? AppColors.primaryTint
                : AppColors.dangerTint,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: statusOk ? AppColors.primary : AppColors.danger,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.displayName.isNotEmpty
                          ? user.displayName
                          : user.username,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (user.age != null) ...[
                      const Text(
                        ' · ',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                      Text(
                        s.ageYears(user.age!),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  recentNote,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusOk
                        ? AppColors.textTertiary
                        : AppColors.dangerPressed,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusOk ? AppColors.successTint : AppColors.dangerTint,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusOk ? AppColors.success : AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  statusOk ? s.normal : s.needsConfirm,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusOk ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
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
    final s = S.of(context);
    return GestureDetector(
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: event.isSevere
                    ? AppColors.dangerTint
                    : AppColors.warningTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person_off_outlined,
                color: event.isSevere ? AppColors.danger : AppColors.warning,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.monitoredEventTitle(
                      event.monitoredUserName,
                      event.isSevere,
                    ),
                    style: TextStyle(
                      color: event.isSevere
                          ? AppColors.danger
                          : AppColors.warningText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _formatTs(event.timestamp),
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (event.isAcknowledged)
              const Icon(Icons.check_circle, color: AppColors.success, size: 16)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  s.unconfirmed,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 16,
            ),
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
    } catch (_) {
      return ts;
    }
  }
}
