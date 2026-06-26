// Pure business entity — no JSON, no Flutter dependency
class UserEntity {
  final int id;
  final String email;
  final String name;
  final String phone;
  final String accountType;
  final bool isPlatformAdmin;
  final bool isVerified;

  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.accountType,
    required this.isPlatformAdmin,
    required this.isVerified,
  });
}
