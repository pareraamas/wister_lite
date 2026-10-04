import 'package:flutter/material.dart' show DateUtils;
import 'package:get/get.dart';
import 'package:wister_lite/app/ults/clock.dart';
import 'package:wister_lite/app/data/models/budget_model.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';
import 'package:wister_lite/app/modules/main_nav/controllers/main_nav_controller.dart';
import 'package:wister_lite/app/routes/app_pages.dart';
import 'package:wister_lite/app/ui/budget_progress.dart';
import 'package:wister_lite/app/widgets/app_snackbar.dart';

class HomeController extends GetxController {
  final ExpenseRepository _expenseRepository = Get.find<ExpenseRepository>();

  /// Beranda hanya menampilkan beberapa transaksi hari ini; sisanya di Riwayat Transaksi.
  static const todayLimit = 5;

  final totalOutcomeDay = 0.0.obs;
  final totalOutcomeMonth = 0.0.obs;
  final totalIncomeMonth = 0.0.obs;
  final totalBalance = 0.0.obs;

  /// Banyaknya kategori teratas di kartu "Paling banyak keluar".
  static const topCategoryCount = 3;

  /// Pengeluaran per hari, 7 hari terakhir (indeks 0 = 6 hari lalu, terakhir = hari ini).
  final last7Days = <double>[].obs;

  /// Pengeluaran bulan lalu dari tanggal 1 sampai tanggal yang sama dengan hari ini.
  final lastMonthToDate = 0.0.obs;

  final categories = <Category>[].obs;
  final budgetByCategory = <String, double>{}.obs;
  final spendingByCategory = <String, double>{}.obs;

  /// Load pertama (untuk skeleton).
  final isLoading = true.obs;

  /// Semua transaksi hari ini (terbaru dulu); view menampilkan [todayLimit] pertama.
  final todayExpenses = <Expense>[].obs;

  /// Bulan yang diringkas di kartu Masuk/Keluar.
  DateTime get currentMonth => DateTime(Clock.now().year, Clock.now().month);

  double get totalBudget => budgetByCategory.values.fold(0.0, (a, b) => a + b);

  /// Pengeluaran hanya dari kategori yang punya budget (sama dengan halaman Anggaran).
  double get budgetedSpent => budgetByCategory.keys.fold(0.0, (sum, id) => sum + (spendingByCategory[id] ?? 0));

  /// Rata-rata pengeluaran harian bulan ini sampai hari ini.
  double get dailyAverage => totalOutcomeMonth.value / Clock.now().day;

  /// Perubahan dibanding periode yang sama bulan lalu (0.12 = naik 12%). Null = bulan lalu kosong.
  double? get monthChange {
    if (lastMonthToDate.value <= 0) return null;
    return totalOutcomeMonth.value / lastMonthToDate.value - 1;
  }

  /// Kategori yang terpakai >= 80% atau lewat anggaran.
  int get budgetAlertCount => budgetByCategory.entries
      .where((b) => b.value > 0 && BudgetProgress.statusOf(BudgetProgress.ratioOf(spendingByCategory[b.key] ?? 0, b.value)) != BudgetStatus.safe)
      .length;

