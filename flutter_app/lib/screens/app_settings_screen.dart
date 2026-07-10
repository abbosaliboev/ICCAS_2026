import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../strings.dart';
import 'profile_screen.dart';
import 'safe_zone_screen.dart';
import 'add_care_recipient_screen.dart';
import '../widgets/app_toast.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s        = S.of(context);
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
            Text(s.settingsTitle,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: textP)),
            const SizedBox(height: 20),

            // ── Account card ────────────────────────────────────────────────
            _accountCard(context, s, user, initial, isDark, primary),
            const SizedBox(height: 28),

            // ── Appearance ──────────────────────────────────────────────────
            _sectionTitle(s.appearanceSection, textT),
            _appearanceCard(context, s, themeP, settingsP, isDark, primary, chipBg, textP, textS),
            const SizedBox(height: 28),

            // ── Contact & guardian tools ─────────────────────────────────────
            _sectionTitle(user.isGuardian
                ? (s.isKorean ? '보호자 관리' : 'Guardian Tools')
                : s.emergencyContactSection, textT),
            if (user.isGuardian)
              _guardianToolsCard(context, s, settingsP, isDark, textP, textS, primary, chipBg)
            else
              _emergencyContactRow(context, s, settingsP, isDark, textP, textS, primary),
            const SizedBox(height: 28),
            // ── Camera & Safety ─────────────────────────────────────────────
            if (!user.isGuardian) ...[
              const SizedBox(height: 28),
              _sectionTitle(s.cameraAndSafetySection, textT),
              _cameraTypeRow(context, s, settingsP, isDark, textP, textS, chipBg, primary),
              const SizedBox(height: 8),
              _SettingsRow(
                icon: Icons.crop_free_outlined,
                title: s.safeZoneLabel,
                subtitle: s.safeZoneSubtitle,
                isDark: isDark,
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SafeZoneScreen())),
              ),
              const SizedBox(height: 8),
              const _CameraDemoModeRow(),
            ],

            const SizedBox(height: 28),
            _sectionTitle(s.appInfoSection, textT),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: textS),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MobiCare', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textP)),
                        Text(s.appInfoSubtitle, style: TextStyle(fontSize: 13, color: textS)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            _sectionTitle('Demo Tool', textT),
            _demoToolsCard(settingsP, isDark, textP, textS, primary, chipBg),
            const SizedBox(height: 28),

            // ── Logout ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () async {
                  final sNow = S.read(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(sNow.logoutConfirmTitle),
                      content: Text(sNow.logoutConfirmBody),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(sNow.cancel)),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(sNow.logoutLabel,
                                style: const TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<AuthProvider>().logout();
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? DarkColors.danger : AppColors.danger,
                  backgroundColor:
                      isDark ? DarkColors.dangerTint : AppColors.dangerTint,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(s.logoutLabel,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Account card ──────────────────────────────────────────────────────────

  Widget _accountCard(BuildContext context, S s, dynamic user, String initial,
      bool isDark, Color primary) {
    final textP   = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textS   = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final accentBg = user.isGuardian
        ? (isDark ? DarkColors.accentTint : AppColors.accentTint)
        : (isDark ? DarkColors.primaryTint  : AppColors.primaryTint);
    final accentFg = user.isGuardian
        ? (isDark ? DarkColors.accent : AppColors.accent)
        : primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDeco(radius: 18, dark: isDark, bordered: false),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: accentBg,
            child: Text(initial,
                style: TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w800, color: accentFg)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isNotEmpty ? user.displayName : user.username,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: textP),
                ),
                const SizedBox(height: 2),
                Text(user.isGuardian ? s.guardianAccountLabel : s.userAccountLabel,
                    style: TextStyle(fontSize: 13, color: textS)),
              ],
            ),
          ),
          // tonal fill instead of an outlined border — quieter, same affordance
          TextButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            style: TextButton.styleFrom(
              foregroundColor: primary,
              backgroundColor:
                  isDark ? DarkColors.primaryTint : AppColors.primaryTint,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(s.edit,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }


  Widget _appearanceCard(BuildContext context, S s, ThemeProvider themeP,
      SettingsProvider settingsP, bool isDark, Color primary, Color chipBg,
      Color textP, Color textS) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDeco(radius: 16, dark: isDark, bordered: false),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.brightness_6_outlined, size: 19,
                    color: isDark ? DarkColors.textSecondary : AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.themeLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textP)),
                    Text(s.themeSubtitle, style: TextStyle(fontSize: 13, color: textS)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showThemeDialog(context, themeP, isDark, primary),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isDark ? (s.isKorean ? '다크' : 'Dark') : (s.isKorean ? '라이트' : 'Light'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? DarkColors.border : AppColors.border),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.language_outlined, size: 19,
                    color: isDark ? DarkColors.textSecondary : AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.languageLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textP)),
                    Text(s.languageSubtitle, style: TextStyle(fontSize: 13, color: textS)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showLanguageDialog(context, settingsP, isDark, primary),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        SettingsProvider.languages.firstWhere(
                          (l) => l['code'] == settingsP.localeCode,
                          orElse: () => {'label': 'Korean'},
                        )['label']!,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  void _showThemeDialog(BuildContext context, ThemeProvider themeP,
      bool isDark, Color primary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DarkColors.surface : AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final s = S.read(context);
        final textP = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? DarkColors.border : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(s.themeLabel,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textP)),
              const SizedBox(height: 12),
              _ThemeChoiceTile(
                label: s.isKorean ? '라이트' : 'Light',
                selected: !themeP.isDark,
                primary: primary,
                textColor: textP,
                onTap: () {
                  themeP.setDark(false);
                  Navigator.pop(ctx);
                  AppToast.show(context, S.read(context).lightModeSet, type: ToastType.success);
                },
              ),
              _ThemeChoiceTile(
                label: s.isKorean ? '다크' : 'Dark',
                selected: themeP.isDark,
                primary: primary,
                textColor: textP,
                onTap: () {
                  themeP.setDark(true);
                  Navigator.pop(ctx);
                  AppToast.show(context, S.read(context).darkModeSet, type: ToastType.success);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  void _showLanguageDialog(BuildContext context, SettingsProvider settingsP,
      bool isDark, Color primary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DarkColors.surface : AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final s = S.read(context);
        return Padding(
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
              Text(s.selectLanguage,
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
                    AppToast.show(
                      context,
                      S.read(context).languageSelected(lang['label']!),
                      type: ToastType.success,
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _guardianToolsCard(BuildContext context, S s, SettingsProvider settingsP,
      bool isDark, Color textP, Color textS, Color primary, Color chipBg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: cardDeco(radius: 16, dark: isDark, bordered: false),
      child: Column(
        children: [
          _SettingsInlineRow(
            icon: Icons.phone_outlined,
            title: s.emergencyContactSection,
            subtitle: settingsP.contactPhone.isNotEmpty
                ? '${settingsP.contactName.isNotEmpty ? settingsP.contactName : (settingsP.localeCode == 'ko' ? '이름 없음' : 'No name')} · ${settingsP.contactPhone}'
                : s.emergencyContactSubtitle,
            iconTint: settingsP.contactPhone.isNotEmpty
                ? (isDark ? DarkColors.danger : AppColors.danger)
                : textS,
            chipBg: settingsP.contactPhone.isNotEmpty
                ? (isDark ? DarkColors.dangerTint : AppColors.dangerTint)
                : chipBg,
            textP: textP,
            textS: textS,
            onTap: () => _showContactDialog(context, settingsP, isDark, primary),
          ),
          Divider(height: 1, color: isDark ? DarkColors.border : AppColors.border),
          _SettingsInlineRow(
            icon: Icons.crop_free_outlined,
            title: s.safeZoneLabel,
            subtitle: s.safeZoneSubtitle,
            iconTint: textS,
            chipBg: chipBg,
            textP: textP,
            textS: textS,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SafeZoneScreen()),
            ),
          ),
          Divider(height: 1, color: isDark ? DarkColors.border : AppColors.border),
          _SettingsInlineRow(
            icon: Icons.person_add_alt_1_outlined,
            title: s.isKorean ? 'Care Recipients 수정' : 'Edit care recipients',
            subtitle: s.isKorean ? '정보 보기, 수정, 추가' : 'View, edit, and add recipients',
            iconTint: textS,
            chipBg: chipBg,
            textP: textP,
            textS: textS,
            onTap: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const AddCareRecipientScreen()),
              );
              if (changed == true && context.mounted) {
                AppToast.show(context, s.isKorean ? 'Home에서 목록을 새로고침하세요' : 'Refresh Home to update recipients', type: ToastType.success);
              }
            },
          ),
        ],
      ),
    );
  }
  // ── Emergency contact ─────────────────────────────────────────────────────

  Widget _emergencyContactRow(BuildContext context, S s, SettingsProvider settingsP,
      bool isDark, Color textP, Color textS, Color primary) {
    final chipBg  = isDark ? DarkColors.chip    : AppColors.chip;
    final hasContact = settingsP.contactPhone.isNotEmpty;

    return GestureDetector(
      onTap: () => _showContactDialog(context, settingsP, isDark, primary),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: cardDeco(radius: 16, dark: isDark, bordered: false),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: hasContact
                      ? (isDark ? DarkColors.dangerTint : AppColors.dangerTint)
                      : chipBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.phone_outlined,
                  size: 19,
                  color: hasContact
                      ? (isDark ? DarkColors.danger : AppColors.danger)
                      : (isDark ? DarkColors.textSecondary : AppColors.textSecondary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.emergencyContactSection,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: textP)),
                  Text(
                    hasContact
                        ? '${settingsP.contactName.isNotEmpty ? settingsP.contactName : (settingsP.localeCode == 'ko' ? '이름 없음' : 'No name')} · ${settingsP.contactPhone}'
                        : s.emergencyContactSubtitle,
                    style: TextStyle(fontSize: 13, color: textS),
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
    final s = S.read(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.emergencyContactSection),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: lightInputDeco(s.nameHint, icon: Icons.person_outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: lightInputDeco(s.phoneHint, icon: Icons.phone_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              settingsP.setContact(name, phone);
              Navigator.pop(ctx);
              final label = name.isNotEmpty ? name : phone;
              AppToast.show(
                context,
                label.isNotEmpty ? s.emergencyContactSet(label) : s.emergencyContactCleared,
                type: ToastType.success,
              );
            },
            child: Text(s.save),
          ),
        ],
      ),
    );
  }

  // ── Camera type ───────────────────────────────────────────────────────────

  Widget _demoToolsCard(SettingsProvider settingsP, bool isDark, Color textP,
      Color textS, Color primary, Color chipBg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: cardDeco(radius: 16, dark: isDark, bordered: false),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.record_voice_over_outlined,
              size: 19,
              color: isDark ? DarkColors.textSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guardian TTS / STT Demo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textP,
                  ),
                ),
                Text(
                  'Run the voice response overlay on guardian fall alerts.',
                  style: TextStyle(fontSize: 13, color: textS),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: settingsP.demoTtsSttEnabled,
            activeColor: primary,
            onChanged: settingsP.setDemoTtsSttEnabled,
          ),
        ],
      ),
    );
  }

  Widget _cameraTypeRow(BuildContext context, S s, SettingsProvider settingsP,
      bool isDark, Color textP, Color textS, Color chipBg, Color primary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDeco(radius: 16, dark: isDark, bordered: false),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.videocam_outlined,
                size: 19, color: isDark ? DarkColors.textSecondary : AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.cameraTypeLabel,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: textP)),
                Text(s.cameraTypeSubtitle, style: TextStyle(fontSize: 13, color: textS)),
              ],
            ),
          ),
          _CameraTypeToggle(
            value: settingsP.cameraType,
            isDark: isDark,
            primary: primary,
            chipBg: chipBg,
            textP: textP,
            frontLabel: s.frontCameraBtn,
            ceilingLabel: s.ceilingCameraBtn,
            onChanged: (val) async {
              await settingsP.setCameraType(val);
              try {
                final api = context.read<AuthProvider>().api;
                await api.setCameraType(val);
              } catch (_) {}
              final sNow = S.read(context);
              final label = val == 'front' ? sNow.frontCameraLabel : sNow.ceilingCameraLabel;
              if (context.mounted) {
                AppToast.show(context, sNow.cameraTypeSet(label), type: ToastType.success);
              }
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

class _ThemeChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primary;
  final Color textColor;
  final VoidCallback onTap;

  const _ThemeChoiceTile({
    required this.label,
    required this.selected,
    required this.primary,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? primary : textColor,
          ),
        ),
        trailing: selected ? Icon(Icons.check_rounded, color: primary) : null,
        onTap: onTap,
      );
}

