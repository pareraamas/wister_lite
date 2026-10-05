import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/data/services/transaction_csv.dart';
import 'package:wister_lite/app/data/services/transaction_pdf.dart';
import 'package:wister_lite/app/data/services/transaction_report.dart';
import 'package:wister_lite/app/data/services/transaction_xlsx.dart';

enum ExportFormat {
  excel('xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  pdf('pdf', 'application/pdf'),
  csv('csv', 'text/csv');

  const ExportFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;
}

/// File hasil export, siap dibagikan.
class ExportFile {
  const ExportFile(this.bytes, this.fileName, this.mimeType);

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

abstract final class TransactionExport {
  static Future<ExportFile> build(ExportFormat format, List<Expense> expenses, ReportPeriod period) async {
    final summary = TransactionSummary.of(expenses);
    final stamp = {'stamp': period.fileStamp};
    final base = format == ExportFormat.pdf ? 'laporan-@stamp'.trParams(stamp) : 'transaksi-@stamp'.trParams(stamp);
    final bytes = switch (format) {
      ExportFormat.excel => TransactionXlsx.encode(summary, period),
      ExportFormat.pdf => await TransactionPdf.build(summary, period),
      ExportFormat.csv => Uint8List.fromList(utf8.encode(TransactionCsv.encode(summary.expenses))),
    };
    return ExportFile(bytes, '$base.${format.extension}', format.mimeType);
  }

  /// Template import: header + dua contoh baris.
  static ExportFile template() {
    Category cat(String label) => Category(id: '', label: label, colorValue: 0, icon: '');
    Expense row(String name, String category, String type, DateTime at, double price) =>
        Expense(id: '', name: name, type: '', category: cat(category), transactionType: type, dateTime: at, price: price);

    final csv = TransactionCsv.encode([
      row('Gaji'.tr, 'Gaji'.tr, 'income', DateTime(2026, 9, 1, 9), 8000000),
      row('Makan siang'.tr, 'Makanan'.tr, 'expense', DateTime(2026, 9, 2, 12, 30), 25000),
    ]);
    return ExportFile(Uint8List.fromList(utf8.encode(csv)), 'template-import.csv'.tr, ExportFormat.csv.mimeType);
  }
}
