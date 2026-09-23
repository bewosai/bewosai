import 'package:flutter_test/flutter_test.dart';
import 'package:bewosai_app/features/staff/data/models/staff_access.dart';
import 'package:bewosai_app/features/staff/data/services/staff_service.dart' show defaultPermissionsFor;

void main() {
  group('permissionsForAccess', () {
    test('each level sets exactly the flags it says', () {
      expect(permissionsForAccess(StaffAccess.none), {'view': false, 'create': false, 'edit': false, 'delete': false});
      expect(permissionsForAccess(StaffAccess.view), {'view': true, 'create': false, 'edit': false, 'delete': false});
      expect(permissionsForAccess(StaffAccess.add), {'view': true, 'create': true, 'edit': false, 'delete': false});
      expect(permissionsForAccess(StaffAccess.edit), {'view': true, 'create': true, 'edit': true, 'delete': false});
      expect(permissionsForAccess(StaffAccess.full), {'view': true, 'create': true, 'edit': true, 'delete': true});
    });

    test('every level reads back as itself', () {
      for (final level in StaffAccess.values) {
        expect(accessOf(permissionsForAccess(level)), level, reason: '$level');
      }
    });
  });

  group('accessOf', () {
    test('a mix no level describes is null (shown as Custom)', () {
      expect(accessOf({'view': true, 'create': false, 'edit': true, 'delete': false}), isNull); // edit without add
      expect(accessOf({'view': false, 'create': true, 'edit': false, 'delete': false}), isNull); // add without view
    });

    test('a flag left out counts as allowed, the way the server reads it', () {
      expect(accessOf({'view': true, 'create': false}), isNull); // edit/delete default to allowed
      expect(accessOf({'view': true, 'create': true, 'edit': true, 'delete': true}), StaffAccess.full);
      expect(accessOf(<String, dynamic>{}), StaffAccess.full);
    });
  });

  group('accessFor', () {
    test('a module never configured is full, except staff management which is never implied', () {
      expect(accessFor(const {}, 'sales'), StaffAccess.full);
      expect(accessFor(const {}, 'staff'), StaffAccess.none);
    });
  });

  test('withAccess changes only the one feature', () {
    final start = {
      'sales': permissionsForAccess(StaffAccess.add),
      'purchases': permissionsForAccess(StaffAccess.none),
    };
    final next = withAccess(start, 'purchases', StaffAccess.view);
    expect(accessFor(next, 'purchases'), StaffAccess.view);
    expect(accessFor(next, 'sales'), StaffAccess.add);
    expect(accessFor(start, 'purchases'), StaffAccess.none, reason: 'the original is untouched');
  });

  group('samePermissions', () {
    test('equal maps, and a missing module equals its default', () {
      final a = defaultPermissionsFor('CASHIER');
      expect(samePermissions(a, {...a}), isTrue);
      expect(samePermissions({'sales': permissionsForAccess(StaffAccess.full)}, const {}), isTrue); // unset == allowed
      expect(samePermissions({'staff': permissionsForAccess(StaffAccess.none)}, const {}), isTrue); // unset staff == denied
    });

    test('a single flag difference is noticed', () {
      final a = defaultPermissionsFor('MANAGER');
      final b = withAccess(a, 'sales', StaffAccess.full);
      expect(samePermissions(a, b), isFalse);
    });
  });

  group('the role presets read as sensible levels', () {
    test('Cashier: sells and adds expenses, sees stock, no purchases or banking', () {
      final p = defaultPermissionsFor('CASHIER');
      expect(accessFor(p, 'sales'), StaffAccess.add);
      expect(accessFor(p, 'expenses'), StaffAccess.add);
      expect(accessFor(p, 'inventory'), StaffAccess.view);
      expect(accessFor(p, 'purchases'), StaffAccess.none);
      expect(accessFor(p, 'banking'), StaffAccess.none);
      expect(accessFor(p, 'staff'), StaffAccess.none);
    });

    test('Manager: adds and edits but cannot delete; banking and reports view-only', () {
      final p = defaultPermissionsFor('MANAGER');
      expect(accessFor(p, 'sales'), StaffAccess.edit);
      expect(accessFor(p, 'purchases'), StaffAccess.edit);
      expect(accessFor(p, 'banking'), StaffAccess.view);
      expect(accessFor(p, 'reports'), StaffAccess.view);
    });

    test('Viewer: view-only everywhere', () {
      final p = defaultPermissionsFor('VIEWER');
      for (final (module, _) in staffModules) {
        expect(accessFor(p, module), StaffAccess.view, reason: module);
      }
    });
  });
}
