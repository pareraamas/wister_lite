import 'package:get/get.dart';
import 'package:wister_lite/app/ults/clock.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/services/home_widget_service.dart';
import 'package:wister_lite/app/data/services/sync_service.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';

class BudgetController extends GetxController {
  final ExpenseRepository _repository = Get.find<ExpenseRepository>();

  final selectedMonth = DateTime(Clock.now().year, Clock.now().month).obs;
  final categories = <Category>[].obs;
  final budgetByCategory = <String, double>{}.obs;
  final spendingByCategory = <String, double>{}.obs;
  final isLoading = true.obs;

  double get totalBudget => budgetByCategory.values.fold(0.0, (a, b) => a + b);
  double get totalSpent => spendingByCategory.values.fold(0.0, (a, b) => a + b);

  /// Pengeluaran hanya dari kategori yang punya budget (untuk kartu "Sisa").
  double get budgetedSpent => budgetByCategory.keys.fold(0.0, (sum, id) => sum + (spendingByCategory[id] ?? 0));

  double get remaining => totalBudget - budgetedSpent;

  /// Posisi hari ini di bulan terpilih (0–1). Bulan lalu = 1, bulan depan = 0.
  double get pace {
    final now = Clock.now();
    final m = selectedMonth.value;
    if (m.year == now.year && m.month == now.month) {
      final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
      return now.day / daysInMonth;
    }
    return m.isBefore(DateTime(now.year, now.month)) ? 1 : 0;
  }

  /// Penanda pace untuk [BudgetProgress]: hanya di bulan berjalan.
  double? get paceMarker {
    final p = pace;
    return p > 0 && p < 1 ? p : null;
  }

  List<Category> get categoriesWithBudget => categories.where((c) => (budgetByCategory[c.id] ?? 0) > 0).toList();

  List<Category> get categoriesWithoutBudget => categories.where((c) => (budgetByCategory[c.id] ?? 0) <= 0).toList();

  /// True jika ada budget dan semuanya masih di bawah pace (momen Dompi bangga).
  bool get allUnderPace {
    if (budgetByCategory.isEmpty) return false;
    return budgetByCategory.entries.every((e) => (spendingByCategory[e.key] ?? 0) / e.value <= pace);
  }

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  /// Skeleton hanya saat load pertama; refresh berikutnya diam-diam.
  Future<void> loadData() async {
    final fetchedCategories = await _repository.getCategories();
    final budgets = await _repository.getBudgetsForMonth(selectedMonth.value);
    final spending = await _repository.getCategorySpendingForMonth(selectedMonth.value);

    categories.assignAll(fetchedCategories);
    budgetByCategory
      ..clear()
      ..addEntries(budgets.map((b) => MapEntry(b.categoryId, b.amount)));
    spendingByCategory.assignAll(spending);

    isLoading.value = false;
  }

  void goToPreviousMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month - 1);
    loadData();
  }

  void goToNextMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month + 1);
    loadData();
  }

  void setMonth(DateTime month) {
    selectedMonth.value = DateTime(month.year, month.month);
    loadData();
  }

  Future<void> setBudget(String categoryId, double amount) async {
    if (amount <= 0) {
      await _repository.deleteBudget(categoryId, selectedMonth.value);
      budgetByCategory.remove(categoryId);
    } else {
      await _repository.setBudget(categoryId, selectedMonth.value, amount);
      budgetByCategory[categoryId] = amount;
    }
    if (Get.isRegistered<HomeWidgetService>()) Get.find<HomeWidgetService>().update();
    if (Get.isRegistered<SyncService>()) Get.find<SyncService>().scheduleSync();
  }
}
