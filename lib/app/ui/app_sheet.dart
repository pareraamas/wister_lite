import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bottom sheet standar: radius 28, handle, judul, isi, dan satu tombol utama.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.trailing,
    this.primaryLabel,
    this.onPrimary,
  });

  final String title;

  /// Konteks kecil di bawah judul, mis. "Terpakai bulan ini Rp 430.000".
  final String? subtitle;

  /// Widget di kiri judul (mis. `CategoryBlob` besar).
  final Widget? leading;

  /// Widget di kanan judul (mis. pemilih kategori).
  final Widget? trailing;
  final Widget child;

  /// Label tombol utama. Tombol tidak tampil bila null.
  final String? primaryLabel;

  /// Null = tombol utama nonaktif.
  final VoidCallback? onPrimary;

  /// Menampilkan [AppSheet] sebagai modal bottom sheet (ikut naik saat keyboard muncul).
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    String? primaryLabel,
    VoidCallback? onPrimary,
    bool isDismissible = true,
  }) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    isDismissible: isDismissible,
    builder: (_) => AppSheet(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: c.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s12, AppSpacing.s24, AppSpacing.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(color: c.outline, borderRadius: AppRadius.fullAll),
                  ),
                ),
                const SizedBox(height: AppSpacing.s20),
                Row(
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.s16)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(title, style: t.titleLarge?.copyWith(color: c.ink)),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppSpacing.s4),
                            Text(subtitle!, style: t.bodySmall?.copyWith(color: c.inkMuted)),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[const SizedBox(width: AppSpacing.s8), trailing!],
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                Flexible(child: child),
                if (primaryLabel != null) ...[
                  const SizedBox(height: AppSpacing.s24),
                  FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
