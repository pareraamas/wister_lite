import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import 'app_illustration.dart';

/// Satu-satunya dialog konfirmasi hapus di aplikasi: ilustrasi kecil,
/// judul, pesan, lalu "Batal" dan tombol bahaya "Hapus".
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.destructive = true,
    this.illustration,
  });

  final String title;
  final String message;
  /// Null = "Hapus" (diterjemahkan).
  final String? confirmLabel;

  /// Null = "Batal" (diterjemahkan).
  final String? cancelLabel;

  /// True: tombol konfirmasi berwarna bahaya (hapus). False: warna brand.
  final bool destructive;

  /// Null = [AppIllustrations.confirmHapus].
  final String? illustration;

  /// Menampilkan dialog; `true` hanya jika user menekan [confirmLabel].
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    bool destructive = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s24, AppSpacing.s24, AppSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIllustration(illustration ?? AppIllustrations.confirmHapus, size: 64),
            const SizedBox(height: AppSpacing.s16),
            Semantics(
              header: true,
              child: Text(title, textAlign: TextAlign.center, style: context.text.titleLarge?.copyWith(color: c.ink)),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(message, textAlign: TextAlign.center, style: context.text.bodySmall?.copyWith(color: c.inkMuted)),
            const SizedBox(height: AppSpacing.s24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(foregroundColor: c.ink, minimumSize: const Size(64, 52)),
                    child: Text(cancelLabel ?? 'Batal'.tr),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: destructive ? FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: c.onDanger) : null,
                    child: Text(confirmLabel ?? 'Hapus'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
