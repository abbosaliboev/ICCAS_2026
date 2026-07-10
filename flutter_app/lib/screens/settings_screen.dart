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
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? DarkColors.bg          : AppColors.bg;
    final textPri = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final textTer = isDark ? DarkColors.textTertiary : AppColors.textTertiary;
    final primary = isDark ? DarkColors.primary     : AppColors.primary;
    final success = isDark ? DarkColors.success     : AppColors.success;
    final infoBg  = isDark ? DarkColors.primaryTint : AppColors.primaryTint;

    return Scaffold(
      backgroundColor: bg,
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
              style: TextStyle(
                color: textPri,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.backendUrlHelp,
              style: TextStyle(color: textTer, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _urlCtrl,
              style: TextStyle(color: textPri, fontSize: 14),
              keyboardType: TextInputType.url,
              decoration: appInputDeco(
                'http://192.168.x.x:8000',
                icon: Icons.dns_outlined,
                dark: isDark,
              ),
            ),

            const SizedBox(height: 24),

            // ── Edge URL ──────────────────────────────────────────────────
            Text(
              s.edgeUrlLabel,
              style: TextStyle(
                color: textPri,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.edgeUrlHelp,
              style: TextStyle(color: textTer, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _edgeUrlCtrl,
              style: TextStyle(color: textPri, fontSize: 14),
              keyboardType: TextInputType.url,
              decoration: appInputDeco(
                'http://192.168.x.x:8000',
                icon: Icons.videocam_outlined,
                dark: isDark,
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saved ? success : primary,
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
                color: infoBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        s.connectionGuideTitle,
                        style: TextStyle(
                          color: primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.connectionGuideBody,
                    style: TextStyle(
                      color: primary,
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
