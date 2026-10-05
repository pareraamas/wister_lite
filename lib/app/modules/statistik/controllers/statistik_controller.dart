import 'dart:convert';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:wister_lite/app/ults/clock.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';
import 'package:wister_lite/app/data/services/share_service.dart';
import 'package:wister_lite/app/data/services/transaction_csv.dart';
import 'package:wister_lite/app/data/services/transaction_export.dart';
import 'package:wister_lite/app/data/services/transaction_import.dart';
import 'package:wister_lite/app/data/services/transaction_report.dart';
import 'package:wister_lite/app/data/services/transaction_xlsx.dart';
import 'package:wister_lite/app/modules/import_preview/controllers/import_preview_controller.dart';
import 'package:wister_lite/app/modules/main_nav/controllers/main_nav_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wister_lite/app/routes/app_pages.dart';
import 'package:wister_lite/app/widgets/app_snackbar.dart';

class StatistikController extends GetxController {
  final ExpenseRepository _repository = Get.find<ExpenseRepository>();

  final selectedMonth = DateTime(Clock.now().year, Clock.now().month).obs;
  final categories = <Category>[].obs;
  final spendingByCategory = <String, double>{}.obs;
  final totalIncome = 0.0.obs;
  final totalExpense = 0.0.obs;
  final isLoading = true.obs;

  double get balance => totalIncome.value - totalExpense.value;

  List<Category> get categoriesWithSpending {
    final result = categories.where((c) => (spendingByCategory[c.id] ?? 0) > 0).toList();
    result.sort((a, b) => (spendingByCategory[b.id] ?? 0).compareTo(spendingByCategory[a.id] ?? 0));
    return result;
  }

  /// Irisan donut: maksimal 6 kategori terbesar + "Lainnya".
  static const maxSlices = 6;

  List<DonutSlice> get donutSlices {
    final sorted = categoriesWithSpending;
    final slices = [for (final c in sorted.take(maxSlices)) DonutSlice(category: c, amount: spendingByCategory[c.id] ?? 0)];
    if (sorted.length > maxSlices) {
      final rest = sorted.skip(maxSlices).fold(0.0, (sum, c) => sum + (spendingByCategory[c.id] ?? 0));
      slices.add(DonutSlice(category: null, amount: rest));
    }
    return slices;
  }

  /// Persentase [amount] terhadap total pengeluaran bulan ini (0–1).
  double shareOf(double amount) => totalExpense.value <= 0 ? 0 : (amount / totalExpense.value).clamp(0.0, 1.0);

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  /// Skeleton hanya saat load pertama; refresh berikutnya diam-diam.
  Future<void> loadData() async {
    final fetchedCategories = await _repository.getCategories();
    final spending = await _repository.getCategorySpendingForMonth(selectedMonth.value);
    final income = await _repository.getMonthlyTotal(selectedMonth.value, 'income');
    final expense = await _repository.getMonthlyTotal(selectedMonth.value, 'expense');

    categories.assignAll(fetchedCategories);
    spendingByCategory.assignAll(spending);
    totalIncome.value = income;
    totalExpense.value = expense;

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

  // --- Export & bagikan ---

  void openShareCard() => Get.toNamed(Routes.SHARE_CARD, arguments: selectedMonth.value);

  /// Export transaksi bulan terpilih, atau semua transaksi bila [allTime].
  Future<void> export(ExportFormat format, {bool allTime = false, Rect? origin}) async {
    final month = selectedMonth.value;
    final period = allTime ? const ReportPeriod.allTime() : ReportPeriod.month(month);
    final expenses = allTime
        ? await _repository.getExpensesByDateRange(DateTime(2000), DateTime(2100))
        : await _repository.getExpensesForMonth(month);
    if (expenses.isEmpty) {
      showAppSnackBar('Belum ada transaksi untuk diekspor.'.tr);
      return;
    }
    try {
      final file = await TransactionExport.build(format, expenses, period);
      await Get.find<ShareService>().shareExport(file, origin: origin);
    } catch (_) {
      showAppSnackBar('Gagal mengekspor file. Coba lagi.'.tr);
    }
  }

  // --- Import ---

  /// Pilih file CSV/Excel, baca, lalu buka layar pratinjau. Data baru
  /// tersimpan setelah pengguna menekan "Impor" di pratinjau.
  Future<void> pickImportFile() async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['csv', 'xlsx']);
    } catch (_) {
      showAppSnackBar('Tidak bisa membuka pemilih file.'.tr);
      return;
    }
    if (picked.isEmpty) return;
    final file = picked.first;

    final ImportPlan plan;
    try {
      final bytes = await file.xFile.readAsBytes();
      final rows = file.extension?.toLowerCase() == 'xlsx'
          ? TransactionXlsx.decode(bytes)
          : TransactionCsv.decode(utf8.decode(bytes, allowMalformed: true));
      final importer = TransactionImporter(
        categories: await _repository.getCategories(),
        existing: await _repository.getExpensesByDateRange(DateTime(1900), DateTime(2200)),
      );
      plan = importer.parse(rows);
    } catch (_) {
      showAppSnackBar('File tidak bisa dibaca. Pastikan formatnya CSV atau Excel (.xlsx).'.tr);
      return;
    }

    final imported = await Get.toNamed(Routes.IMPORT_PREVIEW, arguments: ImportPreviewArgs(file.name, plan));
    if (imported is int && imported > 0) {
      MainNavController.refreshAll();
      showAppSnackBar('@n transaksi berhasil diimpor.'.trParams({'n': '$imported'}));
    }
  }
}

/// Satu irisan donut. [category] null = gabungan "Lainnya".
class DonutSlice {
  const DonutSlice({required this.category, required this.amount});

  final Category? category;
  final double amount;

  bool get isOther => category == null;
  String get label => category?.label ?? 'Lainnya'.tr;
}
