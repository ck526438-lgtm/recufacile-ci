import 'package:intl/intl.dart';

/// Formate un montant entier en FCFA avec espaces : 13000 → "13 000".
String formatAmount(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buf';
}

String formatMoney(int value, [String currency = 'FCFA']) => '${formatAmount(value)} $currency';

/// Numéro de reçu unique, séquentiel : 1 → "RC-000001".
String formatReceiptNumber(int sequence) => 'RC-${sequence.toString().padLeft(6, '0')}';

final _date = DateFormat('dd/MM/yyyy', 'fr_FR');
final _time = DateFormat('HH:mm', 'fr_FR');
final _dateTime = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

String formatDate(DateTime d) => _date.format(d);
String formatTime(DateTime d) => _time.format(d);
String formatDateTime(DateTime d) => _dateTime.format(d);

/// Convertit une saisie utilisateur ("5 000", "5.000", "5000") en entier.
int parseAmount(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.isEmpty) return 0;
  return int.tryParse(cleaned) ?? 0;
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime startOfWeek(DateTime d) => startOfDay(d).subtract(Duration(days: d.weekday - 1));
DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);
