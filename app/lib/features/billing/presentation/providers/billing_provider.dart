import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../data/services/billing_service.dart';

/// Backs the Upgrade Plan / Refer & Earn screen. Not a
/// ChangeNotifierProxyProvider like LicenseProvider — this doesn't need to
/// gate the whole app or refetch on every business switch, just load once
/// when the screen opens (same as StaffProvider's pattern).
class BillingProvider extends ChangeNotifier {
  final _service = BillingService();

  SubscriptionStatus? subscription;
  ReferralInfo? referral;
  bool isLoading = false;
  String? error;

  bool isApplyingCoupon = false;
  String? couponError;
  String? couponSuccess;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([_service.subscription(), _service.referral()]);
      subscription = results[0] as SubscriptionStatus;
      referral = results[1] as ReferralInfo;
    } catch (e) {
      error = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> applyCoupon(String code) async {
    isApplyingCoupon = true;
    couponError = null;
    couponSuccess = null;
    notifyListeners();
    try {
      final message = await _service.applyCoupon(code);
      couponSuccess = message;
      isApplyingCoupon = false;
      notifyListeners();
      await load();
      return true;
    } catch (e) {
      isApplyingCoupon = false;
      couponError = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearCouponMessages() {
    if (couponError == null && couponSuccess == null) return;
    couponError = null;
    couponSuccess = null;
    notifyListeners();
  }
}
