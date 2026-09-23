import 'package:flutter_test/flutter_test.dart';
import 'package:bewosai_app/core/constants/app_constants.dart';
import 'package:bewosai_app/features/auth/data/models/business_model.dart';

// A real token is secrets.token_urlsafe(32): 43 URL-safe characters.
const _token = 'k3J9xQ2mZ7vB1nL5pR8tW0yC4dF6gH_aS-uE2iO7jXc';

Business _business([Map<String, dynamic> extra = const {}]) => Business.fromJson({
      'id': 1,
      'name': 'Shop',
      'owner': 7,
      ...extra,
    });

void main() {
  group('AppConstants.staffTokenFromLink', () {
    test('takes the token out of the shared link, on any host', () {
      expect(AppConstants.staffTokenFromLink('https://bewosaiapp.vercel.app/staff-login/$_token'), _token);
      expect(AppConstants.staffTokenFromLink('http://192.168.1.5:5173/staff-login/$_token'), _token);
    });

    test('accepts the bare token, and ignores surrounding whitespace', () {
      expect(AppConstants.staffTokenFromLink(_token), _token);
      expect(AppConstants.staffTokenFromLink('  https://x.app/staff-login/$_token \n'), _token);
    });

    test('finds the link inside a pasted message and stops at the end of the token', () {
      expect(
        AppConstants.staffTokenFromLink('Sita, sign in here: https://bewosaiapp.vercel.app/staff-login/$_token. Keep it private!'),
        _token,
      );
    });

    test('the link the app itself shares comes straight back', () {
      expect(AppConstants.staffTokenFromLink(AppConstants.staffLoginUrl(_token)), _token);
    });

    test('rejects things that are not a staff link', () {
      expect(AppConstants.staffTokenFromLink(null), isNull);
      expect(AppConstants.staffTokenFromLink(''), isNull);
      expect(AppConstants.staffTokenFromLink('   '), isNull);
      expect(AppConstants.staffTokenFromLink('hello'), isNull);
      expect(AppConstants.staffTokenFromLink('https://bewosaiapp.vercel.app/login'), isNull);
      expect(AppConstants.staffTokenFromLink('https://x.app/staff-login/short'), isNull);
      expect(AppConstants.staffTokenFromLink('two words $_token'), isNull);
    });
  });

  group('Business.can (what this person may do here)', () {
    final cashier = _business({
      'my_role': 'CASHIER',
      'my_permissions': {
        'sales': {'view': true, 'create': true, 'edit': true, 'delete': false},
        'purchases': {'view': false, 'create': false, 'edit': false, 'delete': false},
        'expenses': {'view': true, 'create': true, 'edit': true, 'delete': true},
      },
    });

    test('follows the table the server sent', () {
      expect(cashier.myRole, 'CASHIER');
      expect(cashier.can('sales'), isTrue);
      expect(cashier.can('sales', 'create'), isTrue);
      expect(cashier.can('sales', 'delete'), isFalse);
      expect(cashier.can('purchases'), isFalse);
      expect(cashier.can('purchases', 'create'), isFalse);
    });

    test('a module or action the table does not mention is not denied (the server decides)', () {
      expect(cashier.can('inventory'), isTrue);
    });

    test('no table at all (a session from before it existed) shows everything', () {
      final old = _business();
      expect(old.myPermissions, isNull);
      expect(old.can('purchases'), isTrue);
      expect(old.canDeleteAnything, isTrue);
    });

    test('canDeleteAnything is true only if some module allows delete', () {
      expect(cashier.canDeleteAnything, isTrue); // expenses
      final viewer = _business({
        'my_permissions': {
          for (final m in ['sales', 'purchases', 'expenses', 'inventory', 'parties', 'payments', 'banking'])
            m: {'view': true, 'create': false, 'edit': false, 'delete': false},
        },
      });
      expect(viewer.canDeleteAnything, isFalse);
    });

    test('the permissions survive being saved and loaded again', () {
      final again = Business.fromJson(cashier.toRawJson());
      expect(again.myRole, 'CASHIER');
      expect(again.can('purchases'), isFalse);
      expect(again.can('sales', 'delete'), isFalse);
      expect(again.can('sales', 'edit'), isTrue);
    });
  });
}
