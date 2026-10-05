import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'app_format.dart';

/// Status anggaran berdasarkan rasio terpakai / budget.
enum BudgetStatus {
  /// Di bawah ambang peringatan (80%).
  safe,

  /// 80%–100%: hampir habis.
  warning,

  /// Di atas 100%: lewat anggaran.
  over,
}

/// Progress anggaran dengan penanda pace: garis tegak = posisi hari ini di
/// bulan berjalan. Bar yang melewatinya berarti belanja lebih cepat dari jadwal.
///
/// Warna bar dari `budgetProgress.colorFor` (brand → amber di 80% → danger di
/// atas 100%), selalu disertai teks status dan ikon.
class BudgetProgress extends StatelessWidget {
  /// [ratio] = terpakai / budget (boleh > 1). [used] dan [budget] opsional;
  /// bila keduanya diisi, tampil baris "Rp x dari Rp y" dan sisa nominal.
  const BudgetProgress({
    super.key,
    required this.ratio,
    this.pace,
    this.label,
    this.used,
    this.budget,
    this.showDetails = true,
    this.showRemaining = true,
  });

  /// Versi praktis: rasio dihitung dari [used] dan [budget].
  BudgetProgress.fromAmounts({
    super.key,
    required num this.used,
    required num this.budget,
    this.pace,
    this.label,
    this.showDetails = true,
    this.showRemaining = true,
  }) : ratio = ratioOf(used, budget);

  /// Terpakai / budget. Budget 0 dengan pemakaian = `double.infinity` (lewat).
  final double ratio;

  /// Posisi hari ini di bulan (0–1). Null = tanpa penanda (bulan lampau/depan).
  /// Pakai [BudgetProgress.paceOf] untuk bulan berjalan.
  final double? pace;

  /// Nama kategori di atas bar.
  final String? label;

  /// Nominal terpakai & budget untuk baris detail (opsional).
  final num? used;
  final num? budget;

  /// Tampilkan baris detail/status di bawah bar.
  final bool showDetails;

  /// Tampilkan sisa/lewat di baris detail. Matikan bila sisa sudah tampil
  /// sebagai angka utama di dekatnya agar tidak dobel.
  final bool showRemaining;

  /// Kunci bagian bar yang terisi (untuk test).
  static const fillKey = ValueKey('budget-progress-fill');

  /// Rasio terpakai; budget 0 dengan pemakaian dianggap lewat.
  static double ratioOf(num used, num budget) {
    if (budget <= 0) return used > 0 ? double.infinity : 0;
    return used / budget;
  }

  static BudgetStatus statusOf(double ratio, {double warningThreshold = 0.8}) {
    if (ratio > 1) return BudgetStatus.over;
    if (ratio >= warningThreshold) return BudgetStatus.warning;
    return BudgetStatus.safe;
  }

