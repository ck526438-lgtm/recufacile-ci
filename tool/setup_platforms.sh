#!/usr/bin/env bash
# Génère les dossiers natifs Android/iOS puis applique la configuration
# de ReçuFacile CI (nom, biométrie, icône). À lancer une fois après le clonage.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create . --org ci.recufacile --project-name recufacile_ci --platforms=android,ios >/dev/null
rm -f test/widget_test.dart   # test d'exemple généré par flutter create
flutter pub get

MANIFEST=android/app/src/main/AndroidManifest.xml
# Nom affiché de l'application
sed -i.bak 's/android:label="[^"]*"/android:label="ReçuFacile CI"/' "$MANIFEST"
# Permission biométrie (local_auth)
grep -q USE_BIOMETRIC "$MANIFEST" || sed -i.bak 's#<application#<uses-permission android:name="android.permission.USE_BIOMETRIC"/>\n    <application#' "$MANIFEST"
rm -f "$MANIFEST.bak"

# INTERNET, liens https, signature release (si android/key.properties)
python3 tool/patch_android.py

# local_auth exige FlutterFragmentActivity
MAIN=$(find android/app/src/main -name 'MainActivity.kt' | head -1)
if [ -n "$MAIN" ]; then
  sed -i.bak 's/import io.flutter.embedding.android.FlutterActivity/import io.flutter.embedding.android.FlutterFragmentActivity/; s/: FlutterActivity()/: FlutterFragmentActivity()/' "$MAIN"
  rm -f "$MAIN.bak"
fi

# Thème AppCompat requis par local_auth
for f in android/app/src/main/res/values/styles.xml android/app/src/main/res/values-night/styles.xml; do
  [ -f "$f" ] && sed -i.bak 's/@android:style\/Theme.Light.NoTitleBar/Theme.AppCompat.Light.NoActionBar/; s/@android:style\/Theme.Black.NoTitleBar/Theme.AppCompat.NoActionBar/' "$f" && rm -f "$f.bak"
done

# Dépendance AppCompat pour le thème ci-dessus
if [ -f android/app/build.gradle.kts ] && ! grep -q appcompat android/app/build.gradle.kts; then
  printf '\ndependencies {\n    implementation("androidx.appcompat:appcompat:1.7.0")\n}\n' >> android/app/build.gradle.kts
elif [ -f android/app/build.gradle ] && ! grep -q appcompat android/app/build.gradle; then
  printf '\ndependencies {\n    implementation "androidx.appcompat:appcompat:1.7.0"\n}\n' >> android/app/build.gradle
fi

# iOS : texte de la demande Face ID
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q NSFaceIDUsageDescription "$PLIST"; then
  sed -i.bak 's#<dict>#<dict>\n\t<key>NSFaceIDUsageDescription</key>\n\t<string>Déverrouiller ReçuFacile CI</string>\n\t<key>NSPhotoLibraryUsageDescription</key>\n\t<string>Choisir le logo de votre boutique</string>#' "$PLIST"
  rm -f "$PLIST.bak"
fi

dart run flutter_launcher_icons
echo "✓ Plateformes prêtes. Lancez : flutter run"
