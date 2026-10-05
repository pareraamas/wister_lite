import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/expense.dart';

/// Format CSV transaksi. Header & isi kolom adalah kontrak: file hasil export
/// harus bisa di-import kembali, jadi jangan diubah tanpa menjaga kompatibilitas.
///
/// Memakai `Csv.excel()` (pemisah `;` + BOM UTF-8) karena Excel berlokal
/// Indonesia memakai `;` sebagai pemisah daftar; Google Sheets & Numbers
/// mendeteksinya otomatis.
///
/// Header & jenis ikut bahasa aktif; versi Inggrisnya (Date, Type, Category,
/// Name, Amount, Income, Expense) sudah dikenali `ImportColumn` & `parseType`.
abstract final class TransactionCsv {
  static List<String> get headers => ['Tanggal'.tr, 'Jenis'.tr, 'Kategori'.tr, 'Nama'.tr, 'Jumlah'.tr, 'ID'];

  static String get income => 'Pemasukan'.tr;
  static String get expense => 'Pengeluaran'.tr;

  static String encode(List<Expense> expenses) {
    final rows = <List<Object?>>[
      headers,
      for (final e in expenses)
        [
          formatDate(e.dateTime),
          e.transactionType == 'income' ? income : expense,
          e.category?.label ?? '',
          e.name,
          formatAmount(e.price),
          e.id ?? '',
        ],
    ];
    return Csv.excel().encode(rows);
  }

  /// Baris mentah (semua `String`) untuk import. Pemisah `,` `;` tab atau `|`
  /// dideteksi otomatis, termasuk header `sep=;` dari Excel; BOM dibuang.
  static List<List<Object?>> decode(String content) {
    final text = content.startsWith('\uFEFF') ? content.substring(1) : content;
    return [
      for (final row in Csv().decode(text)) [for (final cell in row) cell?.toString()],
    ];
  }

  /// "2026-09-28 14:30" — urut secara teks dan tidak bergantung locale.
  static String formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  /// Angka mentah tanpa pemisah ribuan: "25000", atau "2500.5" bila berdesimal.
  static String formatAmount(double price) => price == price.roundToDouble() ? price.round().toString() : price.toString();
}
