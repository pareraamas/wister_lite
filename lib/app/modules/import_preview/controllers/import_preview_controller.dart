import 'dart:ui';

import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';
import 'package:wister_lite/app/data/services/share_service.dart';
import 'package:wister_lite/app/data/services/transaction_export.dart';
import 'package:wister_lite/app/data/services/transaction_import.dart';
import 'package:wister_lite/app/widgets/app_snackbar.dart';

/// Argumen route pratinjau import.
class ImportPreviewArgs {
  const ImportPreviewArgs(this.fileName, this.plan);

  final String fileName;
  final ImportPlan plan;
}

/// Pratinjau hasil baca file sebelum disimpan. `Get.back(result: n)` dengan
/// n = jumlah transaksi yang tersimpan.
class ImportPreviewController extends GetxController {
  final ExpenseRepository _repository = Get.find<ExpenseRepository>();

  late final String fileName;
  late final ImportPlan plan;
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as ImportPreviewArgs;
    fileName = args.fileName;
    plan = args.plan;
  }

  List<Expense> get expenses => plan.expenses;

  double total(String type) => expenses.where((e) => e.transactionType == type).fold(0.0, (sum, e) => sum + e.price);

  /// Rentang tanggal transaksi yang akan diimpor, lama → baru.
  (DateTime, DateTime)? get range {
    if (expenses.isEmpty) return null;
    final dates = expenses.map((e) => e.dateTime).toList()..sort();
    return (dates.first, dates.last);
  }

  Future<void> save() async {
    if (isSaving.value || plan.isEmpty) return;
    isSaving.value = true;
    try {
      await _repository.importTransactions(plan.newCategories, plan.expenses);
      Get.back(result: plan.expenses.length);
    } catch (_) {
      isSaving.value = false;
      showAppSnackBar('Gagal menyimpan. Tidak ada data yang berubah.'.tr);
    }
  }

  Future<void> shareTemplate({Rect? origin}) async {
    try {
      await Get.find<ShareService>().shareExport(TransactionExport.template(), origin: origin);
    } catch (_) {
      showAppSnackBar('Gagal membagikan template.'.tr);
    }
  }
}
