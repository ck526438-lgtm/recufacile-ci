import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/receipt_tile.dart';
import '../widgets/ticket.dart';
import 'create_receipt_screen.dart';

/// Affichage d'un reçu au format « ticket » (maquette 2) + actions.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.receiptId, this.justCreated = false});

  final int receiptId;
  final bool justCreated;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.justCreated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reçu enregistré ✓')));
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action impossible : $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Receipt r) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Annuler ${r.number} ?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Le reçu restera visible dans l\'historique avec le statut « Annulé » et ne sera plus compté dans les ventes.'),
          const SizedBox(height: 12),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'Motif (facultatif)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Retour')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler le reçu'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppState>().cancelReceipt(r.id!, reason: reason.text.trim());
    }
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final m = state.merchant!;
    return FutureBuilder<Receipt?>(
      key: ValueKey(state.revision),
      future: state.db.getReceipt(widget.receiptId),
      builder: (context, snap) {
        final r = snap.data;
        return Scaffold(
          backgroundColor: AppColors.blueDeep,
          body: BlueScaffoldBody(
            child: SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Row(children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_ios_new,
                      size: 46,
                      background: Colors.white.withValues(alpha: 0.15),
                      onTap: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text('Reçu', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    if (r != null)
                      PopupMenuButton<String>(
                        icon: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.more_horiz, color: Colors.white),
                        ),
                        onSelected: (v) {
                          if (v == 'correct') {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => CreateReceiptScreen(correcting: r)),
                            );
                          } else if (v == 'cancel') {
                            _cancel(r);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'correct',
                            enabled: r.status == ReceiptStatus.valide,
                            child: const ListTile(leading: Icon(Icons.edit_outlined), title: Text('Corriger')),
                          ),
                          PopupMenuItem(
                            value: 'cancel',
                            enabled: r.status == ReceiptStatus.valide,
                            child: const ListTile(leading: Icon(Icons.block, color: AppColors.danger), title: Text('Annuler')),
                          ),
                        ],
                      )
                    else
                      const SizedBox(width: 46),
                  ]),
                ),
                Expanded(
                  child: r == null
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                          child: _ReceiptTicket(receipt: r, merchant: m),
                        ),
                ),
                if (r != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Row(children: [
                      RoundIconButton(
                        icon: Icons.print_outlined,
                        size: 56,
                        tooltip: 'Imprimer / Enregistrer en PDF',
                        onTap: () => _run(() => ShareService.printOrSave(r, m)),
                      ),
                      const SizedBox(width: 10),
                      RoundIconButton(
                        icon: Icons.download_outlined,
                        size: 56,
                        tooltip: 'Enregistrer sur le téléphone',
                        onTap: () => _run(() async {
                          final messenger = ScaffoldMessenger.of(context);
                          final File f = await PdfService.saveToDevice(r, m);
                          messenger.showSnackBar(SnackBar(content: Text('PDF enregistré : ${f.uri.pathSegments.last}')));
                        }),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PillActionBar(
                          label: _busy ? 'Préparation…' : 'Partager (WhatsApp…)',
                          icon: Icons.share,
                          onTap: () => _run(() => ShareService.sharePdf(r, m)),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _ReceiptTicket extends StatelessWidget {
  const _ReceiptTicket({required this.receipt, required this.merchant});

  final Receipt receipt;
  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final m = merchant;
    final cur = m.currency;
    return TicketCard(
      notchOffsets: const [0.2, 0.42],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // En-tête dégradé (équivalent de l'illustration de la maquette).
        Container(
          height: 118,
          decoration: BoxDecoration(gradient: AppColors.ticketGradient, borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            if (m.logoPath != null && File(m.logoPath!).existsSync())
              Container(
                width: 62,
                height: 62,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Image.file(File(m.logoPath!), fit: BoxFit.cover),
              ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: AppColors.ink,
                  child: const Text('REÇU DE VENTE',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                ),
                const SizedBox(height: 8),
                Text(m.businessName.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.ink, height: 1.05)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(m.phone.isEmpty ? m.address : 'Contact : ${m.phone}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        if (r.status != ReceiptStatus.valide) ...[
          const SizedBox(height: 10),
          Center(child: StatusBadge(r.status)),
          if (r.correctedBy != null)
            Center(child: Text('Remplacé par ${r.correctedBy}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5))),
        ],
        if (r.correctsNumber != null)
          Center(child: Text('Corrige le reçu ${r.correctsNumber}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5))),
        const DashedDivider(),
        Row(children: [
          Expanded(child: TicketField(label: 'Date', value: formatDate(r.createdAt))),
          TicketField(label: 'Heure', value: formatTime(r.createdAt), end: true),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TicketField(label: 'Client', value: r.customerName)),
          TicketField(label: 'N°', value: r.number, end: true),
        ]),
        const DashedDivider(),
        const Row(children: [
          Expanded(flex: 5, child: Text('Produit', style: TextStyle(color: AppColors.muted, fontSize: 12.5))),
          Expanded(flex: 1, child: Text('Qté', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12.5))),
          Expanded(flex: 3, child: Text('Prix', textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted, fontSize: 12.5))),
        ]),
        const SizedBox(height: 6),
        for (final i in r.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${formatAmount(i.unitPrice)} / u', style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                ]),
              ),
              Expanded(flex: 1, child: Text('${i.quantity}', textAlign: TextAlign.center)),
              Expanded(
                flex: 3,
                child: Text(formatAmount(i.lineTotal), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        const DashedDivider(),
        _line('Sous-total', formatMoney(r.subtotal, cur)),
        _line('Remise', formatMoney(r.discount, cur)),
        const SizedBox(height: 6),
        Row(children: [
          const Expanded(child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
          Text(formatMoney(r.total, cur),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: AppColors.blue,
                decoration: r.status == ReceiptStatus.valide ? null : TextDecoration.lineThrough,
              )),
        ]),
        const SizedBox(height: 4),
        _line('Paiement', r.paymentMethod.label),
        if (r.note != null && r.note!.isNotEmpty) _line('Note', r.note!),
        const DashedDivider(),
        Text(m.thankYouMessage, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 14),
        ReceiptBarcode(data: r.number),
      ]),
    );
  }

  Widget _line(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(a, style: const TextStyle(color: AppColors.muted))),
          Flexible(child: Text(b, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
