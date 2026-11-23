import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Vérifie (au plus une fois par jour, si Internet est disponible) s'il existe
/// une version plus récente publiée sur GitHub. Aucune donnée n'est envoyée.
class UpdateService {
  static const _kLastCheck = 'update_last_check';
  static const _kLatest = 'update_latest';

  static Future<String?> availableUpdate(SharedPreferences prefs) async {
    final cached = prefs.getString(_kLatest);
    final last = prefs.getInt(_kLastCheck) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    String? latest = cached;
    if (now - last > const Duration(hours: 20).inMilliseconds) {
      latest = await _fetchLatest() ?? cached;
      await prefs.setInt(_kLastCheck, now);
      if (latest != null) await prefs.setString(_kLatest, latest);
    }
    if (latest != null && isNewerVersion(latest, AppConfig.version)) return latest.replaceFirst('v', '');
    return null;
  }

  static Future<String?> _fetchLatest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.getUrl(Uri.parse(AppConfig.latestReleaseApi));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set(HttpHeaders.userAgentHeader, 'RecuFacile-CI');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      return (jsonDecode(body) as Map<String, dynamic>)['tag_name'] as String?;
    } catch (_) {
      return null; // hors ligne : on réessaiera plus tard
    } finally {
      client.close(force: true);
    }
  }
}
