import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/models.dart';
import '../services/security_service.dart';

/// État global : profil, catalogue, et un compteur de révision qui
/// déclenche le rafraîchissement des écrans après chaque modification.
class AppState extends ChangeNotifier {
  AppState(this._db, this.security);

  AppDatabase _db;
  final SecurityService security;

  AppDatabase get db => _db;
  Merchant? merchant;
  List<Product> products = [];
  int revision = 0;

  bool get isConfigured => merchant != null && merchant!.businessName.trim().isNotEmpty;

  Future<void> load() async {
    merchant = await _db.getMerchant();
    products = await _db.getProducts();
    notifyListeners();
  }

  void _changed() {
    revision++;
    notifyListeners();
  }

  Future<void> saveMerchant(Merchant m) async {
    await _db.saveMerchant(m);
    merchant = m;
    _changed();
  }

  Future<void> saveProduct(Product p) async {
    await _db.saveProduct(p);
    products = await _db.getProducts();
    _changed();
  }

  Future<void> deleteProduct(int id) async {
    await _db.deleteProduct(id);
    products = await _db.getProducts();
    _changed();
  }

  Future<Receipt> createReceipt(Receipt draft) async {
    final r = await _db.insertReceipt(draft);
    _changed();
    return r;
  }

  Future<void> cancelReceipt(int id, {String? reason}) async {
    await _db.cancelReceipt(id, reason: reason);
    _changed();
  }

  Future<void> wipeAll() async {
    await _db.wipeAll();
    await security.removePin();
    merchant = null;
    products = [];
    _changed();
  }

  /// Restaure une sauvegarde (.db) après vérification de sa structure.
  Future<bool> restoreBackup(String sourcePath) async {
    try {
      final probe = await openReadOnlyDatabase(sourcePath);
      final tables = await probe.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('receipts','merchant')");
      await probe.close();
      if (tables.length < 2) return false;
      final target = await _db.path;
      await _db.close();
      await File(sourcePath).copy(target);
      _db = await AppDatabase.open(path: target);
      await load();
      _changed();
      return true;
    } catch (_) {
      return false;
    }
  }
}
