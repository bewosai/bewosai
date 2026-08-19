import 'dart:io';

import 'package:bewosai_app/core/offline/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Covers the outbox/cache logic real money-tracking correctness depends
/// on: a write queued offline must survive being read back with the right
/// business scoping, and must actually disappear once synced — silently
/// losing or double-counting a queued entry would be a real financial bug,
/// not a cosmetic one.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Start from a clean file so a previous interrupted test run can't
    // leave stale rows behind and make a test pass/fail for the wrong reason.
    final dir = await databaseFactory.getDatabasesPath();
    final path = p.join(dir, 'bewosai_cache.db');
    if (await File(path).exists()) {
      await File(path).delete();
    }
  });

  group('generic outbox (enqueueWrite/pendingWrites/removePendingWrite)', () {
    test('a queued write comes back with the right payload and temp id sign', () async {
      final tempId = await AppDatabase.instance.enqueueWrite(
        'expense', 'biz-1', {'amount': 500, 'description': 'Fuel'},
      );
      expect(tempId, lessThan(0), reason: 'temp ids are negative so they never collide with real server ids');

      final pending = await AppDatabase.instance.pendingWrites('expense', 'biz-1');
      expect(pending, hasLength(1));
      expect(pending.first['temp_id'], tempId);
      expect(pending.first['amount'], 500);
      expect(pending.first['description'], 'Fuel');
    });

    test('different entity types never leak into each other\'s pending list', () async {
      await AppDatabase.instance.enqueueWrite('purchase', 'biz-2', {'bill_number': 'PUR-0001'});
      await AppDatabase.instance.enqueueWrite('bank_transaction', 'biz-2', {'amount': 100});

      final purchases = await AppDatabase.instance.pendingWrites('purchase', 'biz-2');
      final transactions = await AppDatabase.instance.pendingWrites('bank_transaction', 'biz-2');
      expect(purchases, hasLength(1));
      expect(transactions, hasLength(1));
      expect(purchases.first['bill_number'], 'PUR-0001');
    });

    test('different businesses never see each other\'s queued writes', () async {
      await AppDatabase.instance.enqueueWrite('expense', 'biz-3a', {'amount': 10});
      await AppDatabase.instance.enqueueWrite('expense', 'biz-3b', {'amount': 20});

      final a = await AppDatabase.instance.pendingWrites('expense', 'biz-3a');
      final b = await AppDatabase.instance.pendingWrites('expense', 'biz-3b');
      expect(a.map((e) => e['amount']), [10]);
      expect(b.map((e) => e['amount']), [20]);
    });

    test('removePendingWrite removes exactly the one entry and nothing else', () async {
      final keep = await AppDatabase.instance.enqueueWrite('expense', 'biz-4', {'amount': 1});
      final remove = await AppDatabase.instance.enqueueWrite('expense', 'biz-4', {'amount': 2});

      await AppDatabase.instance.removePendingWrite(remove);

      final remaining = await AppDatabase.instance.pendingWrites('expense', 'biz-4');
      expect(remaining, hasLength(1));
      expect(remaining.first['temp_id'], keep);
    });

    test('pending writes come back oldest first, matching creation order', () async {
      await AppDatabase.instance.enqueueWrite('expense', 'biz-5', {'seq': 1});
      await AppDatabase.instance.enqueueWrite('expense', 'biz-5', {'seq': 2});
      await AppDatabase.instance.enqueueWrite('expense', 'biz-5', {'seq': 3});

      final pending = await AppDatabase.instance.pendingWrites('expense', 'biz-5');
      expect(pending.map((e) => e['seq']), [1, 2, 3]);
    });
  });

  group('totalPendingCount', () {
    test('counts across both the Sales-specific outbox and the generic one', () async {
      await AppDatabase.instance.enqueueSale('biz-6', {'invoice_number': 'INV-1'});
      await AppDatabase.instance.enqueueWrite('expense', 'biz-6', {'amount': 1});
      await AppDatabase.instance.enqueueWrite('purchase', 'biz-6', {'bill_number': 'PUR-1'});

      expect(await AppDatabase.instance.totalPendingCount('biz-6'), 3);
    });

    test('a synced (removed) write drops out of the count', () async {
      final tempId = await AppDatabase.instance.enqueueWrite('expense', 'biz-7', {'amount': 1});
      expect(await AppDatabase.instance.totalPendingCount('biz-7'), 1);

      await AppDatabase.instance.removePendingWrite(tempId);
      expect(await AppDatabase.instance.totalPendingCount('biz-7'), 0);
    });
  });

  group('cache (products/parties)', () {
    test('replaceCache overwrites the previous snapshot for that business, not appends to it', () async {
      await AppDatabase.instance.replaceCache('cached_products', 'biz-8', [
        {'id': 1, 'name': 'Old Product'},
      ]);
      await AppDatabase.instance.replaceCache('cached_products', 'biz-8', [
        {'id': 2, 'name': 'New Product'},
      ]);

      final rows = await AppDatabase.instance.readCache('cached_products', 'biz-8');
      expect(rows, hasLength(1));
      expect(rows.first['name'], 'New Product');
    });

    test('readCache for a business with nothing cached returns an empty list, not an error', () async {
      final rows = await AppDatabase.instance.readCache('cached_products', 'biz-never-seen');
      expect(rows, isEmpty);
    });
  });
}
