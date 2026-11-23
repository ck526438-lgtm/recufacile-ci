import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/share_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ticket.dart';
import 'catalog_screen.dart';
import 'help_screen.dart';
import 'lock_screen.dart';
import 'onboarding_screen.dart';

/// « Ma boutique » : profil, catalogue, sécurité, sauvegarde, données.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().security.canUseBiometrics().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _togglePin(bool enable) async {
    final sec = context.read<AppState>().security;
    if (!enable) {
      await sec.removePin();
      setState(() {});
      _snack('Code PIN désactivé');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => LockScreen(
        onPinChosen: (pin) async {
          await sec.setPin(pin);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    ));
    setState(() {});
    if (sec.hasPin) _snack('Code PIN activé');
  }

  Future<void> _restore() async {
    final state = context.read<AppState>();
    final path = await ShareService.pickBackup();
    if (path == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer la sauvegarde ?'),
        content: const Text('Les données actuelles seront remplacées par celles de la sauvegarde.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurer')),
        ],
      ),
    );
    if (ok != true) return;
    final restored = await state.restoreBackup(path);
    if (mounted) _snack(restored ? 'Sauvegarde restaurée ✓' : 'Fichier de sauvegarde invalide');
  }

  Future<void> _wipe() async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer toutes les données ?'),
        content: const Text('Reçus, produits et profil seront définitivement effacés de ce téléphone. Pensez à faire une sauvegarde avant.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tout supprimer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await state.wipeAll();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sec = state.security;
    final m = state.merchant;
    return Scaffold(
      appBar: AppBar(title: const Text('Ma boutique')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (m != null)
            TicketCard(
              notchOffsets: const [0.5],
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/icon/icon.png', width: 54)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.businessName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    if (m.phone.isNotEmpty) Text(m.phone, style: const TextStyle(color: AppColors.muted)),
                    if (m.address.isNotEmpty) Text(m.address, style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.blue),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (ctx) => Scaffold(
                      appBar: AppBar(title: const Text('Modifier le profil')),
                      body: ListView(padding: const EdgeInsets.all(16), children: [
                        TicketCard(
                          notchOffsets: const [0.13],
                          child: MerchantForm(submitLabel: 'Enregistrer', onSaved: () => Navigator.pop(ctx)),
                        ),
                      ]),
                    ),
                  )),
                ),
              ]),
            ),
          const SizedBox(height: 18),
          _Section(title: 'Produits', children: [
            _Tile(
              icon: Icons.inventory_2_outlined,
              title: 'Catalogue',
              subtitle: '${state.products.length} produit(s) enregistré(s)',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CatalogScreen())),
            ),
          ]),
          _Section(title: 'Aide', children: [
            _Tile(
              icon: Icons.help_outline,
              title: 'Aide & avis',
              subtitle: 'Guide, donner mon avis, recommander l\'app',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
            ),
          ]),
          _Section(title: 'Sécurité', children: [
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline, color: AppColors.blue),
              title: const Text('Code PIN', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Demander un code à l\'ouverture'),
              value: sec.hasPin,
              onChanged: _togglePin,
            ),
            if (sec.hasPin && _bioAvailable)
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint, color: AppColors.blue),
                title: const Text('Empreinte / visage', style: TextStyle(fontWeight: FontWeight.w600)),
                value: sec.biometricEnabled,
                onChanged: (v) async {
                  await sec.setBiometric(v);
                  setState(() {});
                },
              ),
          ]),
          _Section(title: 'Sauvegarde', children: [
            _Tile(
              icon: Icons.cloud_upload_outlined,
              title: 'Exporter une sauvegarde',
              subtitle: 'Envoyer le fichier vers Drive, WhatsApp, e-mail…',
              onTap: () async => ShareService.exportBackup(await state.db.path),
            ),
            _Tile(
              icon: Icons.restore,
              title: 'Restaurer une sauvegarde',
              subtitle: 'Importer un fichier .db exporté',
              onTap: _restore,
            ),
          ]),
          _Section(title: 'Données', children: [
            _Tile(
              icon: Icons.delete_outline,
              title: 'Supprimer mes données',
              subtitle: 'Efface tout de ce téléphone',
              color: AppColors.danger,
              onTap: _wipe,
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(24)),
            child: const Column(children: [
              Text('0 FCFA / mois', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('Aucun abonnement · Reçus illimités · Données gardées sur votre téléphone',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('ReçuFacile CI v${AppConfig.version} · L\'application n\'effectue aucun transfert d\'argent.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(title.toUpperCase(),
                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 12)),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ]),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap, this.subtitle, this.color = AppColors.blue});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color == AppColors.danger ? color : null)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
