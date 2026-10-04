@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wister_lite/app/data/models/transaction_filter.dart';
import 'package:wister_lite/app/routes/app_pages.dart';

import 'support/fixtures.dart';
import 'support/harness.dart';

void main() {
  setUpAll(setUpQa);

  QaScreen history([TransactionFilter? filter]) => QaScreen('riwayat', route: Routes.TRANSACTION_HISTORY, arguments: filter);

  testWidgets('tombol ">" di Beranda membuka Riwayat Transaksi', (tester) async {
    await pumpScreen(tester, const QaScreen('beranda', route: Routes.MAIN_NAV));
    // Bagian "Transaksi hari ini" ada di bawah kartu ringkasan.
    await tester.scrollUntilVisible(find.byTooltip('Lihat semua riwayat'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Lihat semua riwayat'));
    await settle(tester);
    expect(find.text('Riwayat Transaksi'), findsOneWidget);
    expect(find.text('16 transaksi'), findsOneWidget);
  });

  testWidgets('pencarian mencocokkan catatan', (tester) async {
    await pumpScreen(tester, history());
    await tester.enterText(find.byType(TextField), 'kopi');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.text('1 transaksi'), findsOneWidget);
    expect(find.text('Kopi'), findsOneWidget);
  });

  testWidgets('bottom sheet filter: tipe Pemasukan', (tester) async {
    await pumpScreen(tester, history());
    await tester.tap(find.byTooltip('Filter'));
    await settle(tester);
    await tester.tap(find.text('Pemasukan'));
    await settle(tester);
    expect(find.text('Tampilkan 3 transaksi'), findsOneWidget);
    await tester.tap(find.text('Tampilkan 3 transaksi'));
    await settle(tester);
    expect(find.text('3 transaksi'), findsOneWidget);
    expect(find.byTooltip('Filter, 1 aktif'), findsOneWidget);
  });

  testWidgets('rentang tanggal terbuka: sejak 20 Sep', (tester) async {
    await pumpScreen(tester, history(const TransactionFilter().withPeriod(DateTime(2026, 9, 20), null)));
    expect(find.text('4 transaksi'), findsOneWidget);
    expect(find.text('Sejak 20 Sep 2026'), findsOneWidget);
  });

  testWidgets('rentang tanggal: 1–5 Sep', (tester) async {
    await pumpScreen(tester, history(const TransactionFilter().withPeriod(DateTime(2026, 9, 5), DateTime(2026, 9, 1))));
    expect(find.text('4 transaksi'), findsOneWidget);
    expect(find.text('1 Sep – 5 Sep 2026'), findsOneWidget);
  });

  testWidgets('filter awal dari argumen: kategori + periode', (tester) async {
    await pumpScreen(
      tester,
      history(TransactionFilter(categoryIds: const {'food'}, start: DateTime(2026, 9), end: DateTime(2026, 9, 30, 23, 59, 59, 999))),
    );
    expect(find.text('3 transaksi'), findsOneWidget);
    expect(find.text('Sep 2026'), findsOneWidget);
  });

  testWidgets('filter tanpa hasil menampilkan tombol Hapus filter', (tester) async {
    await pumpScreen(tester, history(const TransactionFilter(minAmount: 99000000)));
    expect(find.text('Tidak ada yang cocok'), findsOneWidget);
    await tester.tap(find.text('Hapus filter'));
    await settle(tester);
    expect(find.text('16 transaksi'), findsOneWidget);
  });

  test('urutan nominal terbesar, seri diurutkan terbaru', () {
    final list = sampleExpenses()..sort(const TransactionFilter(sort: TransactionSort.highest).compare);
    expect(list.take(3).map((e) => e.id), ['tx-01', 'tx-15', 'tx-16']);
  });
}
