import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/theme/app_theme.dart';

import 'app/routes/app_pages.dart';
import 'app/bindings/initial_binding.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    GetMaterialApp(
      title: "Wister Lite",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: AppTheme.mode,
      initialRoute: AppPages.INITIAL,
      initialBinding: InitialBinding(),
      locale: const Locale('id', 'ID'), // 🇮🇩 Set locale ke Indonesia
      supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID')],
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
