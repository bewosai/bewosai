import '../../../../core/network/api_client.dart';

/// Mirrors the response shape of GET /api/billing/subscription/ (see
/// backend/billing/views.py SubscriptionCurrentView and the React web
/// client's `billing.subscription()` in client/src/api/index.js).
class SubscriptionStatus {
  final String effectivePlan;
  final String basePlan;
  final bool activeLicense;
  final DateTime? licenseExpiry;
  final Map<String, dynamic>? activeSubscription;

  const SubscriptionStatus({
    required this.effectivePlan,
    required this.basePlan,
    required this.activeLicense,
    this.licenseExpiry,
    this.activeSubscription,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) => SubscriptionStatus(
        effectivePlan: json['effective_plan'] as String? ?? 'FREE',
        basePlan: json['base_plan'] as String? ?? 'FREE',
        activeLicense: json['active_license'] == true,
        licenseExpiry: json['license_expiry'] != null ? DateTime.tryParse(json['license_expiry'] as String) : null,
        activeSubscription: json['active_subscription'] as Map<String, dynamic>?,
      );
}

class ReferralReward {
  final int id;
  final String referredBusinessName;
  final String status;

  const ReferralReward({required this.id, required this.referredBusinessName, required this.status});

  factory ReferralReward.fromJson(Map<String, dynamic> json) => ReferralReward(
        id: json['id'] as int,
        referredBusinessName: json['referred_business_name'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );
}

class ReferralInfo {
  final String? referralCode;
  final String? referralLink;
  final int totalReferrals;
  final List<ReferralReward> rewards;

  const ReferralInfo({
    this.referralCode,
    this.referralLink,
    required this.totalReferrals,
    required this.rewards,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) => ReferralInfo(
        referralCode: json['referral_code'] as String?,
        referralLink: json['referral_link'] as String?,
        totalReferrals: json['total_referrals'] as int? ?? 0,
        rewards: (json['rewards'] as List? ?? [])
            .map((e) => ReferralReward.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Refer & Earn + coupon redemption — hits the same backend/billing app
/// endpoints as the React web client's `billing` API namespace
/// (client/src/api/index.js), kept separate from LicenseService/
/// core/licensing on purpose (a deliberate product decision — see
/// backend/billing/models.py's module docstring).
class BillingService {
  final _dio = ApiClient.instance.dio;

  Future<SubscriptionStatus> subscription() async {
    try {
      final res = await _dio.get('/billing/subscription/');
      return SubscriptionStatus.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<ReferralInfo> referral() async {
    try {
      final res = await _dio.get('/billing/referral/');
      return ReferralInfo.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Returns the backend's own success message ("Coupon applied — ...").
  Future<String> applyCoupon(String code) async {
    try {
      final res = await _dio.post('/billing/apply-coupon/', data: {'code': code});
      final data = res.data as Map<String, dynamic>;
      return data['message'] as String? ?? 'Coupon applied.';
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
