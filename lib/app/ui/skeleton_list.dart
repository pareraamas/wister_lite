import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';

/// Bentuk kerangka yang meniru konten aslinya.
enum SkeletonShape {
  /// Seperti `TransactionTile`: blob, dua baris teks, nominal.
  tile,

  /// Seperti baris anggaran: judul, bar, keterangan.
  budget,

  /// Seperti `BalanceCard`.
  card,
}

/// Pengganti spinner layar penuh: kerangka mengikuti bentuk konten dengan
/// shimmer halus. Shimmer mati saat animasi sistem dimatikan.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.shape = SkeletonShape.tile,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
    this.semanticLabel,
  });

  final int itemCount;
  final SkeletonShape shape;
  final EdgeInsetsGeometry padding;
  /// Null = "Memuat data" (diterjemahkan).
  final String? semanticLabel;

  /// Satu putaran shimmer (1,2 detik).
  static final Duration period = AppMotion.long * 3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget list = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.stack),
            _SkeletonItem(shape: shape, index: i),
          ],
        ],
      ),
    );

    if (!AppMotion.reduced(context)) {
      list = list
          .animate(onPlay: (ctrl) => ctrl.repeat())
          .shimmer(duration: period, curve: AppMotion.emphasized, color: c.surfaceContainerLowest.withValues(alpha: 0.7));
    }

    return Semantics(label: semanticLabel ?? 'Memuat data'.tr, liveRegion: true, child: ExcludeSemantics(child: list));
  }
}

class _SkeletonItem extends StatelessWidget {
  const _SkeletonItem({required this.shape, required this.index});

  final SkeletonShape shape;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Variasi lebar agar tidak terasa seperti pola cetakan.
    final w = const [0.62, 0.44, 0.55, 0.38, 0.5][index % 5];

    return switch (shape) {
      SkeletonShape.tile => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        decoration: BoxDecoration(color: c.surfaceContainerLowest, borderRadius: AppRadius.cardAll),
        child: Row(
          children: [
            const SkeletonBox.circle(size: 40),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(widthFactor: w + 0.2, child: const SkeletonBox(height: 14)),
                  const SizedBox(height: AppSpacing.s8),
                  FractionallySizedBox(widthFactor: w, child: const SkeletonBox(height: 12)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            const SkeletonBox(width: 72, height: 14),
          ],
        ),
      ),
      SkeletonShape.budget => Container(
        padding: const EdgeInsets.all(AppSpacing.card),
        decoration: BoxDecoration(color: c.surfaceContainerLowest, borderRadius: AppRadius.cardAll),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonBox.circle(size: 32),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: w,
                    child: const SkeletonBox(height: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            const SkeletonBox(height: 8),
            const SizedBox(height: AppSpacing.s8),
            FractionallySizedBox(widthFactor: w, child: const SkeletonBox(height: 12)),
          ],
        ),
      ),
      SkeletonShape.card => Container(
        height: 132,
        padding: const EdgeInsets.all(AppSpacing.s20),
        decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: AppRadius.cardAll),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 96, height: 14, strong: true),
            SizedBox(height: AppSpacing.s16),
            SkeletonBox(width: 220, height: 36, strong: true),
          ],
        ),
      ),
    };
  }
}

/// Kotak kerangka dasar (sudut 8, atau lingkaran).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.strong = false}) : _circle = false;

  const SkeletonBox.circle({super.key, required double size, this.strong = false})
    : width = size,
      height = size,
      _circle = true;

  final double? width;
  final double height;

  /// Warna lebih pekat, untuk kerangka di atas permukaan yang lebih gelap.
  final bool strong;
  final bool _circle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: strong ? c.surfaceContainerLowest.withValues(alpha: 0.6) : c.surfaceContainerHighest,
        borderRadius: _circle ? AppRadius.fullAll : AppRadius.chipAll,
      ),
    );
  }
}
