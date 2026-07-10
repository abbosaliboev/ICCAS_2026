import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/fall_event.dart';
import '../models/user.dart';
import '../strings.dart';
import '../widgets/app_toast.dart';
import 'event_detail_screen.dart';

const _kPageSize = 30;
enum _DateFilter { all, today, week, month }

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => EventsScreenState();
}

class EventsScreenState extends State<EventsScreen>
    with AutomaticKeepAliveClientMixin {
  List<FallEvent> _events = [];
  bool _loading = true;
  String? _error;
  List<User> _monitoredUsers = [];
  _DateFilter _dateFilter = _DateFilter.all;
  String? _userFilterId;

  bool _selectMode = false;
  bool _deleting = false;
  final Set<String> _selectedIds = {};

  int _page = 0;
  bool _hasMore = true;
  late ScrollController _scrollCtrl;
  StreamSubscription? _wsSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _load();
    // list is kept alive inside an IndexedStack, so it never rebuilds on tab
    // switch — listen for live fall events to stay in sync with the backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = context.read<AuthProvider>().ws;
      _wsSub = ws?.events.listen((event) {
        if (mounted && (event.isFallDetected || event.isFallResolved)) {
          _load();
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _wsSub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 && !_loading && _hasMore) {
      _loadMore();
    }
  }

  /// Called by HomeScreen when this tab becomes visible (kept alive in a
  /// PageView, so initState only ever runs once).
  void reload() => _load();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _page = 0; _hasMore = true; });
    try {
      final auth = context.read<AuthProvider>();
      final events = await auth.api.getFallEvents(limit: _kPageSize, offset: 0);
      final users = auth.user?.isGuardian == true
          ? await auth.api.getMonitoredUsers()
          : <User>[];
      if (mounted) {
        setState(() {
          _events = events;
          _monitoredUsers = users;
          _hasMore = events.length >= _kPageSize;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final nextPage = _page + 1;
      final events = await context.read<AuthProvider>().api
          .getFallEvents(limit: _kPageSize, offset: nextPage * _kPageSize);
      if (mounted) {
        setState(() {
          _page = nextPage;
          _events = [..._events, ...events];
          if (events.length < _kPageSize) _hasMore = false;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FallEvent> get _filtered {
    final now = DateTime.now();
    return _events.where((e) {
      final dt = DateTime.tryParse(e.timestamp)?.toLocal();
      final dateOk = switch (_dateFilter) {
        _DateFilter.all => true,
        _DateFilter.today => dt != null &&
            dt.year == now.year && dt.month == now.month && dt.day == now.day,
        _DateFilter.week => dt != null && now.difference(dt).inDays < 7,
        _DateFilter.month => dt != null &&
            dt.year == now.year && dt.month == now.month,
      };
      final userOk = _userFilterId == null || e.userId == _userFilterId;
      return dateOk && userOk;
    }).toList();
  }

  String _dateFilterLabel(S s) => switch (_dateFilter) {
        _DateFilter.all => s.all,
        _DateFilter.today => s.today,
        _DateFilter.week => s.thisWeek,
        _DateFilter.month => s.thisMonth,
      };

  String _userFilterLabel(S s) {
    if (_userFilterId == null) return s.isKorean ? '모든 사용자' : 'All users';
    for (final user in _monitoredUsers) {
      if (user.id == _userFilterId) {
        return user.displayName.isNotEmpty ? user.displayName : user.username;
      }
    }
    return s.isKorean ? '사용자' : 'User';
  }

  Future<void> _openFilters() async {
    final s = S.read(context);
    var nextDate = _dateFilter;
    var nextUserId = _userFilterId;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? DarkColors.surface
          : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textPri = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.isKorean ? '필터' : 'Filters',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPri)),
                  const SizedBox(height: 16),
                  Text(s.isKorean ? '날짜별' : 'Date',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPri)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChoicePill(label: s.all, selected: nextDate == _DateFilter.all, onTap: () => setSheetState(() => nextDate = _DateFilter.all)),
                      _ChoicePill(label: s.today, selected: nextDate == _DateFilter.today, onTap: () => setSheetState(() => nextDate = _DateFilter.today)),
                      _ChoicePill(label: s.thisWeek, selected: nextDate == _DateFilter.week, onTap: () => setSheetState(() => nextDate = _DateFilter.week)),
                      _ChoicePill(label: s.thisMonth, selected: nextDate == _DateFilter.month, onTap: () => setSheetState(() => nextDate = _DateFilter.month)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(s.isKorean ? '연결 사용자별' : 'Care recipient',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPri)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChoicePill(label: s.isKorean ? '모든 사용자' : 'All users', selected: nextUserId == null, onTap: () => setSheetState(() => nextUserId = null)),
                      ..._monitoredUsers.map((u) {
                        final name = u.displayName.isNotEmpty ? u.displayName : u.username;
                        return _ChoicePill(label: name, selected: nextUserId == u.id, onTap: () => setSheetState(() => nextUserId = u.id));
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _dateFilter = nextDate;
                          _userFilterId = nextUserId;
                          _selectedIds.clear();
                        });
                        Navigator.pop(ctx);
                        AppToast.show(context, s.isKorean ? '필터가 적용되었습니다' : 'Filters applied', type: ToastType.success);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(s.isKorean ? '적용' : 'Apply',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _enterSelectMode() {
    setState(() { _selectMode = true; _selectedIds.clear(); });
  }

  void _exitSelectMode() {
    setState(() { _selectMode = false; _selectedIds.clear(); });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final allIds = _filtered.map((e) => e.id).toSet();
    setState(() {
      if (_selectedIds.containsAll(allIds)) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final s     = S.read(context);
    final count = _selectedIds.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? DarkColors.surface : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.deleteSelectedTitle(count),
            style: TextStyle(
                color: isDark ? DarkColors.textPrimary : AppColors.textPrimary)),
        content: Text(s.deleteSelectedBody(count),
            style: TextStyle(
                color: isDark ? DarkColors.textSecondary : AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel,
                style: TextStyle(
                    color: isDark
                        ? DarkColors.textSecondary
                        : AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete,
                style: TextStyle(
                    color: isDark ? DarkColors.danger : AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final ids = List<String>.from(_selectedIds);
    final api = context.read<AuthProvider>().api;
    setState(() => _deleting = true);
    try {
      await api.deleteEvents(ids);
      if (!mounted) return;
      _exitSelectMode();
      await _load();
      AppToast.show(context, s.deleteSuccessMsg(ids.length), type: ToastType.success);
    } catch (_) {
      if (mounted) {
        AppToast.show(context, s.deletePartialFail, type: ToastType.warning);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s       = S.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? DarkColors.bg           : AppColors.bg;
    final textPri = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final primary = isDark ? DarkColors.primary       : AppColors.primary;
    final danger  = isDark ? DarkColors.danger        : AppColors.danger;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
        Positioned.fill(
        child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _selectMode
                      ? Text(
                          s.selectedCount(_selectedIds.length),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        )
                      : Text(
                          s.fallRecords,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textPri,
                          ),
                        ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectMode) ...[
                        TextButton(
                          onPressed: filtered.isEmpty ? null : _toggleSelectAll,
                          child: Text(
                              filtered.isNotEmpty &&
                                      _selectedIds.containsAll(
                                          filtered.map((e) => e.id))
                                  ? s.deselectAll
                                  : s.selectAll,
                              style: TextStyle(
                                  color: filtered.isEmpty ? textSec : primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                        TextButton(
                          onPressed: _exitSelectMode,
                          child: Text(s.cancelSelect,
                              style: TextStyle(color: textSec)),
                        ),
                      ] else ...[
                        IconButton(
                          icon: Icon(Icons.filter_list_rounded, color: textSec),
                          onPressed: _openFilters,
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh_rounded, color: textSec),
                          onPressed: _load,
                        ),
                        TextButton(
                          onPressed: _filtered.isEmpty ? null : _enterSelectMode,
                          child: Text(s.selectBtn,
                              style: TextStyle(
                                  color: _filtered.isEmpty ? textSec : primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!_selectMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  '${_dateFilterLabel(s)} · ${_userFilterLabel(s)}',
                  style: TextStyle(color: textSec, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),

            const SizedBox(height: 14),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: (_loading && _events.isEmpty)
                  ? Center(
                      child: CircularProgressIndicator(
                          color: primary, strokeWidth: 2))
                  : _error != null
                      ? _ErrorView(error: _error!, onRetry: _load)
                      : filtered.isEmpty
                          ? _EmptyView(
                              message: s.noFiltered)
                          : RefreshIndicator(
                              color: primary,
                              onRefresh: _load,
                              child: ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                                itemCount: filtered.length + (_hasMore ? 1 : 0),
                                itemBuilder: (ctx, i) {
                                  if (i == filtered.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            color: primary, strokeWidth: 2),
                                      ),
                                    );
                                  }
                                  return _EventCard(
                                    event: filtered[i],
                                    isDark: isDark,
                                    selectMode: _selectMode,
                                    selected: _selectedIds.contains(filtered[i].id),
                                    onTap: () async {
                                      if (_selectMode) {
                                        _toggleSelect(filtered[i].id);
                                      } else {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EventDetailScreen(
                                                eventId: filtered[i].id),
                                          ),
                                        );
                                        _load();
                                      }
                                    },
                                    onLongPress: _selectMode
                                        ? null
                                        : () {
                                            _enterSelectMode();
                                            _toggleSelect(filtered[i].id);
                                          },
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
        ),
        ),
        if (_deleting)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.25),
              child: Center(
                child: CircularProgressIndicator(color: primary, strokeWidth: 3),
              ),
            ),
          ),
        ],
      ),

      // ── Delete action bar (select mode) ──────────────────────────────────
      bottomSheet: _selectMode && _selectedIds.isNotEmpty
          ? Container(
              decoration: BoxDecoration(
                color: isDark ? DarkColors.surface : AppColors.surface,
                border: Border(
                    top: BorderSide(
                        color: isDark ? DarkColors.border : AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(
                    s.deleteSelectedBtn,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final chip = isDark ? DarkColors.chip : AppColors.chip;
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary : chip,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : textSec,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _EventCard({
    required this.event,
    required this.isDark,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final textPri  = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textTer  = isDark ? DarkColors.textTertiary  : AppColors.textTertiary;
    final primary  = isDark ? DarkColors.primary       : AppColors.primary;
    final success  = isDark ? DarkColors.success       : AppColors.success;
    final warning  = isDark ? DarkColors.warning       : AppColors.warning;
    final statusColor = event.isAcknowledged ? success : warning;
    final statusBg = statusColor.withOpacity(isDark ? 0.18 : 0.12);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? DarkColors.surface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? primary
                : (isDark ? DarkColors.border : AppColors.border),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Selection indicator or severity icon
            if (selectMode)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? primary : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? primary
                        : (isDark ? DarkColors.border : AppColors.border),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              )
            else
              // calm blue — severity is shown only by the small badge on the
              // right, so a wall of history entries doesn't read as all-alarm
              Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(right: 14),
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

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTs(event.timestamp),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textPri,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          event.isAcknowledged ? 'Confirmed' : 'Need to Confirm',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!selectMode) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: Text(
                  event.monitoredUserName?.isNotEmpty == true ? event.monitoredUserName! : '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textTer),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: textTer),
            ],
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
            Text(error,
                style: TextStyle(color: textSec),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
    final textTer = Theme.of(context).brightness == Brightness.dark
        ? DarkColors.textTertiary
        : AppColors.textTertiary;
    return Center(
      child: Text(
        message,
        style: TextStyle(color: textTer, fontSize: 14),
      ),
    );
  }
}









