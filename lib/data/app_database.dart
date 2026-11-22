import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../utils/format.dart';

/// Base SQLite locale : tout fonctionne sans Internet (section 14).
class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static const _version = 1;

  static Future<AppDatabase> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'recufacile.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _create(db),
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _create(Database db) async {
    await db.execute('''
      CREATE TABLE merchant (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        business_name TEXT NOT NULL,
        owner_name TEXT,
        phone TEXT,
        address TEXT,
        logo_path TEXT,
        currency TEXT NOT NULL DEFAULT 'FCFA',
        thank_you TEXT
      )''');
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        category TEXT
      )''');
    await db.execute('''
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL,
        customer_name TEXT NOT NULL,
        discount INTEGER NOT NULL DEFAULT 0,
        subtotal INTEGER NOT NULL,
        total INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'valide',
        note TEXT,
        corrects_number TEXT,
        corrected_by TEXT
      )''');
    await db.execute('''
      CREATE TABLE receipt_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL
      )''');
    await db.execute('CREATE TABLE counters (key TEXT PRIMARY KEY, value INTEGER NOT NULL)');
    await db.insert('counters', {'key': 'receipt', 'value': 0});
    await db.execute('CREATE INDEX idx_receipts_date ON receipts(created_at)');
    await db.execute('CREATE INDEX idx_receipts_customer ON receipts(customer_name)');
  }

  // ---------- Commerçant ----------
  Future<Merchant?> getMerchant() async {
    final rows = await db.query('merchant', where: 'id = 1');
    return rows.isEmpty ? null : Merchant.fromMap(rows.first);
  }

  Future<void> saveMerchant(Merchant m) =>
      db.insert('merchant', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  // ---------- Catalogue ----------
  Future<List<Product>> getProducts() async =>
      (await db.query('products', orderBy: 'name COLLATE NOCASE')).map(Product.fromMap).toList();

  Future<int> saveProduct(Product p) async {
    if (p.id == null) return db.insert('products', p.toMap());
    await db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
    return p.id!;
  }

  Future<void> deleteProduct(int id) => db.delete('products', where: 'id = ?', whereArgs: [id]);

  // ---------- Reçus ----------
  /// Crée un reçu avec un numéro unique attribué dans la même transaction.
  Future<Receipt> insertReceipt(Receipt draft) {
    return db.transaction((txn) async {
      final row = await txn.query('counters', where: 'key = ?', whereArgs: ['receipt']);
      final next = ((row.first['value'] as num).toInt()) + 1;
      await txn.update('counters', {'value': next}, where: 'key = ?', whereArgs: ['receipt']);
      final number = formatReceiptNumber(next);
      final receipt = Receipt(
        number: number,
        createdAt: draft.createdAt,
        customerName: draft.customerName.trim().isEmpty ? 'Client comptant' : draft.customerName.trim(),
        items: draft.items,
        discount: draft.discount,
        paymentMethod: draft.paymentMethod,
        note: draft.note,
        correctsNumber: draft.correctsNumber,
      );
      final id = await txn.insert('receipts', receipt.toMap());
      for (final item in receipt.items) {
        await txn.insert('receipt_items', item.toMap(id));
      }
      if (receipt.correctsNumber != null) {
        await txn.update(
          'receipts',
          {'status': ReceiptStatus.corrige.name, 'corrected_by': number},
          where: 'number = ?',
          whereArgs: [receipt.correctsNumber],
        );
      }
      return receipt.copyWith(id: id);
    });
  }

  Future<void> cancelReceipt(int id, {String? reason}) => db.update(
        'receipts',
        {'status': ReceiptStatus.annule.name, if (reason != null && reason.isNotEmpty) 'note': reason},
        where: 'id = ? AND status = ?',
        whereArgs: [id, ReceiptStatus.valide.name],
      );

  Future<Receipt?> getReceipt(int id) async {
    final rows = await db.query('receipts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _withItems(rows.first);
  }

  Future<Receipt?> getReceiptByNumber(String number) async {
    final rows = await db.query('receipts', where: 'number = ?', whereArgs: [number]);
    if (rows.isEmpty) return null;
    return _withItems(rows.first);
  }

  Future<Receipt> _withItems(Map<String, Object?> row) async {
    final items = await db.query('receipt_items', where: 'receipt_id = ?', whereArgs: [row['id']], orderBy: 'id');
    return Receipt.fromMap(row, items.map(ReceiptItem.fromMap).toList());
  }

  /// Recherche par numéro ou nom du client, filtre par période et mode de paiement.
  Future<List<Receipt>> searchReceipts({
    String? query,
    DateTime? from,
    DateTime? to,
    PaymentMethod? payment,
    ReceiptStatus? status,
    int? limit,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (query != null && query.trim().isNotEmpty) {
      where.add('(number LIKE ? OR customer_name LIKE ?)');
      final q = '%${query.trim()}%';
      args..add(q)..add(q);
    }
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('created_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (payment != null) {
      where.add('payment_method = ?');
      args.add(payment.name);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }
    final rows = await db.query(
      'receipts',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    final result = <Receipt>[];
    for (final r in rows) {
      result.add(await _withItems(r));
    }
    return result;
  }

  // ---------- Statistiques ----------
  Future<int> salesTotal(DateTime from, DateTime to) async {
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(total),0) AS t FROM receipts WHERE status = ? AND created_at >= ? AND created_at < ?',
      [ReceiptStatus.valide.name, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (r.first['t'] as num).toInt();
  }

  Future<int> receiptCount({DateTime? from, DateTime? to, bool validOnly = false}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (validOnly) {
      where.add('status = ?');
      args.add(ReceiptStatus.valide.name);
    }
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('created_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM receipts${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}',
      args,
    );
    return (r.first['c'] as num).toInt();
  }

  /// Répartition des ventes valides par mode de paiement sur une période.
  Future<Map<PaymentMethod, int>> salesByPayment(DateTime from, DateTime to) async {
    final rows = await db.rawQuery(
      'SELECT payment_method, SUM(total) AS t FROM receipts WHERE status = ? AND created_at >= ? AND created_at < ? GROUP BY payment_method',
      [ReceiptStatus.valide.name, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return {
      for (final r in rows) PaymentMethod.fromName(r['payment_method'] as String?): (r['t'] as num).toInt(),
    };
  }

  /// Ventes valides jour par jour (clé = début de journée).
  Future<Map<DateTime, int>> dailySales(DateTime from, DateTime to) async {
    final rows = await db.query(
      'receipts',
      columns: ['created_at', 'total'],
      where: 'status = ? AND created_at >= ? AND created_at < ?',
      whereArgs: [ReceiptStatus.valide.name, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    final map = <DateTime, int>{};
    for (final r in rows) {
      final day = startOfDay(DateTime.fromMillisecondsSinceEpoch((r['created_at'] as num).toInt()));
      map[day] = (map[day] ?? 0) + (r['total'] as num).toInt();
    }
    return map;
  }

  // ---------- Données ----------
  Future<void> wipeAll() async {
    await db.transaction((txn) async {
      await txn.delete('receipt_items');
      await txn.delete('receipts');
      await txn.delete('products');
      await txn.delete('merchant');
      await txn.update('counters', {'value': 0});
    });
  }

  Future<String> get path async => db.path;
  Future<void> close() => db.close();
}
