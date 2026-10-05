import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/services/transaction_csv.dart';
import 'package:wister_lite/app/data/services/transaction_report.dart';
import 'package:wister_lite/app/theme/tokens/app_colors.dart';

/// Laporan Excel (.xlsx): sheet "Transaksi" (kolom sama dengan CSV, jadi bisa
/// di-import kembali) dan sheet "Ringkasan" per kategori.
///
/// Memakai `excel_community` karena `excel` masih terkunci di `archive` ^3,
/// bentrok dengan `lottie` yang butuh `archive` ^4.
abstract final class TransactionXlsx {
  /// Nama sheet ikut bahasa aktif; [decode] mengenali versi Indonesia & aktif.
  static String get transactionsSheet => 'Transaksi'.tr;
  static String get summarySheet => 'Ringkasan'.tr;

  static final _money = CustomNumericNumFormat(formatCode: '#,##0');
  static final _date = CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd hh:mm');

  static Uint8List encode(TransactionSummary summary, ReportPeriod period) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet()!;
    final transactionsSheet = TransactionXlsx.transactionsSheet;
    excel.rename(defaultSheet, transactionsSheet);
    excel.setDefaultSheet(transactionsSheet);

    final header = CellStyle(
      bold: true,
      fontColorHex: _hex(AppColors.light.onBrand.toARGB32()),
      backgroundColorHex: _hex(AppColors.light.brand.toARGB32()),
    );

    // --- Transaksi ---
    final tx = excel[transactionsSheet];
    _appendStyled(tx, [for (final h in TransactionCsv.headers) TextCellValue(h)], header);
    for (final e in summary.expenses) {
      tx.appendRow([
        DateTimeCellValue.fromDateTime(e.dateTime),
        TextCellValue(e.transactionType == 'income' ? TransactionCsv.income : TransactionCsv.expense),
        TextCellValue(e.category?.label ?? ''),
        TextCellValue(e.name),
        _amount(e.price),
        TextCellValue(e.id ?? ''),
      ]);
      final row = tx.maxRows - 1;
      _format(tx, 0, row, _date);
      _format(tx, 4, row, _money);
    }
    const widths = [18.0, 14.0, 18.0, 32.0, 14.0, 38.0];
    for (var i = 0; i < widths.length; i++) {
      tx.setColumnWidth(i, widths[i]);
    }

    // --- Ringkasan ---
    final sum = excel[summarySheet];
    sum.appendRow([TextCellValue('Periode'.tr), TextCellValue(period.label)]);
    sum.appendRow([TextCellValue('Pemasukan'.tr), _amount(summary.income)]);
    sum.appendRow([TextCellValue('Pengeluaran'.tr), _amount(summary.expense)]);
    sum.appendRow([TextCellValue('Selisih'.tr), _amount(summary.balance)]);
    for (var r = 1; r <= 3; r++) {
      _format(sum, 1, r, _money);
    }
    sum.appendRow([]);
    _appendStyled(sum, [
      TextCellValue('Kategori'.tr),
      TextCellValue('Pengeluaran'.tr),
      TextCellValue('% pengeluaran'.tr),
      TextCellValue('Pemasukan'.tr),
    ], header);
    for (final c in summary.categories) {
      sum.appendRow([
        TextCellValue(c.label),
        _amount(c.expense),
        DoubleCellValue(double.parse((summary.shareOf(c.expense) * 100).toStringAsFixed(1))),
        _amount(c.income),
      ]);
      final row = sum.maxRows - 1;
      _format(sum, 1, row, _money);
      _format(sum, 3, row, _money);
    }
    sum.setColumnWidth(0, 22);
    for (var i = 1; i <= 3; i++) {
      sum.setColumnWidth(i, 16);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  /// Baris sheet "Transaksi" (atau sheet pertama) sebagai nilai mentah:
  /// `String`, `num`, `DateTime`, atau null. Dipakai oleh import.
  static List<List<Object?>> decode(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables['Transaksi'] ?? excel.tables[transactionsSheet] ?? (excel.tables.isEmpty ? null : excel.tables.values.first);
    if (sheet == null) return const [];
    return [
      for (final row in sheet.rows) [for (final cell in row) _raw(cell?.value)],
    ];
  }

  static Object? _raw(CellValue? v) => switch (v) {
    null => null,
    TextCellValue() => v.value.toString(),
    IntCellValue() => v.value,
    DoubleCellValue() => v.value,
    DateTimeCellValue() => v.asDateTimeLocal(),
    DateCellValue() => v.asDateTimeLocal(),
    FormulaCellValue() => _raw(v.cachedValue),
    BoolCellValue() => v.value.toString(),
    _ => v.toString(),
  };

  static CellValue _amount(double v) => v == v.roundToDouble() ? IntCellValue(v.round()) : DoubleCellValue(v);

  static void _appendStyled(Sheet sheet, List<CellValue> values, CellStyle style) {
    sheet.appendRow(values);
    final row = sheet.maxRows - 1;
    for (var col = 0; col < values.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).cellStyle = style;
    }
  }

  static void _format(Sheet sheet, int col, int row, NumFormat format) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.cellStyle = (cell.cellStyle ?? CellStyle()).copyWith(numberFormat: format);
  }

  static ExcelColor _hex(int argb) => ExcelColor.fromHexString('#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}');
}
