import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/ults/clock.dart';
import 'package:intl/intl.dart';
import 'package:wister_lite/app/data/models/expense.dart';
import 'package:wister_lite/app/data/models/category_model.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';
import 'package:wister_lite/app/data/services/settings_service.dart';
import 'package:wister_lite/app/modules/main_nav/controllers/main_nav_controller.dart';
import 'package:wister_lite/app/routes/app_pages.dart';
import 'package:wister_lite/app/widgets/app_snackbar.dart';

class ExpanseCreateController extends GetxController {
  final ExpenseRepository repository = Get.find<ExpenseRepository>();

  /// Batas nominal (12 digit, Rp 999 miliar) agar teks tidak meluap.
  static const maxAmount = 999999999999;

  /// Jumlah chip kategori terakhir di atas tombol "Semua".
  static const recentCount = 5;

  /// Catatan opsional (kolom `name`). Kosong → pakai nama kategori.
  late TextEditingController nameController;
  final noteFocus = FocusNode();

  final selectedDate = Clock.now().obs;
  final selectedCategory = Rxn<Category>();
  final categories = <Category>[].obs;
  final recentCategories = <Category>[].obs;

  /// Nominal dalam rupiah bulat, diisi lewat keypad.
  final amount = 0.obs;

  final transactionType = 'expense'.obs; // 'income' or 'expense'

  /// ID transaksi yang sedang diubah; kosong = tambah baru.
  final arg = "".obs;

  final isSaving = false.obs;

  /// True sesaat setelah tersimpan: view memutar centang + Dompi senang,
  /// lalu memanggil [finishSave] untuk menutup form.
  final justSaved = false.obs;
  Timer? _closeFallback;
  VoidCallback? _afterClose;

  /// Pesan validasi inline di bawah nominal / kategori (kunci terjemahan; `.tr` saat ditampilkan).
  final amountError = RxnString();
  final categoryError = RxnString();

  bool get isEditing => arg.value.isNotEmpty;
  bool get isIncome => transactionType.value == 'income';

  String get title => isEditing
      ? (isIncome ? 'Ubah Pemasukan' : 'Ubah Pengeluaran').tr
      : (isIncome ? 'Tambah Pemasukan' : 'Tambah Pengeluaran').tr;

  String get dateLabel => DateFormat(SettingsService.intlTag == 'en_US' ? 'EEEE, MMMM d, yyyy' : 'EEEE, d MMMM yyyy', SettingsService.intlTag)
      .format(selectedDate.value);

