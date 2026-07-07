import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../strings.dart';
import 'settings_screen.dart';
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
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _nameCtrl = TextEditingController(text: user.displayName);
    _phoneCtrl = TextEditingController(text: user.phone);
    _addressCtrl = TextEditingController(text: user.address);
    _ageCtrl = TextEditingController(text: user.age?.toString() ?? '');
    _guardianCtrl = TextEditingController();
    _gender = user.gender;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _addressCtrl,
      _ageCtrl,
      _guardianCtrl,
    ]) {
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
      setState(() {
        _editing = false;
        _message = S.read(context).profileSaved;
        _messageIsError = false;
      });
    } catch (e) {
      setState(() {
        _message = S.read(context).saveFailedShort(e);
        _messageIsError = true;
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.read(context).linkSuccess),
            backgroundColor: Colors.green,
          ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final auth = context.watch<AuthProvider>();
    final s = S.of(context);
    final user = auth.user!;

    final bg = isDark ? DarkColors.bg : AppColors.bg;
    final surface = isDark ? DarkColors.surface : Colors.white;
    final border = isDark ? DarkColors.border : AppColors.border;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final textPri = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final textSec = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
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
          IconButton(
            icon: Icon(Icons.settings, color: textSec),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: user.isGuardian
                      ? Colors.purple.withOpacity(0.12)
                      : primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.isGuardian ? s.guardianRole : s.careRecipientRole,
                  style: TextStyle(
                    color: user.isGuardian ? Colors.purple : primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              if (_message != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _messageIsError
                        ? Colors.red.withOpacity(0.08)
                        : Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _messageIsError
                          ? Colors.red.withOpacity(0.3)
                          : Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _messageIsError ? Colors.red : Colors.green,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Basic info card ───────────────────────────────────────────
              _card(isDark, surface, border, textSec, s.basicInfoSection, [
                _field(
                  isDark,
                  textPri,
                  textSec,
                  inputFill,
                  primary,
                  s.nameLabelShort,
                  _nameCtrl,
                  Icons.badge_outlined,
                ),
                _field(
                  isDark,
                  textPri,
                  textSec,
                  inputFill,
                  primary,
                  s.phoneLabelP,
                  _phoneCtrl,
                  Icons.phone_outlined,
                ),
                _field(
                  isDark,
                  textPri,
                  textSec,
                  inputFill,
                  primary,
                  s.addressLabelP,
                  _addressCtrl,
                  Icons.location_on_outlined,
                ),
                if (!user.isGuardian) ...[
                  _field(
                    isDark,
                    textPri,
                    textSec,
                    inputFill,
                    primary,
                    s.ageLabelP,
                    _ageCtrl,
                    Icons.cake_outlined,
                    type: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.genderLabel,
                    style: TextStyle(color: textSec, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _genderChip(isDark, primary, 'M', s.male),
                      const SizedBox(width: 8),
                      _genderChip(isDark, primary, 'F', s.female),
                      const SizedBox(width: 8),
                      _genderChip(isDark, primary, '', s.genderUnspecified),
                    ],
                  ),
                ],
              ]),
              const SizedBox(height: 16),

              // ── Guardian link card ────────────────────────────────────────
              if (!user.isGuardian)
                _card(
                  isDark,
                  surface,
                  border,
                  textSec,
                  s.guardianConnectLabel,
                  [
                    Text(
                      s.guardianConnectLabel,
                      style: TextStyle(
                        color: textPri,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.guardianConnectHelp,
                      style: TextStyle(
                        color: textSec,
                        fontSize: 12,
                        height: 1.5,
                      ),
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
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(s.connectBtn),
                        ),
                      ],
                    ),
                  ],
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
                    label: Text(
                      s.safeZoneLabel,
                      style: TextStyle(color: primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primary.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // ── Logout button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => auth.logout(),
                  icon: const Icon(
                    Icons.logout,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  label: Text(
                    s.logoutLabel,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

  Widget _card(
    bool isDark,
    Color surface,
    Color border,
    Color textSec,
    String title,
    List<Widget> children,
  ) => Container(
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
          title,
          style: TextStyle(
            color: textSec,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  Widget _field(
    bool isDark,
    Color textPri,
    Color textSec,
    Color fill,
    Color primary,
    String label,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctrl,
      enabled: _editing,
      keyboardType: type,
      style: TextStyle(color: textPri),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSec, fontSize: 13),
        prefixIcon: Icon(icon, color: textSec, size: 20),
        filled: true,
        fillColor: _editing ? fill : fill.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
    ),
  );

  Widget _genderChip(bool isDark, Color primary, String value, String label) =>
      GestureDetector(
        onTap: _editing ? () => setState(() => _gender = value) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _gender == value
                ? primary.withOpacity(0.12)
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _gender == value ? primary : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: _gender == value
                  ? primary
                  : (isDark ? Colors.white38 : Colors.black38),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
}
