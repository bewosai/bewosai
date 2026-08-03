class AppUser {
  final int id;
  final String email;
  final String name;
  final String phone;
  final String accountType;
  final bool isPlatformAdmin;
  final bool isActive;
  final bool isVerified;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.accountType,
    required this.isPlatformAdmin,
    required this.isActive,
    required this.isVerified,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        accountType: json['account_type'] as String? ?? 'business',
        isPlatformAdmin: json['is_platform_admin'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        isVerified: json['is_verified'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
        'account_type': accountType,
        'is_platform_admin': isPlatformAdmin,
        'is_active': isActive,
        'is_verified': isVerified,
      };

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : email[0].toUpperCase();
}