  /// Label ringkas untuk chip tanggal: "Hari ini", "Kemarin", atau "Sen, 21 Sep".
  String get dateShortLabel {
    final now = Clock.now();
    final d = selectedDate.value;
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days == 0) return 'Hari ini'.tr;
    if (days == 1) return 'Kemarin'.tr;
    final en = SettingsService.intlTag == 'en_US';
    final pattern = d.year == now.year ? (en ? 'EEE, MMM d' : 'EEE, d MMM') : (en ? 'MMM d, yyyy' : 'd MMM yyyy');
    return DateFormat(pattern, SettingsService.intlTag).format(d);
  }

  @override
  void onInit() {
    super.onInit();
    nameController = TextEditingController();
    // Tombol − / + di widget home screen memilih tipe transaksi.
    if (Get.parameters['type'] == 'income') transactionType.value = 'income';
    _loadCategories();
  }

  @override
  void onReady() {
    final data = Get.arguments as String?;
    if (data != null) {
      arg.value = data;
      onGetByid(data);
    }
    super.onReady();
  }

  @override
  void onClose() {
    _closeFallback?.cancel();
    nameController.dispose();
    noteFocus.dispose();
    super.onClose();
  }

  Future<void> _loadCategories() async {
    categories.assignAll(await repository.getCategories());
    await _loadRecentCategories();
    if (!isEditing && selectedCategory.value == null && recentCategories.isNotEmpty) {
      selectedCategory.value = recentCategories.first;
    }
  }

  /// Kategori yang paling baru dipakai, dilengkapi urutan default bila kurang.
  Future<void> _loadRecentCategories() async {
    final latest = await repository.getExpenses(limit: 30);
    final ids = <String>{};
    for (final e in latest) {
      ids.add(e.type);
      if (ids.length == recentCount) break;
    }
    final byId = {for (final c in categories) c.id: c};
    final result = [for (final id in ids) ?byId[id]];
    for (final c in categories) {
      if (result.length >= recentCount) break;
      if (!result.contains(c)) result.add(c);
    }
    recentCategories.assignAll(result);
  }

  /// Dipanggil setelah kembali dari Kelola/Buat Kategori agar kategori baru langsung muncul.
  Future<void> reloadCategories() async {
    categories.assignAll(await repository.getCategories());
    final current = selectedCategory.value;
    if (current != null) {
      // Label/warna bisa berubah; hilang jika kategorinya dihapus.
      selectedCategory.value = categories.firstWhereOrNull((c) => c.id == current.id);
    }
    await _loadRecentCategories();
  }

  /// True jika kategori baru dibuat (dan langsung terpilih).
  Future<bool> openCreateCategory() async {
    final result = await Get.toNamed(Routes.CATEGORY_CREATE);
    if (result is Category) {
      await reloadCategories();
      selectCategory(categories.firstWhereOrNull((c) => c.id == result.id) ?? result);
      return true;
    }
    if (result == true) await reloadCategories();
    return false;
  }

  Future<void> openManageCategories() async {
    await Get.toNamed(Routes.CATEGORY_LIST);
    await reloadCategories();
  }

  void setType(String type) => transactionType.value = type;

  void selectCategory(Category category) {
    selectedCategory.value = category;
    categoryError.value = null;
    // Kategori dari "Semua" ikut tampil sebagai chip agar terlihat terpilih.
    if (!recentCategories.any((c) => c.id == category.id)) {
      recentCategories
        ..insert(0, category)
        ..removeRange(recentCount.clamp(0, recentCategories.length), recentCategories.length);
    }
  }

  void setDate(DateTime date) {
    final t = selectedDate.value;
    // Jam lama dipertahankan agar urutan riwayat dalam satu hari tidak berubah.
    selectedDate.value = DateTime(date.year, date.month, date.day, t.hour, t.minute, t.second);
  }

  // --- Keypad ---

  void onAmountChanged(int value) {
    amount.value = value.clamp(0, maxAmount);
    if (amount.value > 0) amountError.value = null;
  }

  bool _validate() {
    amountError.value = amount.value <= 0 ? 'Masukkan nominal dulu' : null;
    categoryError.value = selectedCategory.value == null ? 'Pilih kategori' : null;
    return amountError.value == null && categoryError.value == null;
  }

  String get _name {
    final note = nameController.text.trim();
    return note.isNotEmpty ? note : selectedCategory.value!.storedLabel;
  }

  Future<void> save() => isEditing ? onUpdateSubmit() : submitForm();

  Future<void> submitForm() async {
    if (isSaving.value || justSaved.value || !_validate()) return;
    isSaving.value = true;
    try {
      final expense = Expense.create(
        name: _name,
        categoryId: selectedCategory.value!.id,
        transactionType: transactionType.value,
        dateTime: selectedDate.value,
        price: amount.value.toDouble(),
      );

      await repository.insertExpense(expense);
      log('Saving expense: ${expense.toDbMap()}');

      final message = (isIncome ? 'Pemasukan tersimpan' : 'Pengeluaran tersimpan').tr;
      _celebrate(
        () => showAppSnackBar(
          message,
          actionLabel: 'Urungkan'.tr,
          onAction: () async {
            await repository.deleteExpense(expense.id!);
            MainNavController.refreshAll();
          },
        ),
      );
    } catch (e) {
      log('Error saving expense: $e');
      showAppSnackBar('Gagal menyimpan. Coba lagi, ya.'.tr);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> onUpdateSubmit() async {
    if (isSaving.value || justSaved.value || !_validate()) return;
    isSaving.value = true;
    try {
      final updatedExpense = Expense(
        id: arg.value,
        name: _name,
        type: selectedCategory.value!.id,
        transactionType: transactionType.value,
        dateTime: selectedDate.value,
        price: amount.value.toDouble(),
      );

      await repository.updateExpense(updatedExpense);
      log('Updating expense: ${updatedExpense.toDbMap()}');

      _celebrate(() => showAppSnackBar('Perubahan tersimpan'.tr));
    } catch (e) {
      log('Error updating expense: $e');
      showAppSnackBar('Gagal menyimpan perubahan. Coba lagi, ya.'.tr);
    } finally {
      isSaving.value = false;
    }
  }

  void _celebrate(VoidCallback afterClose) {
    HapticFeedback.lightImpact();
    _afterClose = afterClose;
    justSaved.value = true;
    // Jaga-jaga bila animasi tidak memanggil balik (mis. aset gagal dimuat).
    _closeFallback = Timer(const Duration(milliseconds: 1600), finishSave);
  }

  /// Menutup form setelah momen sukses. Aman dipanggil lebih dari sekali.
  void finishSave() {
    if (!justSaved.value) return;
    justSaved.value = false;
    _closeFallback?.cancel();
    Get.back(result: true);
    _afterClose?.call();
    _afterClose = null;
  }

  Future<bool> deleteExpanse() async {
    try {
      await repository.deleteExpense(arg.value);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> onGetByid(String id) async {
    try {
      final expense = await repository.getExpense(id);
      if (expense == null) {
        Get.back();
        showAppSnackBar('Transaksi tidak ditemukan'.tr);
        return;
      }

      if (categories.isEmpty) await _loadCategories();

      transactionType.value = expense.transactionType;
      amount.value = expense.price.round();
      selectedDate.value = expense.dateTime;
      final cat = categories.firstWhereOrNull((c) => c.id == expense.type);
      if (cat != null) selectCategory(cat);
      // Catatan lama yang sama dengan nama kategori dianggap kosong.
      nameController.text = cat?.matchesLabel(expense.name) ?? false ? '' : expense.name;
    } catch (e) {
      log('Error loading expense: $e');
      Get.back();
      showAppSnackBar('Gagal memuat transaksi'.tr);
    }
  }
}
