import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../strings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _edgeUrlCtrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _urlCtrl = TextEditingController(text: auth.baseUrl);
    _edgeUrlCtrl = TextEditingController(text: auth.edgeUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _edgeUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    await auth.setBaseUrl(_urlCtrl.text);
    await auth.setEdgeUrl(_edgeUrlCtrl.text);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(s.serverSettingsTitle),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Backend URL ───────────────────────────────────────────────
            Text(
              s.backendUrlLabel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.backendUrlHelp,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _urlCtrl,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              keyboardType: TextInputType.url,
              decoration: lightInputDeco(
                'http://192.168.x.x:8000',
                icon: Icons.dns_outlined,
              ),
            ),

            const SizedBox(height: 24),

            // ── Edge URL ──────────────────────────────────────────────────
            Text(
              s.edgeUrlLabel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.edgeUrlHelp,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _edgeUrlCtrl,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              keyboardType: TextInputType.url,
              decoration: lightInputDeco(
                'http://192.168.x.x:8000',
                icon: Icons.videocam_outlined,
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saved
                      ? AppColors.success
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _saved ? s.savedDone : s.save,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Info box ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.connectionGuideTitle,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.connectionGuideBody,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
