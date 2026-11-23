#!/usr/bin/env python3
"""Configure le projet Android généré par `flutter create` :
- permission INTERNET (vérification des mises à jour, liens) ;
- requêtes d'intent pour ouvrir les liens (url_launcher, Android 11+) ;
- signature de release stable à partir de android/key.properties s'il existe.
"""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
manifest = root / "android/app/src/main/AndroidManifest.xml"
m = manifest.read_text(encoding="utf-8")

if "android.permission.INTERNET" not in m:
    m = m.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)

VIEW_HTTPS = '<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>'
if 'android:scheme="https"' not in m:
    if "<queries>" in m:
        m = m.replace("<queries>", "<queries>\n        " + VIEW_HTTPS, 1)
    else:
        m = m.replace("</manifest>", "    <queries>\n        " + VIEW_HTTPS + "\n    </queries>\n</manifest>", 1)
manifest.write_text(m, encoding="utf-8")

gradle = root / "android/app/build.gradle.kts"
if gradle.exists():
    g = gradle.read_text(encoding="utf-8")
    if "keystoreProperties" not in g:
        g = "import java.io.FileInputStream\nimport java.util.Properties\n\n" + g
        loader = (
            'val keystoreProperties = Properties()\n'
            'val keystorePropertiesFile = rootProject.file("key.properties")\n'
            'if (keystorePropertiesFile.exists()) {\n'
            '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
            '}\n\n'
        )
        g = g.replace("android {", loader + "android {", 1)
        signing = (
            "android {\n"
            "    signingConfigs {\n"
            '        create("release") {\n'
            "            if (keystorePropertiesFile.exists()) {\n"
            '                keyAlias = keystoreProperties["keyAlias"] as String\n'
            '                keyPassword = keystoreProperties["keyPassword"] as String\n'
            '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
            '                storePassword = keystoreProperties["storePassword"] as String\n'
            "            }\n"
            "        }\n"
            "    }\n"
        )
        g = g.replace("android {\n", signing, 1)
        g = re.sub(
            r'signingConfig = signingConfigs\.getByName\("debug"\)',
            'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
            g,
        )
        gradle.write_text(g, encoding="utf-8")

print("✓ Android configuré", "(signature release)" if (root / "android/key.properties").exists() else "(signature debug)")
