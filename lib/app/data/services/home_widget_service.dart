import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:wister_lite/app/data/models/budget_model.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';
import 'package:wister_lite/app/modules/expanse_create/controllers/expanse_create_controller.dart';
import 'package:wister_lite/app/modules/main_nav/controllers/main_nav_controller.dart';
import 'package:wister_lite/app/routes/app_pages.dart';
import 'package:wister_lite/app/ui/app_format.dart';
import 'package:wister_lite/app/ults/clock.dart';

/// Jembatan ke widget home screen Android "Ringkasan" dan "Anggaran"
/// (`android/.../SummaryWidgetProvider.kt`, `BudgetWidgetProvider.kt`) serta
/// tile Quick Settings "Catat transaksi" (`CatatTileService.kt`).
///
/// Nominal diformat di sini agar sama persis dengan aplikasi; provider native
/// hanya menampilkan string dan menampilkan Rp 0 untuk total yang tanggalnya sudah lewat.
class HomeWidgetService extends GetxService {
  static const _summaryProvider = 'com.developerparera.wister_lite.SummaryWidgetProvider';
  static const _budgetProvider = 'com.developerparera.wister_lite.BudgetWidgetProvider';

  /// Jadwal gambar ulang tengah malam ke depan; diperbarui tiap [update].
  static const _scheduledDays = 14;

  /// Jumlah baris kategori di widget Anggaran ukuran besar.
  static const _budgetRows = 3;