  /// Pace hari [date] di bulannya: 28 Sep → 28/30.
  static double paceOf(DateTime date) {
    final days = DateUtils.getDaysInMonth(date.year, date.month);
    return date.day / days;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final tok = context.components.budgetProgress;
    final status = statusOf(ratio, warningThreshold: tok.warningThreshold);
    final barColor = tok.colorFor(ratio);
    final percent = ratio.isFinite ? (ratio * 100).round() : 100;
    final hasAmounts = used != null && budget != null;
    final remaining = hasAmounts ? budget! - used! : 0;

    final (statusText, statusColor, statusIcon) = switch (status) {
      BudgetStatus.safe => (hasAmounts ? 'Sisa @amount'.trParams({'amount': AppFormat.rupiah(remaining)}) : '@percent% terpakai'.trParams({'percent': '$percent'}), c.inkMuted, null),
      BudgetStatus.warning => (hasAmounts ? 'Sisa @amount'.trParams({'amount': AppFormat.rupiah(remaining)}) : 'Hampir habis'.tr, c.warning, AppIconsFill.warning),
      BudgetStatus.over => (hasAmounts ? 'Lewat @amount'.trParams({'amount': AppFormat.rupiah(remaining)}) : 'Lewat anggaran'.tr, c.danger, AppIconsFill.warningOctagon),
    };

    final statusSpoken = switch (status) {
      BudgetStatus.safe => hasAmounts ? 'aman, sisa @amount'.trParams({'amount': AppFormat.spokenRupiah(remaining)}) : 'aman'.tr,
      BudgetStatus.warning => hasAmounts ? 'hampir habis, sisa @amount'.trParams({'amount': AppFormat.spokenRupiah(remaining)}) : 'hampir habis'.tr,
      BudgetStatus.over => hasAmounts ? 'lewat anggaran @amount'.trParams({'amount': AppFormat.spokenRupiah(remaining)}) : 'lewat anggaran'.tr,
    };
    final semantics = [
      ?label,
      if (hasAmounts) 'terpakai @used dari @budget'.trParams({'used': AppFormat.digits(used!), 'budget': AppFormat.spokenRupiah(budget!)}),
      '@percent persen'.trParams({'percent': '$percent'}),
      statusSpoken,
      if (pace != null) 'hari ini @pace persen bulan berjalan'.trParams({'pace': '${(pace! * 100).round()}'}),
    ].join(', ');

    final statusRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (statusIcon != null) ...[Icon(statusIcon, size: 16, color: statusColor), const SizedBox(width: AppSpacing.s4)],
        Flexible(
          child: Text(statusText, style: AppTypography.amountSmall.copyWith(color: statusColor)),
        ),
      ],
    );

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(color: c.ink),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text('$percent%', style: AppTypography.amountSmall.copyWith(color: status == BudgetStatus.safe ? c.inkMuted : statusColor)),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          _Bar(ratio: ratio, pace: pace, color: barColor, tokens: tok),
          if (showDetails) ...[
            const SizedBox(height: AppSpacing.s8),
            if (hasAmounts && !showRemaining)
              Text(
                'Terpakai @used dari @budget'.trParams({'used': AppFormat.rupiah(used!), 'budget': AppFormat.rupiah(budget!)}),
                style: AppTypography.amountSmall.copyWith(color: c.inkMuted, fontWeight: FontWeight.w500),
              )
            else if (hasAmounts)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s4,
                children: [
                  Text(
                    '@used dari @budget'.trParams({'used': AppFormat.rupiah(used!), 'budget': AppFormat.rupiah(budget!)}),
                    style: AppTypography.amountSmall.copyWith(color: c.inkMuted, fontWeight: FontWeight.w500),
                  ),
                  statusRow,
                ],
              )
            else
              statusRow,
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.ratio, required this.pace, required this.color, required this.tokens});

  final double ratio;
  final double? pace;
  final Color color;
  final BudgetProgressTokens tokens;

  @override
  Widget build(BuildContext context) {
    final h = tokens.height;
    const markerOverhang = AppSpacing.s4;
    final fill = ratio.isFinite ? ratio.clamp(0.0, 1.0) : 1.0;
    final duration = AppMotion.of(context, AppMotion.long);

    return SizedBox(
      height: h + markerOverhang * 2,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            alignment: AlignmentDirectional.centerStart,
            children: [
              Container(
                height: h,
                decoration: BoxDecoration(color: tokens.track, borderRadius: AppRadius.fullAll),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fill),
                duration: duration,
                curve: AppMotion.emphasized,
                builder: (_, v, _) => AnimatedContainer(
                  key: BudgetProgress.fillKey,
                  duration: duration,
                  width: w * v,
                  height: h,
                  decoration: BoxDecoration(color: color, borderRadius: AppRadius.fullAll),
                ),
              ),
              if (pace != null)
                PositionedDirectional(
                  start: (w * pace!.clamp(0.0, 1.0) - 1).clamp(0.0, w - 2),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(color: tokens.paceMarker, borderRadius: AppRadius.fullAll),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
