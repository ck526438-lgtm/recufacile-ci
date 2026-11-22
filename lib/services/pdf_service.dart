import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../utils/format.dart';

/// Génère le reçu PDF hors ligne, au style « ticket » de l'application.
class PdfService {
  static const _blue = PdfColor.fromInt(0xFF2563EB);
  static const _ink = PdfColor.fromInt(0xFF0B0F1A);
  static const _muted = PdfColor.fromInt(0xFF8A93A6);
  static const _red = PdfColor.fromInt(0xFFE5484D);

  static Future<Uint8List> build(Receipt r, Merchant m) async {
    final doc = pw.Document(title: 'Reçu ${r.number}', author: m.businessName, creator: 'ReçuFacile CI');
    pw.ImageProvider? logo;
    if (m.logoPath != null && File(m.logoPath!).existsSync()) {
      logo = pw.MemoryImage(await File(m.logoPath!).readAsBytes());
    }
    final cur = m.currency;
    final font = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();

    pw.Widget dashed() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Divider(color: _muted, borderStyle: pw.BorderStyle.dashed, thickness: 0.7, height: 1),
        );

    pw.Widget row(String a, String b, {bool strong = false, double size = 9.5}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(a, style: pw.TextStyle(font: strong ? bold : font, fontSize: size, color: strong ? _ink : _muted))),
            pw.Text(b, style: pw.TextStyle(font: strong ? bold : font, fontSize: size, color: _ink)),
          ]),
        );

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: font, bold: bold),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: pw.BoxDecoration(color: _blue, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(children: [
                if (logo != null) pw.Container(height: 36, margin: const pw.EdgeInsets.only(bottom: 6), child: pw.Image(logo)),
                pw.Text('REÇU DE VENTE', style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white, letterSpacing: 2)),
                pw.SizedBox(height: 3),
                pw.Text(m.businessName.toUpperCase(),
                    textAlign: pw.TextAlign.center, style: pw.TextStyle(font: bold, fontSize: 15, color: PdfColors.white)),
              ]),
            ),
            pw.SizedBox(height: 6),
            if (m.phone.isNotEmpty) pw.Text('Contact : ${m.phone}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            if (m.address.isNotEmpty) pw.Text(m.address, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9, color: _muted)),
            dashed(),
            row('N°', r.number, strong: true),
            row('Date', '${formatDate(r.createdAt)}  ${formatTime(r.createdAt)}'),
            row('Client', r.customerName),
            if (r.status != ReceiptStatus.valide)
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 6),
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: _red), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text(
                  r.status == ReceiptStatus.annule
                      ? 'REÇU ANNULÉ'
                      : 'REÇU CORRIGÉ — remplacé par ${r.correctedBy ?? ''}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: bold, fontSize: 9, color: _red),
                ),
              ),
            if (r.correctsNumber != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text('Corrige le reçu ${r.correctsNumber}', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
              ),
            dashed(),
            pw.Table(
              columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(2)},
              children: [
                pw.TableRow(children: [
                  pw.Text('Produit', style: pw.TextStyle(font: bold, fontSize: 9)),
                  pw.Text('Qté', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: bold, fontSize: 9)),
                  pw.Text('Prix', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: bold, fontSize: 9)),
                ]),
                for (final i in r.items)
                  pw.TableRow(children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(i.name, style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('${formatAmount(i.unitPrice)} / u', style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
                      ]),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text('${i.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(formatAmount(i.lineTotal), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
                    ),
                  ]),
              ],
            ),
            dashed(),
            row('Sous-total', formatMoney(r.subtotal, cur)),
            row('Remise', formatMoney(r.discount, cur)),
            pw.SizedBox(height: 4),
            row('TOTAL', formatMoney(r.total, cur), strong: true, size: 13),
            row('Paiement', r.paymentMethod.label),
            if (r.note != null && r.note!.isNotEmpty) row('Note', r.note!),
            dashed(),
            pw.Text(m.thankYouMessage, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.SizedBox(height: 8),
            pw.BarcodeWidget(barcode: pw.Barcode.code128(), data: r.number, height: 34, drawText: false),
            pw.SizedBox(height: 3),
            pw.Text(r.number, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8, color: _muted, letterSpacing: 2)),
            pw.SizedBox(height: 6),
            pw.Text('Généré avec ReçuFacile CI', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.5, color: _muted)),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// Enregistre le PDF dans le dossier de l'application et renvoie le fichier.
  static Future<File> saveToDevice(Receipt r, Merchant m) async {
    final bytes = await build(r, m);
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'recus'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(dir.path, 'Recu_${r.number}.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
