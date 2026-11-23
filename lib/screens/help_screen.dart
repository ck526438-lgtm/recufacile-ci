import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme/app_theme.dart';
import '../widgets/ticket.dart';

Future<void> openLink(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir le lien. Vérifiez votre connexion.')));
  }
}

/// Aide, avis, recommandation et informations légales.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _guide = [
    ('Créer un reçu', 'Touchez « Créer un reçu », ajoutez le client et les produits, choisissez le paiement puis « Valider ».'),
    ('Envoyer au client', 'Sur le reçu, touchez « Partager » puis WhatsApp. Le reçu part en PDF avec votre logo.'),
    ('Gagner du temps', 'Dans Ma boutique → Catalogue, enregistrez vos produits habituels. Le prix reste modifiable à chaque vente.'),
    ('Erreur sur un reçu ?', 'Ouvrez-le, menu ⋯ → Corriger. Un nouveau reçu le remplace ; l\'ancien reste visible comme « Corrigé ».'),
    ('Changer de téléphone', 'Ma boutique → Exporter une sauvegarde, puis Restaurer une sauvegarde sur le nouveau téléphone.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aide & avis')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          ClipPath(
            clipper: const ScallopClipper(count: 6),
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.ticketGradient),
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: AppColors.ink,
                  child: const Text('VOTRE AVIS COMPTE',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                ),
                const SizedBox(height: 14),
                const Text('Aidez-nous à améliorer ReçuFacile CI',
                    style: TextStyle(fontSize: 22, height: 1.15, fontWeight: FontWeight.w900, color: AppColors.ink)),
                const SizedBox(height: 6),
                const Text('Un bug, une idée, une fonction qui manque ? Dites-le-nous.',
                    style: TextStyle(color: AppColors.ink)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.ink, minimumSize: const Size.fromHeight(50)),
                  onPressed: () => openLink(context, AppConfig.feedbackUrl),
                  icon: Icon(AppConfig.supportWhatsApp.isEmpty ? Icons.feedback_outlined : Icons.chat_outlined),
                  label: Text(AppConfig.supportWhatsApp.isEmpty ? 'Donner mon avis' : 'Donner mon avis sur WhatsApp'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Share.share(AppConfig.shareMessage, subject: 'ReçuFacile CI'),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(children: [
                  CircleAvatar(radius: 24, backgroundColor: AppColors.lime, child: Icon(Icons.favorite, color: AppColors.ink)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Recommander à un commerçant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('Partagez l\'application sur WhatsApp', style: TextStyle(color: Colors.white70)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 8),
            child: Text('GUIDE RAPIDE', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 12)),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (title, body) in _guide)
                  ExpansionTile(
                    shape: const Border(),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedAlignment: Alignment.centerLeft,
                    children: [Text(body, style: const TextStyle(color: Color(0xFF4B5366)))],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.language, color: AppColors.blue),
                title: const Text('Site officiel', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openLink(context, AppConfig.website),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.blue),
                title: const Text('Politique de confidentialité', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openLink(context, AppConfig.privacyUrl),
              ),
              ListTile(
                leading: const Icon(Icons.system_update_outlined, color: AppColors.blue),
                title: const Text('Télécharger la dernière version', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openLink(context, AppConfig.downloadUrl),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('ReçuFacile CI v${AppConfig.version} · Gratuit, sans abonnement',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}
