import 'package:flutter_test/flutter_test.dart';
import 'package:bewosai_app/features/staff/data/models/staff_model.dart';
import 'package:bewosai_app/features/staff/data/services/staff_service.dart';

StaffMember _member({String name = '', String email = ''}) => StaffMember(
      id: 1,
      user: 1,
      userName: name,
      userEmail: email,
      business: 1,
      role: 'CASHIER',
      permissions: const {},
      isActive: true,
    );

void main() {
  group('StaffMember.initial', () {
    test('uses the name, then the email', () {
      expect(_member(name: 'sita').initial, 'S');
      expect(_member(email: 'ram@x.com').initial, 'R');
    });

    test('never crashes for a link-only member with no name and no email', () {
      expect(_member().initial, '?');
    });
  });

  group('defaultPermissionsFor (what a role gets, and what a role change resets to)', () {
    bool can(Map<String, dynamic> perms, String module, String action) =>
        (perms[module] as Map)[action] == true;

    test('a Cashier can create sales but not touch purchases or banking', () {
      final p = defaultPermissionsFor('CASHIER');
      expect(can(p, 'sales', 'create'), isTrue);
      expect(can(p, 'sales', 'delete'), isFalse);
      expect(can(p, 'purchases', 'view'), isFalse);
      expect(can(p, 'banking', 'view'), isFalse);
    });

    test('a Manager can edit but not delete, and only views banking/staff/reports', () {
      final p = defaultPermissionsFor('MANAGER');
      expect(can(p, 'sales', 'edit'), isTrue);
      expect(can(p, 'sales', 'delete'), isFalse);
      expect(can(p, 'banking', 'create'), isFalse);
      expect(can(p, 'staff', 'view'), isTrue);
      expect(can(p, 'staff', 'edit'), isFalse);
    });

    test('a Viewer can only view, everywhere', () {
      final p = defaultPermissionsFor('VIEWER');
      for (final module in p.keys) {
        expect(can(p, module, 'view'), isTrue, reason: module);
        expect(can(p, module, 'create'), isFalse, reason: module);
        expect(can(p, module, 'edit'), isFalse, reason: module);
        expect(can(p, module, 'delete'), isFalse, reason: module);
      }
    });

    test('promoting a Cashier really changes what they can do', () {
      final asCashier = defaultPermissionsFor('CASHIER');
      final asManager = defaultPermissionsFor('MANAGER');
      expect(can(asCashier, 'purchases', 'view'), isFalse);
      expect(can(asManager, 'purchases', 'view'), isTrue);
    });
  });
}
