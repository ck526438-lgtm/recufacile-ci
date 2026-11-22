import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Forme de ticket : coins arrondis + encoches circulaires sur les côtés
/// aux positions [notchOffsets] (fractions de la hauteur), comme la maquette.
class TicketShape extends ShapeBorder {
  const TicketShape({this.radius = 28, this.notchRadius = 12, this.notchOffsets = const []});

  final double radius;
  final double notchRadius;
  final List<double> notchOffsets;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    var path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final f in notchOffsets) {
      final y = rect.top + rect.height * f;
      final cut = Path()
        ..addOval(Rect.fromCircle(center: Offset(rect.left, y), radius: notchRadius))
        ..addOval(Rect.fromCircle(center: Offset(rect.right, y), radius: notchRadius));
      path = Path.combine(PathOperation.difference, path, cut);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => TicketShape(radius: radius * t, notchRadius: notchRadius * t, notchOffsets: notchOffsets);
}

/// Carte « ticket » blanche avec encoches latérales et ombre douce.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.child, this.notchOffsets = const [0.32, 0.62], this.color = Colors.white, this.padding});

  final Widget child;
  final List<double> notchOffsets;
  final Color color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 6,
      shadowColor: Colors.black26,
      shape: TicketShape(notchOffsets: notchOffsets),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding ?? const EdgeInsets.fromLTRB(22, 22, 22, 18), child: child),
    );
  }
}

/// Ligne pointillée bleue séparant les sections du ticket.
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key, this.color = AppColors.blue, this.height = 22, this.dash = 5, this.gap = 4});

  final Color color;
  final double height;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, c) {
        final count = (c.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => SizedBox(width: dash, height: 1.4, child: DecoratedBox(decoration: BoxDecoration(color: color.withValues(alpha: 0.7)))),
          ),
        );
      }),
    );
  }
}

/// Code-barres du numéro de reçu (Code 128), comme sur les maquettes.
class ReceiptBarcode extends StatelessWidget {
  const ReceiptBarcode({super.key, required this.data, this.height = 64, this.color = AppColors.ink});

  final String data;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BarcodeWidget(barcode: Barcode.code128(), data: data, height: height, drawText: false, color: color),
      const SizedBox(height: 6),
      Text(data, style: const TextStyle(color: AppColors.muted, letterSpacing: 3, fontSize: 12)),
    ]);
  }
}

/// Petit couple libellé gris / valeur en gras (« Date / Sep 5, 2024 »).
class TicketField extends StatelessWidget {
  const TicketField({super.key, required this.label, required this.value, this.end = false, this.valueColor});

  final String label;
  final String value;
  final bool end;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 2),
        Text(value,
            textAlign: end ? TextAlign.right : TextAlign.left,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: valueColor ?? AppColors.ink)),
      ],
    );
  }
}

/// Bord festonné (haut/bas) façon billet découpé — 3e maquette.
class ScallopClipper extends CustomClipper<Path> {
  const ScallopClipper({this.radius = 9, this.count = 7, this.sideNotch = 12});

  final double radius;
  final int count;
  final double sideNotch;

  @override
  Path getClip(Size size) {
    var path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)));
    final cuts = Path();
    final step = size.width / (count + 1);
    for (var i = 1; i <= count; i++) {
      cuts.addOval(Rect.fromCircle(center: Offset(step * i, 0), radius: radius));
      cuts.addOval(Rect.fromCircle(center: Offset(step * i, size.height), radius: radius));
    }
    final y = size.height * 0.36;
    cuts.addOval(Rect.fromCircle(center: Offset(0, y), radius: sideNotch));
    cuts.addOval(Rect.fromCircle(center: Offset(size.width, y), radius: sideNotch));
    path = Path.combine(PathOperation.difference, path, cuts);
    return path;
  }

  @override
  bool shouldReclip(covariant ScallopClipper old) => old.radius != radius || old.count != count;
}

/// Bouton rond noir (maquette 2, en bas à gauche).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap, this.background = AppColors.ink, this.foreground = Colors.white, this.size = 52, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Icon(icon, color: foreground, size: size * 0.44)),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Barre d'action en pilule avec pastille citron vert et chevrons
/// (« Show QR Code  >>> » de la maquette).
class PillActionBar extends StatelessWidget {
  const PillActionBar({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.22),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.ink, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))),
            Text('›››', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 20, letterSpacing: -2)),
            const SizedBox(width: 14),
          ]),
        ),
      ),
    );
  }
}

/// Fond dégradé bleu plein écran, coins arrondis (écran « Ticket » de la maquette).
class BlueScaffoldBody extends StatelessWidget {
  const BlueScaffoldBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.blueDeep, AppColors.blue, Color(0xFF5B8DEF)],
        ),
      ),
      child: child,
    );
  }
}
