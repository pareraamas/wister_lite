import 'package:wister_lite/app/data/models/budget_model.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/data/models/transaction_filter.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';

import 'fixtures.dart';

/// Bulan & hari acuan untuk semua test QA. Golden harus sama besok maupun
/// tahun depan, jadi "bulan ini" dan "hari ini" dipatok ke sini.
final referenceToday = DateTime(2026, 9, 28);

/// Nilai `Clock.now` selama test QA.
final referenceNow = DateTime(2026, 9, 28, 10);

/// Pengganti [ExpenseRepository] di memori, meniru semantik SQL di
/// `DatabaseHelper` (JOIN kategori, urutan DESC, paginasi, BETWEEN inklusif).
///
/// Harness mengunci `Clock.now` ke [referenceNow]. Sebagai jaring kedua bagi
/// kode yang masih memanggil `DateTime.now()`, fake memetakan bulan/hari nyata
/// ke [referenceToday]. Rentang lain (mis. saldo all-time 2000–2100) dipakai
/// apa adanya.
class FakeExpenseRepository implements ExpenseRepository {
  FakeExpenseRepository({
    List<Category> categories = const [],
    List<Expense> expenses = const [],
    List<Budget> budgets = const [],
    DateTime? realNow,
  })  : _realNow = realNow ?? DateTime.now(),
        categories = [...categories],
        expenses = [...expenses],
        budgets = [...budgets];

  final DateTime _realNow;
  final List<Category> categories;
  final List<Expense> expenses;
  final List<Budget> budgets;

  /// Log pemanggilan yang mengubah data, untuk uji paritas.
  final writes = <String>[];

  // --- Pemetaan waktu ---

  bool _isRealMonth(DateTime d) => d.year == _realNow.year && d.month == _realNow.month;
  bool _isRealDay(DateTime d) => _isRealMonth(d) && d.day == _realNow.day;

  DateTime _pinMonth(DateTime d) {
    if (!_isRealMonth(d)) return d;
    final lastDay = DateTime(referenceToday.year, referenceToday.month + 1, 0).day;
    return DateTime(referenceToday.year, referenceToday.month, d.day.clamp(1, lastDay), d.hour, d.minute, d.second, d.millisecond);
  }

  (DateTime, DateTime) _pinRange(DateTime start, DateTime end) {
    if (_isRealDay(start) && _isRealDay(end)) {
      DateTime at(DateTime d) => DateTime(referenceToday.year, referenceToday.month, referenceToday.day, d.hour, d.minute, d.second, d.millisecond);
      return (at(start), at(end));
    }
    if (_isRealMonth(start) && _isRealMonth(end)) {
      final s = DateTime(referenceToday.year, referenceToday.month, 1, start.hour, start.minute, start.second);
      final e = DateTime(referenceToday.year, referenceToday.month + 1, 0, 23, 59, 59);
      // Rentang sebulan penuh dipetakan ke bulan acuan penuh.
      if (start.day == 1 && end.day == DateTime(end.year, end.month + 1, 0).day) return (s, e);
      return (_pinMonth(start), _pinMonth(end));
    }
    return (start, end);
  }

  (DateTime, DateTime) _monthRange(DateTime month) {
    final m = _pinMonth(month);
    return (DateTime(m.year, m.month, 1), DateTime(m.year, m.month + 1, 0, 23, 59, 59));
  }

  // --- Helper query ---

