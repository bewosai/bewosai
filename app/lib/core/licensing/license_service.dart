import '../network/api_client.dart';

class LicenseStatus {
  final bool hasActiveSubscription;
  final bool isGrandfathered;
  final bool isTrialActive;
  final DateTime? trialExpiryDate;
  final Map<String, dynamic>? license;

  const LicenseStatus({
    required this.hasActiveSubscription,
    required this.isGrandfathered,
    required this.isTrialActive,
    this.trialExpiryDate,
    this.license,
  });

  factory LicenseStatus.fromJson(Map<String, dynamic> json) => LicenseStatus(
        hasActiveSubscription: json['has_active_subscription'] == true,
        isGrandfathered: json['is_grandfathered'] == true,
        isTrialActive: json['is_trial_active'] == true,
        trialExpiryDate: json['trial_expiry_date'] != null
            ? DateTime.tryParse(json['trial_expiry_date'] as String)
            : null,
        license: json['license'] as Map<String, dynamic>?,
      );
}

class LicenseService {
  final _dio = ApiClient.instance.dio;

  /// Trial/license status for the current business — same endpoint the
  /// React web client reads. Exempted from HasActiveSubscription backend
  /// side, so a locked-out business can still call this to find out why.
  Future<LicenseStatus> me() async {
    try {
      final res = await _dio.get('/auth/licenses/me/');
      return LicenseStatus.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Activates a license Super Admin generated for the current business.
  /// Returns the activated license payload; throws [ApiException] with the
  /// backend's real message on failure (invalid code, revoked, expired,
  /// belongs to a different business, ...).
  Future<Map<String, dynamic>> activate(String code) async {
    try {
      final res = await _dio.post('/auth/licenses/activate/', data: {'code': code});
      final data = res.data as Map<String, dynamic>;
      return data['license'] as Map<String, dynamic>? ?? data;
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
