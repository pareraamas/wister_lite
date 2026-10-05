import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wister_lite/app/theme/app_theme.dart';

/// Pilihan tema & bahasa, disimpan di SharedPreferences agar tetap sama
/// setelah aplikasi ditutup.
class SettingsService extends GetxService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'theme_mode';
  static const _localeKey = 'locale';

  static const indonesian = Locale('id', 'ID');
  static const english = Locale('en', 'US');
  static const supportedLocales = [indonesian, english];

  /// Tag locale untuk `intl` (DateFormat dsb.) sesuai bahasa aktif.
  static String get intlTag => Get.locale?.languageCode == 'en' ? 'en_US' : 'id_ID';

  late final themeMode = _readThemeMode().obs;
  late final locale = _readLocale().obs;

  /// Belum pernah dipilih: ikuti `--dart-define=THEME_MODE` (default terang).
  ThemeMode _readThemeMode() => ThemeMode.values.firstWhereOrNull((m) => m.name == _prefs.getString(_themeKey)) ?? AppTheme.mode;

  /// Belum pernah dipilih: Inggris bila bahasa HP Inggris, selain itu Indonesia.
  Locale _readLocale() {
    final saved = _prefs.getString(_localeKey);
    final match = supportedLocales.firstWhereOrNull((l) => l.languageCode == saved);
    if (match != null) return match;
    return Get.deviceLocale?.languageCode == 'en' ? english : indonesian;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> setLocale(Locale value) async {
    locale.value = value;
    await Get.updateLocale(value);
    await _prefs.setString(_localeKey, value.languageCode);
  }
}
