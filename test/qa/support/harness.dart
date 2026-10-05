import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';
import 'package:wister_lite/app/data/services/settings_service.dart';
import 'package:wister_lite/app/routes/app_pages.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ults/clock.dart';

import 'fake_repository.dart';
import 'fixtures.dart';

/// Ukuran layar uji (dp). `phone` = Pixel 7, `small` = HP kelas bawah.
enum Device {
  phone(Size(412, 915)),
  small(Size(360, 640));

  const Device(this.size);
  final Size size;
}

bool _setUp = false;

/// Dipanggil sekali per file test: font asli (bukan kotak Ahem), locale id_ID,
/// dan google_fonts tidak boleh mengunduh dari internet.
Future<void> setUpQa() async {
  if (_setUp) return;
  _setUp = true;
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  Get.testMode = true;
  await initializeDateFormatting('id_ID');
  await _loadManifestFonts();
}

/// Memuat semua font di FontManifest.json (Plus Jakarta Sans, MaterialIcons,
/// ikon dari package) agar golden menampilkan teks & ikon sungguhan.
Future<void> _loadManifestFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Satu layar yang diuji QA: cara membukanya dan data yang dipakai.
class QaScreen {
  const QaScreen(
    this.name, {
    this.route = '',
    this.page,
    this.arguments,
    this.data = DataSet.full,
    this.open,
    this.golden = true,
  });

  /// Nama file golden & label test.
  final String name;
  final String route;

  /// Halaman tanpa route (mis. galeri komponen debug), dibuka lewat `Get.to`.
  final Widget Function()? page;
  final Object? arguments;
  final DataSet data;

  /// Langkah setelah route terbuka, mis. pindah tab atau membuka sheet.
  final Future<void> Function(WidgetTester tester)? open;

  /// False untuk layar yang isinya bergantung pada jam nyata (mis. tanggal
  /// default hari ini), sehingga golden-nya tidak bisa stabil.
  final bool golden;

  @override
  String toString() => name;
}

const _blankRoute = '/qa-blank';

/// Memompa app seperti `main.dart`, tapi dengan [FakeExpenseRepository],
/// tema terkunci, ukuran layar, dan skala teks yang ditentukan.
Future<FakeExpenseRepository> pumpScreen(
  WidgetTester tester,
  QaScreen screen, {
  Brightness brightness = Brightness.light,
  Device device = Device.phone,
  double textScale = 1,
  FakeExpenseRepository? repository,
}) async {
  await setUpQa();
  Get.reset();
  // Harus sebelum controller dibuat: selectedMonth/selectedDate diambil di init.
  Clock.now = () => referenceNow;
  addTearDown(() => Clock.now = DateTime.now);
  final repo = repository ?? repositoryFor(screen.data);
  Get.put<ExpenseRepository>(repo, permanent: true);
  SharedPreferences.setMockInitialValues({});
  Get.put<SettingsService>(SettingsService(await SharedPreferences.getInstance()), permanent: true);

  tester.view.physicalSize = device.size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  addTearDown(Get.reset);

  await tester.pumpWidget(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      initialRoute: _blankRoute,
      getPages: [GetPage(name: _blankRoute, page: () => const SizedBox.shrink()), ...AppPages.routes],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  if (screen.page != null) {
    Get.to<void>(screen.page!);
  } else {
    Get.toNamed(screen.route, arguments: screen.arguments);
  }
  await settle(tester);
  if (screen.open != null) {
    await screen.open!(tester);
    await settle(tester);
  }
  return repo;
}

/// `pumpAndSettle` dengan batas waktu. Animasi tak berujung (shimmer, maskot
/// Rive/Lottie berulang) tidak boleh membuat test menggantung.
Future<void> settle(WidgetTester tester, {Duration max = const Duration(seconds: 3)}) async {
  // Beri kesempatan Future repository (microtask) selesai.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, max);
  } on FlutterError {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Mengosongkan semua timer (snackbar GetX, dsb.) sebelum test selesai.
Future<void> drainTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(seconds: 1));
}

/// Mencari elemen dengan beberapa kemungkinan finder, supaya driver tetap
/// jalan untuk UI lama maupun hasil redesign. Yang pertama ketemu dipakai.
Finder firstOf(List<Finder> candidates, {required String what}) {
  for (final f in candidates) {
    if (f.evaluate().isNotEmpty) return f.first;
  }
  throw TestFailure('QA driver: tidak menemukan "$what". Perbarui finder di test/qa/support/.');
}

/// Menggulir layar teratas sampai salah satu [candidates] ter-build, lalu
/// memastikannya terlihat dan mengetuknya. Aman untuk HP kecil + teks 200%.
Future<void> tapAny(WidgetTester tester, List<Finder> candidates, {required String what}) async {
  Finder? found() {
    for (final f in candidates) {
      if (f.evaluate().isNotEmpty) return f.first;
    }
    return null;
  }

  var target = found();
  for (var i = 0; target == null && i < 12; i++) {
    final scrollables = find.byType(Scrollable).hitTestable();
    if (scrollables.evaluate().isEmpty) break;
    await tester.drag(scrollables.first, const Offset(0, -300));
    await tester.pump();
    target = found();
  }
  if (target == null) throw TestFailure('QA driver: tidak menemukan "$what". Perbarui finder di test/qa/support/.');
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await settle(tester);
}

/// Tooltip tombol hapus data ("Hapus transaksi", "Hapus kategori"), bukan
/// backspace keypad ("Hapus digit").
final deleteTooltip = RegExp(r'^Hapus (?!digit)');

/// Pembuka sheet kategori di form transaksi: chip "Semua" (redesign),
/// tile "Pilih kategori", atau field "Kategori" (UI lama).
List<Finder> categorySheetTriggers() => [
      find.text('Semua'),
      find.byTooltip('Pilih kategori'),
      find.text('Pilih kategori'),
      find.text('Kategori'),
    ];

/// Tab di navigasi bawah (NavigationBar M3 atau BottomNavigationBar lama).
Future<void> tapNavTab(WidgetTester tester, String label) async {
  final bar = find.byWidgetPredicate((w) => w is NavigationBar || w is BottomNavigationBar);
  await tester.tap(firstOf([find.descendant(of: bar, matching: find.text(label))], what: 'tab $label'));
  await settle(tester);
}
