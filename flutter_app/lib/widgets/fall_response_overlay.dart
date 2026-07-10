import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../strings.dart';

class FallResponseOverlay extends StatefulWidget {
  final String eventId;
  final VoidCallback onDismiss;
  final bool demoMode;

  const FallResponseOverlay({
    super.key,
    required this.eventId,
    required this.onDismiss,
    this.demoMode = false,
  });

  @override
  State<FallResponseOverlay> createState() => _FallResponseOverlayState();
}

class _FallResponseOverlayState extends State<FallResponseOverlay> {
  final _tts = FlutterTts();
  final _stt = SpeechToText();
  // low-latency SFX player for the short confirmation tones — a beep is
  // faster and less intrusive than a spoken confirmation
  final _sfx = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

  Timer? _countdownTimer;
  int _remaining = 15;
  bool _ttsPlaying = true;
  bool _listening = false;
  bool _responded = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _startTts();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tts.stop();
    _stt.stop();
    _sfx.dispose();
    super.dispose();
  }

  Future<void> _beepAck() async {
    try {
      await _sfx.play(AssetSource('sounds/ack.wav'), volume: 1.0);
    } catch (_) {}
  }

  Future<void> _beepDone() async {
    try {
      await _sfx.play(AssetSource('sounds/done.wav'), volume: 1.0);
    } catch (_) {}
  }

  Future<void> _startTts() async {
    final s = S.read(context);
    final isKorean = s.isKorean;
    _statusText = s.fallAlertTtsPlaying;
    final demoTtsMessage = isKorean
        ? '낙상이 감지되었습니다. 보호자나 119에게 연락이 필요하시면 "연락", 괜찮으시다면 "아니"라고 말씀해주세요. 15초 간 아무 응답이 없으시면 자동으로 문자가 발송됩니다.'
        : 'A fall has been detected. If you need to contact your guardian or emergency services, say "call". If you are okay, say "no". If there is no response for 15 seconds, a text message will be sent automatically.';

    await _tts.setLanguage(isKorean ? 'ko-KR' : 'en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      if (!mounted || _responded) return;
      setState(() {
        _ttsPlaying = false;
        _statusText = S.read(context).fallAlertVoicePrompt;
      });
      _startCountdown();
      _startListening();
    });
    await _tts.speak(widget.demoMode ? demoTtsMessage : s.fallAlertTtsMessage);
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _handleResponse(emergency: true);
      }
    });
  }

  Future<void> _startListening() async {
    if (_responded) return;
    final available = await _stt.initialize(
      onStatus: (status) {
        if (status == 'done' && !_responded && mounted) _startListening();
      },
    );
    if (!available || !mounted || _responded) return;
    if (mounted) setState(() => _listening = true);
    _stt.listen(
      onResult: (result) {
        if (!mounted || _responded) return;
        final text = result.recognizedWords.toLowerCase();
        final bool wantsHelp;
        final bool isOk;
        if (S.read(context).isKorean) {
          wantsHelp =
              text.contains('연락') || text.contains('네') || text.contains('예');
          isOk = text.contains('아니') ||
              text.contains('괜찮') ||
              text.contains('아냐');
        } else {
          // token match, not substring — 'no' must not fire on 'know',
          // and short English commands need a wider synonym set to be
          // recognized reliably
          final words = text
              .replaceAll(RegExp(r"[^a-z' ]"), ' ')
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .toSet();
          const helpWords = {
            'help', 'yes', 'yeah', 'yep', 'call', 'emergency', 'sos',
            'contact', 'hurt', 'ambulance',
          };
          const okWords = {
            'no', 'nope', 'okay', 'ok', 'fine', 'good', 'alright',
            "i'm", 'cancel',
          };
          wantsHelp = words.intersection(helpWords).isNotEmpty;
          isOk = !wantsHelp && words.intersection(okWords).isNotEmpty;
        }

        if (wantsHelp) {
          _handleResponse(emergency: true);
        } else if (isOk) {
          _handleResponse(emergency: false);
        }
      },
      localeId: S.read(context).isKorean ? 'ko_KR' : 'en_US',
      listenFor: const Duration(seconds: 14),
      pauseFor: const Duration(seconds: 4),
      // short-command mode: biases the recognizer toward brief phrases and
      // returns partials, which materially improves one-word English commands
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
      ),
    );
  }

  Future<void> _handleResponse({required bool emergency}) async {
    if (_responded) return;
    _responded = true;
    _countdownTimer?.cancel();
    _beepAck(); // command received — instant tone, no spoken confirmation
    await _tts.stop();
    await _stt.stop();
    if (mounted) setState(() => _listening = false);

    final s = S.read(context);
    if (emergency) {
      if (mounted) setState(() => _statusText = s.fallAlertContacting);
      try {
        final api = context.read<AuthProvider>().api;
        await Future.wait([
          api.notifyGuardianSms(widget.eventId),
          api.notifyEmergencySms(widget.eventId),
        ]);
        _beepDone(); // action completed
        if (mounted) setState(() => _statusText = s.fallAlertContacted);
      } catch (_) {
        if (mounted) setState(() => _statusText = s.fallAlertContactError);
      }
    } else {
      _beepDone();
      if (mounted) setState(() => _statusText = s.fallAlertCanceled);
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final demoInstruction = s.isKorean
        ? '실사용자의 화면에서 사용 가능한 STT, TTS 서비스입니다. 카메라라고 생각하시고 진행해주세요.'
        : 'This is the STT and TTS service available on the care recipient screen. Please proceed as if the camera is speaking.';

    return Material(
      color: const Color(0xFF280A08).withOpacity(0.92),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Alert card ────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      // Red header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: AppColors.dangerTint,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              s.fallAlertTitle,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.dangerPressed,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.fallAlertMeta,
                              style: const TextStyle(
                                  color: AppColors.dangerPressed, fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                      // Body
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            if (widget.demoMode) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTint,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  demoInstruction,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.primaryPressed,
                                    fontSize: 13,
                                    height: 1.45,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _CameraVoiceVisual(),
                              const SizedBox(height: 16),
                            ],
                            // Status text
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _statusText.isEmpty
                                    ? s.fallAlertTtsPlaying
                                    : _statusText,
                                key: ValueKey(_statusText),
                                style: TextStyle(
                                  color: _ttsPlaying
                                      ? AppColors.primary
                                      : AppColors.success,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            // Countdown (after TTS)
                            if (!_ttsPlaying) ...[
                              const SizedBox(height: 16),
                              Text(
                                s.fallAlertSeconds(_remaining),
                                style: TextStyle(
                                  color: _remaining <= 5
                                      ? AppColors.danger
                                      : AppColors.textPrimary,
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _remaining / 15,
                                  backgroundColor: AppColors.chip,
                                  color: _remaining <= 5
                                      ? AppColors.danger
                                      : AppColors.warning,
                                  minHeight: 8,
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // 119 button (primary)
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: _responded
                                    ? null
                                    : () => _handleResponse(emergency: true),
                                icon: const Icon(Icons.phone),
                                label: Text(
                                  s.fallAlertReport119,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Guardian button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: _responded
                                    ? null
                                    : () => _handleResponse(emergency: true),
                                icon: const Icon(Icons.people_outline),
                                label: Text(
                                  s.fallAlertContactGuardian,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // OK button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: TextButton(
                                onPressed: _responded
                                    ? null
                                    : () => _handleResponse(emergency: false),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  s.fallAlertConfirmed,
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),

                            if (_listening) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.mic,
                                      color: AppColors.success, size: 14),
                                  const SizedBox(width: 5),
                                  Text(
                                    s.fallAlertMicActive,
                                    style: const TextStyle(
                                        color: AppColors.success, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraVoiceVisual extends StatelessWidget {
  const _CameraVoiceVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(
            size: const Size(76, 48),
            painter: _VoiceWavePainter(),
          ),
          const SizedBox(width: 18),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.videocam_rounded,
                  color: Color(0xFF4B5563),
                  size: 42,
                ),
                Positioned(
                  right: 14,
                  bottom: 15,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
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

class _VoiceWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final heights = [18.0, 34.0, 44.0, 30.0, 46.0, 36.0, 22.0];
    final gap = size.width / (heights.length + 1);
    for (var i = 0; i < heights.length; i++) {
      final x = gap * (i + 1);
      final h = heights[i];
      final y1 = (size.height - h) / 2;
      final y2 = y1 + h;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

