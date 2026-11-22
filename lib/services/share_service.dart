import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../utils/format.dart';
import 'pdf_service.dart';

/// Partage : WhatsApp, Bluetooth, e-mail passent par la feuille de partage
/// Android (Android Share) — aucune connexion requise pour Bluetooth.
class ShareService {
  static String summary(Receipt r, Merchant m) => [
        '${m.businessName} — Reçu ${r.number}',
        'Date : ${formatDateTime(r.createdAt)}',
        'Client : ${r.customerName}',
        'Total : ${formatMoney(r.total, m.currency)} (${r.paymentMethod.label})',
        m.thankYouMessage,
      ].join('\n');

  static Future<void> sharePdf(Receipt r, Merchant m) async {
    final file = await PdfService.saveToDevice(r, m);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: summary(r, m),
      subject: 'Reçu ${r.number} — ${m.businessName}',
    );
  }

  /// Imprimer ou « Enregistrer au format PDF » via le dialogue système.
  static Future<void> printOrSave(Receipt r, Merchant m) =>
      Printing.layoutPdf(name: 'Recu_${r.number}', onLayout: (_) => PdfService.build(r, m));

  /// Sauvegarde : exporte une copie de la base de données locale.
  static Future<void> exportBackup(String dbPath) async {
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final tmp = await getTemporaryDirectory();
    final copy = await File(dbPath).copy(p.join(tmp.path, 'recufacile_sauvegarde_$stamp.db'));
    await Share.shareXFiles([XFile(copy.path)], subject: 'Sauvegarde ReçuFacile CI $stamp');
  }

  /// Choisit un fichier de sauvegarde ; renvoie son chemin ou null.
  static Future<String?> pickBackup() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    return res?.files.single.path;
  }
}
