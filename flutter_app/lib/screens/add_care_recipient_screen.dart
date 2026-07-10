import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../strings.dart';
import '../widgets/app_toast.dart';

class AddCareRecipientScreen extends StatefulWidget {
  const AddCareRecipientScreen({super.key});

  @override
  State<AddCareRecipientScreen> createState() => _AddCareRecipientScreenState();
}

class _AddCareRecipientScreenState extends State<AddCareRecipientScreen> {
  List<User> _recipients = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await context.read<AuthProvider>().api.getMonitoredUsers();
      if (mounted) {
        setState(() {
          _recipients = users;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.show(context, e.toString(), type: ToastType.error);
      }
    }
  }

  Future<void> _openEditor({User? user}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? DarkColors.surface
          : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _CareRecipientEditor(user: user),
    );
    if (changed == true) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DarkColors.bg : AppColors.bg;
    final text = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final sub = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          foregroundColor: text,
          title: Text(s.isKorean ? 'Care Recipients 수정' : 'Edit care recipients'),
          actions: [
            IconButton(
              tooltip: s.isKorean ? '추가' : 'Add',
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () => _openEditor(),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: primary,
            onRefresh: _load,
            child: _loading
                ? Center(child: CircularProgressIndicator(color: primary, strokeWidth: 2))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      Text(
                        s.isKorean
                            ? '현재 연결된 실사용자 정보를 확인하고 수정하거나 새 실사용자를 추가할 수 있습니다.'
                            : 'View, edit, or add connected care recipients.',
                        style: TextStyle(color: sub, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      if (_recipients.isEmpty)
                        _EmptyRecipients(isDark: isDark)
                      else
                        ..._recipients.map((user) => _RecipientCard(
                              user: user,
                              isDark: isDark,
                              onEdit: () => _openEditor(user: user),
                            )),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => _openEditor(),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(s.isKorean ? '실사용자 추가' : 'Add recipient'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  final User user;
  final bool isDark;
  final VoidCallback onEdit;
  const _RecipientCard({required this.user, required this.isDark, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final sub = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final name = user.displayName.isNotEmpty ? user.displayName : user.username;
    final info = [
      if (user.age != null) s.isKorean ? '${user.age}세' : '${user.age}',
      if (user.gender.isNotEmpty) user.gender == 'M' ? s.male : user.gender == 'F' ? s.female : user.gender,
      if (user.phone.isNotEmpty) user.phone,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(radius: 14, dark: isDark, bordered: false),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isDark ? DarkColors.primaryTint : AppColors.primaryTint,
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? DarkColors.primary : AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
                const SizedBox(height: 2),
                Text(info.isEmpty ? user.id : info, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: sub)),
                if (user.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(user.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: sub)),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: s.edit,
            icon: const Icon(Icons.edit_outlined),
            color: sub,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _EmptyRecipients extends StatelessWidget {
  final bool isDark;
  const _EmptyRecipients({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sub = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: cardDeco(radius: 14, dark: isDark, bordered: false),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 34, color: sub),
          const SizedBox(height: 8),
          Text(s.noLinkedRecipients, textAlign: TextAlign.center,
              style: TextStyle(color: sub, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CareRecipientEditor extends StatefulWidget {
  final User? user;
  const _CareRecipientEditor({this.user});

  @override
  State<_CareRecipientEditor> createState() => _CareRecipientEditorState();
}

class _CareRecipientEditorState extends State<_CareRecipientEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _rtspCtrl;
  late String _gender;
  bool _saving = false;

  bool get _editing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u?.displayName ?? '');
    _addressCtrl = TextEditingController(text: u?.address ?? '');
    _phoneCtrl = TextEditingController(text: u?.phone ?? '');
    _ageCtrl = TextEditingController(text: u?.age?.toString() ?? '');
    _rtspCtrl = TextEditingController();
    _gender = u?.gender ?? '';
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _addressCtrl, _phoneCtrl, _ageCtrl, _rtspCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final s = S.read(context);
    setState(() => _saving = true);
    try {
      final api = context.read<AuthProvider>().api;
      if (_editing) {
        await api.updateMonitoredUser(
          userId: widget.user!.id,
          name: _nameCtrl.text.trim().isEmpty ? 'Demo User' : _nameCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          age: int.tryParse(_ageCtrl.text.trim()),
          gender: _gender,
          rtspUrl: _rtspCtrl.text.trim(),
        );
        if (!mounted) return;
        AppToast.show(context, s.isKorean ? '실사용자 정보가 수정되었습니다' : 'Care recipient updated', type: ToastType.success);
      } else {

        await api.createMonitoredUser(
          name: _nameCtrl.text.trim().isEmpty ? 'Demo User' : _nameCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          age: int.tryParse(_ageCtrl.text.trim()),
          gender: _gender,
          rtspUrl: _rtspCtrl.text.trim().isEmpty ? 'test1' : _rtspCtrl.text.trim(),
        );
        if (!mounted) return;
        AppToast.show(context, s.isKorean ? '실사용자가 추가되었습니다' : 'Care recipient added', type: ToastType.success);
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppToast.show(context, e.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRecipient() async {
    if (!_editing || _saving) return;
    final s = S.read(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? DarkColors.surface : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.isKorean ? '실사용자 삭제' : 'Delete recipient'),
        content: Text(s.isKorean
            ? '이 실사용자를 Care Recipients 목록에서 삭제할까요?'
            : 'Remove this recipient from your Care Recipients list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().api.deleteMonitoredUser(widget.user!.id);
      if (!mounted) return;
      AppToast.show(context, s.isKorean ? '실사용자가 삭제되었습니다' : 'Care recipient deleted', type: ToastType.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppToast.show(context, e.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final sub = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_editing
                    ? (s.isKorean ? '실사용자 정보 수정' : 'Edit recipient')
                    : (s.isKorean ? '실사용자 추가' : 'Add recipient'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: text)),
            const SizedBox(height: 6),
            Text(_editing
                    ? (s.isKorean ? 'RTSP는 비워두면 기존 값을 유지합니다.' : 'Leave RTSP blank to keep the current stream.')
                    : (s.isKorean ? '데모 실사용자를 추가할 수 있습니다.' : 'Create a demo care recipient.'),
                style: TextStyle(fontSize: 12, color: sub)),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: lightInputDeco(s.nameLabel, icon: Icons.person_outline)),
            const SizedBox(height: 12),
            TextField(controller: _addressCtrl, decoration: lightInputDeco(s.addressLabel, icon: Icons.home_outlined)),
            const SizedBox(height: 12),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: lightInputDeco(s.contactField, icon: Icons.phone_outlined)),
            const SizedBox(height: 12),
            TextField(controller: _ageCtrl, keyboardType: TextInputType.number, decoration: lightInputDeco(s.ageLabel, icon: Icons.cake_outlined)),
            const SizedBox(height: 12),
            _GenderSelector(
              value: _gender,
              onChanged: (v) => setState(() => _gender = v),
              isDark: isDark,
              primary: primary,
              label: s.genderLabel,
              options: [
                _GenderOption('', s.genderUnspecified, Icons.remove_circle_outline),
                _GenderOption('M', s.male, Icons.male_rounded),
                _GenderOption('F', s.female, Icons.female_rounded),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _rtspCtrl, decoration: lightInputDeco('RTSP', icon: Icons.videocam_outlined)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_editing ? s.save : (s.isKorean ? '추가 완료' : 'Add recipient'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            if (_editing) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton.icon(
                  onPressed: _saving ? null : _deleteRecipient,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(s.isKorean ? '실사용자 삭제' : 'Delete recipient'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? DarkColors.danger : AppColors.danger,
                    backgroundColor: isDark ? DarkColors.dangerTint : AppColors.dangerTint,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GenderOption {
  final String value;
  final String label;
  final IconData icon;
  const _GenderOption(this.value, this.label, this.icon);
}

class _GenderSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final Color primary;
  final String label;
  final List<_GenderOption> options;
  const _GenderSelector({
    required this.value,
    required this.onChanged,
    required this.isDark,
    required this.primary,
    required this.label,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final text = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final sub = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final chip = isDark ? DarkColors.chip : AppColors.chip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: sub)),
        ),
        Row(
          children: options.map((option) {
            final selected = value == option.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: option == options.last ? 0 : 8),
                child: GestureDetector(
                  onTap: () => onChanged(option.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected ? primary.withOpacity(0.14) : chip,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? primary : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(option.icon, size: 17, color: selected ? primary : sub),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                              color: selected ? primary : text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

