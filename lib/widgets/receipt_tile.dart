import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final ReceiptStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ReceiptStatus.valide => AppColors.success,
      ReceiptStatus.annule => AppColors.danger,
      ReceiptStatus.corrige => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(status.label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }
}

/// Ligne de reçu dans les listes : numéro, client, date, montant, statut.
class ReceiptTile extends StatelessWidget {
  const ReceiptTile({super.key, required this.receipt, required this.currency, required this.onTap});

  final Receipt receipt;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final inactive = r.status != ReceiptStatus.valide;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: inactive ? null : AppColors.brandGradient,
                color: inactive ? const Color(0xFFEDEFF3) : null,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.receipt_long, color: inactive ? AppColors.muted : Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(r.customerName,
                        overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  if (inactive) ...[const SizedBox(width: 6), StatusBadge(r.status)],
                ]),
                const SizedBox(height: 2),
                Text('${r.number} · ${formatDate(r.createdAt)} ${formatTime(r.createdAt)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatAmount(r.total),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    decoration: inactive ? TextDecoration.lineThrough : null,
                    color: inactive ? AppColors.muted : AppColors.ink,
                  )),
              Text(r.paymentMethod.label, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
            ]),
          ]),
        ),
      ),
    );
  }
}
