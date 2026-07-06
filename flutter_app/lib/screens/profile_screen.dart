import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
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
      setState(() {
        _editing = false;
        _message = '프로필이 저장되었습니다';
      });
    } catch (e) {
      setState(() => _message = '저장 실패: $e');
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
          const SnackBar(content: Text('보호자 연결 완료'), backgroundColor: Colors.green),
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
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('내 프로필', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54),
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
              _editing ? (_saving ? '저장 중...' : '저장') : '편집',
              style: const TextStyle(color: Color(0xFF4FC3F7)),
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
              // Avatar
              CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFF4FC3F7).withOpacity(0.2),
                child: Text(
                  (user.displayName.isNotEmpty ? user.displayName : user.username)[0].toUpperCase(),
                  style: const TextStyle(fontSize: 36, color: Color(0xFF4FC3F7)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '@${user.username}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isGuardian
                      ? Colors.purple.withOpacity(0.2)
                      : const Color(0xFF4FC3F7).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.isGuardian ? '보호자' : '피보호자',
                  style: TextStyle(
                    color: user.isGuardian ? Colors.purpleAccent : const Color(0xFF4FC3F7),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (_message != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _message!.contains('실패') || _message!.contains('오류')
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _message!.contains('실패') ? Colors.redAccent : Colors.greenAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _card([
                _field('이름', _nameCtrl, Icons.badge),
                _field('전화번호', _phoneCtrl, Icons.phone),
                _field('주소', _addressCtrl, Icons.location_on),
                if (!user.isGuardian) _field('나이', _ageCtrl, Icons.cake, type: TextInputType.number),
                if (!user.isGuardian) ...[
                  const SizedBox(height: 8),
                  const Text('성별', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
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
              ], '기본 정보'),
              const SizedBox(height: 16),
              if (!user.isGuardian)
                _card([
                  const Text('보호자 연결', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  const Text(
                    '보호자 계정의 아이디를 입력하면 낙상 발생 시 자동으로 알림이 전송됩니다.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _guardianCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: '보호자 아이디',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _linkGuardian,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4FC3F7),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('연결', style: TextStyle(color: Colors.black87)),
                      ),
                    ],
                  ),
                ], '보호자 연결'),
              const SizedBox(height: 16),
              if (!user.isGuardian)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SafeZoneScreen()),
                    ),
                    icon: const Icon(Icons.crop_free, color: Color(0xFF4FC3F7)),
                    label: const Text('안전 구역 설정', style: TextStyle(color: Color(0xFF4FC3F7))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFF4FC3F7).withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => auth.logout(),
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text('로그아웃', style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent.withAlpha(102)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children, String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          enabled: _editing,
          keyboardType: type,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: Icon(icon, color: Colors.white24, size: 20),
            filled: true,
            fillColor: Colors.white.withOpacity(_editing ? 0.08 : 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  Widget _genderChip(String value, String label) => GestureDetector(
        onTap: _editing ? () => setState(() => _gender = value) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _gender == value
                ? const Color(0xFF4FC3F7).withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _gender == value ? const Color(0xFF4FC3F7) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: _gender == value ? const Color(0xFF4FC3F7) : Colors.white38,
              fontSize: 12,
            ),
          ),
        ),
      );
}
