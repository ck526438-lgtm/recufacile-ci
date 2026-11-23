import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recufacile_ci/config.dart';

void main() {
  test('AppConfig.version correspond à pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final version = line.split(':').last.trim().split('+').first;
    expect(AppConfig.version, version);
  });

  test('comparaison de versions', () {
    expect(isNewerVersion('v1.2.0', '1.1.0'), isTrue);
    expect(isNewerVersion('1.1.1', '1.1.0'), isTrue);
    expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
    expect(isNewerVersion('v1.1.0', '1.1.0'), isFalse);
    expect(isNewerVersion('1.0.9', '1.1.0'), isFalse);
  });

  test('lien de téléchargement stable', () {
    expect(AppConfig.downloadUrl, endsWith('/releases/latest/download/RecuFacile-CI.apk'));
  });
}
