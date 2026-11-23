/// Configuration publique de l'application.
class AppConfig {
  /// Doit correspondre à `version:` dans pubspec.yaml (vérifié par les tests).
  static const version = '1.1.0';

  static const repo = 'ck526438-lgtm/recufacile-ci';
  static const website = 'https://ck526438-lgtm.github.io/recufacile-ci/';
  static const privacyUrl = '${website}confidentialite.html';
  static const downloadUrl = 'https://github.com/$repo/releases/latest/download/RecuFacile-CI.apk';
  static const latestReleaseApi = 'https://api.github.com/repos/$repo/releases/latest';
  static const issuesUrl = 'https://github.com/$repo/issues/new/choose';

  /// Numéro WhatsApp du support au format international sans « + »
  /// (ex. 2250700000000). Vide = les avis passent par GitHub.
  static const supportWhatsApp = '2250787256074';

  static String get feedbackUrl => supportWhatsApp.isEmpty
      ? issuesUrl
      : 'https://wa.me/$supportWhatsApp?text=${Uri.encodeComponent('Bonjour, mon avis sur ReçuFacile CI : ')}';

  static const shareMessage = 'J\'utilise ReçuFacile CI pour faire mes reçus sur WhatsApp. '
      'C\'est gratuit, sans abonnement et ça marche sans Internet : $website';
}

/// Compare deux versions « 1.2.3 » ; renvoie true si [candidate] est plus récente.
bool isNewerVersion(String candidate, String current) {
  List<int> parse(String v) => v.replaceFirst(RegExp(r'^v'), '').split('+').first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final a = parse(candidate), b = parse(current);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
