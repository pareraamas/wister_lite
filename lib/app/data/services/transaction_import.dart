import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/data/models/expense_type.dart';
import 'package:wister_lite/app/ui/app_illustration.dart';
import 'package:uuid/uuid.dart';

/// Kolom yang dikenali, dengan nama alternatif (tanpa beda huruf besar/kecil).
enum ImportColumn {
  date(['tanggal', 'tgl', 'date', 'waktu', 'datetime', 'date_time']),
  type(['jenis', 'tipe', 'type', 'transaction_type']),
  category(['kategori', 'category']),
  name(['nama', 'catatan', 'keterangan', 'deskripsi', 'name', 'note', 'description']),
  amount(['jumlah', 'nominal', 'amount', 'harga', 'price', 'total']),
  id(['id']);

  const ImportColumn(this.aliases);

  final List<String> aliases;

  static const required = [date, category, amount];
}

/// Satu baris yang gagal dibaca. [row] = nomor baris seperti di spreadsheet.
///
/// [message] adalah key terjemahan (teks Indonesia dengan `@value`), jadi
/// [toString] selalu mengikuti bahasa aktif.
class ImportIssue {
  const ImportIssue(this.row, this.message, [this.value = '']);

  final int row;
  final String message;
  final String value;

  @override
  String toString() => 'Baris @row: @msg'.trParams({
    'row': '$row',
    'msg': message.trParams({'value': value}),
  });
}

/// Hasil membaca file, belum disimpan. Ditampilkan di layar pratinjau.
class ImportPlan {
  const ImportPlan({
    required this.expenses,
    required this.newCategories,
    required this.duplicates,
    required this.issues,
    this.missingColumns = const [],
  });

  /// Transaksi siap disimpan; `category` sudah terisi (kategori lama atau baru).
  final List<Expense> expenses;
  final List<Category> newCategories;
  final int duplicates;
  final List<ImportIssue> issues;

  /// Kolom wajib yang tidak ditemukan di header. Bila tidak kosong, tidak ada baris yang dibaca.
  final List<ImportColumn> missingColumns;

  bool get isEmpty => expenses.isEmpty;
}

/// Membaca baris mentah (dari CSV atau Excel) menjadi [ImportPlan].
///
/// - Header dicari di 10 baris pertama, jadi baris judul di atasnya tidak masalah.
/// - Kategori dicocokkan dengan label (tanpa beda besar/kecil); yang belum ada dibuat baru.
/// - Duplikat dilewati: ID sama, atau tanggal (menit) + nama + jumlah + jenis sama.
class TransactionImporter {
  TransactionImporter({required List<Category> categories, required List<Expense> existing, String Function()? newId})
    : _categories = {for (final c in categories) ...{_norm(c.storedLabel): c, _norm(c.label): c}},
      _existingIds = {for (final e in existing) ?e.id},
      _existingKeys = {for (final e in existing) _key(e)},
      _newId = newId ?? (() => const Uuid().v4());

  final Map<String, Category> _categories;
  final Set<String> _existingIds;
  final Set<String> _existingKeys;
  final String Function() _newId;

  ImportPlan parse(List<List<Object?>> rows) {
    final (headerIndex, columns) = _findHeader(rows);
    final missing = [
      for (final c in ImportColumn.required)
        if (!columns.containsKey(c)) c,
    ];
    if (headerIndex < 0 || missing.isNotEmpty) {
      return ImportPlan(expenses: const [], newCategories: const [], duplicates: 0, issues: const [], missingColumns: missing);
    }

    final expenses = <Expense>[];
    final created = <String, Category>{};
    final issues = <ImportIssue>[];
    final seenIds = {..._existingIds};
    final seenKeys = {..._existingKeys};
    var duplicates = 0;

    for (var i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      Object? cell(ImportColumn c) {
        final index = columns[c];
        return index == null || index >= row.length ? null : row[index];
      }

      if (row.every((v) => v == null || v.toString().trim().isEmpty)) continue;
      final rowNumber = i + 1;

      final date = parseDate(cell(ImportColumn.date));
      if (date == null) {
        issues.add(ImportIssue(rowNumber, 'tanggal "@value" tidak dikenali', _show(cell(ImportColumn.date))));
        continue;
      }
      final rawAmount = parseAmount(cell(ImportColumn.amount));
      if (rawAmount == null || rawAmount == 0) {
        issues.add(ImportIssue(rowNumber, 'jumlah "@value" tidak valid', _show(cell(ImportColumn.amount))));
        continue;
      }
      final typeCell = cell(ImportColumn.type);
      final String type;
      if (typeCell == null || typeCell.toString().trim().isEmpty) {
        type = 'expense'; // tanpa kolom jenis: anggap pengeluaran
      } else {
        final parsed = parseType(typeCell);
        if (parsed == null) {
          issues.add(ImportIssue(rowNumber, 'jenis "@value" harus Pemasukan atau Pengeluaran', _show(typeCell)));
          continue;
        }
        type = parsed;
      }
      final categoryLabel = cell(ImportColumn.category)?.toString().trim() ?? '';
      if (categoryLabel.isEmpty) {
        issues.add(ImportIssue(rowNumber, 'kategori kosong'));
        continue;
      }

      final norm = _norm(categoryLabel);
      final category = _categories[norm] ?? created.putIfAbsent(norm, () => _createCategory(categoryLabel, _categories.length + created.length));
      final name = cell(ImportColumn.name)?.toString().trim() ?? '';
      final id = cell(ImportColumn.id)?.toString().trim() ?? '';

      final expense = Expense(
        id: id.isEmpty ? _newId() : id,
        name: name.isEmpty ? category.storedLabel : name,
        type: category.id,
        category: category,
        transactionType: type,
        dateTime: date,
        price: rawAmount.abs(),
      );
      final key = _key(expense);
      if ((id.isNotEmpty && seenIds.contains(id)) || seenKeys.contains(key)) {
        duplicates++;
        continue;
      }
      seenIds.add(expense.id!);
      seenKeys.add(key);
      expenses.add(expense);
    }

    // Kategori baru yang ternyata hanya dipakai baris duplikat tidak perlu dibuat.
    final used = {for (final e in expenses) e.type};
    return ImportPlan(
      expenses: expenses,
      newCategories: [
        for (final c in created.values)
          if (used.contains(c.id)) c,
      ],
      duplicates: duplicates,
      issues: issues,
    );
  }

