import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/models/expense_type.dart';
import 'package:wister_lite/app/data/models/budget_model.dart';
import 'package:wister_lite/app/data/models/transaction_filter.dart';
import 'package:wister_lite/app/data/api/wister_api.dart';

import 'dart:io';

class DatabaseHelper {
  static const _databaseName = 'expense_database.db';
  static const _databaseVersion = 2;

  // Table names
  static const tableExpenses = 'expenses';
  static const tableCategories = 'categories';
  static const tableBudgets = 'budgets';
  static const tableDeletions = 'sync_deletions';

  // Kolom sync (v2) di ketiga tabel data.
  static const columnUpdatedAt = 'updated_at';
  static const columnDirty = 'dirty';

  /// Tabel yang ikut sync; namanya juga dipakai sebagai `entity` di API.
  static const syncedTables = [tableCategories, tableBudgets, tableExpenses];

  /// `updated_at` kategori bawaan: paling tua, agar versi server selalu menang.
  static const _seedUpdatedAt = '1970-01-01T00:00:00.000Z';

  // Expense Column names
  static const columnId = 'id';
  static const columnName = 'name';
  static const columnType = 'type'; // References Category ID
  static const columnTransactionType = 'transaction_type';
  static const columnDateTime = 'date_time';
  static const columnPrice = 'price';

  // Category Column names
  static const catId = 'id';
  static const catLabel = 'label';
  static const catColor = 'color_value';
  static const catIcon = 'icon';

  // Budget Column names
  static const budgetId = 'id';
  static const budgetCategoryId = 'category_id';
  static const budgetYearMonth = 'year_month'; // Format: 'YYYY-MM'
  static const budgetAmount = 'amount';

