import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'amount_text.dart';
import 'category_blob.dart';
import 'confirm_dialog.dart';

/// Baris transaksi dengan tinggi fleksibel: blob kategori, judul + kategori
/// (+ catatan opsional), dan nominal bertanda di kanan.
///
/// Jika [onDelete] diisi, baris bisa digeser ke kiri untuk menghapus.
/// Konfirmasi memakai [confirmDelete] atau, bila null, [ConfirmDialog] bawaan.
/// Screen reader mendapat aksi "Hapus" sebagai pengganti gestur geser.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.title,
    required this.amount,
    required this.kind,
    required this.categoryIcon,
    required this.categoryColor,
    this.categoryLabel,
    this.note,
    this.dateLabel,
    this.onTap,
    this.onDelete,
    this.confirmDelete,
    this.dismissKey,
  });

  final String title;
  final num amount;
  final AmountKind kind;
  final String categoryIcon;
  final Color categoryColor;

  /// Nama kategori, tampil di bawah judul.
  final String? categoryLabel;
  final String? note;

  /// Keterangan waktu kecil di bawah nominal, mis. "28 Sep".
  final String? dateLabel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Future<bool> Function()? confirmDelete;

  /// Kunci unik untuk [Dismissible] (mis. id transaksi). Wajib bila [onDelete] diisi.
  final Key? dismissKey;

  Future<bool> _confirm(BuildContext context) =>
      confirmDelete?.call() ??
      ConfirmDialog.show(
        context,
        title: 'Hapus transaksi ini?'.tr,
        message: 'Catatan "@title" akan dihapus permanen dan tidak bisa dikembalikan.'.trParams({'title': title}),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final subtitle = [?categoryLabel, ?note].where((s) => s.isNotEmpty).join(' · ');

    final tile = Material(
      color: c.surfaceContainerLowest,
      borderRadius: AppRadius.cardAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
            child: Row(
              children: [
                CategoryBlob(iconAsset: categoryIcon, color: categoryColor),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(color: c.ink)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AmountText(amount, kind: kind),
                    if (dateLabel != null) Text(dateLabel!, style: t.bodySmall?.copyWith(color: c.inkMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onDelete == null) return tile;

    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Hapus'.tr): () async {
          if (await _confirm(context)) onDelete!();
        },
      },
      child: Dismissible(
        key: dismissKey ?? ValueKey('$title|$amount|$dateLabel'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirm(context),
        onDismissed: (_) => onDelete!(),
        background: DecoratedBox(
          decoration: BoxDecoration(color: c.dangerContainer, borderRadius: AppRadius.cardAll),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Hapus'.tr, style: t.labelLarge?.copyWith(color: c.onDangerContainer)),
                  const SizedBox(width: AppSpacing.s8),
                  Icon(AppIcons.trash, color: c.onDangerContainer, semanticLabel: 'Hapus'.tr),
                ],
              ),
            ),
          ),
        ),
        child: tile,
      ),
    );
  }
}
