import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import 'app_format.dart';

/// Jenis nominal. Warna tidak pernah jadi satu-satunya penanda: pemasukan
/// selalu diawali "+", pengeluaran selalu diawali "−".
enum AmountKind { income, expense, neutral }

/// Ukuran nominal, dipetakan ke gaya `AppTypography.amount*` (tabular figures).
enum AmountSize { display, large, medium, small }

/// Teks nominal rupiah: "+Rp 25.000", "−Rp 25.000", atau "Rp 25.000".
///
/// Screen reader membaca "Pemasukan 25.000 rupiah" / "Pengeluaran 25.000 rupiah".
/// [amount] boleh negatif hanya untuk [AmountKind.neutral] (mis. saldo minus);
/// untuk income/expense tanda ditentukan oleh [kind], bukan oleh nilai.
class AmountText extends StatelessWidget {
  const AmountText(
    this.amount, {
    super.key,
    this.kind = AmountKind.neutral,
    this.size = AmountSize.medium,
    this.color,
    this.fontWeight,
    this.textAlign,
    this.semanticsPrefix,
    this.semanticsAmount,
  });

  final num amount;
  final AmountKind kind;
  final AmountSize size;

  /// Override warna (mis. teks di atas kartu saldo berwarna brand).
  final Color? color;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;

  /// Awalan label semantik, mis. "Saldo total". Default mengikuti [kind].
  final String? semanticsPrefix;

  /// Nilai yang dibacakan screen reader bila berbeda dari yang tampil
  /// (mis. saat count-up berjalan, dibacakan nilai akhirnya).
  final num? semanticsAmount;

  /// Teks tampil, mis. "+Rp 25.000".
  static String format(num amount, AmountKind kind) => '${_sign(amount, kind)}${AppFormat.rupiah(amount)}';

  /// Label semantik, mis. "Pengeluaran 25.000 rupiah".
  static String semanticsFor(num amount, AmountKind kind, {String? prefix}) {
    final spoken = AppFormat.spokenRupiah(amount);
    final minus = kind == AmountKind.neutral && amount.round() < 0 ? 'minus ' : '';
    final p =
        prefix ??
        switch (kind) {
          AmountKind.income => 'Pemasukan'.tr,
          AmountKind.expense => 'Pengeluaran'.tr,
          AmountKind.neutral => null,
        };
    return [?p, '$minus$spoken'].join(' ');
  }

  static String _sign(num amount, AmountKind kind) => switch (kind) {
    AmountKind.income => '+',
    AmountKind.expense => AppFormat.minus,
    AmountKind.neutral => amount.round() < 0 ? AppFormat.minus : '',
  };

  static TextStyle styleFor(AmountSize size) => switch (size) {
    AmountSize.display => AppTypography.amountDisplay,
    AmountSize.large => AppTypography.amountLarge,
    AmountSize.medium => AppTypography.amountMedium,
    AmountSize.small => AppTypography.amountSmall,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.components.amountText;
    final resolved =
        color ??
        switch (kind) {
          AmountKind.income => t.income,
          AmountKind.expense => t.expense,
          AmountKind.neutral => t.neutral,
        };
    return Semantics(
      label: semanticsFor(semanticsAmount ?? amount, kind, prefix: semanticsPrefix),
      excludeSemantics: true,
      child: Text(
        format(amount, kind),
        textAlign: textAlign,
        maxLines: 1,
        softWrap: false,
        style: styleFor(size).copyWith(color: resolved, fontWeight: fontWeight),
      ),
    );
  }
}