  // Make this a singleton class
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create Categories table first
    await db.execute('''
      CREATE TABLE $tableCategories (
        $catId TEXT PRIMARY KEY,
        $catLabel TEXT NOT NULL,
        $catColor INTEGER NOT NULL,
        $catIcon TEXT NOT NULL,
        $columnUpdatedAt TEXT,
        $columnDirty INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create Expenses table
    await db.execute('''
      CREATE TABLE $tableExpenses (
        $columnId TEXT PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnType TEXT NOT NULL,
        $columnTransactionType TEXT NOT NULL DEFAULT 'expense',
        $columnDateTime TEXT NOT NULL,
        $columnPrice REAL NOT NULL,
        $columnUpdatedAt TEXT,
        $columnDirty INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create Budgets table (one budget per category per month)
    await db.execute('''
      CREATE TABLE $tableBudgets (
        $budgetId TEXT PRIMARY KEY,
        $budgetCategoryId TEXT NOT NULL,
        $budgetYearMonth TEXT NOT NULL,
        $budgetAmount REAL NOT NULL,
        $columnUpdatedAt TEXT,
        $columnDirty INTEGER NOT NULL DEFAULT 1,
        UNIQUE($budgetCategoryId, $budgetYearMonth)
      )
    ''');

    await _createDeletionsTable(db);
    await _seedCategories(db);
  }

  /// Hapus lokal dicatat di sini agar ikut terkirim saat sync berikutnya.
  Future<void> _createDeletionsTable(DatabaseExecutor db) => db.execute('''
      CREATE TABLE $tableDeletions (
        entity TEXT NOT NULL,
        id TEXT NOT NULL,
        deleted_at TEXT NOT NULL,
        PRIMARY KEY (entity, id)
      )
    ''');

  Future<void> _seedCategories(DatabaseExecutor db) async {
    for (var type in ExpenseType.values) {
      await db.insert(tableCategories, {
        'id': type.toShortString().toLowerCase(), // Use enum name as ID for migration compatibility
        'label': type.label,
        'color_value': type.color.toARGB32(),
        'icon': type.icon,
        columnUpdatedAt: _seedUpdatedAt,
      });
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: kolom sync. Data lama ditandai dirty agar terunggah saat sync pertama.
      final now = _now();
      for (final table in syncedTables) {
        await db.execute('ALTER TABLE $table ADD COLUMN $columnUpdatedAt TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN $columnDirty INTEGER NOT NULL DEFAULT 1');
        await db.update(table, {columnUpdatedAt: now});
      }
      await _createDeletionsTable(db);
    }
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  /// Baris yang diubah lokal: cap waktu baru dan antre untuk sync.
  static Map<String, Object?> _stamped(Map<String, dynamic> row) => {...row, columnUpdatedAt: _now(), columnDirty: 1};

  static Future<void> _tombstone(DatabaseExecutor db, String table, Iterable<String> ids) async {
    final now = _now();
    for (final id in ids) {
      await db.insert(tableDeletions, {'entity': table, 'id': id, 'deleted_at': now}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Hapus baris berdasarkan id sekaligus mencatat tombstone-nya.
  Future<int> _deleteWhere(String table, String where, List<Object?> whereArgs) async {
    Database db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(table, columns: ['id'], where: where, whereArgs: whereArgs);
      await _tombstone(txn, table, rows.map((r) => r['id'] as String));
      return txn.delete(table, where: where, whereArgs: whereArgs);
    });
  }

  // --- Category Methods ---

  Future<List<Category>> getCategories() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(tableCategories);
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> insertCategory(Category category) async {
    Database db = await database;
    return await db.insert(tableCategories, _stamped(category.toMap()));
  }

  Future<int> updateCategory(Category category) async {
    Database db = await database;
    return await db.update(tableCategories, _stamped(category.toMap()), where: '$catId = ?', whereArgs: [category.id]);
  }

  Future<int> countExpensesByCategory(String categoryId) async {
    Database db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableExpenses WHERE $columnType = ?', [categoryId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteCategory(String categoryId) {
    return _deleteWhere(tableCategories, '$catId = ?', [categoryId]);
  }

  // --- Budget Methods ---

  Future<List<Budget>> getBudgetsForMonth(String yearMonth) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(tableBudgets, where: '$budgetYearMonth = ?', whereArgs: [yearMonth]);
    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  Future<void> setBudget(String categoryId, String yearMonth, double amount) async {
    Database db = await database;
    final existing = await db.query(tableBudgets, where: '$budgetCategoryId = ? AND $budgetYearMonth = ?', whereArgs: [categoryId, yearMonth]);

    if (existing.isNotEmpty) {
      await db.update(tableBudgets, _stamped({budgetAmount: amount}), where: '$budgetId = ?', whereArgs: [existing.first[budgetId]]);
    } else {
      await db.insert(tableBudgets, _stamped(Budget.create(categoryId: categoryId, yearMonth: yearMonth, amount: amount).toMap()));
    }
  }

  Future<int> deleteBudget(String categoryId, String yearMonth) {
    return _deleteWhere(tableBudgets, '$budgetCategoryId = ? AND $budgetYearMonth = ?', [categoryId, yearMonth]);
  }

  // --- Expense Methods ---

  Future<int> insertExpense(Expense expense) async {
    Database db = await database;
    return await db.insert(tableExpenses, _stamped(expense.toDbMap()));
  }

  /// Simpan hasil import dalam satu transaksi SQLite: gagal satu, batal semua.
  /// Baris dengan ID yang sudah ada dilewati (bukan ditimpa).
  Future<void> importTransactions(List<Category> categories, List<Expense> expenses) async {
    Database db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final c in categories) {
        batch.insert(tableCategories, _stamped(c.toMap()), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final e in expenses) {
        batch.insert(tableExpenses, _stamped(e.toDbMap()), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Expense>> getExpenses({int limit = 10, int offset = 0}) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT e.*, c.label as cat_label, c.color_value as cat_color, c.icon as cat_icon
      FROM $tableExpenses e
      JOIN $tableCategories c ON e.$columnType = c.$catId
      ORDER BY e.$columnDateTime DESC
      LIMIT ? OFFSET ?
    ''',
      [limit, offset * limit],
    );

    return List.generate(maps.length, (i) {
      final map = maps[i];
      final category = Category(
        id: map[columnType] as String,
        label: map['cat_label'] as String,
        colorValue: map['cat_color'] as int,
        icon: map['cat_icon'] as String,
      );
      return Expense.fromDbMap(map).copyWith(category: category);
    });
  }

  /// WHERE untuk [TransactionFilter]; alias `e` = expenses, `c` = categories.
  (String, List<Object?>) _filterWhere(TransactionFilter f) {
    final where = <String>[];
    final args = <Object?>[];
    final q = f.query.trim();
    if (q.isNotEmpty) {
      final like = '%${q.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
      where.add("(e.$columnName LIKE ? ESCAPE '\\' OR c.$catLabel LIKE ? ESCAPE '\\')");
      args.addAll([like, like]);
    }
    if (f.transactionType != null) {
      where.add('e.$columnTransactionType = ?');
      args.add(f.transactionType);
    }
    if (f.start != null) {
      where.add('e.$columnDateTime >= ?');
      args.add(f.start!.toIso8601String());
    }
    if (f.end != null) {
      where.add('e.$columnDateTime <= ?');
      args.add(f.end!.toIso8601String());
    }
    if (f.categoryIds.isNotEmpty) {
      where.add('e.$columnType IN (${List.filled(f.categoryIds.length, '?').join(', ')})');
      args.addAll(f.categoryIds);
    }
    if (f.minAmount != null) {
      where.add('e.$columnPrice >= ?');
      args.add(f.minAmount);
    }
    if (f.maxAmount != null) {
      where.add('e.$columnPrice <= ?');
      args.add(f.maxAmount);
    }
    return (where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}', args);
  }

  /// Riwayat terfilter, [offset] dalam jumlah baris.
  Future<List<Expense>> searchExpenses(TransactionFilter filter, {int limit = 20, int offset = 0}) async {
    Database db = await database;
    final (where, args) = _filterWhere(filter);
    final orderBy = switch (filter.sort) {
      TransactionSort.newest => 'e.$columnDateTime DESC',
      TransactionSort.oldest => 'e.$columnDateTime ASC',
      TransactionSort.highest => 'e.$columnPrice DESC, e.$columnDateTime DESC',
      TransactionSort.lowest => 'e.$columnPrice ASC, e.$columnDateTime DESC',
    };
    List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT e.*, c.label as cat_label, c.color_value as cat_color, c.icon as cat_icon
      FROM $tableExpenses e
      JOIN $tableCategories c ON e.$columnType = c.$catId
      $where
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
    ''',
      [...args, limit, offset],
    );

    return maps.map((map) {
      final category = Category(
        id: map[columnType] as String,
        label: map['cat_label'] as String,
        colorValue: map['cat_color'] as int,
        icon: map['cat_icon'] as String,
      );
      return Expense.fromDbMap(map).copyWith(category: category);
    }).toList();
  }

  /// Jumlah & total masuk/keluar semua baris yang lolos filter.
  Future<TransactionTotals> summarizeExpenses(TransactionFilter filter) async {
    Database db = await database;
    final (where, args) = _filterWhere(filter);
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count,
        SUM(CASE WHEN e.$columnTransactionType = 'income' THEN e.$columnPrice ELSE 0 END) as income,
        SUM(CASE WHEN e.$columnTransactionType = 'income' THEN 0 ELSE e.$columnPrice END) as expense
      FROM $tableExpenses e
      JOIN $tableCategories c ON e.$columnType = c.$catId
      $where
    ''', args);
    final row = result.first;
    return (count: row['count'] as int? ?? 0, income: (row['income'] as num?)?.toDouble() ?? 0, expense: (row['expense'] as num?)?.toDouble() ?? 0);
  }

  Future<Expense?> getExpense(String id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT e.*, c.label as cat_label, c.color_value as cat_color, c.icon as cat_icon
      FROM $tableExpenses e
      JOIN $tableCategories c ON e.$columnType = c.$catId
      WHERE e.$columnId = ?
    ''',
      [id],
    );

    if (maps.isNotEmpty) {
      final map = maps.first;
      final category = Category(
        id: map[columnType] as String,
        label: map['cat_label'] as String,
        colorValue: map['cat_color'] as int,
        icon: map['cat_icon'] as String,
      );
      return Expense.fromDbMap(map).copyWith(category: category);
    }
    return null;
  }

  Future<int> updateExpense(Expense expense) async {
    Database db = await database;
    return await db.update(tableExpenses, _stamped(expense.toDbMap()), where: '$columnId = ?', whereArgs: [expense.id]);
  }

  Future<int> deleteExpense(String id) {
    return _deleteWhere(tableExpenses, '$columnId = ?', [id]);
  }

  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end, {String? transactionType}) async {
    Database db = await database;
    String whereClause = 'e.$columnDateTime BETWEEN ? AND ?';
    List<dynamic> whereArgs = [start.toIso8601String(), end.toIso8601String()];

    if (transactionType != null) {
      whereClause += ' AND e.$columnTransactionType = ?';
      whereArgs.add(transactionType);
    }

    List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT e.*, c.label as cat_label, c.color_value as cat_color, c.icon as cat_icon
      FROM $tableExpenses e
      JOIN $tableCategories c ON e.$columnType = c.$catId
      WHERE $whereClause
      ORDER BY e.$columnDateTime DESC
    ''', whereArgs);

    return List.generate(maps.length, (i) {
      final map = maps[i];
      final category = Category(
        id: map[columnType] as String,
        label: map['cat_label'] as String,
        colorValue: map['cat_color'] as int,
        icon: map['cat_icon'] as String,
      );
      return Expense.fromDbMap(map).copyWith(category: category);
    });
  }

  // Get total expenses by category label (using join)
  Future<Map<String, double>> getExpensesByType({String transactionType = 'expense'}) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT c.$catLabel as category_label, SUM(e.$columnPrice) as total
      FROM $tableExpenses e
      JOIN $tableCategories c ON e.$columnType = c.$catId
      WHERE e.$columnTransactionType = ?
      GROUP BY c.$catLabel
    ''',
      [transactionType],
    );

    Map<String, double> expensesByType = {};
    for (var row in result) {
      expensesByType[row['category_label'] as String] = row['total'] as double;
    }
    return expensesByType;
  }

  // Get total spent per category id within a date range (for budget tracking)
  Future<Map<String, double>> getSpendingByCategoryForRange(DateTime start, DateTime end, {String transactionType = 'expense'}) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT $columnType as category_id, SUM($columnPrice) as total
      FROM $tableExpenses
      WHERE $columnTransactionType = ? AND $columnDateTime BETWEEN ? AND ?
      GROUP BY $columnType
    ''',
      [transactionType, start.toIso8601String(), end.toIso8601String()],
    );

    Map<String, double> spendingByCategory = {};
    for (var row in result) {
      spendingByCategory[row['category_id'] as String] = (row['total'] as num).toDouble();
    }
    return spendingByCategory;
  }

  Future<double> getTotalAmountByDateRange(DateTime start, DateTime end, String transactionType) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT SUM($columnPrice) as total
      FROM $tableExpenses
      WHERE $columnTransactionType = ? AND $columnDateTime BETWEEN ? AND ?
    ''',
      [transactionType, start.toIso8601String(), end.toIso8601String()],
    );

