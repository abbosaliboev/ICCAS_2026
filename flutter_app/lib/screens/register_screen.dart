import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../app_theme.dart';

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
  final _ageCtrl = TextEditingController();

  String _role = 'user';
  String _gender = '';
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [_userCtrl, _passCtrl, _nameCtrl, _phoneCtrl, _addressCtrl, _ageCtrl]) {
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
            age: int.tryParse(_ageCtrl.text),
            phone: _phoneCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
            gender: _gender,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('회원가입'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  '어떤 분으로 가입하시나요?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '역할에 따라 화면과 기능이 달라져요.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 20),

                // Role cards
                _RoleCard(
                  value: 'user',
                  selected: _role,
                  icon: Icons.shield_rounded,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primaryTint,
                  title: '실사용자',
                  subtitle: '낙상 위험이 있는 어르신 본인이에요.',
                  features: '내 상태 확인 · 긴급 연락 · 카메라/안전구역 설정',
                  onTap: () => setState(() => _role = 'user'),
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  value: 'guardian',
                  selected: _role,
                  icon: Icons.favorite_rounded,
                  iconColor: AppColors.accent,
                  iconBg: AppColors.accentTint,
                  title: '보호자',
                  subtitle: '가족/간병인/요양시설 담당자예요.',
                  features: '피보호자 목록 · 알림 수신 · 리포트 확인',
                  onTap: () => setState(() => _role = 'guardian'),
                ),

                const SizedBox(height: 28),
                _sectionLabel('계정 정보'),
                _field(_userCtrl, '아이디', Icons.person_outline, required: true),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: lightInputDeco('비밀번호', icon: Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => v!.length < 4 ? '4자 이상 입력하세요' : null,
                ),

                const SizedBox(height: 20),
                _sectionLabel('프로필 정보'),
                _field(_nameCtrl, '이름', Icons.badge_outlined),
                const SizedBox(height: 12),
                _field(_phoneCtrl, '전화번호 (010-XXXX-XXXX)', Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field(_addressCtrl, '주소 (선택)', Icons.location_on_outlined),

                if (_role == 'user') ...[
                  const SizedBox(height: 12),
                  _field(_ageCtrl, '나이', Icons.cake_outlined,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  _sectionLabel('성별'),
                  Row(
                    children: [
                      _genderChip('M', '남성'),
                      const SizedBox(width: 8),
                      _genderChip('F', '여성'),
                      const SizedBox(width: 8),
                      _genderChip('', '미선택'),
                    ],
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerTint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
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
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: auth.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('가입 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  Widget _genderChip(String value, String label) => GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _gender == value ? AppColors.primaryTint : AppColors.chip,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: _gender == value ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: _gender == value ? AppColors.primary : AppColors.textSecondary,
              fontWeight: _gender == value ? FontWeight.w700 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType? keyboardType,
  }) =>
      TextFormField(
        controller: ctrl,
        style: const TextStyle(color: AppColors.textPrimary),
        keyboardType: keyboardType,
        decoration: lightInputDeco(label, icon: icon),
        validator: required ? (v) => v!.isEmpty ? '$label을 입력하세요' : null : null,
      );
}

// ── Role selection card ───────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String value;
  final String selected;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String features;
  final VoidCallback onTap;

  const _RoleCard({
    required this.value,
    required this.selected,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? (value == 'user' ? AppColors.primaryTint : AppColors.accentTint)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? iconColor : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? iconColor : iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? iconColor : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '✓ $features',
                    style: TextStyle(
                      color: isSelected ? iconColor : AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: iconColor, size: 22),
          ],
        ),
      ),
    );
  }
}
