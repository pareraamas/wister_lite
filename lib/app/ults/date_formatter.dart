import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:wister_lite/app/data/services/settings_service.dart';

import 'clock.dart';

extension DateTimeExtension on DateTime {
  String toHumanReadable() {
    final now = Clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(year, month, day);

    final difference = target.difference(today).inDays;

    if (difference == 0) {
      return 'Hari ini'.tr;
    } else if (difference == -1) {
      return 'Kemarin'.tr;
    } else if (difference == 1) {
      return 'Besok'.tr;
    } else {
      final dayName = DateFormat.EEEE(SettingsService.intlTag).format(this); // contoh: Sabtu
      final formattedDate = DateFormat(
        SettingsService.intlTag == 'en_US' ? "MMMM d, yyyy" : "d MMMM yyyy",
        SettingsService.intlTag,
      ).format(this); // contoh: 8 Agustus 2022
      return "$dayName, $formattedDate";
    }
  }
}
