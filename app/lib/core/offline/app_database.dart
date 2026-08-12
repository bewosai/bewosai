import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Local on-device cache so the most-needed data (products, parties) can
/// still be browsed with no signal, plus a small outbox table for writes
/// made while offline (currently just Sales — see [SyncService]).
///
/// Each cache table stores the full API JSON blob per row rather than a
/// normalized schema: the server is the single source of truth, so there's
/// nothing to gain from modelling relations locally — we just need "what
/// did the server say last time we asked" and "what haven't we told the
/// server yet."
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  bool _unavailable = false;

  /// Null when sqflite has no usable backend on this platform (e.g. running
  /// on web/desktop without a databaseFactory registered) — callers treat
  /// that as "no local cache" rather than crashing the screen.
  Future<Database?> get _database async {
    if (_unavailable) return null;
    if (_db != null) return _db;
    try {
      _db = await _open();
      return _db;
    } catch (_) {
      _unavailable = true;
      return null;
    }
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'bewosai_cache.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE cached_products (id INTEGER PRIMARY KEY, business_id TEXT, json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE cached_parties (id INTEGER PRIMARY KEY, business_id TEXT, json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE outbox_sales (temp_id INTEGER PRIMARY KEY AUTOINCREMENT, business_id TEXT, json TEXT NOT NULL, created_at TEXT NOT NULL)',
        );
      },
    );
  }

  // ── Generic cache helpers (products / parties) ──────────────────────────

  Future<void> replaceCache(String table, String businessId, List<Map<String, dynamic>> rows) async {
    final db = await _database;
    if (db == null) return;
    await db.transaction((txn) async {
      await txn.delete(table, where: 'business_id = ?', whereArgs: [businessId]);
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(table, {
          'id': row['id'],
          'business_id': businessId,
          'json': jsonEncode(row),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> readCache(String table, String businessId) async {
    final db = await _database;
    if (db == null) return [];
    final rows = await db.query(table, where: 'business_id = ?', whereArgs: [businessId]);
    return rows.map((r) => jsonDecode(r['json'] as String) as Map<String, dynamic>).toList();
  }

  // ── Sales outbox ─────────────────────────────────────────────────────────

  /// Queues a Sale payload for later sync, returning a negative temp ID used
  /// to display it in the Sales list until it's actually created server-side.
  Future<int> enqueueSale(String businessId, Map<String, dynamic> payload) async {
    final db = await _database;
    if (db == null) {
      throw StateError('Offline saving is not available on this device.');
    }
    final rowId = await db.insert('outbox_sales', {
      'business_id': businessId,
      'json': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
    return -rowId;
  }

  Future<List<Map<String, dynamic>>> pendingSales(String businessId) async {
    final db = await _database;
    if (db == null) return [];
    final rows = await db.query(
      'outbox_sales',
      where: 'business_id = ?',
      whereArgs: [businessId],
      orderBy: 'temp_id ASC',
    );
    return rows
        .map((r) => {
              'temp_id': -(r['temp_id'] as int),
              'created_at': r['created_at'],
              ...jsonDecode(r['json'] as String) as Map<String, dynamic>,
            })
        .toList();
  }

  Future<int> pendingSaleCount(String businessId) async {
    final db = await _database;
    if (db == null) return 0;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM outbox_sales WHERE business_id = ?',
      [businessId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> removePendingSale(int tempId) async {
    final db = await _database;
    if (db == null) return;
    await db.delete('outbox_sales', where: 'temp_id = ?', whereArgs: [-tempId]);
  }
}
