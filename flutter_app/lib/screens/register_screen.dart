import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('회원가입', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('역할 선택'),
                Row(
                  children: [
                    _roleChip('user', '피보호자 (노인)'),
                    const SizedBox(width: 8),
                    _roleChip('guardian', '보호자 (가족)'),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionLabel('계정 정보'),
                _field(_userCtrl, '아이디', Icons.person, required: true),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('비밀번호', Icons.lock).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white54),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => v!.length < 4 ? '4자 이상 입력하세요' : null,
                ),
                const SizedBox(height: 20),
                _sectionLabel('프로필 정보'),
                _field(_nameCtrl, '이름', Icons.badge),
                const SizedBox(height: 12),
                _field(_phoneCtrl, '전화번호 (010-XXXX-XXXX)', Icons.phone,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field(_addressCtrl, '주소', Icons.location_on),
                if (_role == 'user') ...[
                  const SizedBox(height: 12),
                  _field(_ageCtrl, '나이', Icons.cake,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: auth.loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4FC3F7),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: auth.loading
                        ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.black54)
                        : const Text('회원가입', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      );

  Widget _roleChip(String value, String label) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _role = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _role == value
                  ? const Color(0xFF4FC3F7)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _role == value ? Colors.black87 : Colors.white70,
                fontWeight: _role == value ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );

  Widget _genderChip(String value, String label) => GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: _gender == value
                ? const Color(0xFF4FC3F7)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: _gender == value ? Colors.black87 : Colors.white70,
              fontWeight: _gender == value ? FontWeight.bold : FontWeight.normal,
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
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        decoration: _inputDeco(label, icon),
        validator: required ? (v) => v!.isEmpty ? '$label을 입력하세요' : null : null,
      );

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4FC3F7)),
        ),
      );
}
