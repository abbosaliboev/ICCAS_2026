import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../strings.dart';
import '../widgets/app_toast.dart';
import 'safe_zone_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _guardianCtrl;
  String _gender = '';
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _nameCtrl    = TextEditingController(text: user.displayName);
    _phoneCtrl   = TextEditingController(text: user.phone);
    _addressCtrl = TextEditingController(text: user.address);
    _ageCtrl     = TextEditingController(text: user.age?.toString() ?? '');
    _guardianCtrl = TextEditingController();
    _gender = user.gender;
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _addressCtrl, _ageCtrl, _guardianCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().api.updateProfile(
        displayName: _nameCtrl.text.trim(),
        age: int.tryParse(_ageCtrl.text),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        gender: _gender,
      );
      await context.read<AuthProvider>().refreshUser();
      setState(() { _editing = false; });
      if (mounted) {
        AppToast.show(context, S.read(context).profileSaved, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, S.read(context).saveFailedShort(e), type: ToastType.error);
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _linkGuardian() async {
    final name = _guardianCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await context.read<AuthProvider>().api.linkGuardian(name);
      await context.read<AuthProvider>().refreshUser();
      _guardianCtrl.clear();
      if (mounted) {
        AppToast.show(context, S.read(context).linkSuccess, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, e.toString(), type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = context.watch<ThemeProvider>().isDark;
    final auth     = context.watch<AuthProvider>();
    final s        = S.of(context);
    final user     = auth.user!;

    final bg       = isDark ? DarkColors.bg      : AppColors.bg;
    final surface  = isDark ? DarkColors.surface  : Colors.white;
    final border   = isDark ? DarkColors.border   : AppColors.border;
    final primary  = isDark ? DarkColors.primary  : AppColors.primary;
    final textPri  = isDark ? DarkColors.textPrimary   : AppColors.textPrimary;
    final textSec  = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final inputFill = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.03);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: textPri,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          s.profileTitle,
          style: TextStyle(color: textPri, fontWeight: FontWeight.w700),
        ),
        iconTheme: IconThemeData(color: textPri),
        actions: [
          TextButton(
            onPressed: () async {
              if (_editing) {
                await _save();
              } else {
                setState(() => _editing = true);
              }
            },
            child: Text(
              _editing ? (_saving ? s.saving : s.save) : s.edit,
              style: TextStyle(color: primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Avatar ────────────────────────────────────────────────────
              CircleAvatar(
                radius: 44,
                backgroundColor: primary.withOpacity(0.12),
                child: Text(
                  (user.displayName.isNotEmpty
                          ? user.displayName
                          : user.username)[0]
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 36,
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '@${user.username}',
                style: TextStyle(color: textSec, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isGuardian
                      ? (isDark ? DarkColors.accentTint : AppColors.accentTint)
                      : primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.isGuardian ? s.guardianRole : s.careRecipientRole,
                  style: TextStyle(
                    color: user.isGuardian
                        ? (isDark ? DarkColors.accent : AppColors.accent)
                        : primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Basic info card ───────────────────────────────────────────
              _BasicInfoCard(
                isDark: isDark,
                surface: surface,
                border: border,
                textPri: textPri,
                textSec: textSec,
                primary: primary,
                inputFill: inputFill,
                editing: _editing,
                user: user,
                nameCtrl: _nameCtrl,
                phoneCtrl: _phoneCtrl,
                addressCtrl: _addressCtrl,
                ageCtrl: _ageCtrl,
                gender: _gender,
                onGenderChanged: (v) => setState(() => _gender = v),
                s: s,
              ),
              const SizedBox(height: 16),

              // ── Guardian link card ────────────────────────────────────────
              if (!user.isGuardian)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.guardianConnectLabel,
                        style: TextStyle(
                          color: textSec,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.guardianConnectLabel,
                        style: TextStyle(color: textPri, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.guardianConnectHelp,
                        style: TextStyle(color: textSec, fontSize: 12, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _guardianCtrl,
                              style: TextStyle(color: textPri),
                              decoration: InputDecoration(
                                hintText: s.guardianUsernameHint,
                                hintStyle: TextStyle(color: textSec),
                                filled: true,
                                fillColor: inputFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _linkGuardian,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(s.connectBtn),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // ── Safe zone button ──────────────────────────────────────────
              if (!user.isGuardian)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SafeZoneScreen()),
                    ),
                    icon: Icon(Icons.crop_free, color: primary, size: 18),
                    label: Text(s.safeZoneLabel,
                        style: TextStyle(color: primary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primary.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // ── Logout button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => auth.logout(),
                  icon: Icon(Icons.logout, color: isDark ? DarkColors.danger : AppColors.danger, size: 18),
                  label: Text(s.logoutLabel,
                      style: TextStyle(color: isDark ? DarkColors.danger : AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: (isDark ? DarkColors.danger : AppColors.danger).withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Basic Information card ────────────────────────────────────────────────────

class _BasicInfoCard extends StatelessWidget {
  final bool isDark;
  final Color surface;
  final Color border;
  final Color textPri;
  final Color textSec;
  final Color primary;
  final Color inputFill;
  final bool editing;
  final dynamic user;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController ageCtrl;
  final String gender;
  final ValueChanged<String> onGenderChanged;
  final S s;

  const _BasicInfoCard({
    required this.isDark,
    required this.surface,
    required this.border,
    required this.textPri,
    required this.textSec,
    required this.primary,
    required this.inputFill,
    required this.editing,
    required this.user,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.ageCtrl,
    required this.gender,
    required this.onGenderChanged,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_outline, color: primary, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  s.basicInfoSection,
                  style: TextStyle(
                    color: textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: border, height: 1),

          // Fields
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(s.nameLabelShort, nameCtrl, Icons.badge_outlined),
                _divider(),
                _field(s.phoneLabelP, phoneCtrl, Icons.phone_outlined),
                _divider(),
                _field(s.addressLabelP, addressCtrl, Icons.location_on_outlined),
                if (!user.isGuardian) ...[
                  _divider(),
                  _field(s.ageLabelP, ageCtrl, Icons.cake_outlined,
                      type: TextInputType.number),
                  _divider(),
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 4),
                    child: Text(s.genderLabel,
                        style: TextStyle(
                            color: textSec, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _genderChip('M', s.male),
                      const SizedBox(width: 8),
                      _genderChip('F', s.female),
                      const SizedBox(width: 8),
                      _genderChip('', s.genderUnspecified),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        color: border.withOpacity(0.6),
        height: 1,
        indent: 44,
      );

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType? type,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TextField(
          controller: ctrl,
          enabled: editing,
          keyboardType: type,
          style: TextStyle(color: textPri, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: textSec, fontSize: 13),
            prefixIcon: Icon(icon, color: textSec, size: 20),
            filled: true,
            fillColor: editing ? inputFill : Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          ),
        ),
      );

  Widget _genderChip(String value, String label) => GestureDetector(
        onTap: editing ? () => onGenderChanged(value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: gender == value
                ? primary.withOpacity(0.12)
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: gender == value ? primary : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: gender == value
                  ? primary
                  : (isDark ? Colors.white38 : Colors.black38),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
}
