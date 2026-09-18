import 'package:flutter_test/flutter_test.dart';
import 'package:bewosai_app/router/dashboard_route.dart';

void main() {
  group('dashboardLocation', () {
    test('points at the dashboard with the requested tab and sub-tab', () {
      final uri = Uri.parse(dashboardLocation(tab: 1, subtab: 1));
      expect(uri.path, '/dashboard');
      expect(uri.queryParameters['tab'], '1');
      expect(uri.queryParameters['subtab'], '1');
    });

    test('defaults to the Home tab, with no sub-tab', () {
      final uri = Uri.parse(dashboardLocation());
      expect(uri.queryParameters['tab'], '0');
      expect(uri.queryParameters.containsKey('subtab'), isFalse);
    });

    test('every call is a different address, so repeating the same request still registers', () {
      // Asking for "/dashboard?tab=0" twice looked like no change to the router,
      // which is why the Home button did nothing while already on a shell tab.
      final a = dashboardLocation();
      final b = dashboardLocation();
      expect(a, isNot(b));
      expect(Uri.parse(a).queryParameters['t'], isNotNull);
    });
  });
}
