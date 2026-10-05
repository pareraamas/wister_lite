import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import 'app_illustration.dart';

/// Empty state = ilustrasi + judul + satu kalimat + satu tombol.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.illustration,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustrationSize = 160,
  });

  /// Beranda: riwayat kosong.
  EmptyState.beranda({super.key, this.onAction, this.illustrationSize = 160})
    : illustration = AppIllustrations.emptyBeranda,
      title = 'Belum ada catatan'.tr,
      message = 'Yuk, catat pengeluaran pertamamu.'.tr,
      actionLabel = 'Tambah'.tr;

  /// Anggaran: belum ada budget bulan ini.
  EmptyState.anggaran({super.key, this.onAction, this.illustrationSize = 160})
    : illustration = AppIllustrations.emptyAnggaran,
      title = 'Belum ada anggaran'.tr,
      message = 'Belum ada anggaran bulan ini.'.tr,
      actionLabel = 'Atur anggaran'.tr;

  /// Statistik: belum ada transaksi bulan ini.
  EmptyState.statistik({super.key, this.onAction, this.illustrationSize = 160})
    : illustration = AppIllustrations.emptyStatistik,
      title = 'Bulan ini masih bersih'.tr,
      message = 'Belum ada transaksi untuk dihitung.'.tr,
      actionLabel = 'Tambah transaksi'.tr;

  /// Kelola Kategori: belum ada kategori.
  EmptyState.kategori({super.key, this.onAction, this.illustrationSize = 160})
    : illustration = AppIllustrations.emptyKategori,
      title = 'Kategorimu kosong'.tr,
      message = 'Buat kategori agar catatanmu lebih rapi.'.tr,
      actionLabel = 'Buat kategori'.tr;

  final String illustration;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double illustrationSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final reduced = AppMotion.reduced(context);

    Widget art = AppIllustration(illustration, size: illustrationSize);
    if (!reduced) {
      art = art
          .animate()
          .fadeIn(duration: AppMotion.long, curve: AppMotion.standard)
          .scaleXY(begin: 0.92, end: 1, duration: AppMotion.long, curve: AppMotion.emphasized);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32, vertical: AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            art,
            const SizedBox(height: AppSpacing.s16),
            Semantics(
              header: true,
              child: Text(title, textAlign: TextAlign.center, style: t.titleLarge?.copyWith(color: c.ink)),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(message, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: c.inkMuted)),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.s24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
