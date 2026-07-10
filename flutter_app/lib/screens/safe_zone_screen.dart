import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../models/user.dart';
import '../strings.dart';
import '../widgets/app_toast.dart';

class _Zone {
  final double x, y, w, h;
  _Zone(this.x, this.y, this.w, this.h);
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};
  static _Zone fromJson(Map<String, dynamic> j) => _Zone(
        (j['x'] as num).toDouble(), (j['y'] as num).toDouble(),
        (j['w'] as num).toDouble(), (j['h'] as num).toDouble(),
      );
}

class SafeZoneScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;
  const SafeZoneScreen({super.key, this.targetUserId, this.targetUserName});
  @override
  State<SafeZoneScreen> createState() => _SafeZoneScreenState();
}

class _SafeZoneScreenState extends State<SafeZoneScreen> {
  List<_Zone> _zones = [];
  Uint8List? _snapshot;
  bool _loadingSnapshot = true;
  bool _loadingRecipients = false;
  bool _saving = false;
  bool _drawing = false;
  List<User> _recipients = [];
  String? _targetUserId;
  String? _targetUserName;

  // View/edit state machine: drawing and destructive actions only exist in
  // edit mode; Save (or Cancel) returns to view mode. _zonesBackup restores
  // the server state when the user cancels.
  bool _editing = false;
  List<_Zone> _zonesBackup = [];

  Offset? _drawStart;
  Offset? _drawCurrent;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthProvider>().api;
    final auth = context.read<AuthProvider>();
    _targetUserId = widget.targetUserId;
    _targetUserName = widget.targetUserName;
    if (auth.user?.isGuardian == true && _targetUserId == null) {
      if (mounted) setState(() => _loadingRecipients = true);
      try {
        final users = await api.getMonitoredUsers();
        if (users.isNotEmpty) {
          _targetUserId = users.first.id;
          _targetUserName = _displayName(users.first);
        }
        if (mounted) setState(() => _recipients = users);
      } catch (_) {
        if (mounted) setState(() => _recipients = []);
      } finally {
        if (mounted) setState(() => _loadingRecipients = false);
      }
    }
    try {
      final data = await api.getSafeZone(userId: _targetUserId);
      final zones = (data['zones'] as List?)
              ?.map((e) => _Zone.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      if (mounted) setState(() => _zones = zones);
    } catch (_) {}
    await _fetchSnapshot();
  }

  String _displayName(User user) =>
      user.displayName.isNotEmpty ? user.displayName : user.username;

  Future<void> _selectRecipient(User user) async {
    setState(() {
      _targetUserId = user.id;
      _targetUserName = _displayName(user);
      _snapshot = null;
      _zones = [];
      _editing = false;
      _drawStart = null;
      _drawCurrent = null;
      _drawing = false;
    });
    await _loadTargetData();
  }

