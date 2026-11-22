import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Catalogue des produits habituels (section 8). En [pickMode], toucher un
/// produit le renvoie à l'écran de création ; son prix reste modifiable
/// sur le reçu sans changer le catalogue.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, this.pickMode = false});
  final bool pickMode;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _query = '';

  Future<void> _edit([Product? p]) async {
    final name = TextEditingController(text: p?.name ?? '');
    final price = TextEditingController(text: p == null ? '' : '${p.price}');
    final category = TextEditingController(text: p?.category ?? '');
    final key = GlobalKey<FormState>();
    final result = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(p == null ? 'Nouveau produit' : 'Modifier le produit', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nom du produit *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Prix de vente *', suffixText: 'FCFA'),
              validator: (v) => parseAmount(v ?? '') <= 0 ? 'Prix obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: category,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Catégorie (facultatif)'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                if (!key.currentState!.validate()) return;
                Navigator.pop(
                  ctx,
                  Product(id: p?.id, name: name.text.trim(), price: parseAmount(price.text), category: category.text.trim()),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ]),
        ),
      ),
    );
    if (result != null && mounted) await context.read<AppState>().saveProduct(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _query.toLowerCase();
    final list = state.products
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || (p.category ?? '').toLowerCase().contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.pickMode ? 'Choisir un produit' : 'Catalogue')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Produit'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(fillColor: Colors.white, hintText: 'Rechercher', prefixIcon: Icon(Icons.search)),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Enregistrez vos produits habituels pour les retrouver en un geste.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: const CircleAvatar(backgroundColor: Color(0xFFEAF0FF), child: Icon(Icons.sell_outlined, color: AppColors.blue)),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: p.category == null ? null : Text(p.category!),
                        trailing: widget.pickMode
                            ? Text(formatAmount(p.price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(formatAmount(p.price), style: const TextStyle(fontWeight: FontWeight.w800)),
                                PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'edit') _edit(p);
                                    if (v == 'delete') await state.deleteProduct(p.id!);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                                  ],
                                ),
                              ]),
                        onTap: widget.pickMode ? () => Navigator.pop(context, p) : () => _edit(p),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
