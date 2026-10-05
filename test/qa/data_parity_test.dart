@Tags(['qa', 'gerbang'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/routes/app_pages.dart';

import 'support/app_driver.dart';
import 'support/fake_repository.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

/// Gerbang "fitur identik": skenario uji manual dari rencana redesign
/// dijalankan lewat UI, lalu isi data dibandingkan dengan hasil yang
/// diharapkan. Ekspektasi ditulis langsung di level data, jadi berlaku
/// sama untuk UI lama maupun hasil redesign.
void main() {
  setUpAll(setUpQa);

  /// Data awal + [change] yang diterapkan langsung ke repository.
  Future<Map<String, Object>> expected(Future<void> Function(FakeExpenseRepository r) change) async {
    final r = repositoryFor(DataSet.full);
    await change(r);
    return r.snapshot();
  }

  Future<void> run(WidgetTester tester, String route, Object? args, Future<void> Function(AppDriver d) steps, Map<String, Object> want) async {
    final repo = await pumpScreen(tester, QaScreen('paritas', route: route, arguments: args));
    await steps(AppDriver(tester));
    await drainTimers(tester);
    expect(repo.snapshot(), want);
  }

  testWidgets('tambah pengeluaran', (tester) async {
    final want = await expected((r) => r.insertExpense(
          Expense(id: 'x', name: 'Bakso', type: 'food', transactionType: 'expense', dateTime: referenceNow, price: 25000),
        ));
    await run(tester, Routes.EXPANSE_CREATE, null, (d) async {
      await d.chooseType('expense');
      await d.enterAmount(25000);
      await d.chooseCategory('Makanan');
      await d.enterNote('Bakso');
      await d.ensureDate();
      await d.save();
    }, want);
  });

  testWidgets('tambah pemasukan', (tester) async {
    final want = await expected((r) => r.insertExpense(
          Expense(id: 'x', name: 'Bonus', type: 'gift', transactionType: 'income', dateTime: referenceNow, price: 500000),
        ));
    await run(tester, Routes.EXPANSE_CREATE, null, (d) async {
      await d.chooseType('income');
      await d.enterAmount(500000);
      await d.chooseCategory('Hadiah');
      await d.enterNote('Bonus');
      await d.ensureDate();
      await d.save();
    }, want);
  });

  testWidgets('ubah nominal transaksi', (tester) async {
    final want = await expected((r) async {
      final i = r.expenses.indexWhere((e) => e.id == 'tx-05');
      r.expenses[i] = r.expenses[i].copyWith(price: 50000);
    });
    await run(tester, Routes.EXPANSE_CREATE, 'tx-05', (d) async {
      await d.enterAmount(50000);
      await d.save();
    }, want);
  });

  testWidgets('hapus transaksi', (tester) async {
    final want = await expected((r) => r.deleteExpense('tx-06'));
    await run(tester, Routes.EXPANSE_CREATE, 'tx-06', (d) => d.deleteAndConfirm(), want);
  });

  testWidgets('atur budget', (tester) async {
    final want = await expected((r) => r.setBudget('internet', referenceToday, 400000));
    await run(tester, Routes.MAIN_NAV, null, (d) async {
      await d.openTab('Anggaran');
      await tapAny(tester, [find.text('Tambah'), find.text('Atur anggaran')], what: 'tombol tambah anggaran');
      await d.tapText('Ganti');
      await d.tapText('Internet');
      await d.enterAmount(400000, fieldLabel: 'Anggaran');
      await d.save();
    }, want);
  });

  testWidgets('buat kategori', (tester) async {
    final food = seedCategories().first;
    final want = await expected((r) => r.insertCategory(Category(id: 'x', label: 'Kucing', colorValue: food.colorValue, icon: food.icon)));
    await run(tester, Routes.CATEGORY_CREATE, null, (d) async {
      await tester.enterText(find.byType(TextField).first, 'Kucing');
      await settle(tester);
      await d.save();
    }, want);
  });

  testWidgets('kategori yang dipakai tidak bisa dihapus', (tester) async {
    final want = await expected((r) async {});
    await run(tester, Routes.CATEGORY_CREATE, seedCategories().first, (d) => d.deleteAndConfirm(), want);
  });
}
