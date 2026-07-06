import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

const _kAlertMessage =
    '낙상이 감지되었습니다. '
    '보호자에게 연락 및 119 신고를 원하시면 "연락"이라고 말씀해주세요. '
    '괜찮으시면 "아니"라고 말씀해주세요. '
    '15초 간 응답이 없으시면 자동으로 119 문자 신고 및 보호자에게 연락 조치가 진행됩니다.';

class FallResponseOverlay extends StatefulWidget {
  final String eventId;
  final VoidCallback onDismiss;

  const FallResponseOverlay({
    super.key,
    required this.eventId,
    required this.onDismiss,
  });

  @override
  State<FallResponseOverlay> createState() => _FallResponseOverlayState();
}

class _FallResponseOverlayState extends State<FallResponseOverlay> {
  final _tts = FlutterTts();
  final _stt = SpeechToText();

  Timer? _countdownTimer;
  int _remaining = 15;
  bool _ttsPlaying = true;
  bool _listening = false;
  bool _responded = false;
  String _statusText = 'TTS 재생 중...';

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
    super.dispose();
  }

  Future<void> _startTts() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      if (!mounted || _responded) return;
      setState(() {
        _ttsPlaying = false;
        _statusText = '"연락" 또는 "아니"라고 말씀해주세요';
      });
      _startCountdown();
      _startListening();
    });
    await _tts.speak(_kAlertMessage);
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
        if (status == 'done' && !_responded && mounted) {
          _startListening();
        }
      },
    );
    if (!available || !mounted || _responded) return;
    if (mounted) setState(() => _listening = true);
    _stt.listen(
      onResult: (result) {
        if (!mounted || _responded) return;
        final text = result.recognizedWords;
        if (text.contains('연락') || text.contains('네') || text.contains('예')) {
          _handleResponse(emergency: true);
        } else if (text.contains('아니') || text.contains('괜찮') || text.contains('아냐')) {
          _handleResponse(emergency: false);
        }
      },
      localeId: 'ko_KR',
      listenFor: const Duration(seconds: 14),
      pauseFor: const Duration(seconds: 4),
    );
  }

  Future<void> _handleResponse({required bool emergency}) async {
    if (_responded) return;
    _responded = true;
    _countdownTimer?.cancel();
    await _tts.stop();
    await _stt.stop();
    if (mounted) setState(() => _listening = false);

    if (emergency) {
      if (mounted) setState(() => _statusText = '연락 중...');
      try {
        final api = context.read<AuthProvider>().api;
        await Future.wait([
          api.notifyGuardianSms(widget.eventId),
          api.notifyEmergencySms(widget.eventId),
        ]);
        if (mounted) setState(() => _statusText = '✅ 보호자 및 119에 연락 완료');
      } catch (_) {
        if (mounted) setState(() => _statusText = '⚠️ 연락 처리 중 오류 발생');
      }
    } else {
      if (mounted) setState(() => _statusText = '✅ 취소되었습니다. 안전하세요!');
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.94),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Warning icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent, width: 2.5),
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 52),
              ),
              const SizedBox(height: 32),

              // Message box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                ),
                child: const Text(
                  _kAlertMessage,
                  style: TextStyle(color: Colors.white, fontSize: 16, height: 1.65),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),

              // Status text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusText,
                  key: ValueKey(_statusText),
                  style: TextStyle(
                    color: _ttsPlaying ? Colors.blue.shade200 : Colors.greenAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Countdown + buttons (shown after TTS)
              if (!_ttsPlaying) ...[
                const SizedBox(height: 24),
                Text(
                  '$_remaining초',
                  style: TextStyle(
                    color: _remaining <= 5 ? Colors.redAccent : Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _remaining / 15,
                    backgroundColor: Colors.white12,
                    color: _remaining <= 5 ? Colors.redAccent : Colors.orangeAccent,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _responded ? null : () => _handleResponse(emergency: true),
                        icon: const Icon(Icons.phone),
                        label: const Text('연락하기', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _responded ? null : () => _handleResponse(emergency: false),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('괜찮아요', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_listening) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.mic, color: Colors.greenAccent, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        '마이크 활성화 중',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
