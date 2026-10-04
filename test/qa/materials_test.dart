@Tags(['qa', 'gerbang'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:wister_lite/app/data/models/expense_type.dart';
import 'package:wister_lite/app/ui/ui.dart';

import 'support/harness.dart';

/// Warna kontrak ilustrasi: hanya RGB ini yang dipetakan ke token oleh
/// `IllustrationColorMapper`, plus `fixedRgb` yang sengaja sama di kedua tema.
/// Warna lain akan tetap sama di mode gelap tanpa disengaja.
final _contractRgb = {
  ...{0x1B2430, 0x1B2431, 0x0E8C7F, 0xCDEFE9, 0xFFB547, 0xFFE7C2, 0xFFFFFF, 0x1E9E5A, 0xF0634A},
  ...IllustrationColorMapper.fixedRgb,
};

/// Path ikon kategori di rilis sebelum redesign (lib/gen/assets.gen.dart,
/// commit 3b8ce8e). Nilai ini tersimpan di SQLite pengguna sebagai
/// `categories.icon`; sejak ikon dipindah ke `assets/icon_category/`, path ini
/// wajib bisa dipetakan ulang oleh `CategoryIcons.resolve`.
const _legacyCategoryIcons = [
  'assets/uil_basketball.svg',
  'assets/uil_book-open.svg',
  'assets/uil_car-sideview.svg',
  'assets/uil_clapper-board.svg',
  'assets/uil_gift.svg',
  'assets/uil_home.svg',
  'assets/uil_pizza-slice.svg',
  'assets/uil_rss-alt.svg',
  'assets/uil_shopping-cart.svg',
];

final _illustrations = [
  ...AppIllustrations.empty,
  ...AppIllustrations.micro,
  for (final m in DompiMood.values) m.asset,
];

Iterable<int> _hexColors(String svg) sync* {
  for (final m in RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b').allMatches(svg)) {
    var hex = m.group(1)!;
    if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
    yield int.parse(hex, radix: 16);
  }
}

/// Gerbang Bahan: aset ilustrasi & ikon memenuhi kontrak rencana redesign.
void main() {
  setUpAll(setUpQa);

  group('ikon kategori', () {
    test('path lama di SQLite dipetakan ke ikon yang ada', () {
      final resolved = _legacyCategoryIcons.map(CategoryIcons.resolve).toSet();
      expect(CategoryIcons.legacy.toSet(), resolved);
      expect(CategoryIcons.all, containsAll(resolved));
      expect(CategoryIcons.all.toSet(), hasLength(CategoryIcons.all.length), reason: 'ada ikon ganda');
      for (final t in ExpenseType.values) {
        expect(resolved, contains(t.icon), reason: '${t.name} bukan ikon bawaan lama');
      }
      for (final path in CategoryIcons.all) {
        expect(CategoryIcons.resolve(path), path, reason: 'path baru tidak boleh diubah');
      }
    });

    test('setiap ikon punya label screen reader', () {
      for (final path in CategoryIcons.all) {
        expect(CategoryIcons.labels, contains(path), reason: path);
      }
    });

    for (final path in CategoryIcons.all) {
      test('$path hanya putih/currentColor agar bisa di-tint', () {
        final svg = File(path).readAsStringSync();
        final others = _hexColors(svg).where((c) => c != 0xFFFFFF).map((c) => '#${c.toRadixString(16)}');
        expect(others, isEmpty);
      });
    }
  });

  for (final path in [..._illustrations, ...CategoryIcons.all]) {
    group(path, () {
      test('ada di bundle & < 8 KB', () async {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, lessThan(8 * 1024));
      });

      test('SVG valid (tidak jatuh ke kotak kosong)', () async {
        final info = await vg.loadPicture(SvgAssetLoader(path), null);
        expect(info.size.isEmpty, isFalse);
        info.picture.dispose();
      });

      if (!path.contains('/uil_')) {
        test('hanya warna kontrak (ikut tema gelap)', () {
          final bad = {
            for (final c in _hexColors(File(path).readAsStringSync()))
              if (!_contractRgb.contains(c)) '#${c.toRadixString(16).padLeft(6, '0')}',
          };
          expect(bad, isEmpty, reason: 'Warna di luar IllustrationColorMapper tidak berubah di dark mode');
        });
      }
    });
  }

  test('Lottie sukses valid', () async {
    final bytes = await rootBundle.load(AppIllustrations.successCheck);
    expect(json.decode(utf8.decode(bytes.buffer.asUint8List())), isA<Map<String, dynamic>>());
    final composition = await LottieComposition.fromByteData(bytes);
    expect(composition.duration, greaterThan(Duration.zero));
    // Animasi sukses harus singkat (motion token: momen, bukan loop).
    expect(composition.duration, lessThanOrEqualTo(const Duration(seconds: 2)));
  });

  test('semua path aset di pubspec ada', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final m in RegExp(r'^\s+- (assets/\S*)', multiLine: true).allMatches(pubspec)) {
      final p = m.group(1)!;
      expect(p.endsWith('/') ? Directory(p).existsSync() : File(p).existsSync(), isTrue, reason: p);
    }
  });
}
