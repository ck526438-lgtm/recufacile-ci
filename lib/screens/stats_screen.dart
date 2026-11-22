import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ticket.dart';

enum _Period { jour, semaine, mois }

/// Statistiques gratuites : recettes jour / semaine / mois, nombre de reçus,
/// répartition par mode de paiement (section 11).
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _Stats {
  _Stats(this.total, this.count, this.byPayment, this.daily, this.allTime);
  final int total;
  final int count;
  final Map<PaymentMethod, int> byPayment;
  final Map<DateTime, int> daily;
  final int allTime;
}

class _StatsScreenState extends State<StatsScreen> {
  _Period _period = _Period.jour;

  (DateTime, DateTime) _bounds() {
    final now = DateTime.now();
    return switch (_period) {
      _Period.jour => (startOfDay(now), startOfDay(now).add(const Duration(days: 1))),
      _Period.semaine => (startOfWeek(now), startOfWeek(now).add(const Duration(days: 7))),
      _Period.mois => (startOfMonth(now), DateTime(now.year, now.month + 1)),
    };
  }

  Future<_Stats> _load(AppState s) async {
    final (from, to) = _bounds();
    final today = startOfDay(DateTime.now());
    final chartFrom = today.subtract(const Duration(days: 6));
    return _Stats(
      await s.db.salesTotal(from, to),
      await s.db.receiptCount(from: from, to: to, validOnly: true),
      await s.db.salesByPayment(from, to),
      await s.db.dailySales(chartFrom, today.add(const Duration(days: 1))),
      await s.db.receiptCount(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cur = state.merchant!.currency;
    final label = switch (_period) {
      _Period.jour => 'VENTES DU JOUR',
      _Period.semaine => 'VENTES DE LA SEMAINE',
      _Period.mois => 'VENTES DU MOIS',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Mes ventes')),
      body: FutureBuilder<_Stats>(
        key: ValueKey('${state.revision}-$_period'),
        future: _load(state),
        builder: (context, snap) {
          final s = snap.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              SegmentedButton<_Period>(
                segments: const [
                  ButtonSegment(value: _Period.jour, label: Text('Jour')),
                  ButtonSegment(value: _Period.semaine, label: Text('Semaine')),
                  ButtonSegment(value: _Period.mois, label: Text('Mois')),
                ],
                selected: {_period},
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.white,
                  selectedBackgroundColor: AppColors.blue,
                  selectedForegroundColor: Colors.white,
                ),
                onSelectionChanged: (v) => setState(() => _period = v.first),
              ),
              const SizedBox(height: 18),
              ClipPath(
                clipper: const ScallopClipper(count: 6),
                child: Container(
                  decoration: const BoxDecoration(gradient: AppColors.ticketGradient),
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      color: AppColors.ink,
                      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                    ),
                    const SizedBox(height: 18),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('${formatAmount(s?.total ?? 0)} $cur',
                          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -1)),
                    ),
                    const Divider(color: AppColors.ink, thickness: 1.4, height: 22),
                    Row(children: [
                      Expanded(child: TicketField(label: 'reçus valides', value: '${s?.count ?? 0}')),
                      TicketField(label: 'total créés', value: '${s?.allTime ?? 0}', end: true),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              _Card(
                title: '7 derniers jours',
                child: s == null ? const SizedBox(height: 150) : _WeekChart(daily: s.daily),
              ),
              const SizedBox(height: 14),
              _Card(
                title: 'Répartition par mode de paiement',
                child: s == null || s.byPayment.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text('Aucune vente sur la période.', style: TextStyle(color: AppColors.muted)),
                      )
                    : Column(children: _paymentBars(s.byPayment, cur)),
              ),
              const SizedBox(height: 10),
              const Text('Les reçus annulés ou corrigés ne sont pas comptés.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _paymentBars(Map<PaymentMethod, int> data, String cur) {
    final total = data.values.fold(0, (a, b) => a + b);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) {
      final ratio = total == 0 ? 0.0 : e.value / total;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(e.key.label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('${formatMoney(e.value, cur)} · ${(ratio * 100).round()} %', style: const TextStyle(color: AppColors.muted)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0xFFEDF1F7),
              valueColor: const AlwaysStoppedAnimation(AppColors.blue),
            ),
          ),
        ]),
      );
    }).toList();
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.daily});
  final Map<DateTime, int> daily;

  static const _days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final today = startOfDay(DateTime.now());
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final values = days.map((d) => daily[d] ?? 0).toList();
    final max = values.fold(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final v = values[i];
          final h = max == 0 ? 4.0 : 4 + 110 * v / max;
          final isToday = i == 6;
          return Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (v > 0)
                FittedBox(
                  child: Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k' : '$v',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                ),
              const SizedBox(height: 4),
              Container(
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  gradient: isToday ? null : AppColors.brandGradient,
                  color: isToday ? AppColors.lime : null,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 6),
              Text(_days[days[i].weekday - 1],
                  style: TextStyle(fontWeight: isToday ? FontWeight.w800 : FontWeight.w500, color: isToday ? AppColors.ink : AppColors.muted)),
            ]),
          );
        }),
      ),
    );
  }
}
