<p align="center">
  <img src="assets/icon/icon.png" width="120" alt="ReçuFacile CI" style="border-radius:28px">
</p>

<h1 align="center">ReçuFacile CI</h1>
<p align="center"><b>Votre commerce, simplement.</b><br>
Reçus numériques gratuits pour commerçants — <b>0 FCFA / mois, aucun abonnement</b>, fonctionne hors ligne.</p>

---

## ✨ Fonctionnalités

| | |
|---|---|
| 🧾 **Création de reçu** | Client, produits/services, quantité, prix unitaire, remise, total automatique |
| 🔢 **Numérotation** | Numéro unique séquentiel `RC-000001`, date et heure |
| 📄 **PDF** | Reçu au format ticket 80 mm avec logo, code-barres et message de remerciement |
| 📤 **Partage** | WhatsApp, Bluetooth, e-mail (feuille de partage Android), impression / enregistrement |
| 📚 **Catalogue** | Produits habituels réutilisables ; prix modifiable à la vente sans toucher au catalogue |
| 💳 **Modes de paiement** | Espèces, Orange Money, MTN MoMo, Wave, Moov Money, Virement, Autre |
| 🔎 **Historique** | Recherche par n° ou client, filtres date / paiement / statut, re-partage |
| ✏️ **Correction & annulation** | Reçu de correction lié à l'original ; reçus annulés/corrigés conservés et identifiables |
| 📊 **Statistiques** | Ventes du jour, de la semaine, du mois, 7 derniers jours, répartition par paiement |
| 🔒 **Sécurité** | Code PIN (haché), empreinte / visage, sauvegarde & restauration, suppression des données |
| 📴 **Hors ligne** | Base SQLite locale — création, calculs, historique et PDF sans Internet |

## 🎨 Design

Dégradé bleu → turquoise de l'icône, reçus en **ticket blanc à encoches** avec pointillés et **code-barres**,
bouton rond noir et **pilule de partage à pastille citron vert**, carte « Aujourd'hui » en **billet festonné à dégradé**
et typographie très grasse.

## 🚀 Installer l'APK

Chaque push sur `main` construit l'APK via GitHub Actions : onglet **Actions → Build APK → Artifacts**.
Pour une version publique : créez un tag `v1.0.0`, l'APK est attaché à la **Release**.

## 🛠️ Développement

Prérequis : Flutter 3.29+ et Android SDK.

```bash
git clone https://github.com/ck526438-lgtm/recufacile-ci.git
cd recufacile-ci
bash tool/setup_platforms.sh   # génère android/ et ios/ + nom, biométrie, icône
flutter run
flutter test
```

## 🧱 Architecture

```
lib/
├── main.dart                 # verrou PIN → configuration → accueil
├── theme/app_theme.dart      # couleurs & dégradés des maquettes
├── models/models.dart        # Commerçant, Produit, Reçu, Paiement, Statut
├── data/app_database.dart    # SQLite : reçus, lignes, catalogue, compteur, stats
├── state/app_state.dart      # état global (Provider)
├── services/                 # PDF, partage/sauvegarde, sécurité
├── widgets/                  # ticket à encoches, code-barres, pilule, tuiles
└── screens/                  # accueil, création, reçu, historique, ventes, boutique, catalogue, PIN
```

| Élément | Technologie |
|---|---|
| Application | Flutter / Dart |
| Base locale | SQLite (`sqflite`) |
| PDF | `pdf` + `printing` |
| Partage | `share_plus` (Android Share) |
| Serveur | **Aucun** pour la v1 |

## 💚 Engagements

Aucun abonnement mensuel ou annuel · pas de paiement pour générer, exporter ou partager un reçu ·
pas de limite de reçus · aucune donnée envoyée à des tiers.
L'application **n'effectue aucun transfert d'argent** : elle enregistre le mode et le montant déclarés.

## 🗺️ Évolutions prévues

Gestion des stocks · clients · carnet de dettes · factures et devis · export Excel ·
sauvegarde Google Drive · plusieurs boutiques/utilisateurs · imprimante thermique Bluetooth.
