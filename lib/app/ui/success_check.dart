import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'app_illustration.dart';

/// Centang sukses kecil (Lottie) untuk momen "Tersimpan".
///
/// Diputar sekali. Saat animasi sistem dimatikan, langsung tampil frame
/// terakhir. Bila aset Lottie gagal dimuat, tampil ikon centang biasa.
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({super.key, this.size = 72, this.semanticLabel, this.onCompleted});

  final double size;
  /// Null = "Tersimpan" (diterjemahkan).
  final String? semanticLabel;
  final VoidCallback? onCompleted;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    if (!mounted) return;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
      widget.onCompleted?.call();
      return;
    }
    _controller
      ..duration = composition.duration
      ..forward(from: 0).whenCompleteOrCancel(() {
        if (mounted) widget.onCompleted?.call();
      });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fallback = Icon(AppIconsFill.checkCircle, size: widget.size, color: c.income);
    return Semantics(
      label: widget.semanticLabel ?? 'Tersimpan'.tr,
      liveRegion: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: Lottie.asset(
            AppIllustrations.successCheck,
            controller: _controller,
            width: widget.size,
            height: widget.size,
            onLoaded: _onLoaded,
            // Warna bawaan JSON = brand light; ganti ke token agar ikut tema.
            delegates: LottieDelegates(
              values: [
                ValueDelegate.color(const ['lingkaran', '**'], value: c.brand),
                ValueDelegate.strokeColor(const ['centang', '**'], value: c.onBrand),
              ],
            ),
            errorBuilder: (_, _, _) => fallback,
          ),
        ),
      ),
    );
  }
}