  /// Kategori dengan pengeluaran terbesar bulan ini, terbesar dulu.
  List<(Category, double)> get topCategories {
    final byId = {for (final c in categories) c.id: c};
    final entries = spendingByCategory.entries.where((e) => e.value > 0 && byId.containsKey(e.key)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(topCategoryCount).map((e) => (byId[e.key]!, e.value)).toList();
  }

  /// Sapaan sesuai jam (tanpa nama; aplikasi tidak menyimpan nama user).
  String get greeting {
    final h = Clock.now().hour;
    if (h < 11) return 'Selamat pagi!';
    if (h < 15) return 'Selamat siang!';
    if (h < 18) return 'Selamat sore!';
    return 'Selamat malam!';
  }

  Future<void> openCreate() async {
    if (Get.isRegistered<MainNavController>()) return Get.find<MainNavController>().openCreateTransaction();
    final result = await Get.toNamed(Routes.EXPANSE_CREATE);
    if (result == true) MainNavController.refreshAll();
  }

  void openBudget() => _openTab(1, Routes.BUDGET);

  void openStatistik() => _openTab(2, Routes.STATISTIK);

  void _openTab(int index, String route) {
    if (Get.isRegistered<MainNavController>()) return Get.find<MainNavController>().changeTab(index);
    Get.toNamed(route);
  }

  /// Riwayat lengkap dengan filter ada di halaman sendiri.
  void openHistory() => Get.toNamed(Routes.TRANSACTION_HISTORY);

  Future<void> openEdit(Expense expense) async {
    final result = await Get.toNamed(Routes.EXPANSE_CREATE, arguments: expense.id);
    if (result == true) MainNavController.refreshAll();
  }

  /// Hapus dari geser di riwayat (sudah dikonfirmasi oleh [TransactionTile]).
  Future<void> deleteExpense(Expense expense) async {
    // Langsung hilang dari list agar Dismissible tidak dibangun ulang.
    todayExpenses.removeWhere((e) => e.id == expense.id);
    try {
      await _expenseRepository.deleteExpense(expense.id!);
      showAppSnackBar('Transaksi dihapus');
    } catch (_) {
      showAppSnackBar('Gagal menghapus transaksi. Coba lagi, ya.');
    }
    MainNavController.refreshAll();
  }

  @override
  void onInit() {
    super.onInit();
    onRefresh();
  }

  Future<void> onRefresh() async {
    await Future.wait([onGetMonthlySummary(), onGetTotalOutcomeDay(), onGetTodayExpenses(), onGetBudgetAndCategories(), onGetTrend()]);
    isLoading.value = false;
  }

  Future<void> onGetTodayExpenses() async {
    final now = Clock.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    todayExpenses.assignAll(await _expenseRepository.getExpensesByDateRange(start, end));
  }

  Future<void> onGetBudgetAndCategories() async {
    final month = currentMonth;
    final results = await Future.wait([
      _expenseRepository.getCategories(),
      _expenseRepository.getBudgetsForMonth(month),
      _expenseRepository.getCategorySpendingForMonth(month),
    ]);
    categories.assignAll(results[0] as List<Category>);
    budgetByCategory
      ..clear()
      ..addEntries((results[1] as List<Budget>).map((b) => MapEntry(b.categoryId, b.amount)));
    spendingByCategory.assignAll(results[2] as Map<String, double>);
  }

  /// Data grafik 7 hari dan pembanding bulan lalu.
  Future<void> onGetTrend() async {
    final now = Clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = today.subtract(const Duration(days: 6));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final expenses = await _expenseRepository.getExpensesByDateRange(from, end, transactionType: 'expense');
    final days = List.filled(7, 0.0);
    for (final e in expenses) {
      final i = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day).difference(from).inDays;
      if (i >= 0 && i < 7) days[i] += e.price;
    }
    last7Days.assignAll(days);

    // 31 Okt → 30 Sep: tanggal dipotong ke hari terakhir bulan lalu.
    final lastStart = DateTime(now.year, now.month - 1);
    final lastEnd = DateTime(lastStart.year, lastStart.month, now.day.clamp(1, DateUtils.getDaysInMonth(lastStart.year, lastStart.month)), 23, 59, 59, 999);
    lastMonthToDate.value = await _expenseRepository.getTotalAmount(lastStart, lastEnd, 'expense');
  }

  Future<void> onGetTotalOutcomeDay() async {
    final now = Clock.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    totalOutcomeDay.value = await _expenseRepository.getTotalAmount(start, end, 'expense');
  }

  Future<void> onGetMonthlySummary() async {
    final now = Clock.now();
    totalOutcomeMonth.value = await _expenseRepository.getMonthlyTotal(now, 'expense');
    totalIncomeMonth.value = await _expenseRepository.getMonthlyTotal(now, 'income');

    final allIncome = await _expenseRepository.getTotalAmount(DateTime(2000), DateTime(2100), 'income');
    final allExpense = await _expenseRepository.getTotalAmount(DateTime(2000), DateTime(2100), 'expense');
    totalBalance.value = allIncome - allExpense;
  }
}
