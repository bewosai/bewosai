import 'package:flutter/foundation.dart';

import '../../features/billing/data/services/billing_service.dart';
import '../network/api_client.dart';
import 'license_service.dart';

/// Mirrors the React LicenseContext: caches the current business's
/// trial/license status. Fails open (`true`) until the first fetch resolves
/// so a slow/failed network call can't lock out a legitimate user on its
/// own — the backend's HasActiveSubscription permission is the real gate on
/// every write; this only drives what the UI shows.
class LicenseProvider extends ChangeNotifier {
  final _service = LicenseService();

  LicenseStatus? _status;
  bool _loaded = false;
  int? _lastBusinessId;

  bool isActivating = false;
  String? activateError;

  bool get loaded => _loaded;
  LicenseStatus? get status => _status;
  bool get hasActiveSubscription => _status?.hasActiveSubscription ?? true;

  /// Called from the ChangeNotifierProxyProvider update() whenever
  /// AuthProvider's currentBusiness changes, so switching businesses always
  /// refetches the right status instead of showing the previous business's.
  void syncBusiness(int? businessId) {
    if (businessId == _lastBusinessId) return;
    _lastBusinessId = businessId;
    if (businessId != null) refresh();
  }

  Future<void> refresh() async {
    try {
      _status = await _service.me();
    } catch (_) {
      // keep whatever was last known rather than assuming locked out
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Called by ApiClient's interceptor the moment any business-scoped call
  /// comes back blocked by the backend's HasActiveSubscription permission —
  /// the trial/license may have lapsed mid-session, well after the last
  /// refresh(). Flips state immediately for a responsive redirect, then
  /// refreshes to get the real trial_expiry_date/license payload for the
  /// License Required screen to display.
  void markBlocked() {
    if (_status != null && !_status!.hasActiveSubscription) return;
    _status = LicenseStatus(
      hasActiveSubscription: false,
      isGrandfathered: _status?.isGrandfathered ?? false,
      isTrialActive: false,
      trialExpiryDate: _status?.trialExpiryDate,
      license: _status?.license,
    );
    _loaded = true;
    notifyListeners();
    refresh();
  }

  /// Length of a Premium coupon code (billing.models.COUPON_CODE_LENGTH);
  /// license codes are 5, so one box on the locked screen can take either.
  static const couponCodeLength = 6;

  /// The backend's "Coupon applied — Premium active until …" message after a
  /// coupon (rather than a license) unlocked the business; null otherwise.
  String? couponMessage;

  Future<bool> activate(String code) async {
    isActivating = true;
    activateError = null;
    couponMessage = null;
    notifyListeners();
    try {
      if (code.length == couponCodeLength) {
        couponMessage = await BillingService().applyCoupon(code);
      } else {
        await _service.activate(code);
      }
      await refresh();
      isActivating = false;
      notifyListeners();
      return true;
    } catch (e) {
      isActivating = false;
      activateError = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearActivateError() {
    if (activateError == null) return;
    activateError = null;
    notifyListeners();
  }
}