  Category? _category(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Meniru `JOIN categories`: transaksi tanpa kategori tidak ikut.
  List<Expense> _joined(Iterable<Expense> source) => [
        for (final e in source)
          if (_category(e.type) case final c?) e.copyWith(category: c),
      ]..sort((a, b) => b.dateTime.toIso8601String().compareTo(a.dateTime.toIso8601String()));

  // BETWEEN di SQLite membandingkan string ISO-8601.
  bool _between(DateTime d, DateTime start, DateTime end) {
    final s = d.toIso8601String();
    return s.compareTo(start.toIso8601String()) >= 0 && s.compareTo(end.toIso8601String()) <= 0;
  }

  Iterable<Expense> _inRange(DateTime start, DateTime end, String? transactionType) =>
      expenses.where((e) => _between(e.dateTime, start, end) && (transactionType == null || e.transactionType == transactionType));

  double _sum(Iterable<Expense> list) => list.fold(0.0, (a, e) => a + e.price);

  // --- Expense ---

  @override
  Future<int> insertExpense(Expense expense) async {
    writes.add('insertExpense');
    expenses.add(expense.copyWith());
    return 1;
  }

  @override
  Future<void> importTransactions(List<Category> categories, List<Expense> expenses) async {
    writes.add('importTransactions');
    final catIds = {for (final c in this.categories) c.id};
    this.categories.addAll(categories.where((c) => catIds.add(c.id)));
    final ids = {for (final e in this.expenses) e.id};
    this.expenses.addAll(expenses.where((e) => ids.add(e.id)).map((e) => e.copyWith()));
  }

  @override
  Future<void> resetLocalData() async {
    writes.add('resetLocalData');
    expenses.clear();
    budgets.clear();
    categories
      ..clear()
      ..addAll(seedCategories());
  }

  @override
  Future<int> clearDatabase() async {
    writes.add('clearDatabase');
    expenses.clear();
    final n = categories.length;
    categories.clear();
    return n;
  }

  @override
  Future<List<Expense>> getExpenses({int limit = 10, int offset = 0}) async =>
      _joined(expenses).skip(offset * limit).take(limit).toList();

  @override
  Future<List<Expense>> searchExpenses(TransactionFilter filter, {int limit = 20, int offset = 0}) async =>
      (_joined(expenses).where(filter.matches).toList()..sort(filter.compare)).skip(offset).take(limit).toList();

  @override
  Future<TransactionTotals> summarizeExpenses(TransactionFilter filter) async {
    final list = _joined(expenses).where(filter.matches).toList();
    return (
      count: list.length,
      income: _sum(list.where((e) => e.transactionType == 'income')),
      expense: _sum(list.where((e) => e.transactionType != 'income')),
    );
  }

  @override
  Future<Expense?> getExpense(String id) async {
    for (final e in _joined(expenses)) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<int> updateExpense(Expense expense) async {
    writes.add('updateExpense');
    final i = expenses.indexWhere((e) => e.id == expense.id);
    if (i < 0) return 0;
    expenses[i] = expense;
    return 1;
  }

  @override
  Future<int> deleteExpense(String id) async {
    writes.add('deleteExpense');
    final before = expenses.length;
    expenses.removeWhere((e) => e.id == id);
    return before - expenses.length;
  }

  @override
  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end, {String? transactionType}) async {
    final (s, e) = _pinRange(start, end);
    return _joined(_inRange(s, e, transactionType));
  }

  @override
  Future<Map<String, double>> getExpensesByType({String transactionType = 'expense'}) async {
    final result = <String, double>{};
    for (final e in _joined(expenses.where((e) => e.transactionType == transactionType))) {
      result.update(e.category!.label, (v) => v + e.price, ifAbsent: () => e.price);
    }
    return result;
  }

  @override
  Future<double> getTotalAmount(DateTime start, DateTime end, String transactionType) async {
    final (s, e) = _pinRange(start, end);
    return _sum(_inRange(s, e, transactionType));
  }

  @override
  Future<List<Expense>> getExpensesForMonth(DateTime month, {String? transactionType}) async {
    final (s, e) = _monthRange(month);
    return _joined(_inRange(s, e, transactionType));
  }

  @override
  Future<double> getMonthlyTotal(DateTime month, String transactionType) async {
    final (s, e) = _monthRange(month);
    return _sum(_inRange(s, e, transactionType));
  }

  // --- Category ---

  @override
  Future<List<Category>> getCategories() async => [...categories];

  @override
  Future<int> insertCategory(Category category) async {
    writes.add('insertCategory');
    categories.add(category);
    return 1;
  }

  @override
  Future<int> updateCategory(Category category) async {
    writes.add('updateCategory');
    final i = categories.indexWhere((c) => c.id == category.id);
    if (i < 0) return 0;
    categories[i] = category;
    return 1;
  }

  @override
  Future<int> countExpensesByCategory(String categoryId) async => expenses.where((e) => e.type == categoryId).length;

  @override
  Future<int> deleteCategory(String categoryId) async {
    writes.add('deleteCategory');
    final before = categories.length;
    categories.removeWhere((c) => c.id == categoryId);
    return before - categories.length;
  }

  // --- Budget ---

  @override
  Future<Map<String, double>> getCategorySpendingForMonth(DateTime month, {String transactionType = 'expense'}) async {
    final (s, e) = _monthRange(month);
    final result = <String, double>{};
    for (final x in _inRange(s, e, transactionType)) {
      result.update(x.type, (v) => v + x.price, ifAbsent: () => x.price);
    }
    return result;
  }

  @override
  Future<List<Budget>> getBudgetsForMonth(DateTime month) async {
    final ym = Budget.yearMonthOf(_pinMonth(month));
    return budgets.where((b) => b.yearMonth == ym).toList();
  }

  @override
  Future<void> setBudget(String categoryId, DateTime month, double amount) async {
    writes.add('setBudget');
    final ym = Budget.yearMonthOf(_pinMonth(month));
    final i = budgets.indexWhere((b) => b.categoryId == categoryId && b.yearMonth == ym);
    if (i >= 0) {
      budgets[i] = Budget(id: budgets[i].id, categoryId: categoryId, yearMonth: ym, amount: amount);
    } else {
      budgets.add(Budget.create(categoryId: categoryId, yearMonth: ym, amount: amount));
    }
  }

  @override
  Future<int> deleteBudget(String categoryId, DateTime month) async {
    writes.add('deleteBudget');
    final ym = Budget.yearMonthOf(_pinMonth(month));
    final before = budgets.length;
    budgets.removeWhere((b) => b.categoryId == categoryId && b.yearMonth == ym);
    return before - budgets.length;
  }

  /// Isi "database" dalam bentuk yang bisa dibandingkan antar versi UI.
  /// Id acak (uuid) diganti penanda agar snapshot deterministik.
  Map<String, Object> snapshot() {
    String catRef(String id) => seedCategoryIds.contains(id) ? id : 'baru:${_category(id)?.label ?? id}';
    return {
      'categories': [
        for (final c in [...categories]..sort((a, b) => a.label.compareTo(b.label)))
          {'id': catRef(c.id), 'label': c.label, 'color': c.colorValue.toRadixString(16), 'icon': c.icon},
      ],
      'expenses': [
        for (final e in [...expenses]..sort((a, b) => '${a.dateTime.toIso8601String()}${a.name}'.compareTo('${b.dateTime.toIso8601String()}${b.name}')))
          {'name': e.name, 'category': catRef(e.type), 'type': e.transactionType, 'date': _day(e.dateTime), 'price': e.price},
      ],
      'budgets': [
        for (final b in [...budgets]..sort((a, b) => '${a.yearMonth}${a.categoryId}'.compareTo('${b.yearMonth}${b.categoryId}')))
          {'category': catRef(b.categoryId), 'month': b.yearMonth, 'amount': b.amount},
      ],
    };
  }

  // Transaksi baru bertanggal "sekarang" nyata; ditulis relatif agar stabil.
  String _day(DateTime d) {
    bool sameDay(DateTime x) => d.year == x.year && d.month == x.month && d.day == x.day;
    if (sameDay(_realNow) || sameDay(referenceToday)) return 'hari-ini';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

/// Id 9 kategori bawaan, sama dengan yang di-seed `DatabaseHelper._onCreate`.
const seedCategoryIds = {'food', 'internet', 'education', 'gift', 'transportation', 'shopping', 'home_appliances', 'sport', 'entertainment'};
