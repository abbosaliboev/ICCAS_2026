import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../providers/auth_provider.dart';
import '../models/fall_event.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  FallEvent? _event;
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;
  VideoPlayerController? _vpCtrl;
  ChewieController? _chewieCtrl;
  bool _videoInitialized = false;
  bool _smsLoading = false;
  String? _smsResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthProvider>().api;
    try {
      final event = await api.getFallEvent(widget.eventId);
      if (event == null) throw Exception('이벤트를 찾을 수 없습니다');
      Map<String, dynamic>? report;
      try {
        report = await api.getEmergencyReport(widget.eventId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _event = event;
          _report = report;
          _loading = false;
        });
        if (event.hasVideo) _initVideo(api.videoUrl(widget.eventId));
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _initVideo(String url) async {
    _vpCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
    await _vpCtrl!.initialize();
    _chewieCtrl = ChewieController(
      videoPlayerController: _vpCtrl!,
      autoPlay: false,
      looping: false,
      aspectRatio: _vpCtrl!.value.aspectRatio,
    );
    if (mounted) setState(() => _videoInitialized = true);
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _vpCtrl?.dispose();
    super.dispose();
  }

  Future<void> _acknowledge() async {
    final api = context.read<AuthProvider>().api;
    try {
      await api.acknowledgeEvent(widget.eventId);
      setState(() => _event = FallEvent(
            id: _event!.id,
            deviceId: _event!.deviceId,
            userId: _event!.userId,
            timestamp: _event!.timestamp,
            category: _event!.category,
            videoPath: _event!.videoPath,
            thumbnailPath: _event!.thumbnailPath,
            isAcknowledged: true,
          ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('확인 처리되었습니다'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendSms() async {
    setState(() {
      _smsLoading = true;
      _smsResult = null;
    });
    try {
      final result = await context.read<AuthProvider>().api.notifyGuardianSms(widget.eventId);
      setState(() => _smsResult = result['ok'] == true ? '문자 전송 완료' : '문자 전송 실패: ${result['detail']}');
    } catch (e) {
      setState(() => _smsResult = '오류: $e');
    } finally {
      setState(() => _smsLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('이벤트 삭제', style: TextStyle(color: Colors.white)),
        content: const Text('이 이벤트와 관련 영상을 삭제할까요?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AuthProvider>().api.deleteEvent(widget.eventId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('이벤트 상세', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_event != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final event = _event!;
    final isSevere = event.isSevere;
    final color = isSevere ? Colors.red : Colors.orange;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video / thumbnail area
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: event.hasVideo
                ? (_videoInitialized
                    ? AspectRatio(
                        aspectRatio: _vpCtrl!.value.aspectRatio,
                        child: Chewie(controller: _chewieCtrl!),
                      )
                    : Container(
                        height: 200,
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
                        ),
                      ))
                : _ScreenshotWidget(eventId: event.id),
          ),
          const SizedBox(height: 20),
          // Status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_rounded, color: color, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      isSevere ? '심각한 낙상' : '낙상 의심',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (event.isAcknowledged)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                      SizedBox(width: 4),
                      Text('확인됨', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Info cards
          if (_report != null) _reportCard(),
          const SizedBox(height: 20),
          // Action buttons
          if (!event.isAcknowledged)
            _actionButton('확인 처리', Icons.check_circle_outline, Colors.greenAccent, _acknowledge),
          const SizedBox(height: 10),
          _smsSection(),
        ],
      ),
    );
  }

  Widget _reportCard() {
    final r = _report!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('긴급 리포트', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(color: Colors.white12, height: 20),
          _infoRow('이름', r['name'] ?? '-'),
          _infoRow('나이', r['age']?.toString() ?? '-'),
          _infoRow('주소', r['address'] ?? '-'),
          _infoRow('연락처', r['phone'] ?? '-'),
          _infoRow('시각', r['timestamp'] ?? '-'),
          _infoRow('영상', r['has_video'] == true ? '있음' : '없음'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          ],
        ),
      );

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 18),
          label: Text(label, style: TextStyle(color: color)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withOpacity(0.4)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _smsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _smsLoading ? null : _sendSms,
              icon: _smsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4FC3F7)),
                    )
                  : const Icon(Icons.sms, color: Color(0xFF4FC3F7), size: 18),
              label: const Text('보호자에게 문자 전송', style: TextStyle(color: Color(0xFF4FC3F7))),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: const Color(0xFF4FC3F7).withAlpha(102)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_smsResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _smsResult!,
              style: TextStyle(
                color: _smsResult!.contains('완료') ? Colors.greenAccent : Colors.redAccent,
                fontSize: 13,
              ),
            ),
          ],
        ],
      );
}

class _ScreenshotWidget extends StatelessWidget {
  final String eventId;
  const _ScreenshotWidget({required this.eventId});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final url = auth.api.screenshotUrl(eventId);
    return Image.network(
      url,
      headers: {'Authorization': 'Bearer ${auth.token}'},
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 150,
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.white24, size: 48),
        ),
      ),
    );
  }
}
