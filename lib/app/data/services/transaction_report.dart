import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/ui/app_format.dart';

/// Rentang data yang diekspor: satu bulan, atau semua transaksi.
class ReportPeriod {
  const ReportPeriod.month(DateTime this.month);
  const ReportPeriod.allTime() : month = null;

  final DateTime? month;

  bool get isAllTime => month == null;

  /// "September 2026" / "Semua transaksi".
  String get label => month == null ? 'Semua transaksi'.tr : AppFormat.monthYear(month!);

  /// Bagian nama file: "2026-09" / "semua".
  String get fileStamp => month == null ? 'semua'.tr : '${month!.year}-${month!.month.toString().padLeft(2, '0')}';
}

/// Total per kategori dalam satu periode.
class CategoryTotal {
  CategoryTotal(this.label, this.colorValue);

  final String label;
  final int? colorValue;
  double expense = 0;
  double income = 0;
}

/// Ringkasan yang dipakai laporan Excel & PDF.
class TransactionSummary {
  TransactionSummary._(this.expenses, this.income, this.expense, this.categories);

  /// [expenses] diurutkan lama → baru, seperti buku kas.
  factory TransactionSummary.of(List<Expense> expenses) {
    final ordered = [...expenses]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final byCategory = <String, CategoryTotal>{};
    var income = 0.0;
    var expense = 0.0;
    for (final e in ordered) {
      final label = e.category?.label ?? 'Tanpa kategori'.tr;
      final total = byCategory.putIfAbsent(e.type, () => CategoryTotal(label, e.category?.colorValue));
      if (e.transactionType == 'income') {
        income += e.price;
        total.income += e.price;
      } else {
        expense += e.price;
        total.expense += e.price;
      }
    }
    final categories = byCategory.values.toList()..sort((a, b) => (b.expense + b.income).compareTo(a.expense + a.income));
    return TransactionSummary._(ordered, income, expense, categories);
  }

  final List<Expense> expenses;
  final double income;
  final double expense;
  final List<CategoryTotal> categories;

  double get balance => income - expense;

  /// Kategori yang punya pengeluaran, terbesar dulu.
  List<CategoryTotal> get expenseCategories => categories.where((c) => c.expense > 0).toList()..sort((a, b) => b.expense.compareTo(a.expense));

  double shareOf(double amount) => expense <= 0 ? 0 : amount / expense;
}
