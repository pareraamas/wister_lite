import 'package:get/get.dart';

import 'expense.dart';

/// Urutan daftar di halaman Riwayat Transaksi.
enum TransactionSort {
  newest('Terbaru'),
  oldest('Terlama'),
  highest('Nominal terbesar'),
  lowest('Nominal terkecil');

  const TransactionSort(this._label);

  final String _label;

  /// Label tampilan, mengikuti bahasa aktif.
  String get label => _label.tr;

  /// Urutan tanggal dikelompokkan per hari; urutan nominal ditampilkan rata.
  bool get byDate => this == newest || this == oldest;
}

/// Kriteria filter riwayat. Dipakai `DatabaseHelper` (SQL) dan [matches] (memori).
class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.transactionType,
    this.start,
    this.end,
    this.categoryIds = const {},
    this.minAmount,
    this.maxAmount,
    this.sort = TransactionSort.newest,
  });

  /// Dicari di catatan transaksi dan nama kategori.
  final String query;

  /// 'income', 'expense', atau null untuk semua.
  final String? transactionType;

  /// Rentang tanggal inklusif, boleh terbuka di salah satu sisi.
  /// [start] di awal hari, [end] di akhir hari (lihat [withPeriod]).
  final DateTime? start;
  final DateTime? end;
  final Set<String> categoryIds;
  final double? minAmount;
  final double? maxAmount;
  final TransactionSort sort;

  bool get hasPeriod => start != null || end != null;
  bool get hasAmount => minAmount != null || maxAmount != null;

  /// Jumlah filter yang aktif (tidak menghitung urutan).
  int get activeCount => [query.trim().isNotEmpty, transactionType != null, hasPeriod, categoryIds.isNotEmpty, hasAmount].where((b) => b).length;

  bool get isActive => activeCount > 0;

  /// Semua filter dilepas, urutan tetap.
  TransactionFilter cleared() => TransactionFilter(sort: sort);

  /// Rentang per hari: [start] ke 00:00, [end] ke 23:59:59.999; tertukar dibalik.
  TransactionFilter withPeriod(DateTime? start, DateTime? end) {
    var s = start == null ? null : DateTime(start.year, start.month, start.day);
    var e = end == null ? null : DateTime(end.year, end.month, end.day);
    if (s != null && e != null && s.isAfter(e)) (s, e) = (e, s);
    return copyWith(start: () => s, end: () => e == null ? null : DateTime(e.year, e.month, e.day, 23, 59, 59, 999));
  }

  TransactionFilter copyWith({
    String? query,
    String? Function()? transactionType,
    DateTime? Function()? start,
    DateTime? Function()? end,
    Set<String>? categoryIds,
    double? Function()? minAmount,
    double? Function()? maxAmount,
    TransactionSort? sort,
  }) => TransactionFilter(
    query: query ?? this.query,
    transactionType: transactionType != null ? transactionType() : this.transactionType,
    start: start != null ? start() : this.start,
    end: end != null ? end() : this.end,
    categoryIds: categoryIds ?? this.categoryIds,
    minAmount: minAmount != null ? minAmount() : this.minAmount,
    maxAmount: maxAmount != null ? maxAmount() : this.maxAmount,
    sort: sort ?? this.sort,
  );

  /// Padanan WHERE di SQL, untuk transaksi yang sudah di-JOIN kategorinya.
  bool matches(Expense e) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty && !e.name.toLowerCase().contains(q) && !(e.category?.label.toLowerCase().contains(q) ?? false)) return false;
    if (transactionType != null && e.transactionType != transactionType) return false;
    final at = e.dateTime.toIso8601String();
    if (start != null && at.compareTo(start!.toIso8601String()) < 0) return false;
    if (end != null && at.compareTo(end!.toIso8601String()) > 0) return false;
    if (categoryIds.isNotEmpty && !categoryIds.contains(e.type)) return false;
    if (minAmount != null && e.price < minAmount!) return false;
    if (maxAmount != null && e.price > maxAmount!) return false;
    return true;
  }

  /// Pembanding sesuai [sort], sama dengan ORDER BY di SQL.
  int compare(Expense a, Expense b) {
    final byDate = b.dateTime.toIso8601String().compareTo(a.dateTime.toIso8601String());
    return switch (sort) {
      TransactionSort.newest => byDate,
      TransactionSort.oldest => -byDate,
      TransactionSort.highest => b.price.compareTo(a.price) != 0 ? b.price.compareTo(a.price) : byDate,
      TransactionSort.lowest => a.price.compareTo(b.price) != 0 ? a.price.compareTo(b.price) : byDate,
    };
  }
}

/// Ringkasan semua transaksi yang lolos filter (bukan hanya halaman yang dimuat).
typedef TransactionTotals = ({int count, double income, double expense});
