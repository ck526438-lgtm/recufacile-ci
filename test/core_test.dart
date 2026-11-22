import 'package:flutter_test/flutter_test.dart';
import 'package:recufacile_ci/data/app_database.dart';
import 'package:recufacile_ci/models/models.dart';
import 'package:recufacile_ci/utils/format.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Receipt draft({List<ReceiptItem>? items, int discount = 0, PaymentMethod pay = PaymentMethod.especes, String? corrects, DateTime? at}) =>
    Receipt(
      number: '',
      createdAt: at ?? DateTime.now(),
      customerName: '',
      items: items ??
          const [
            ReceiptItem(name: 'Article A', quantity: 2, unitPrice: 5000),
            ReceiptItem(name: 'Article B', quantity: 1, unitPrice: 3000),
          ],
      discount: discount,
      paymentMethod: pay,
      correctsNumber: corrects,
    );

void main() {
  group('Format', () {
    test('montants FCFA avec espaces', () {
      expect(formatAmount(0), '0');
      expect(formatAmount(13000), '13 000');
      expect(formatAmount(1250000), '1 250 000');
      expect(formatMoney(500), '500 FCFA');
    });
    test('numéro de reçu', () {
      expect(formatReceiptNumber(1), 'RC-000001');
      expect(formatReceiptNumber(123456), 'RC-123456');
    });
    test('saisie de montant', () {
      expect(parseAmount('5 000'), 5000);
      expect(parseAmount(''), 0);
      expect(parseAmount('abc'), 0);
    });
  });

  group('Calculs du reçu (modèle du cahier des charges)', () {
    test('sous-total, remise, total', () {
      final r = draft();
      expect(r.subtotal, 13000);
      expect(r.total, 13000);
      expect(draft(discount: 1500).total, 11500);
    });
    test('le total ne devient jamais négatif', () {
      expect(draft(discount: 999999).total, 0);
    });
  });

  group('Base locale', () {
    late AppDatabase db;
    setUpAll(sqfliteFfiInit);
    setUp(() async => db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi));
    tearDown(() => db.close());

    test('numérotation automatique unique et séquentielle', () async {
      final a = await db.insertReceipt(draft());
      final b = await db.insertReceipt(draft());
      expect(a.number, 'RC-000001');
      expect(b.number, 'RC-000002');
      expect(a.customerName, 'Client comptant');
      final loaded = await db.getReceipt(a.id!);
      expect(loaded!.items.length, 2);
      expect(loaded.total, 13000);
    });

    test('annulation : reste dans l\'historique, exclu des ventes', () async {
      final now = DateTime.now();
      final from = startOfDay(now), to = from.add(const Duration(days: 1));
      final a = await db.insertReceipt(draft());
      await db.insertReceipt(draft(discount: 3000));
      expect(await db.salesTotal(from, to), 23000);
      await db.cancelReceipt(a.id!);
      expect(await db.salesTotal(from, to), 10000);
      expect((await db.getReceipt(a.id!))!.status, ReceiptStatus.annule);
      expect(await db.receiptCount(), 2);
    });

    test('correction : original marqué « Corrigé » et lié au nouveau', () async {
      final a = await db.insertReceipt(draft());
      final b = await db.insertReceipt(draft(discount: 1000, corrects: a.number));
      final old = await db.getReceipt(a.id!);
      expect(old!.status, ReceiptStatus.corrige);
      expect(old.correctedBy, b.number);
      final now = startOfDay(DateTime.now());
      expect(await db.salesTotal(now, now.add(const Duration(days: 1))), 12000);
    });

    test('recherche et filtres', () async {
      await db.insertReceipt(draft(pay: PaymentMethod.wave));
      await db.insertReceipt(draft(pay: PaymentMethod.orangeMoney));
      expect((await db.searchReceipts(query: 'RC-000002')).length, 1);
      expect((await db.searchReceipts(query: 'comptant')).length, 2);
      expect((await db.searchReceipts(payment: PaymentMethod.wave)).length, 1);
      final byPay = await db.salesByPayment(DateTime(2000), DateTime(2100));
      expect(byPay[PaymentMethod.wave], 13000);
      expect(byPay[PaymentMethod.orangeMoney], 13000);
    });

    test('catalogue et profil', () async {
      await db.saveMerchant(const Merchant(businessName: 'Ma Boutique', phone: '07 00 00 00 00'));
      expect((await db.getMerchant())!.businessName, 'Ma Boutique');
      final id = await db.saveProduct(const Product(name: 'Chaussures', price: 15000, category: 'Mode'));
      await db.saveProduct(Product(id: id, name: 'Chaussures', price: 17000));
      final list = await db.getProducts();
      expect(list.single.price, 17000);
      await db.wipeAll();
      expect(await db.getMerchant(), isNull);
      expect((await db.insertReceipt(draft())).number, 'RC-000001');
    });
  });
}
