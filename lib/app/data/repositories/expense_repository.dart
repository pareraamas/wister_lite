import 'package:wister_lite/app/data/local/database_helper.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/models/budget_model.dart';
import 'package:wister_lite/app/data/models/transaction_filter.dart';

class ExpenseRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // Insert a new expense
  Future<int> insertExpense(Expense expense) async {
    return await _databaseHelper.insertExpense(expense);
  }

  // Save imported categories & transactions atomically
  Future<void> importTransactions(List<Category> categories, List<Expense> expenses) async {
    return _databaseHelper.importTransactions(categories, expenses);
  }

  // Wipe all local data and re-seed default categories (sign-out)
  Future<void> resetLocalData() {
    return _databaseHelper.resetLocalData();
  }

  // Clear the database
  Future<int> clearDatabase() async {
    return await _databaseHelper.clearDatabase();
  }

  // Get expenses with pagination
  Future<List<Expense>> getExpenses({int limit = 10, int offset = 0}) async {
    return await _databaseHelper.getExpenses(limit: limit, offset: offset);
  }

  // Get filtered history (offset in rows)
  Future<List<Expense>> searchExpenses(TransactionFilter filter, {int limit = 20, int offset = 0}) {
    return _databaseHelper.searchExpenses(filter, limit: limit, offset: offset);
  }

  // Get count & income/expense totals for a filter
  Future<TransactionTotals> summarizeExpenses(TransactionFilter filter) {
    return _databaseHelper.summarizeExpenses(filter);
  }

  // Get a single expense by id
  Future<Expense?> getExpense(String id) async {
    return await _databaseHelper.getExpense(id);
  }

  // Update an expense
  Future<int> updateExpense(Expense expense) async {
    return await _databaseHelper.updateExpense(expense);
  }

  // Delete an expense
  Future<int> deleteExpense(String id) async {
    return await _databaseHelper.deleteExpense(id);
  }

  // Get expenses by date range
  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end, {String? transactionType}) async {
    return await _databaseHelper.getExpensesByDateRange(start, end, transactionType: transactionType);
  }

  // Get total expenses by type
  Future<Map<String, double>> getExpensesByType({String transactionType = 'expense'}) async {
    return await _databaseHelper.getExpensesByType(transactionType: transactionType);
  }

  // Get total amount for a date range and type
  Future<double> getTotalAmount(DateTime start, DateTime end, String transactionType) async {
    return await _databaseHelper.getTotalAmountByDateRange(start, end, transactionType);
  }

  // Get expenses for a specific month
  Future<List<Expense>> getExpensesForMonth(DateTime month, {String? transactionType}) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return _databaseHelper.getExpensesByDateRange(firstDay, lastDay, transactionType: transactionType);
  }

  // Get monthly summary
  Future<double> getMonthlyTotal(DateTime month, String transactionType) async {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return _databaseHelper.getTotalAmountByDateRange(firstDay, lastDay, transactionType);
  }

  // --- Category Methods ---

  Future<List<Category>> getCategories() async {
    return await _databaseHelper.getCategories();
  }

  Future<int> insertCategory(Category category) async {
    return await _databaseHelper.insertCategory(category);
  }

  Future<int> updateCategory(Category category) async {
    return await _databaseHelper.updateCategory(category);
  }

  Future<int> countExpensesByCategory(String categoryId) async {
    return await _databaseHelper.countExpensesByCategory(categoryId);
  }

  Future<int> deleteCategory(String categoryId) async {
    return await _databaseHelper.deleteCategory(categoryId);
  }

  // --- Budget Methods ---

  // Get amount spent per category id for the given month (defaults to 'expense' transactions)
  Future<Map<String, double>> getCategorySpendingForMonth(DateTime month, {String transactionType = 'expense'}) async {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return _databaseHelper.getSpendingByCategoryForRange(firstDay, lastDay, transactionType: transactionType);
  }

  // Get all budgets set for the given month
  Future<List<Budget>> getBudgetsForMonth(DateTime month) async {
    return _databaseHelper.getBudgetsForMonth(Budget.yearMonthOf(month));
  }

  // Set (create or update) the budget for a category in the given month
  Future<void> setBudget(String categoryId, DateTime month, double amount) async {
    return _databaseHelper.setBudget(categoryId, Budget.yearMonthOf(month), amount);
  }

  // Remove the budget for a category in the given month
  Future<int> deleteBudget(String categoryId, DateTime month) async {
    return _databaseHelper.deleteBudget(categoryId, Budget.yearMonthOf(month));
  }
}
