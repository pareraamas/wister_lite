import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';

/// Tombol pada [AmountKeypad].
sealed class KeypadInput {
  const KeypadInput();
}

class KeypadDigit extends KeypadInput {
  const KeypadDigit(this.digit) : assert(digit >= 0 && digit <= 9);
  final int digit;
}

class KeypadTripleZero extends KeypadInput {
  const KeypadTripleZero();
}

class KeypadBackspace extends KeypadInput {
  const KeypadBackspace();
}

class KeypadClear extends KeypadInput {
  const KeypadClear();
}

/// Keypad nominal sendiri: 1–9, 000, 0, hapus. Tanpa desimal.
///
/// Terkontrol: parent menyimpan [value] dan menampilkannya (mis. dengan
/// `AmountText`); keypad hanya memanggil [onChanged] dengan nilai baru.
/// Tahan tombol hapus untuk mengosongkan.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.value, required this.onChanged, this.maxDigits = 12, this.haptics = true});

  final int value;
  final ValueChanged<int> onChanged;

  /// Jumlah digit maksimum (12 = hingga Rp 999.999.999.999).
  final int maxDigits;
  final bool haptics;

  /// Logika murni keypad; dipakai widget dan test.
  static int apply(int value, KeypadInput input, {int maxDigits = 12}) {
    int append(int v, int zeros, [int digit = 0]) {
      var out = v;
      for (var i = 0; i < zeros; i++) {
        final next = out * 10 + (i == zeros - 1 ? digit : 0);
        if (next.toString().length > maxDigits) break;
        out = next;
      }
      return out;
    }

    return switch (input) {
      KeypadDigit(:final digit) => append(value, 1, digit),
      KeypadTripleZero() => value == 0 ? 0 : append(value, 3),
      KeypadBackspace() => value ~/ 10,
      KeypadClear() => 0,
    };
  }

  void _press(KeypadInput input) {
    final next = apply(value, input, maxDigits: maxDigits);
    if (haptics) HapticFeedback.lightImpact();
    if (next != value) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final tok = context.components.keypadKey;
    final digitStyle = context.text.headlineSmall?.copyWith(fontFeatures: AppTypography.tabular);

    Widget digit(int d) => _Key(
      tokens: tok,
      semanticLabel: '$d',
      onTap: () => _press(KeypadDigit(d)),
      child: Text('$d', style: digitStyle?.copyWith(color: tok.foreground)),
    );

    Widget row(List<Widget> keys) => Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s8),
          Expanded(child: keys[i]),
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ]) ...[
          row([for (final d in r) digit(d)]),
          const SizedBox(height: AppSpacing.s8),
        ],
        row([
          _Key(
            tokens: tok,
            semanticLabel: 'Tiga nol'.tr,
            onTap: () => _press(const KeypadTripleZero()),
            child: Text('000', style: digitStyle?.copyWith(color: tok.actionForeground)),
          ),
          digit(0),
          _Key(
            tokens: tok,
            semanticLabel: 'Hapus digit'.tr,
            tooltip: 'Hapus digit (tahan untuk kosongkan)'.tr,
            onTap: () => _press(const KeypadBackspace()),
            onLongPress: () => _press(const KeypadClear()),
            child: Icon(AppIcons.backspace, color: tok.actionForeground, size: 28),
          ),
        ]),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.tokens,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.tooltip,
  });

  final KeypadKeyTokens tokens;
  final String semanticLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(tokens.radius);
    Widget key = Material(
      color: tokens.background,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        highlightColor: tokens.pressed,
        splashColor: tokens.pressed,
        child: SizedBox(
          height: tokens.minSize,
          child: Center(child: ExcludeSemantics(child: child)),
        ),
      ),
    );
    if (tooltip != null) key = Tooltip(message: tooltip!, excludeFromSemantics: true, child: key);
    return Semantics(button: true, label: semanticLabel, child: key);
  }
}
