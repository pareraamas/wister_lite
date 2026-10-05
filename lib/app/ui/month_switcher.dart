import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'app_format.dart';

/// Chip bulan aktif ("Sep 2026") dengan panah kiri/kanan.
///
/// Memakai method prev/next yang sudah ada di controller; [onTap] membuka
/// pemilih bulan (opsional).
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onPrev, required this.onNext, this.onTap});

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = AppFormat.monthYearShort(month);
    final reduced = AppMotion.reduced(context);

    final text = Text(
      label,
      key: ValueKey(label),
      maxLines: 1,
      style: context.text.labelMedium?.copyWith(color: c.ink, fontFeatures: AppTypography.tabular),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPrev,
          tooltip: 'Bulan sebelumnya'.tr,
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          icon: Icon(AppIcons.caretLeft, semanticLabel: 'Bulan sebelumnya'.tr),
        ),
        Semantics(
          button: onTap != null,
          label: 'Bulan aktif @month'.trParams({'month': AppFormat.monthYear(month)}),
          excludeSemantics: true,
          child: Material(
            color: c.surfaceContainerLow,
            shape: StadiumBorder(side: BorderSide(color: c.outlineVariant)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSpacing.s40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.calendarBlank, size: 16, color: c.brand),
                      const SizedBox(width: AppSpacing.s8 - 2),
                      AnimatedSwitcher(
                        duration: reduced ? AppMotion.short : AppMotion.medium,
                        switchInCurve: AppMotion.standard,
                        switchOutCurve: AppMotion.standard,
                        transitionBuilder: (child, anim) => reduced
                            ? FadeTransition(opacity: anim, child: child)
                            : FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim),
                                  child: child,
                                ),
                              ),
                        child: text,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          tooltip: 'Bulan berikutnya'.tr,
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          icon: Icon(AppIcons.caretRight, semanticLabel: 'Bulan berikutnya'.tr),
        ),
      ],
    );
  }
}
