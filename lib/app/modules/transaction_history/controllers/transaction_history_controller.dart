import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/data/models/transaction_filter.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';
import 'package:wister_lite/app/modules/main_nav/controllers/main_nav_controller.dart';
import 'package:wister_lite/app/routes/app_pages.dart';
import 'package:wister_lite/app/widgets/app_snackbar.dart';

/// Riwayat transaksi lengkap dengan pencarian, filter, dan urutan.
///
/// `Get.arguments` boleh berisi [TransactionFilter] awal.
class TransactionHistoryController extends GetxController {
  final ExpenseRepository _expenseRepository = Get.find<ExpenseRepository>();

  static const pageSize = 20;

  late final Rx<TransactionFilter> filter;
  final searchController = TextEditingController();
  final _query = ''.obs;

  final items = <Expense>[].obs;
  final totals = (count: 0, income: 0.0, expense: 0.0).obs;
  final categories = <Category>[].obs;

  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;

  /// Naik tiap reload agar hasil query lama yang telat datang diabaikan.
  int _generation = 0;

  @override
  void onInit() {
    super.onInit();
    final initial = Get.arguments is TransactionFilter ? Get.arguments as TransactionFilter : const TransactionFilter();
    filter = initial.obs;
    searchController.text = initial.query;
    _query.value = initial.query;
    debounce(_query, (q) => filter.value = filter.value.copyWith(query: q), time: const Duration(milliseconds: 300));
    ever(filter, (_) => reload());
    _loadCategories();
    reload();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> _loadCategories() async {
    final list = await _expenseRepository.getCategories();
    categories.assignAll(list..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase())));
  }

  void onSearchChanged(String q) => _query.value = q;

  void clearSearch() {
    searchController.clear();
    _query.value = '';
    filter.value = filter.value.copyWith(query: '');
  }

  /// Dari sheet filter; pencarian tetap diambil dari kolom cari.
  void applyFilter(TransactionFilter f) => filter.value = f.copyWith(query: filter.value.query);

  /// Jumlah hasil untuk tombol "Tampilkan N transaksi" di sheet filter.
  Future<int> countFor(TransactionFilter f) async => (await _expenseRepository.summarizeExpenses(f)).count;

  void setType(String? type) => filter.value = filter.value.copyWith(transactionType: () => type);

  void setPeriod(DateTime? start, DateTime? end) => filter.value = filter.value.withPeriod(start, end);

  void setCategories(Set<String> ids) => filter.value = filter.value.copyWith(categoryIds: ids);

  void setAmount(double? min, double? max) => filter.value = filter.value.copyWith(minAmount: () => min, maxAmount: () => max);

  void setSort(TransactionSort sort) => filter.value = filter.value.copyWith(sort: sort);

  void resetFilters() {
    searchController.clear();
    _query.value = '';
    filter.value = filter.value.cleared();
  }

  Future<void> reload() async {
    final gen = ++_generation;
    final f = filter.value;
    hasMore.value = true;
    final (page, sum) = await (_expenseRepository.searchExpenses(f, limit: pageSize), _expenseRepository.summarizeExpenses(f)).wait;
    if (gen != _generation) return;
    items.assignAll(page);
    totals.value = sum;
    hasMore.value = page.length == pageSize;
    isLoading.value = false;
  }

  Future<void> loadMore() async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value) return;
    final gen = _generation;
    isLoadingMore.value = true;
    final page = await _expenseRepository.searchExpenses(filter.value, limit: pageSize, offset: items.length);
    isLoadingMore.value = false;
    if (gen != _generation) return;
    final ids = {for (final e in items) e.id};
    items.addAll(page.where((e) => ids.add(e.id)));
    hasMore.value = page.length == pageSize;
  }

  Future<void> openEdit(Expense expense) async {
    final result = await Get.toNamed(Routes.EXPANSE_CREATE, arguments: expense.id);
    if (result == true) MainNavController.refreshAll();
  }

  /// Hapus dari geser (sudah dikonfirmasi oleh `TransactionTile`).
  Future<void> deleteExpense(Expense expense) async {
    // Langsung hilang dari list agar Dismissible tidak dibangun ulang.
    items.removeWhere((e) => e.id == expense.id);
    try {
      await _expenseRepository.deleteExpense(expense.id!);
      showAppSnackBar('Transaksi dihapus'.tr);
    } catch (_) {
      showAppSnackBar('Gagal menghapus transaksi. Coba lagi, ya.'.tr);
    }
    MainNavController.refreshAll();
  }
}
