import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/services/transaction_csv.dart';
import 'package:wister_lite/app/data/services/transaction_report.dart';
import 'package:wister_lite/app/theme/tokens/app_colors.dart';
import 'package:wister_lite/app/ui/app_format.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Laporan PDF siap cetak: ringkasan, pengeluaran per kategori, lalu daftar
/// transaksi. Font Plus Jakarta Sans di-embed agar "−" dan huruf lain aman.
abstract final class TransactionPdf {
  static Future<Uint8List> build(TransactionSummary summary, ReportPeriod period, {DateTime? generatedAt}) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'));
    return buildWithFonts(summary, period, regular: regular, bold: bold, generatedAt: generatedAt);
  }

  static Future<Uint8List> buildWithFonts(
    TransactionSummary summary,
    ReportPeriod period, {
    required pw.Font regular,
    required pw.Font bold,
    DateTime? generatedAt,
  }) {
    const c = AppColors.light;
    PdfColor col(Color color) => PdfColor.fromInt(color.toARGB32());
    final brand = col(c.brand);
    final ink = col(c.ink);
    final muted = col(c.inkMuted);
    final line = col(c.outlineVariant);
    final income = col(c.income);
    final expense = col(c.expense);
    final soft = col(c.surfaceContainerLow);

    final doc = pw.Document(
      title: 'Laporan Keuangan @period'.trParams({'period': period.label}),
      author: 'Wister Lite',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    pw.TextStyle st(double size, {bool strong = false, PdfColor? color}) =>
        pw.TextStyle(fontSize: size, fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? ink);

    pw.Widget stat(String label, String value, PdfColor color) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: soft, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: st(9, color: muted)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: st(13, strong: true, color: color)),
          ],
        ),
      ),
    );

    String signed(double v) => '${v < 0 ? AppFormat.minus : ''}${AppFormat.rupiah(v)}';

    final headerStyle = st(9, strong: true, color: PdfColors.white);
    final cellStyle = st(9);
    final categories = summary.expenseCategories;
    final at = generatedAt ?? DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text('Laporan Keuangan · @period'.trParams({'period': period.label}), style: st(9, color: muted)),
              ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Dibuat dengan Wister Lite · @date'.trParams({'date': TransactionCsv.formatDate(at)}), style: st(8, color: muted)),
            pw.Text('Halaman @page/@total'.trParams({'page': '${ctx.pageNumber}', 'total': '${ctx.pagesCount}'}), style: st(8, color: muted)),
          ],
        ),
        build: (ctx) => [
          pw.Text('Laporan Keuangan'.tr, style: st(22, strong: true, color: brand)),
          pw.SizedBox(height: 2),
          pw.Text(period.label, style: st(12, color: muted)),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              stat('Pemasukan'.tr, '+${AppFormat.rupiah(summary.income)}', income),
              pw.SizedBox(width: 8),
              stat('Pengeluaran'.tr, '${AppFormat.minus}${AppFormat.rupiah(summary.expense)}', expense),
              pw.SizedBox(width: 8),
              stat('Selisih'.tr, signed(summary.balance), summary.balance < 0 ? expense : ink),
            ],
          ),
          if (categories.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Pengeluaran per kategori'.tr, style: st(12, strong: true)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Kategori'.tr, 'Jumlah'.tr, '%'],
              data: [
                for (final cat in categories) [cat.label, AppFormat.rupiah(cat.expense), '${(summary.shareOf(cat.expense) * 100).round()}%'],
              ],
              headerStyle: headerStyle,
              headerDecoration: pw.BoxDecoration(color: brand),
              cellStyle: cellStyle,
              border: pw.TableBorder(horizontalInside: pw.BorderSide(color: line, width: 0.5)),
              cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
              columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1)},
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Text('Daftar transaksi (@n)'.trParams({'n': '${summary.expenses.length}'}), style: st(12, strong: true)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Tanggal'.tr, 'Nama'.tr, 'Kategori'.tr, 'Jumlah'.tr],
            data: [
              for (final e in summary.expenses)
                [
                  TransactionCsv.formatDate(e.dateTime),
                  e.name,
                  e.category?.label ?? '',
                  '${e.transactionType == 'income' ? '+' : AppFormat.minus}${AppFormat.rupiah(e.price)}',
                ],
            ],
            headerStyle: headerStyle,
            headerDecoration: pw.BoxDecoration(color: brand),
            cellStyle: cellStyle,
            oddRowDecoration: pw.BoxDecoration(color: soft),
            border: null,
            cellAlignments: {3: pw.Alignment.centerRight},
            columnWidths: {
              0: const pw.FlexColumnWidth(2.2),
              1: const pw.FlexColumnWidth(3.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
          ),
        ],
      ),
    );
    return doc.save();
  }
}
