// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:wister_lite/gen/assets.gen.dart';

enum ExpenseType {
  FOOD('Makanan', 'Food', Color(0xfff2c94c)),
  INTERNET("Internet", "Internet", Color(0xff56CCF2)),
  EDUCATION("Education", "Education", Color(0xffF2994A)),
  GIFT("Hadiah", "Gift", Color(0xffEB5757)),
  TRANSPORTATION("Transport", "Transport", Color(0xff9B51E0)),
  SHOPPING("Belanja", "Shopping", Color(0xff27AE60)),
  HOME_APPLIANCES("Alat Rumah", "Household", Color(0xffBB6BD9)),
  SPORT("Olah Raga", "Sports", Color(0xff2D9CDB)),
  ENTERTAINMENT("Hiburan", "Entertainment", Color(0xff2F80ED));

  /// Label seed yang tersimpan di database. Jangan diubah: dipakai untuk
  /// mengenali kategori bawaan yang belum diganti namanya.
  final String label;
  final String labelEn;
  final Color color;

  const ExpenseType(this.label, this.labelEn, this.color);

  /// Label tampilan Indonesia ("Education" tersimpan dalam bahasa Inggris sejak awal).
  String get labelId => this == ExpenseType.EDUCATION ? 'Pendidikan' : label;

  // get icon
  String get icon => switch (this) {
    ExpenseType.FOOD => Assets.iconCategory.uilPizzaSlice,
    ExpenseType.INTERNET => Assets.iconCategory.uilRssAlt,
    ExpenseType.EDUCATION => Assets.iconCategory.uilBookOpen,
    ExpenseType.GIFT => Assets.iconCategory.uilGift,
    ExpenseType.TRANSPORTATION => Assets.iconCategory.uilCarSideview,
    ExpenseType.SHOPPING => Assets.iconCategory.uilShoppingCart,
    ExpenseType.HOME_APPLIANCES => Assets.iconCategory.uilHome,
    ExpenseType.SPORT => Assets.iconCategory.uilBasketball,
    ExpenseType.ENTERTAINMENT => Assets.iconCategory.uilClapperBoard,
  };

  // Convert string to ExpenseType
  static ExpenseType fromString(String value) {
    try {
      return ExpenseType.values.firstWhere((e) => e.toString().split('.').last.toLowerCase() == value.toLowerCase(), orElse: () => ExpenseType.FOOD);
    } catch (e) {
      return ExpenseType.FOOD;
    }
  }

  // Convert ExpenseType to string (just the enum name)
  String toShortString() {
    return toString().split('.').last;
  }
}