// ── Camera type toggle ────────────────────────────────────────────────────────

class _CameraTypeToggle extends StatelessWidget {
  final String value;
  final bool isDark;
  final Color primary;
  final Color chipBg;
  final Color textP;
  final String frontLabel;
  final String ceilingLabel;
  final ValueChanged<String> onChanged;
  const _CameraTypeToggle({required this.value, required this.isDark,
      required this.primary, required this.chipBg, required this.textP,
      required this.frontLabel, required this.ceilingLabel,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('front', frontLabel),
          const SizedBox(width: 6),
          _tab('top', ceilingLabel),
        ],
      );

  Widget _tab(String code, String label) {
    final selected = value == code;
    return GestureDetector(
      onTap: () => onChanged(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          // tonal fill carries the selected state — no border needed
          color: selected ? primary.withOpacity(0.16) : chipBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                color: selected ? primary : textP)),
      ),
    );
  }
}

class _SettingsInlineRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconTint;
  final Color chipBg;
  final Color textP;
  final Color textS;
  final VoidCallback onTap;

  const _SettingsInlineRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconTint,
    required this.chipBg,
    required this.textP,
    required this.textS,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 19, color: iconTint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textP)),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: textS)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: textS),
            ],
          ),
        ),
      );
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
    final chipBg  = isDark ? DarkColors.chip    : AppColors.chip;
    final textP   = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textS   = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final textT   = isDark ? DarkColors.textTertiary  : AppColors.textTertiary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: cardDeco(radius: 16, dark: isDark, bordered: false),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration:
                  BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 19, color: textS),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: textP)),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: textS)),
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

