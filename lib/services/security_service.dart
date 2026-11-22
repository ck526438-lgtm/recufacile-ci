import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verrouillage par code PIN (haché + salé) et biométrie si disponible (section 16).
class SecurityService {
  SecurityService(this._prefs);
  final SharedPreferences _prefs;
  final _auth = LocalAuthentication();

  static const _kHash = 'pin_hash';
  static const _kSalt = 'pin_salt';
  static const _kBio = 'pin_biometric';

  bool get hasPin => _prefs.getString(_kHash) != null;
  bool get biometricEnabled => _prefs.getBool(_kBio) ?? false;

  static String hashPin(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await _prefs.setString(_kSalt, salt);
    await _prefs.setString(_kHash, hashPin(pin, salt));
  }

  bool verifyPin(String pin) {
    final salt = _prefs.getString(_kSalt);
    final hash = _prefs.getString(_kHash);
    if (salt == null || hash == null) return true;
    return hashPin(pin, salt) == hash;
  }

  Future<void> removePin() async {
    await _prefs.remove(_kHash);
    await _prefs.remove(_kSalt);
    await _prefs.remove(_kBio);
  }

  Future<void> setBiometric(bool value) => _prefs.setBool(_kBio, value);

  Future<bool> canUseBiometrics() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Déverrouillez ReçuFacile CI',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
