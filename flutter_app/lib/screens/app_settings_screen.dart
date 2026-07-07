import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'safe_zone_screen.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final themeP   = context.watch<ThemeProvider>();
    final settingsP = context.watch<SettingsProvider>();
    final user     = auth.user!;
    final isDark   = themeP.isDark;

    final bg      = isDark ? DarkColors.bg      : AppColors.bg;
    final textP   = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textS   = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final textT   = isDark ? DarkColors.textTertiary  : AppColors.textTertiary;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final chipBg  = isDark ? DarkColors.chip    : AppColors.chip;

    final initial = (user.displayName.isNotEmpty ? user.displayName : user.username)
        .characters.first.toUpperCase();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Text('설정',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: textP)),
            const SizedBox(height: 20),

            // ── Account card ────────────────────────────────────────────────
            _accountCard(context, user, initial, isDark, primary),
            const SizedBox(height: 28),

            // ── 외관 ────────────────────────────────────────────────────────
            _sectionTitle('외관', textT),
            _themeToggle(context, themeP, isDark, primary, chipBg, textP, textS),
            const SizedBox(height: 8),
            _languagePicker(context, settingsP, isDark, textP, textS, chipBg, primary),
            const SizedBox(height: 28),

            // ── 긴급 연락처 ──────────────────────────────────────────────────
            _sectionTitle('긴급 연락처', textT),
            _emergencyContactRow(context, settingsP, isDark, textP, textS, primary),
            const SizedBox(height: 28),

            // ── 연결 ────────────────────────────────────────────────────────
            _sectionTitle('연결', textT),
            _SettingsRow(
              icon: Icons.dns_outlined,
              title: '서버 설정',
              subtitle: '백엔드 & 엣지 서버 주소',
              isDark: isDark,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),

            // ── 카메라 & 안전 ───────────────────────────────────────────────
            if (!user.isGuardian) ...[
              const SizedBox(height: 28),
              _sectionTitle('카메라 & 안전', textT),
              _cameraTypeRow(context, settingsP, isDark, textP, textS, chipBg, primary),
              const SizedBox(height: 8),
              _SettingsRow(
                icon: Icons.crop_free_outlined,
                title: '안전 구역 설정',
                subtitle: '낙상 감지 제외 구역 관리',
                isDark: isDark,
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SafeZoneScreen())),
              ),
            ],

            const SizedBox(height: 28),
            _sectionTitle('앱 정보', textT),
            _SettingsRow(
              icon: Icons.info_outline,
              title: 'MobiCare',
              subtitle: 'v1.0.0 · Edge AI 기반 낙상 감지',
              isDark: isDark,
              onTap: null,
            ),
            const SizedBox(height: 36),

            // ── Logout ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('로그아웃'),
                      content: const Text('정말 로그아웃하시겠습니까?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('취소')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('로그아웃',
                                style: TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<AuthProvider>().logout();
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.dangerTint),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('로그아웃',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Account card ──────────────────────────────────────────────────────────

  Widget _accountCard(BuildContext context, dynamic user, String initial,
      bool isDark, Color primary) {
    final surface = isDark ? DarkColors.surface : AppColors.surface;
    final border  = isDark ? DarkColors.border  : AppColors.border;
    final textP   = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textS   = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final accentBg = user.isGuardian
        ? (isDark ? const Color(0xFF2A1F1A) : AppColors.accentTint)
        : (isDark ? DarkColors.primaryTint  : AppColors.primaryTint);
    final accentFg = user.isGuardian
        ? (isDark ? DarkColors.primary : AppColors.accent)
        : primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: accentBg,
            child: Text(initial,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: accentFg)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isNotEmpty ? user.displayName : user.username,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: textP),
                ),
                const SizedBox(height: 2),
                Text(user.isGuardian ? '보호자 계정' : '실사용자 계정',
                    style: TextStyle(fontSize: 13, color: textS)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: BorderSide(color: isDark ? DarkColors.border : AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child:
                const Text('수정', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Theme toggle ──────────────────────────────────────────────────────────

  Widget _themeToggle(BuildContext context, ThemeProvider themeP, bool isDark,
      Color primary, Color chipBg, Color textP, Color textS) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DarkColors.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? DarkColors.border : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: chipBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.brightness_6_outlined,
                    size: 18, color: isDark ? DarkColors.textSecondary : AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('테마', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: textP)),
                    Text('앱 전체 색상 모드', style: TextStyle(fontSize: 12, color: textS)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ThemeBtn(
                label: '☀️  라이트',
                selected: !isDark,
                primary: primary,
                chipBg: chipBg,
                textP: textP,
                onTap: () => themeP.setDark(false),
              ),
              const SizedBox(width: 8),
              _ThemeBtn(
                label: '🌙  다크',
                selected: isDark,
                primary: primary,
                chipBg: chipBg,
                textP: textP,
                onTap: () => themeP.setDark(true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Language picker ───────────────────────────────────────────────────────

  Widget _languagePicker(BuildContext context, SettingsProvider settingsP,
      bool isDark, Color textP, Color textS, Color chipBg, Color primary) {
    final surface = isDark ? DarkColors.surface : AppColors.surface;
    final border  = isDark ? DarkColors.border  : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border)),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.language_outlined,
                size: 18, color: isDark ? DarkColors.textSecondary : AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('언어', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: textP)),
                Text('앱 표시 언어 설정', style: TextStyle(fontSize: 12, color: textS)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showLanguageDialog(context, settingsP, isDark, primary),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: chipBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    SettingsProvider.languages.firstWhere(
                        (l) => l['code'] == settingsP.localeCode,
                        orElse: () => {'label': '한국어'})['label']!,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: primary),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, SettingsProvider settingsP,
      bool isDark, Color primary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DarkColors.surface : AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? DarkColors.border : AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('언어 선택',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: isDark ? DarkColors.textPrimary : AppColors.textPrimary)),
            const SizedBox(height: 12),
            ...SettingsProvider.languages.map((lang) {
              final selected = lang['code'] == settingsP.localeCode;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lang['label']!,
                    style: TextStyle(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                        color: selected ? primary
                            : (isDark ? DarkColors.textPrimary : AppColors.textPrimary))),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: primary)
                    : null,
                onTap: () {
                  settingsP.setLocale(lang['code']!);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Emergency contact ─────────────────────────────────────────────────────

  Widget _emergencyContactRow(BuildContext context, SettingsProvider settingsP,
      bool isDark, Color textP, Color textS, Color primary) {
    final surface = isDark ? DarkColors.surface : AppColors.surface;
    final border  = isDark ? DarkColors.border  : AppColors.border;
    final chipBg  = isDark ? DarkColors.chip    : AppColors.chip;
    final hasContact = settingsP.contactPhone.isNotEmpty;

    return GestureDetector(
      onTap: () => _showContactDialog(context, settingsP, isDark, primary),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border)),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: hasContact ? AppColors.dangerTint : chipBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.phone_outlined,
                  size: 18,
                  color: hasContact ? AppColors.danger
                      : (isDark ? DarkColors.textSecondary : AppColors.textSecondary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('긴급 연락처',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: textP)),
                  Text(
                    hasContact
                        ? '${settingsP.contactName.isNotEmpty ? settingsP.contactName : '이름 없음'} · ${settingsP.contactPhone}'
                        : '연락처를 등록하면 낙상 시 빠른 전화 가능',
                    style: TextStyle(fontSize: 12, color: textS),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18,
                color: isDark ? DarkColors.textTertiary : AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showContactDialog(BuildContext context, SettingsProvider settingsP,
      bool isDark, Color primary) {
    final nameCtrl  = TextEditingController(text: settingsP.contactName);
    final phoneCtrl = TextEditingController(text: settingsP.contactPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('긴급 연락처'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: lightInputDeco('이름 (예: 홍길동)', icon: Icons.person_outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: lightInputDeco('전화번호 (예: 010-1234-5678)', icon: Icons.phone_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0),
            onPressed: () {
              settingsP.setContact(nameCtrl.text.trim(), phoneCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // ── Camera type ───────────────────────────────────────────────────────────

  Widget _cameraTypeRow(BuildContext context, SettingsProvider settingsP,
      bool isDark, Color textP, Color textS, Color chipBg, Color primary) {
    final surface = isDark ? DarkColors.surface : AppColors.surface;
    final border  = isDark ? DarkColors.border  : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border)),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.videocam_outlined,
                size: 18, color: isDark ? DarkColors.textSecondary : AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('카메라 유형',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: textP)),
                Text('설치 위치에 맞게 설정하세요', style: TextStyle(fontSize: 12, color: textS)),
              ],
            ),
          ),
          _CameraTypeToggle(
            value: settingsP.cameraType,
            isDark: isDark,
            primary: primary,
            chipBg: chipBg,
            textP: textP,
            onChanged: (val) async {
              await settingsP.setCameraType(val);
              // sync to backend
              try {
                final api = context.read<AuthProvider>().api;
                await api.setCameraType(val);
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionTitle(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: color, letterSpacing: 0.5)),
      );
}

// ── Theme button ──────────────────────────────────────────────────────────────

class _ThemeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primary;
  final Color chipBg;
  final Color textP;
  final VoidCallback onTap;
  const _ThemeBtn({required this.label, required this.selected, required this.primary,
      required this.chipBg, required this.textP, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? primary.withOpacity(0.12) : chipBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected ? primary : Colors.transparent, width: 1.5),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                color: selected ? primary : textP,
              ),
            ),
          ),
        ),
      );
}

