import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wister_lite/app/data/services/settings_service.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/translations/app_translations.dart';

import 'app/routes/app_pages.dart';
import 'app/bindings/initial_binding.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  // Dibuat sebelum app agar tema & bahasa tersimpan langsung dipakai di frame pertama.
  final settings = Get.put(SettingsService(prefs), permanent: true);

  runApp(
    GetMaterialApp(
      title: "Wister Lite",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode.value,
      initialRoute: AppPages.INITIAL,
      initialBinding: InitialBinding(prefs),
      translations: AppTranslations(),
      locale: settings.locale.value,
      supportedLocales: SettingsService.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      getPages: AppPages.routes,
      // Status bar & navigation bar ikut tema (layar tanpa AppBar juga).
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayStyle(Theme.of(context).brightness),
        child: child!,
      ),
    ),
  );
}
