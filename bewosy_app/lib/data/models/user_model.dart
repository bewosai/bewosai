class UserModel {
  final int id;
  final String email;
  final String name;
  final String phone;
  final String accountType;
  final bool isPlatformAdmin;
  final bool isVerified;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.accountType,
    required this.isPlatformAdmin,
    required this.isVerified,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] ?? 0,
        email: j['email'] ?? '',
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        accountType: j['account_type'] ?? 'business',
        isPlatformAdmin: j['is_platform_admin'] ?? false,
        isVerified: j['is_verified'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
        'account_type': accountType,
        'is_platform_admin': isPlatformAdmin,
        'is_verified': isVerified,
      };
}