// ── Camera type toggle ────────────────────────────────────────────────────────

class _CameraTypeToggle extends StatelessWidget {
  final String value;
  final bool isDark;
  final Color primary;
  final Color chipBg;
  final Color textP;
  final ValueChanged<String> onChanged;
  const _CameraTypeToggle({required this.value, required this.isDark,
      required this.primary, required this.chipBg, required this.textP,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('front', '정면', Icons.camera_front_outlined),
          const SizedBox(width: 6),
          _tab('top', '천장', Icons.camera_outdoor_outlined),
        ],
      );

  Widget _tab(String code, String label, IconData icon) {
    final selected = value == code;
    return GestureDetector(
      onTap: () => onChanged(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? primary.withOpacity(0.12) : chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? primary : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? primary : textP),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                    color: selected ? primary : textP)),
          ],
        ),
      ),
    );
  }
}

// ── Settings row ──────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDark;

  const _SettingsRow({
    required this.icon, required this.title, required this.subtitle,
    required this.onTap, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? DarkColors.surface : AppColors.surface;
    final border  = isDark ? DarkColors.border  : AppColors.border;
    final chipBg  = isDark ? DarkColors.chip    : AppColors.chip;
    final textP   = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textS   = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final textT   = isDark ? DarkColors.textTertiary  : AppColors.textTertiary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border)),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration:
                  BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: textS),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: textP)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: textS)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: textT),
          ],
        ),
      ),
    );
  }
}