  static final NumberFormat _compact = NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 1);

  final ExpenseRepository _repository = Get.find<ExpenseRepository>();
  StreamSubscription<Uri?>? _clicks;

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void onInit() {
    super.onInit();
    if (!_supported) return;
    _clicks = HomeWidget.widgetClicked.listen(_handleUri);
    update();
  }

  @override
  void onClose() {
    _clicks?.cancel();
    super.onClose();
  }

  /// Dipanggil sekali setelah halaman utama tampil, untuk aplikasi yang
  /// dibuka dari tombol widget saat belum berjalan.
  Future<void> handleInitialLaunch() async {
    if (!_supported) return;
    _handleUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
  }

  /// Hitung ulang ringkasan & anggaran lalu gambar ulang widget. Aman dipanggil sering.
  Future<void> update() async {
    if (!_supported) return;
    try {
      final now = Clock.now();
      final today = DateTime(now.year, now.month, now.day);
      await Future.wait([_saveSummary(now), _saveBudget(now)]);
      await HomeWidget.updateWidget(qualifiedAndroidName: _summaryProvider);
      await HomeWidget.updateWidget(qualifiedAndroidName: _budgetProvider);
      // Tengah malam total harian (dan bulanan di tanggal 1) kembali ke nol,
      // dan pace anggaran bergeser satu hari.
      final midnights = [for (var i = 1; i <= _scheduledDays; i++) DateTime(today.year, today.month, today.day + i)];
      await HomeWidget.scheduleWidgetUpdates(midnights, qualifiedAndroidName: _summaryProvider);
      await HomeWidget.scheduleWidgetUpdates(midnights, qualifiedAndroidName: _budgetProvider);
    } catch (e) {
      log('Gagal memperbarui widget: $e');
    }
  }

  Future<void> _saveSummary(DateTime now) async {
    final results = await Future.wait([
      _repository.getTotalAmount(DateTime(2000), DateTime(2100), 'income'),
      _repository.getTotalAmount(DateTime(2000), DateTime(2100), 'expense'),
      _repository.getMonthlyTotal(now, 'income'),
      _repository.getMonthlyTotal(now, 'expense'),
      _repository.getTotalAmount(DateTime(now.year, now.month, now.day), DateTime(now.year, now.month, now.day, 23, 59, 59, 999), 'expense'),
    ]);
    final balance = results[0] - results[1];
    final todayExpense = results[4];

    await Future.wait([
      HomeWidget.saveWidgetData('widget_date', '${Budget.yearMonthOf(now)}-${now.day.toString().padLeft(2, '0')}'),
      HomeWidget.saveWidgetData('widget_month', Budget.yearMonthOf(now)),
      HomeWidget.saveWidgetData('widget_balance', '${balance < 0 ? AppFormat.minus : ''}${AppFormat.rupiah(balance)}'),
      HomeWidget.saveWidgetData('widget_month_income', AppFormat.rupiah(results[2])),
      HomeWidget.saveWidgetData('widget_month_expense', AppFormat.rupiah(results[3])),
      HomeWidget.saveWidgetData('widget_today_expense', AppFormat.rupiah(todayExpense)),
      HomeWidget.saveWidgetData('widget_today_expense_short', _short(todayExpense)),
    ]);
  }

  /// Anggaran bulan berjalan. Rasio terpakai dikirim dalam per mil (int) agar
  /// provider bisa membandingkannya dengan pace harian tanpa aplikasi.
  Future<void> _saveBudget(DateTime now) async {
    final budgets = await _repository.getBudgetsForMonth(now);
    final spending = await _repository.getCategorySpendingForMonth(now);
    final categories = {for (final c in await _repository.getCategories()) c.id: c.label};

    final active = budgets.where((b) => b.amount > 0 && categories.containsKey(b.categoryId)).toList();
    final total = active.fold(0.0, (sum, b) => sum + b.amount);
    final spent = active.fold(0.0, (sum, b) => sum + (spending[b.categoryId] ?? 0));
    final remaining = total - spent;
    int permille(double used, double budget) => budget <= 0 ? 0 : (used / budget * 1000).round();

    final rows = [
      for (final b in active) (label: categories[b.categoryId]!, ratio: permille(spending[b.categoryId] ?? 0, b.amount)),
    ]..sort((a, b) => b.ratio.compareTo(a.ratio));

    await Future.wait([
      HomeWidget.saveWidgetData('budget_month', Budget.yearMonthOf(now)),
      HomeWidget.saveWidgetData('budget_count', active.length),
      HomeWidget.saveWidgetData('budget_remaining', AppFormat.rupiah(remaining)),
      HomeWidget.saveWidgetData('budget_over', remaining < 0),
      HomeWidget.saveWidgetData('budget_ratio', permille(spent, total)),
      HomeWidget.saveWidgetData('budget_max_ratio', rows.isEmpty ? 0 : rows.first.ratio),
      for (var i = 0; i < _budgetRows; i++) ...[
        HomeWidget.saveWidgetData('budget_cat${i}_label', i < rows.length ? rows[i].label : null),
        HomeWidget.saveWidgetData('budget_cat${i}_ratio', i < rows.length ? rows[i].ratio : null),
      ],
    ]);
  }

  /// Versi ringkas untuk widget 3×1 yang sempit: "Rp 85.000", "Rp 1,3 jt".
  static String _short(double amount) => amount < 1000000 ? AppFormat.rupiah(amount) : _compact.format(amount.round());

  /// `wisterlite://create?type=expense|income` membuka form catat,
  /// `wisterlite://budget` membuka tab Anggaran, `wisterlite://home` cukup membuka aplikasi.
  void _handleUri(Uri? uri) {
    if (uri == null) return;
    switch (uri.host) {
      case 'create':
        _openCreate(uri.queryParameters['type'] == 'income' ? 'income' : 'expense');
      case 'budget':
        _openTab(1);
    }
  }

  void _openCreate(String type) {
    // Form tambah yang sudah terbuka cukup ganti tipe agar isian tidak hilang.
    if (_onCreateForm) {
      final form = Get.find<ExpanseCreateController>();
      if (!form.isEditing) form.setType(type);
      return;
    }
    Get.toNamed(Routes.EXPANSE_CREATE, parameters: {'type': type})?.then((result) {
      if (result == true) MainNavController.refreshAll();
    });
  }

  void _openTab(int index) {
    if (!Get.isRegistered<MainNavController>()) return;
    // Form yang sedang diisi dibiarkan; tab tetap diganti di belakangnya.
    if (!_onCreateForm) Get.until((route) => route.settings.name == Routes.MAIN_NAV);
    Get.find<MainNavController>().changeTab(index);
  }

  bool get _onCreateForm => Get.currentRoute.startsWith(Routes.EXPANSE_CREATE) && Get.isRegistered<ExpanseCreateController>();
}
