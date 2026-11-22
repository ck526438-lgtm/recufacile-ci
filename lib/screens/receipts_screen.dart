import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/receipt_tile.dart';
import 'receipt_screen.dart';

/// Historique : recherche par numéro / client, filtres date, paiement, statut (section 10).
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final _search = TextEditingController();
  DateTimeRange? _range;
  PaymentMethod? _payment;
  ReceiptStatus? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _range,
      helpText: 'Filtrer par date',
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cur = state.merchant!.currency;
    final hasFilters = _range != null || _payment != null || _status != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes reçus')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              fillColor: Colors.white,
              hintText: 'Rechercher par n° ou nom du client',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(_search.clear)),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: _range == null ? 'Date' : '${formatDate(_range!.start)} → ${formatDate(_range!.end)}',
                icon: Icons.calendar_month_outlined,
                active: _range != null,
                onTap: _pickRange,
              ),
              _menuChip<PaymentMethod>(
                label: _payment?.label ?? 'Paiement',
                icon: Icons.payments_outlined,
                active: _payment != null,
                values: PaymentMethod.values,
                labelOf: (p) => p.label,
                onSelected: (p) => setState(() => _payment = p),
              ),
              _menuChip<ReceiptStatus>(
                label: _status?.label ?? 'Statut',
                icon: Icons.flag_outlined,
                active: _status != null,
                values: ReceiptStatus.values,
                labelOf: (s) => s.label,
                onSelected: (s) => setState(() => _status = s),
              ),
              if (hasFilters)
                TextButton(
                  onPressed: () => setState(() {
                    _range = null;
                    _payment = null;
                    _status = null;
                  }),
                  child: const Text('Effacer'),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Receipt>>(
            future: state.db.searchReceipts(
              query: _search.text,
              from: _range == null ? null : startOfDay(_range!.start),
              to: _range == null ? null : startOfDay(_range!.end).add(const Duration(days: 1)),
              payment: _payment,
              status: _status,
            ),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = snap.data!;
              if (list.isEmpty) {
                return const Center(child: Text('Aucun reçu trouvé', style: TextStyle(color: AppColors.muted)));
              }
              final total = list.where((r) => r.countsInSales).fold<int>(0, (s, r) => s + r.total);
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: list.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Text('${list.length} reçu(s) · ${formatMoney(total, cur)} encaissés',
                        style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600));
                  }
                  final r = list[i - 1];
                  return ReceiptTile(
                    receipt: r,
                    currency: cur,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(receiptId: r.id!))),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _menuChip<T>({
    required String label,
    required IconData icon,
    required bool active,
    required List<T> values,
    required String Function(T) labelOf,
    required ValueChanged<T?> onSelected,
  }) {
    return PopupMenuButton<int>(
      onSelected: (i) => onSelected(i < 0 ? null : values[i]),
      itemBuilder: (_) => [
        const PopupMenuItem<int>(value: -1, child: Text('Tous')),
        for (var i = 0; i < values.length; i++) PopupMenuItem<int>(value: i, child: Text(labelOf(values[i]))),
      ],
      child: _FilterChip(label: label, icon: icon, active: active),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.icon, required this.active, this.onTap});

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: active ? AppColors.blue : Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: active ? Colors.white : AppColors.ink),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: active ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600)),
      ]),
    );
    return onTap == null ? chip : GestureDetector(onTap: onTap, child: chip);
  }
}