  Future<void> _loadTargetData() async {
    final api = context.read<AuthProvider>().api;
    try {
      final data = await api.getSafeZone(userId: _targetUserId);
      final zones = (data['zones'] as List?)
              ?.map((e) => _Zone.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      if (mounted) setState(() => _zones = zones);
    } catch (_) {}
    await _fetchSnapshot();
  }

  Future<void> _fetchSnapshot() async {
    if (mounted) setState(() => _loadingSnapshot = true);
    try {
      final auth = context.read<AuthProvider>();
      final r = await http.get(
        Uri.parse(auth.api.snapshotUrl(userId: _targetUserId)),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      ).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200 && mounted) {
        setState(() { _snapshot = r.bodyBytes; _loadingSnapshot = false; });
      } else {
        if (mounted) setState(() => _loadingSnapshot = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSnapshot = false);
    }
  }

  Size get _canvasSize {
    final ctx = _canvasKey.currentContext;
    if (ctx == null) return Size.zero;
    final rb = ctx.findRenderObject() as RenderBox?;
    return rb?.size ?? Size.zero;
  }

  void _onPanStart(DragStartDetails d) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() {
      _drawing = true;
      _drawStart = box.globalToLocal(d.globalPosition);
      _drawCurrent = _drawStart;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _drawCurrent = box.globalToLocal(d.globalPosition));
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_drawing) return;
    _drawing = false;
    final size = _canvasSize;
    if (size == Size.zero || _drawStart == null || _drawCurrent == null) {
      setState(() { _drawStart = null; _drawCurrent = null; });
      return;
    }
    final x1 = _drawStart!.dx.clamp(0.0, size.width);
    final y1 = _drawStart!.dy.clamp(0.0, size.height);
    final x2 = _drawCurrent!.dx.clamp(0.0, size.width);
    final y2 = _drawCurrent!.dy.clamp(0.0, size.height);
    final rw = (x2 - x1).abs() / size.width;
    final rh = (y2 - y1).abs() / size.height;
    setState(() {
      if (rw > 0.01 && rh > 0.01) {
        _zones.add(_Zone(
          _dmin(x1, x2) / size.width,
          _dmin(y1, y2) / size.height,
          rw, rh,
        ));
      }
      _drawStart = null;
      _drawCurrent = null;
    });
  }

  double _dmin(double a, double b) => a < b ? a : b;

  void _enterEdit() {
    setState(() {
      _zonesBackup = List.of(_zones);
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _zones = List.of(_zonesBackup);
      _drawStart = null;
      _drawCurrent = null;
      _drawing = false;
      _editing = false;
    });
  }

  Future<void> _save() async {
    final s = S.read(context);
    setState(() => _saving = true);
    try {
      final api     = context.read<AuthProvider>().api;
      final camType = context.read<SettingsProvider>().cameraType;
      // an empty list clears the zones server-side, so a separate clear API
      // call is unnecessary — Clear only edits the local working copy
      await api.setSafeZone(
        _zones.map((z) => z.toJson()).toList(),
        userId: _targetUserId,
      );
      await api.setCameraType(camType);
      if (mounted) {
        context.read<SettingsProvider>().bumpZonesVersion();
        AppToast.show(context, s.safeZoneSaved, type: ToastType.success);
        setState(() => _editing = false); // success → back to view mode
      }
    } catch (e) {
      // stay in edit mode so the drawn zones aren't lost and Save can be retried
      if (mounted) AppToast.show(context, s.saveFailed(e), type: ToastType.error);
    } finally {
      setState(() => _saving = false);
    }
  }

  void _clear() {
    setState(() {
      _zones.clear();
      _drawStart = null;
      _drawCurrent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s       = S.of(context);
    final isDark  = context.watch<ThemeProvider>().isDark;
    final bg      = isDark ? DarkColors.bg      : AppColors.bg;
    final surface = isDark ? DarkColors.surface  : Colors.white;
    final border  = isDark ? DarkColors.border   : AppColors.border;
    final primary = isDark ? DarkColors.primary  : AppColors.primary;
    final textPri = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final dangerTint = isDark ? DarkColors.dangerTint : AppColors.dangerTint;
    final danger     = isDark ? DarkColors.danger     : AppColors.danger;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: textPri,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(s.safeZoneTitle,
            style: TextStyle(color: textPri, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: textPri),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textSec),
            onPressed: _fetchSnapshot,
            tooltip: s.snapshotRefresh,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.safeZoneInfo,
                    style: TextStyle(color: textPri, fontSize: 13, height: 1.5),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            if (_recipients.isNotEmpty) ...[
              Text(
                s.isKorean ? '피보호자 선택' : 'Care recipient',
                style: TextStyle(
                    color: textSec, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _targetUserId,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSec),
                    items: _recipients
                        .map((user) => DropdownMenuItem<String>(
                              value: user.id,
                              child: Text(
                                _displayName(user),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textPri,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: _loadingRecipients
                        ? null
                        : (id) {
                            final user = _recipients.firstWhere((u) => u.id == id);
                            _selectRecipient(user);
                          },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else if (_targetUserName?.isNotEmpty == true) ...[
              Text(
                s.isKorean ? '피보호자' : 'Care recipient',
                style: TextStyle(
                    color: textSec, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Text(
                  _targetUserName!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textPri, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Canvas ────────────────────────────────────────────────────
            Text(s.drawZoneLabel,
                style: TextStyle(
                    color: textSec, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                clipBehavior: Clip.antiAlias,
                child: _loadingSnapshot
                    ? Center(
                        child: CircularProgressIndicator(
                            color: primary, strokeWidth: 2))
                    : GestureDetector(
                        key: _canvasKey,
                        // drawing only in edit mode — casual touches while
                        // viewing must not create zones
                        onPanStart: _editing ? _onPanStart : null,
                        onPanUpdate: _editing ? _onPanUpdate : null,
                        onPanEnd: _editing ? _onPanEnd : null,
                        child: CustomPaint(
                          foregroundPainter: _ZonePainter(
                            zones: _zones,
                            drawStart: _drawStart,
                            drawCurrent: _drawCurrent,
                            primaryColor: primary,
                            drawColor: isDark ? DarkColors.warning : AppColors.warning,
                          ),
                          child: _snapshot != null
                              ? Image.memory(_snapshot!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity)
                              : Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam_off,
                                          color: Colors.white24, size: 40),
                                      const SizedBox(height: 8),
                                      Text(s.noCameraMsg,
                                          style: const TextStyle(
                                              color: Colors.white24,
                                              fontSize: 12),
                                          textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _zones.isEmpty
                      ? s.noZoneLabel
                      : s.zoneCount(_zones.length),
                  style: TextStyle(color: textSec, fontSize: 12),
                ),
                if (_editing && _zones.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _zones.removeLast()),
                    child: Text(s.cancelLastZone,
                        style: const TextStyle(
                            color: AppColors.warning, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // View mode: single Edit button. Edit mode: Cancel / Clear / Save.
            if (!_editing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loadingSnapshot ? null : _enterEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(s.editZones,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              )
            else
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving ? null : _cancelEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: textSec,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(s.cancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_saving || _zones.isEmpty) ? null : _clear,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dangerTint,
                      foregroundColor: danger,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(s.delete, style: TextStyle(color: danger)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(s.save),
                  ),
                ),
              ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────

class _ZonePainter extends CustomPainter {
  final List<_Zone> zones;
  final Offset? drawStart;
  final Offset? drawCurrent;
  final Color primaryColor;
  final Color drawColor;

  _ZonePainter({
    required this.zones,
    this.drawStart,
    this.drawCurrent,
    required this.primaryColor,
    required this.drawColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = primaryColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final z in zones) {
      final rect = Rect.fromLTWH(
        z.x * size.width, z.y * size.height,
        z.w * size.width, z.h * size.height,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
    }

    if (drawStart != null && drawCurrent != null) {
      final rect = Rect.fromPoints(drawStart!, drawCurrent!);
      canvas.drawRect(
          rect,
          Paint()
            ..color = drawColor.withOpacity(0.2)
            ..style = PaintingStyle.fill);
      canvas.drawRect(
          rect,
          Paint()
            ..color = drawColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_ZonePainter old) =>
      old.zones != zones ||
      old.drawStart != drawStart ||
      old.drawCurrent != drawCurrent;
}