    return result.first['total'] as double? ?? 0.0;
  }

  // --- Sync Methods ---

  /// Kolom yang dikirim/diterima per tabel (selain `updated_at`).
  static const _syncColumns = {
    tableCategories: [catId, catLabel, catColor, catIcon],
    tableBudgets: [budgetId, budgetCategoryId, budgetYearMonth, budgetAmount],
    tableExpenses: [columnId, columnName, columnType, columnTransactionType, columnDateTime, columnPrice],
  };

  /// Jumlah perubahan lokal yang belum terkirim ke server.
  Future<int> pendingChangeCount() async {
    Database db = await database;
    var count = 0;
    for (final table in syncedTables) {
      count += Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table WHERE $columnDirty = 1')) ?? 0;
    }
    return count + (Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $tableDeletions')) ?? 0);
  }

  Future<SyncChanges> collectChanges() async {
    Database db = await database;
    return SyncChanges(
      rows: {
        for (final table in syncedTables)
          table: await db.query(table, columns: [..._syncColumns[table]!, columnUpdatedAt], where: '$columnDirty = 1'),
      },
      deletions: await db.query(tableDeletions),
    );
  }

  /// Tandai [sent] sudah terkirim. Baris yang diubah lagi selama sync
  /// (`updated_at` berbeda) tetap dirty.
  Future<void> markSynced(SyncChanges sent) async {
    Database db = await database;
    final batch = db.batch();
    sent.rows.forEach((table, rows) {
      for (final r in rows) {
        batch.update(table, {columnDirty: 0}, where: 'id = ? AND $columnUpdatedAt = ?', whereArgs: [r['id'], r[columnUpdatedAt]]);
      }
    });
    for (final d in sent.deletions) {
      batch.delete(tableDeletions, where: 'entity = ? AND id = ? AND deleted_at = ?', whereArgs: [d['entity'], d['id'], d['deleted_at']]);
    }
    await batch.commit(noResult: true);
  }

  /// Terapkan perubahan dari server. Last-write-wins: perubahan lokal yang
  /// belum terkirim dan lebih baru tidak ditimpa.
  Future<void> applyRemote(SyncChanges remote) async {
    Database db = await database;
    await db.transaction((txn) async {
      for (final table in syncedTables) {
        for (final row in remote.rows[table] ?? const <Map<String, dynamic>>[]) {
          final id = row['id'] as String;
          final remoteAt = row[columnUpdatedAt];
          if (await _localWins(txn, table, id, remoteAt)) continue;

          if (table == tableBudgets) {
            // Slot kategori+bulan yang sama dari HP lain: versi server yang dipakai.
            await txn.delete(
              tableBudgets,
              where: '$budgetCategoryId = ? AND $budgetYearMonth = ? AND $budgetId != ?',
              whereArgs: [row[budgetCategoryId], row[budgetYearMonth], id],
            );
          }
          await txn.insert(table, {
            for (final c in _syncColumns[table]!) c: row[c],
            columnUpdatedAt: remoteAt,
            columnDirty: 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          await txn.delete(tableDeletions, where: 'entity = ? AND id = ?', whereArgs: [table, id]);
        }
      }

      for (final d in remote.deletions) {
        final table = d['entity'] as String;
        if (!_syncColumns.containsKey(table)) continue;
        final id = d['id'] as String;
        if (await _localWins(txn, table, id, d['deleted_at'])) continue;
        await txn.delete(table, where: 'id = ?', whereArgs: [id]);
        await txn.delete(tableDeletions, where: 'entity = ? AND id = ?', whereArgs: [table, id]);
      }
    });
  }

  /// True bila perubahan lokal (edit atau hapus) belum terkirim dan lebih baru dari [remoteAt].
  Future<bool> _localWins(DatabaseExecutor txn, String table, String id, Object? remoteAt) async {
    final remote = DateTime.tryParse('$remoteAt');
    final local = await txn.query(table, columns: [columnUpdatedAt], where: 'id = ? AND $columnDirty = 1', whereArgs: [id]);
    final tomb = await txn.query(tableDeletions, columns: ['deleted_at'], where: 'entity = ? AND id = ?', whereArgs: [table, id]);
    final localAt = DateTime.tryParse('${local.firstOrNull?[columnUpdatedAt] ?? tomb.firstOrNull?['deleted_at']}');
    return localAt != null && (remote == null || localAt.isAfter(remote));
  }

  /// Kosongkan semua data di HP (keluar akun), lalu isi lagi kategori bawaan.
  Future<void> resetLocalData() async {
    Database db = await database;
    await db.transaction((txn) async {
      for (final table in [...syncedTables, tableDeletions]) {
        await txn.delete(table);
      }
      await _seedCategories(txn);
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<int> clearDatabase() async {
    Database db = await database;
    await db.delete(tableExpenses);
    return await db.delete(tableCategories);
  }
}
