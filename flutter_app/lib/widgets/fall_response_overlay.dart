import 'dart:async';
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
    super.dispose();
  }

  Future<void> _startTts() async {
    final s = S.read(context);
    _statusText = s.fallAlertTtsPlaying;

    await _tts.setLanguage(s.isKorean ? 'ko-KR' : 'en-US');
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
    await _tts.speak(s.fallAlertTtsMessage);
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
        final s = S.read(context);
        final wantsHelp = s.isKorean
            ? text.contains('연락') || text.contains('네') || text.contains('예')
            : text.contains('help') ||
                text.contains('yes') ||
                text.contains('call') ||
                text.contains('emergency');
        final isOk = s.isKorean
            ? text.contains('아니') || text.contains('괜찮') || text.contains('아냐')
            : text.contains('no') ||
                text.contains('okay') ||
                text.contains('ok') ||
                text.contains('fine') ||
                text.contains("i'm ok") ||
                text.contains('im ok');

        if (wantsHelp) {
          _handleResponse(emergency: true);
        } else if (isOk) {
          _handleResponse(emergency: false);
        }
      },
      localeId: S.read(context).isKorean ? 'ko_KR' : 'en_US',
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

    final s = S.read(context);
    if (emergency) {
      if (mounted) setState(() => _statusText = s.fallAlertContacting);
      try {
        final api = context.read<AuthProvider>().api;
        await Future.wait([
          api.notifyGuardianSms(widget.eventId),
          api.notifyEmergencySms(widget.eventId),
        ]);
        if (mounted) setState(() => _statusText = s.fallAlertContacted);
      } catch (_) {
        if (mounted) setState(() => _statusText = s.fallAlertContactError);
      }
    } else {
      if (mounted) setState(() => _statusText = s.fallAlertCanceled);
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

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
                            // Glowing icon
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.danger.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.warning_rounded,
                                  color: Colors.white, size: 36),
                            ),
                            const SizedBox(height: 14),
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
