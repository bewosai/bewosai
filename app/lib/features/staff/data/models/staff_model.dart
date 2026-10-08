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

  // Never indexes into an empty string: a link-only staff member has no email,
  // and a blank name would otherwise crash the whole Staff list.
  /// Joined before email invitations: signs in with a shared login link.
  bool get usesLoginLink => userEmail.isEmpty;

  String get initial {
    if (userName.isNotEmpty) return userName[0].toUpperCase();
    if (userEmail.isNotEmpty) return userEmail[0].toUpperCase();
    return '?';
  }
}

/// An invitation waiting for the person to verify their email and accept.
class StaffInvitation {
  final int id;
  final String name;
  final String email;
  final String role;
  final String roleLabel;
  final String status;
  final bool isExpired;
  final DateTime? expiresAt;
  /// The secret link token - only present right after creating or resending.
  final String? token;

  StaffInvitation({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleLabel,
    required this.status,
    required this.isExpired,
    this.expiresAt,
    this.token,
  });

  factory StaffInvitation.fromJson(Map<String, dynamic> json) => StaffInvitation(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? '',
        roleLabel: json['role_label'] as String? ?? (json['role'] as String? ?? ''),
        status: json['status'] as String? ?? 'PENDING',
        isExpired: json['is_expired'] as bool? ?? false,
        expiresAt: Formatters.parseDate(json['expires_at'] as String?),
        token: json['token'] as String?,
      );
}
