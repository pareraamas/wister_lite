import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import 'amount_text.dart';
import 'pressable_scale.dart';

/// Kartu saldo utama: label jelas + angka display yang count-up 600 ms,
/// dengan pola koin halus di pojok kanan atas.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.amount,
    this.label,
    this.caption,
    this.trailing,
    this.footer,
    this.onTap,
    this.animate = true,
  });

  final num amount;

  /// Null = "Saldo total" (diterjemahkan).
  final String? label;

  /// Kalimat penjelas kecil di bawah angka, mis. "Semua pemasukan dikurangi pengeluaran".
  final String? caption;

  /// Widget kecil di pojok kanan atas (mis. ilustrasi mikro).
  final Widget? trailing;

  /// Isi tambahan di bawah angka (mis. ringkasan Masuk/Keluar).
  final Widget? footer;
  final VoidCallback? onTap;

  /// Count-up dari 0 saat pertama tampil, lalu dari nilai lama ke nilai baru.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final t = context.components.balanceCard;
    final label = this.label ?? 'Saldo total'.tr;
    final reduced = !animate || AppMotion.reduced(context);

    Widget amountText(num value) => AmountText(
      value,
      size: AmountSize.display,
      color: t.foreground,
      semanticsPrefix: label,
      semanticsAmount: amount,
    );

    final number = reduced
        ? amountText(amount)
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: amount.toDouble()),
            duration: AppMotion.countUp,
            curve: AppMotion.decelerate,
            builder: (_, v, _) => amountText(v),
          );

    final content = Padding(
      padding: EdgeInsets.all(t.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: context.text.labelLarge?.copyWith(color: t.foregroundMuted)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: number),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(caption!, style: context.text.bodySmall?.copyWith(color: t.foregroundMuted)),
          ],
          if (footer != null) ...[const SizedBox(height: AppSpacing.s16), footer!],
        ],
      ),
    );

    final radius = BorderRadius.circular(t.radius);
    return PressableScale(
      enabled: onTap != null,
      child: Material(
        color: t.background,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: t.pattern,
          highlightColor: t.pattern,
          child: CustomPaint(painter: CoinPatternPainter(t.pattern), child: content),
        ),
      ),
    );
  }
}

/// Tiga koin line-art bertumpuk di pojok kanan atas. Sengaja sangat halus
/// (warna `balanceCard.pattern`) agar tidak bersaing dengan angka.
class CoinPatternPainter extends CustomPainter {
  const CoinPatternPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    void coin(Offset c, double r) {
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r * 0.7, stroke);
      // Kilau kecil ala gambar tangan.
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.45), math.pi * 1.1, math.pi * 0.45, false, stroke);
    }

    final w = size.width;
    coin(Offset(w - 36, 30), 46);
    coin(Offset(w - 104, 18), 22);
    coin(Offset(w + 6, 104), 34);

    // Kilap bintang empat sudut.
    final s = Offset(w - 118, 62);
    const k = 6.0;
    canvas.drawLine(s.translate(0, -k), s.translate(0, k), stroke);
    canvas.drawLine(s.translate(-k, 0), s.translate(k, 0), stroke);
  }

  @override
  bool shouldRepaint(CoinPatternPainter oldDelegate) => oldDelegate.color != color;
}
