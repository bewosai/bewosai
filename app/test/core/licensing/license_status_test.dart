import 'package:bewosai_app/core/licensing/license_service.dart';
import 'package:flutter_test/flutter_test.dart';

LicenseStatus _status({String plan = 'FREE', bool trial = true, Map<String, dynamic>? license}) =>
    LicenseStatus.fromJson({
      'has_active_subscription': true,
      'is_grandfathered': false,
      'is_trial_active': trial,
      'trial_expiry_date': '2026-10-10',
      'effective_plan': plan,
      'license': license,
    });

void main() {
  test('a business still on its free trial shows the banner', () {
    expect(_status().isOnFreeTrial, isTrue);
  });

  test('a coupon or license upgrade hides it', () {
    expect(_status(plan: 'PREMIUM').isOnFreeTrial, isFalse);
    expect(_status(license: {'expiry_date': '2027-01-01'}).isOnFreeTrial, isFalse);
    expect(_status(trial: false).isOnFreeTrial, isFalse);
  });

  test('days left counts whole calendar days and never goes negative', () {
    final s = _status();
    expect(s.trialDaysLeft(DateTime(2026, 10, 1, 23, 59)), 9);
    expect(s.trialDaysLeft(DateTime(2026, 10, 10, 8)), 0);
    expect(s.trialDaysLeft(DateTime(2026, 10, 20)), 0);
  });

  test('an older server without effective_plan still reads as FREE', () {
    final s = LicenseStatus.fromJson({'is_trial_active': true, 'trial_expiry_date': '2026-10-10'});
    expect(s.effectivePlan, 'FREE');
  });
}
