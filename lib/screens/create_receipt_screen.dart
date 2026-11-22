import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ticket.dart';
import 'catalog_screen.dart';
import 'receipt_screen.dart';

/// Ligne éditable du reçu en cours.
class _Line {
  _Line({String name = '', int qty = 1, int price = 0})
      : name = TextEditingController(text: name),
        qty = TextEditingController(text: '$qty'),
        price = TextEditingController(text: price == 0 ? '' : '$price');

  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController price;

  int get quantity => parseAmount(qty.text);
  int get unitPrice => parseAmount(price.text);
  int get total => quantity * unitPrice;
  bool get isValid => name.text.trim().isNotEmpty && quantity > 0;

  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
  }
}

/// Création d'un reçu (section 6.2). Avec [correcting], crée un reçu de
/// correction qui remplace l'original (l'original passe au statut « Corrigé »).
class CreateReceiptScreen extends StatefulWidget {
  const CreateReceiptScreen({super.key, this.correcting});

  final Receipt? correcting;

  @override
  State<CreateReceiptScreen> createState() => _CreateReceiptScreenState();
}

class _CreateReceiptScreenState extends State<CreateReceiptScreen> {
  final _customer = TextEditingController();
  final _discount = TextEditingController();
  final _note = TextEditingController();
  final List<_Line> _lines = [];
  PaymentMethod _payment = PaymentMethod.especes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.correcting;
    if (c != null) {
      _customer.text = c.customerName == 'Client comptant' ? '' : c.customerName;
      _discount.text = c.discount == 0 ? '' : '${c.discount}';
      _payment = c.paymentMethod;
      for (final i in c.items) {
        _lines.add(_Line(name: i.name, qty: i.quantity, price: i.unitPrice));
      }
    } else {
      _lines.add(_Line());
    }
  }

  @override
  void dispose() {
    _customer.dispose();
    _discount.dispose();
    _note.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  int get _subtotal => _lines.fold(0, (s, l) => s + l.total);
  int get _discountValue => parseAmount(_discount.text);
  int get _total => (_subtotal - _discountValue).clamp(0, 1 << 52).toInt();

  Future<void> _addFromCatalog() async {
    final product = await Navigator.of(context).push<Product>(
      MaterialPageRoute(builder: (_) => const CatalogScreen(pickMode: true)),
    );
    if (product == null) return;
    setState(() {
      // Remplace une première ligne vide plutôt que d'en ajouter une.
      final empty = _lines.where((l) => l.name.text.trim().isEmpty && l.unitPrice == 0).toList();
      if (empty.isNotEmpty) {
        empty.first.name.text = product.name;
        empty.first.price.text = '${product.price}';
      } else {
        _lines.add(_Line(name: product.name, price: product.price));
      }
    });
  }

  Future<void> _save() async {
    final valid = _lines.where((l) => l.isValid).toList();
    if (valid.isEmpty) {
      _snack('Ajoutez au moins un produit ou service.');
      return;
    }
    if (_discountValue > _subtotal) {
      _snack('La remise ne peut pas dépasser le sous-total.');
      return;
    }
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final receipt = await state.createReceipt(Receipt(
      number: '',
      createdAt: DateTime.now(),
      customerName: _customer.text,
      items: valid.map((l) => ReceiptItem(name: l.name.text.trim(), quantity: l.quantity, unitPrice: l.unitPrice)).toList(),
      discount: _discountValue,
      paymentMethod: _payment,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      correctsNumber: widget.correcting?.number,
    ));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReceiptScreen(receiptId: receipt.id!, justCreated: true)),
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final currency = context.read<AppState>().merchant?.currency ?? 'FCFA';
    final correcting = widget.correcting;
    return Scaffold(
      appBar: AppBar(title: Text(correcting == null ? 'Nouveau reçu' : 'Corriger ${correcting.number}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
        children: [
          if (correcting != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Text(
                'Un nouveau reçu sera créé. Le reçu ${correcting.number} restera dans l\'historique avec le statut « Corrigé ».',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          TicketCard(
            notchOffsets: const [0.5],
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Client', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              TextField(
                controller: _customer,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom du client',
                  hintText: 'Client comptant',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const DashedDivider(height: 30),
              const Text('Mode de paiement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PaymentMethod.values
                    .map((p) => ChoiceChip(
                          label: Text(p.label),
                          selected: _payment == p,
                          showCheckmark: false,
                          selectedColor: AppColors.blue,
                          backgroundColor: const Color(0xFFF0F3F8),
                          labelStyle: TextStyle(
                            color: _payment == p ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setState(() => _payment = p),
                        ))
                    .toList(),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('Produits / services', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
            TextButton.icon(onPressed: _addFromCatalog, icon: const Icon(Icons.inventory_2_outlined), label: const Text('Catalogue')),
          ]),
          const SizedBox(height: 4),
          for (var i = 0; i < _lines.length; i++) _lineCard(i, currency),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => setState(() => _lines.add(_Line())),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une ligne'),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: Column(children: [
              TextField(
                controller: _discount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: 'Remise éventuelle', suffixText: currency, prefixIcon: const Icon(Icons.discount_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Note (facultatif)', prefixIcon: Icon(Icons.edit_note)),
              ),
              const DashedDivider(height: 30),
              _totalRow('Sous-total', formatMoney(_subtotal, currency)),
              _totalRow('Remise', formatMoney(_discountValue, currency)),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(30)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('TOTAL', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 12)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatMoney(_total, currency),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ),
              ]),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.ink,
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('Valider'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _totalRow(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(a, style: const TextStyle(color: AppColors.muted))),
          Text(b, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _lineCard(int index, String currency) {
    final l = _lines[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: l.name,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: 'Produit ou service ${index + 1}'),
            ),
          ),
          IconButton(
            tooltip: 'Supprimer la ligne',
            onPressed: _lines.length == 1
                ? null
                : () => setState(() {
                      _lines.removeAt(index).dispose();
                    }),
            icon: const Icon(Icons.close),
          ),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(children: [
            SizedBox(
              width: 86,
              child: TextField(
                controller: l.qty,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Qté'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: l.price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: 'Prix unitaire', suffixText: currency),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('= ${formatMoney(l.total, currency)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.blue)),
          ),
        ),
      ]),
    );
  }
}
