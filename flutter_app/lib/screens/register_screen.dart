import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../app_theme.dart';
import '../strings.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  static const String _role = 'guardian';
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [
      _userCtrl,
      _passCtrl,
      _nameCtrl,
      _phoneCtrl,
      _addressCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    try {
      await context.read<AuthProvider>().register(
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        role: _role,
        displayName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(s.registerTitle), leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.registerGuardianTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.registerGuardianSubtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                _sectionLabel(s.accountInfoSection),
                _field(
                  s,
                  _userCtrl,
                  s.usernameHint,
                  Icons.person_outline,
                  required: true,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration:
                      lightInputDeco(
                        s.passwordHint,
                        icon: Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textTertiary,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                  validator: (v) => v!.length < 4 ? s.passwordMinLength : null,
                ),

                const SizedBox(height: 20),
                _sectionLabel(s.profileInfoSection),
                _field(s, _nameCtrl, s.nameLabelShort, Icons.badge_outlined),
                const SizedBox(height: 12),
                _field(
                  s,
                  _phoneCtrl,
                  s.phoneWithFormatLabel,
                  Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _field(
                  s,
                  _addressCtrl,
                  s.addressOptionalLabel,
                  Icons.location_on_outlined,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerTint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.danger.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: auth.loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withOpacity(
                        0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: auth.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            s.completeRegister,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _field(
    S s,
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType? keyboardType,
  }) => TextFormField(
    controller: ctrl,
    style: const TextStyle(color: AppColors.textPrimary),
    keyboardType: keyboardType,
    decoration: lightInputDeco(label, icon: icon),
    validator: required
        ? (v) => v!.isEmpty ? s.requiredField(label) : null
        : null,
  );
}
