import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:wister_lite/app/data/models/expense_type.dart';
import 'package:wister_lite/app/ui/app_illustration.dart';

class Category {
  final String id;

  /// Label apa adanya di database (juga dipakai sebagai nama transaksi tanpa catatan).
  final String storedLabel;
  final int colorValue;
  final String icon;

  Category({required this.id, required String label, required this.colorValue, required this.icon}) : storedLabel = label;

  /// Label untuk ditampilkan. Kategori bawaan yang belum diganti namanya
  /// ikut bahasa aktif; kategori buatan user tampil apa adanya.
  String get label {
    final seed = ExpenseType.values.firstWhereOrNull((t) => t.toShortString().toLowerCase() == id);
    if (seed == null || seed.label != storedLabel) return storedLabel;
    return Get.locale?.languageCode == 'en' ? seed.labelEn : seed.labelId;
  }

  /// Teks tersimpan cocok dengan kategori ini (label asli atau terjemahannya).
  bool matchesLabel(String text) => text == storedLabel || text == label;

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() {
    return {'id': id, 'label': storedLabel, 'color_value': colorValue, 'icon': icon};
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      label: map['label'] as String,
      colorValue: map['color_value'] as int,
      icon: CategoryIcons.resolve(map['icon'] as String),
    );
  }

  factory Category.create({required String label, required Color color, required String icon}) {
    return Category(id: const Uuid().v4(), label: label, colorValue: color.toARGB32(), icon: icon);
  }

  Category copyWith({String? label, Color? color, String? icon}) {
    return Category(id: id, label: label ?? storedLabel, colorValue: color?.toARGB32() ?? colorValue, icon: icon ?? this.icon);
  }
}
