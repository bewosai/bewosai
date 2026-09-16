import '../../../../core/utils/formatters.dart';

class StaffMember {
  final int id;
  final int user;
  final String userName;
  final String userEmail;
  final int business;
  final String role;
  final Map<String, dynamic> permissions;
  final bool isActive;
  final DateTime? joinedAt;
  // Passwordless "click this link to open the app as this staff member"
  // credential — null until an owner/permitted manager generates or
  // regenerates one (see StaffService.regenerateLink). Staff created
  // without an email/phone have no other way to sign in.
  final String? loginToken;

  StaffMember({
    required this.id,
    required this.user,
    required this.userName,
    required this.userEmail,
    required this.business,
    required this.role,
    required this.permissions,
    required this.isActive,
    this.joinedAt,
    this.loginToken,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: json['id'] as int,
        user: json['user'] is int ? json['user'] as int : int.tryParse('${json['user']}') ?? 0,
        userName: json['user_name'] as String? ?? '',
        userEmail: json['user_email'] as String? ?? '',
        business: json['business'] is int ? json['business'] as int : int.tryParse('${json['business']}') ?? 0,
        role: json['role'] as String? ?? 'CASHIER',
        permissions: (json['permissions'] as Map?)?.cast<String, dynamic>() ?? {},
        isActive: json['is_active'] as bool? ?? true,
        joinedAt: Formatters.parseDate(json['joined_at'] as String?),
        loginToken: json['login_token'] as String?,
      );

  String get initial => userName.isNotEmpty ? userName[0].toUpperCase() : userEmail[0].toUpperCase();
}
