import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/models.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/receipt_tile.dart';
import '../widgets/ticket.dart';
import 'create_receipt_screen.dart';
import 'help_screen.dart';
import 'receipt_screen.dart';
import 'receipts_screen.dart';
import 'shop_screen.dart';
import 'stats_screen.dart';

/// Tableau de bord + menu principal (sections 6.1 et 15).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final m = state.merchant!;
    final now = DateTime.now();
    final today = startOfDay(now);
    final tomorrow = today.add(const Duration(days: 1));

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_Dash>(
          key: ValueKey(state.revision),
          future: () async {
            final db = state.db;
            return _Dash(
              todayTotal: await db.salesTotal(today, tomorrow),
              todayCount: await db.receiptCount(from: today, to: tomorrow, validOnly: true),
              allCount: await db.receiptCount(),
              latest: await db.searchReceipts(limit: 5),
            );
          }(),
          builder: (context, snap) {
            final d = snap.data ?? const _Dash();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
              children: [
                Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/icon/icon.png', width: 44)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ReçuFacile CI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      Text(m.businessName, style: const TextStyle(color: AppColors.muted), overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  RoundIconButton(
                    icon: Icons.help_outline,
                    size: 46,
                    tooltip: 'Aide & avis',
                    onTap: () => _open(context, const HelpScreen()),
                  ),
                ]),
                const _UpdateBanner(),
                const SizedBox(height: 22),
                _TodayTicket(total: d.todayTotal, count: d.todayCount, currency: m.currency, date: now),
                const SizedBox(height: 22),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.25,
                  children: [
                    _MenuTile(
                      label: 'Créer un reçu',
                      icon: Icons.receipt_long,
                      primary: true,
                      onTap: () => _open(context, const CreateReceiptScreen()),
                    ),
                    _MenuTile(label: 'Mes reçus', icon: Icons.history, onTap: () => _open(context, const ReceiptsScreen())),
                    _MenuTile(label: 'Mes ventes', icon: Icons.bar_chart_rounded, onTap: () => _open(context, const StatsScreen())),
                    _MenuTile(label: 'Ma boutique', icon: Icons.storefront_outlined, onTap: () => _open(context, const ShopScreen())),
                  ],
                ),
                const SizedBox(height: 26),
                Row(children: [
                  const Expanded(child: Text('Derniers reçus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  Text('${d.allCount} au total', style: const TextStyle(color: AppColors.muted)),
                ]),
                const SizedBox(height: 10),
                if (d.latest.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                    child: const Column(children: [
                      Icon(Icons.receipt_outlined, size: 40, color: AppColors.muted),
                      SizedBox(height: 8),
                      Text('Aucun reçu pour le moment', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('Touchez « Créer un reçu » pour commencer.', style: TextStyle(color: AppColors.muted)),
                    ]),
                  )
                else
                  ...d.latest.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ReceiptTile(
                          receipt: r,
                          currency: m.currency,
                          onTap: () => _open(context, ReceiptScreen(receiptId: r.id!)),
                        ),
                      )),
              ],
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 60,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [BoxShadow(color: Color(0x552563EB), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: PillActionBar(
              label: 'Création rapide d\'un reçu',
              icon: Icons.add,
              onTap: () => _open(context, const CreateReceiptScreen()),
            ),
          ),
        ),
      ),
    );
  }

  static void _open(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

class _Dash {
  const _Dash({this.todayTotal = 0, this.todayCount = 0, this.allCount = 0, this.latest = const []});
  final int todayTotal;
  final int todayCount;
  final int allCount;
  final List<Receipt> latest;
}

/// Carte « Aujourd'hui » au style billet festonné à dégradé (3e maquette).
class _TodayTicket extends StatelessWidget {
  const _TodayTicket({required this.total, required this.count, required this.currency, required this.date});

  final int total;
  final int count;
  final String currency;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const ScallopClipper(),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.ticketGradient),
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: AppColors.ink,
              child: const Text('AUJOURD\'HUI',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)),
            ),
            const Spacer(),
            Text(formatDate(date), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
          ]),
          const SizedBox(height: 22),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatAmount(total),
                style: const TextStyle(fontSize: 46, height: 1, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -1)),
          ),
          const SizedBox(height: 2),
          Text(currency, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.ink)),
          const Divider(color: AppColors.ink, thickness: 1.4, height: 22),
          Row(children: [
            Expanded(
              child: TicketField(
                label: 'reçus',
                value: count == 0 ? '0 reçu créé' : '$count reçu${count > 1 ? 's' : ''} créé${count > 1 ? 's' : ''}',
              ),
            ),
            const Icon(Icons.verified, color: AppColors.ink, size: 30),
          ]),
        ]),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.label, required this.icon, required this.onTap, this.primary = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.blue : Colors.white,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: primary ? AppColors.lime : const Color(0xFFEAF0FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primary ? AppColors.ink : AppColors.blue),
            ),
            const Spacer(),
            Text(label,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: primary ? Colors.white : AppColors.ink)),
          ]),
        ),
      ),
    );
  }
}

/// Bandeau discret affiché quand une nouvelle version est publiée.
class _UpdateBanner extends StatefulWidget {
  const _UpdateBanner();

  @override
  State<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<_UpdateBanner> {
  String? _version;

  @override
  void initState() {
    super.initState();
    UpdateService.availableUpdate(context.read<AppState>().prefs).then((v) {
      if (mounted && v != null) setState(() => _version = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_version == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => openLink(context, AppConfig.downloadUrl),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const CircleAvatar(radius: 20, backgroundColor: AppColors.lime, child: Icon(Icons.system_update, color: AppColors.ink)),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Nouvelle version $_version disponible — touchez pour la télécharger',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                onPressed: () => setState(() => _version = null),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
