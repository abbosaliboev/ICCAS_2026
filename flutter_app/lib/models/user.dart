class User {
  final String id;
  final String username;
  final String role;
  final String displayName;
  final int? age;
  final int? height;
  final int? weight;
  final String gender;
  final String phone;
  final String address;
  final String? guardianId;

  const User({
    required this.id,
    required this.username,
    required this.role,
    required this.displayName,
    this.age,
    this.height,
    this.weight,
    required this.gender,
    required this.phone,
    required this.address,
    this.guardianId,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] ?? '',
        username: j['username'] ?? '',
        role: j['role'] ?? 'user',
        displayName: j['display_name'] ?? '',
        age: j['age'],
        height: j['height'],
        weight: j['weight'],
        gender: j['gender'] ?? '',
        phone: j['phone'] ?? '',
        address: j['address'] ?? '',
        guardianId: j['guardian_id'],
      );

  bool get isGuardian => role == 'guardian';
}
