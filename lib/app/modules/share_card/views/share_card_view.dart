import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';

import '../controllers/share_card_controller.dart';

class ShareCardView extends GetView<ShareCardController> {
  const ShareCardView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text('Bagikan Ringkasan'.tr)),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const SkeletonList(itemCount: 1, shape: SkeletonShape.card, padding: EdgeInsets.all(AppSpacing.page));
        }
        final format = controller.format.value;
        final data = controller.data.value!;
        final hide = controller.hideAmounts.value;
        return SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s16),
                  // Pratinjau diperkecil agar muat; gambar tetap diekspor di ukuran penuh.
                  child: Semantics(
                    label: format == ShareCardFormat.story
                        ? 'Pratinjau gambar Story ringkasan @month'.trParams({'month': AppFormat.monthYear(controller.month)})
                        : 'Pratinjau carousel @n gambar ringkasan @month'.trParams({
                            'n': '${controller.slideCount}',
                            'month': AppFormat.monthYear(controller.month),
                          }),
                    image: true,
                    excludeSemantics: true,
                    child: format == ShareCardFormat.story
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                            child: FittedBox(
                              child: _Framed(
                                boundaryKey: controller.storyKey,
                                child: ShareSummaryCard(data: data, hideAmounts: hide),
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, box) {
                              final size = ShareCardFormat.feed.size;
                              final height = math.min(box.maxHeight, (box.maxWidth - AppSpacing.page * 2) * size.height / size.width);
                              // Semua slide dirender (bukan lazy) agar tiap RepaintBoundary bisa ditangkap.
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    for (var i = 0; i < controller.slideCount; i++) ...[
                                      if (i > 0) const SizedBox(width: AppSpacing.s8),
                                      SizedBox(
                                        width: height * size.width / size.height,
                                        height: height,
                                        child: FittedBox(
                                          child: _Framed(
                                            boundaryKey: controller.slideKey(i),
                                            child: ShareFeedSlide(data: data, index: i, hideAmounts: hide),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
              if (format == ShareCardFormat.feed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.s12),
                  child: Text(
                    'Unggah @n gambar sekaligus sebagai carousel. Geser untuk melihat semua.'.trParams({'n': '${controller.slideCount}'}),
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: SegmentedButton<ShareCardFormat>(
                  showSelectedIcon: false,
                  segments: [for (final f in ShareCardFormat.values) ButtonSegment(value: f, label: Text(f.label))],
                  selected: {format},
                  onSelectionChanged: (s) => controller.format.value = s.first,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              SwitchListTile(
                value: controller.hideAmounts.value,
                onChanged: (v) => controller.hideAmounts.value = v,
                title: Text('Sembunyikan nominal'.tr),
                subtitle: Text('Hanya persentase yang tampil'.tr, style: context.text.bodySmall?.copyWith(color: c.inkMuted)),
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s8, AppSpacing.page, AppSpacing.s16),
                child: Builder(
                  builder: (context) => FilledButton.icon(
                    onPressed: controller.isSharing.value ? null : () => controller.share(origin: _originOf(context)),
                    icon: const Icon(AppIcons.shareNetwork),
                    label: Text(controller.imageCount > 1 ? 'Bagikan @n gambar'.trParams({'n': '${controller.imageCount}'}) : 'Bagikan gambar'.tr),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Bayangan + sudut membulat untuk pratinjau. Sudut tidak ikut diekspor
/// karena `RepaintBoundary` ada di dalam clip.
class _Framed extends StatelessWidget {
  const _Framed({required this.boundaryKey, required this.child});

  final GlobalKey boundaryKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        boxShadow: [BoxShadow(color: context.colors.scrim.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardAll,
        child: RepaintBoundary(key: boundaryKey, child: child),
      ),
    );
  }
}

Rect? _originOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}