  Category _createCategory(String label, int index) {
    final palette = ExpenseType.values;
    return Category.create(label: label, color: palette[index % palette.length].color, icon: CategoryIcons.tag);
  }

  (int, Map<ImportColumn, int>) _findHeader(List<List<Object?>> rows) {
    var best = (-1, <ImportColumn, int>{});
    for (var r = 0; r < rows.length && r < 10; r++) {
      final found = <ImportColumn, int>{};
      for (var i = 0; i < rows[r].length; i++) {
        final text = _norm(rows[r][i]?.toString() ?? '');
        for (final c in ImportColumn.values) {
          if (!found.containsKey(c) && c.aliases.contains(text)) found[c] = i;
        }
      }
      if (found.length > best.$2.length) best = (r, found);
      if (ImportColumn.required.every(found.containsKey)) return (r, found);
    }
    return best;
  }

  static String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _key(Expense e) {
    final d = e.dateTime;
    return '${d.year}-${d.month}-${d.day}-${d.hour}-${d.minute}|${_norm(e.name)}|${e.price.round()}|${e.transactionType}';
  }

  static String _show(Object? v) => v == null ? '' : v.toString().trim();

  // --- Parser nilai (publik untuk test) ---

  static String? parseType(Object? v) {
    final s = _norm(v?.toString() ?? '');
    const income = {'pemasukan', 'masuk', 'income', 'in', 'pendapatan', '+'};
    const expense = {'pengeluaran', 'keluar', 'expense', 'out', 'belanja', '-'};
    if (income.contains(s)) return 'income';
    if (expense.contains(s)) return 'expense';
    return null;
  }

  /// Menerima `DateTime`, serial tanggal Excel, "2026-09-28 14:30",
  /// "2026-09-28", "28/09/2026 14:30", "28-09-2026", dan ISO 8601.
  static DateTime? parseDate(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is num) return _fromExcelSerial(v.toDouble());
    final s = v.toString().trim();
    if (s.isEmpty) return null;

    final ymd = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[ T](\d{1,2})[:.](\d{2})(?:[:.](\d{2}))?)?').firstMatch(s);
    final dmy = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})(?:[ T](\d{1,2})[:.](\d{2})(?:[:.](\d{2}))?)?$').firstMatch(s);
    int n(String? g) => g == null ? 0 : int.parse(g);
    DateTime? build(int y, int m, int d, int h, int min, int sec) {
      if (m < 1 || m > 12 || d < 1 || d > 31 || h > 23 || min > 59 || sec > 59) return null;
      final date = DateTime(y, m, d, h, min, sec);
      return date.month == m && date.day == d ? date : null; // tolak 31 Februari
    }

    if (ymd != null) {
      return build(n(ymd[1]), n(ymd[2]), n(ymd[3]), n(ymd[4]), n(ymd[5]), n(ymd[6]));
    }
    if (dmy != null) {
      return build(n(dmy[3]), n(dmy[2]), n(dmy[1]), n(dmy[4]), n(dmy[5]), n(dmy[6]));
    }
    final serial = double.tryParse(s);
    return serial == null ? null : _fromExcelSerial(serial);
  }

  static DateTime? _fromExcelSerial(double serial) {
    if (serial < 1 || serial > 2958465) return null;
    final base = DateTime(1899, 12, 30);
    final days = serial.floor();
    final minutes = ((serial - days) * 24 * 60).round();
    return DateTime(base.year, base.month, base.day + days, 0, minutes);
  }

  /// Menerima angka, "25000", "25.000", "Rp 25.000", "1.250.000,50",
  /// "1,250,000.50", "-25.000", "−Rp 25.000", "(25.000)".
  static double? parseAmount(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    var s = v.toString().trim().replaceAll(' ', ' ');
    if (s.isEmpty) return null;
    var negative = false;
    if (s.startsWith('(') && s.endsWith(')')) {
      negative = true;
      s = s.substring(1, s.length - 1);
    }
    s = s.replaceAll(RegExp(r'rp\.?', caseSensitive: false), '').replaceAll(' ', '');
    if (s.startsWith('-') || s.startsWith('−')) {
      negative = true;
      s = s.substring(1);
    } else if (s.startsWith('+')) {
      s = s.substring(1);
    }
    if (!RegExp(r'^[\d.,]+$').hasMatch(s)) return null;

    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    String normalized;
    if (lastDot >= 0 && lastComma >= 0) {
      // Pemisah desimal = yang muncul terakhir.
      normalized = lastComma > lastDot ? s.replaceAll('.', '').replaceAll(',', '.') : s.replaceAll(',', '');
    } else if (lastDot >= 0 || lastComma >= 0) {
      final sep = lastDot >= 0 ? '.' : ',';
      final thousands = RegExp('^\\d{1,3}(${RegExp.escape(sep)}\\d{3})+\$').hasMatch(s);
      normalized = thousands ? s.replaceAll(sep, '') : s.replaceAll(',', '.');
    } else {
      normalized = s;
    }
    final value = double.tryParse(normalized);
    if (value == null) return null;
    return negative ? -value : value;
  }
}
