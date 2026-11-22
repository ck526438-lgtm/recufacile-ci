import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ticket.dart';

/// Première utilisation : configuration du profil commerçant (section 7).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blueDeep,
      body: BlueScaffoldBody(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Center(child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/icon/icon.png', width: 84))),
              const SizedBox(height: 16),
              const Text('ReçuFacile CI',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Votre commerce, simplement.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15)),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(20)),
                  child: const Text('0 FCFA / mois · Aucun abonnement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ),
              const SizedBox(height: 26),
              const TicketCard(notchOffsets: [0.13], child: MerchantForm(submitLabel: 'Commencer')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formulaire du profil commerçant, réutilisé dans « Ma boutique ».
class MerchantForm extends StatefulWidget {
  const MerchantForm({super.key, required this.submitLabel, this.onSaved});

  final String submitLabel;
  final VoidCallback? onSaved;

  @override
  State<MerchantForm> createState() => _MerchantFormState();
}

class _MerchantFormState extends State<MerchantForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _business, _owner, _phone, _address, _message, _currency;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    final m = context.read<AppState>().merchant;
    _business = TextEditingController(text: m?.businessName ?? '');
    _owner = TextEditingController(text: m?.ownerName ?? '');
    _phone = TextEditingController(text: m?.phone ?? '');
    _address = TextEditingController(text: m?.address ?? '');
    _currency = TextEditingController(text: m?.currency ?? 'FCFA');
    _message = TextEditingController(text: m?.thankYouMessage ?? 'Merci pour votre achat !');
    _logoPath = m?.logoPath;
  }

  @override
  void dispose() {
    for (final c in [_business, _owner, _phone, _address, _message, _currency]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 85);
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(dir.path, 'logo_${DateTime.now().millisecondsSinceEpoch}${p.extension(x.path)}');
    await File(x.path).copy(dest);
    setState(() => _logoPath = dest);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    final current = state.merchant ?? const Merchant(businessName: '');
    await state.saveMerchant(current.copyWith(
      businessName: _business.text.trim(),
      ownerName: _owner.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      currency: _currency.text.trim().isEmpty ? 'FCFA' : _currency.text.trim(),
      thankYouMessage: _message.text.trim().isEmpty ? 'Merci pour votre achat !' : _message.text.trim(),
      logoPath: _logoPath,
      clearLogo: _logoPath == null,
    ));
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Ma boutique', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const Text('Ces informations apparaîtront sur chaque reçu.', style: TextStyle(color: AppColors.muted)),
        const DashedDivider(height: 34),
        Row(children: [
          GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: const Color(0xFFF3F5F8), borderRadius: BorderRadius.circular(18)),
              clipBehavior: Clip.antiAlias,
              child: _logoPath != null && File(_logoPath!).existsSync()
                  ? Image.file(File(_logoPath!), fit: BoxFit.cover)
                  : const Icon(Icons.add_a_photo_outlined, color: AppColors.blue),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Logo (facultatif)', style: TextStyle(fontWeight: FontWeight.w600)),
              if (_logoPath != null)
                TextButton(onPressed: () => setState(() => _logoPath = null), child: const Text('Retirer le logo'))
              else
                TextButton(onPressed: _pickLogo, child: const Text('Choisir une image')),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        TextFormField(
          controller: _business,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nom commercial *', prefixIcon: Icon(Icons.storefront_outlined)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez le nom de la boutique' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _owner,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nom du propriétaire', prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Téléphone', hintText: '07 XX XX XX XX', prefixIcon: Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _address,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Adresse / Ville', prefixIcon: Icon(Icons.place_outlined)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _currency,
          decoration: const InputDecoration(labelText: 'Devise', prefixIcon: Icon(Icons.payments_outlined)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _message,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Message de remerciement', prefixIcon: Icon(Icons.favorite_border)),
        ),
        const SizedBox(height: 22),
        FilledButton(onPressed: _save, child: Text(widget.submitLabel)),
      ]),
    );
  }
}
