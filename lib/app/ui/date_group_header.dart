import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import 'amount_text.dart';

/// Header tanggal yang lengket di daftar transaksi, dengan selisih harian di kanan.
class DateGroupHeader extends StatelessWidget {
  const DateGroupHeader({super.key, required this.label, required this.net});

  final String label;

  /// Pemasukan dikurangi pengeluaran di hari itu.
  final double net;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s16, AppSpacing.page, AppSpacing.s8),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(label, style: context.text.titleSmall?.copyWith(color: c.inkMuted)),
              ),
            ),
            AmountText(net, size: AmountSize.small, color: c.inkMuted, semanticsPrefix: 'Selisih'.tr),
          ],
        ),
      ),
    );
  }
}