// ── Camera demo mode ─────────────────────────────────────────────────────────
// Swaps the physical edge device's live feed for a looping demo clip so the
// real AI pipeline (YOLO + ST-GCN) can be shown reacting to a fall without
// staging one. Distinct from the "Demo Tool" TTS/STT card below — this one
// controls the actual camera hardware, so its state is always re-fetched from
// the server rather than trusted from a local cache.

class _CameraDemoModeRow extends StatefulWidget {
  const _CameraDemoModeRow();
  @override
  State<_CameraDemoModeRow> createState() => _CameraDemoModeRowState();
}

class _CameraDemoModeRowState extends State<_CameraDemoModeRow> {
  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final enabled = await context.read<AuthProvider>().api.getCameraDemoMode();
      if (mounted) setState(() { _enabled = enabled; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    final s = S.read(context);
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().api.setCameraDemoMode(value);
      if (!mounted) return;
      context.read<SettingsProvider>().setCameraDemoModeLocal(value);
      setState(() => _enabled = value);
      AppToast.show(context, value ? s.cameraDemoModeOnMsg : s.cameraDemoModeOffMsg,
          type: value ? ToastType.warning : ToastType.success);
    } catch (e) {
      if (mounted) AppToast.show(context, s.saveFailed(e), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s       = S.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final chipBg  = isDark ? DarkColors.chip    : AppColors.chip;
    final textP   = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textS   = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final warning = isDark ? DarkColors.warning : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: cardDeco(radius: 16, dark: isDark, bordered: false),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.smart_display_outlined, size: 19,
                color: _enabled ? warning : textS),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.cameraDemoModeLabel,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textP)),
                Text(s.cameraDemoModeSubtitle, style: TextStyle(fontSize: 13, color: textS)),
              ],
            ),
          ),
          if (_loading || _busy)
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
            )
          else
            Switch.adaptive(
              value: _enabled,
              onChanged: _toggle,
              activeColor: warning,
            ),
        ],
      ),
    );
  }
}








