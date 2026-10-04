import 'package:flutter/widgets.dart';

const _pkg = 'phosphor_flutter';
const _regular = 'PhosphorRegular';
const _fill = 'PhosphorFill';

/// Ikon navigasi & aksi dari set Phosphor (bergaris bulat), versi regular.
///
/// Memakai font Phosphor yang dibundel package `phosphor_flutter`, tetapi
/// tanpa meng-import Dart API-nya: `phosphor_flutter` 2.1.0 meng-extend
/// `IconData` yang kini `final`, sehingga gagal dikompilasi di Flutter 3.47.
/// Code point disalin dari `PhosphorIconsRegular` / `PhosphorIconsFill`.
///
/// Pakai [AppIconsFill] untuk status aktif (mis. tab terpilih).
abstract final class AppIcons {
  static const wallet = IconData(0xe68a, fontFamily: _regular, fontPackage: _pkg);
  static const target = IconData(0xe47c, fontFamily: _regular, fontPackage: _pkg);
  static const chartDonut = IconData(0xeaa6, fontFamily: _regular, fontPackage: _pkg);
  static const chartPieSlice = IconData(0xe15a, fontFamily: _regular, fontPackage: _pkg);
  static const plus = IconData(0xe3d4, fontFamily: _regular, fontPackage: _pkg);
  static const trash = IconData(0xe4a6, fontFamily: _regular, fontPackage: _pkg);
  static const pencilSimple = IconData(0xe3b4, fontFamily: _regular, fontPackage: _pkg);
  static const x = IconData(0xe4f6, fontFamily: _regular, fontPackage: _pkg);
  static const check = IconData(0xe182, fontFamily: _regular, fontPackage: _pkg);
  static const checkCircle = IconData(0xe184, fontFamily: _regular, fontPackage: _pkg);
  static const warning = IconData(0xe4e0, fontFamily: _regular, fontPackage: _pkg);
  static const warningOctagon = IconData(0xe4e4, fontFamily: _regular, fontPackage: _pkg);
  static const calendarBlank = IconData(0xe10a, fontFamily: _regular, fontPackage: _pkg);
  static const note = IconData(0xe348, fontFamily: _regular, fontPackage: _pkg);
  static const tag = IconData(0xe478, fontFamily: _regular, fontPackage: _pkg);
  static const magnifyingGlass = IconData(0xe30c, fontFamily: _regular, fontPackage: _pkg);
  static const funnelSimple = IconData(0xe268, fontFamily: _regular, fontPackage: _pkg);
  static const sun = IconData(0xe472, fontFamily: _regular, fontPackage: _pkg);
  static const moon = IconData(0xe330, fontFamily: _regular, fontPackage: _pkg);
  static const monitor = IconData(0xe32e, fontFamily: _regular, fontPackage: _pkg);
  static const translate = IconData(0xe4a2, fontFamily: _regular, fontPackage: _pkg);
  static const shareNetwork = IconData(0xe408, fontFamily: _regular, fontPackage: _pkg);
  static const image = IconData(0xe2ca, fontFamily: _regular, fontPackage: _pkg);
  static const dotsThreeVertical = IconData(0xe208, fontFamily: _regular, fontPackage: _pkg);
  static const fileCsv = IconData(0xeb1c, fontFamily: _regular, fontPackage: _pkg);
  static const fileXls = IconData(0xeb22, fontFamily: _regular, fontPackage: _pkg);
  static const filePdf = IconData(0xe702, fontFamily: _regular, fontPackage: _pkg);
  static const downloadSimple = IconData(0xe20c, fontFamily: _regular, fontPackage: _pkg);

  // Ikon berarah, ikut dicerminkan di bahasa RTL.
  static const caretLeft = IconData(0xe138, fontFamily: _regular, fontPackage: _pkg, matchTextDirection: true);
  static const caretRight = IconData(0xe13a, fontFamily: _regular, fontPackage: _pkg, matchTextDirection: true);
  static const arrowLeft = IconData(0xe058, fontFamily: _regular, fontPackage: _pkg, matchTextDirection: true);
  static const backspace = IconData(0xe0ae, fontFamily: _regular, fontPackage: _pkg, matchTextDirection: true);
}

/// Varian fill Phosphor, untuk status aktif/tegas.
abstract final class AppIconsFill {
  static const wallet = IconData(0xe68a, fontFamily: _fill, fontPackage: _pkg);
  static const target = IconData(0xe47c, fontFamily: _fill, fontPackage: _pkg);
  static const chartDonut = IconData(0xeaa6, fontFamily: _fill, fontPackage: _pkg);
  static const chartPieSlice = IconData(0xe15a, fontFamily: _fill, fontPackage: _pkg);
  static const checkCircle = IconData(0xe184, fontFamily: _fill, fontPackage: _pkg);
  static const warning = IconData(0xe4e0, fontFamily: _fill, fontPackage: _pkg);
  static const warningOctagon = IconData(0xe4e4, fontFamily: _fill, fontPackage: _pkg);
  static const trash = IconData(0xe4a6, fontFamily: _fill, fontPackage: _pkg);
}
