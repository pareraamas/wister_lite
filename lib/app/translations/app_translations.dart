import 'package:get/get.dart';

import 'en/budget_stats.dart';
import 'en/common.dart';
import 'en/forms.dart';
import 'en/history.dart';
import 'en/home.dart';
import 'en/profile_data.dart';
import 'en/ui.dart';

export 'tr_context.dart';

/// Teks Indonesia dipakai langsung sebagai key (`'Simpan'.tr`), jadi
/// `id_ID` tidak perlu peta: key yang tidak ditemukan dikembalikan apa adanya.
/// Hanya terjemahan Inggris yang perlu didaftarkan di sini.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {...enCommon, ...enUi, ...enHome, ...enHistory, ...enForms, ...enBudgetStats, ...enProfileData, ..._enShared},
  };
}

/// Kata umum yang dipakai beberapa layar: satu arti di sini agar konsisten.
/// Arti khusus konteks pakai `trIn` (lihat [ContextTr]).
const Map<String, String> _enShared = {
  'Lainnya': 'Other',
  'Atur anggaran': 'Set budget',
  'Belum ada anggaran': 'No budgets yet',
  'Statistik': 'Statistics',
  'Kategori': 'Category',
  'Pengeluaran per kategori': 'Spending by category',
  'Semua': 'All',
  'Masuk': 'In',
  'Keluar': 'Out',
  'Selisih': 'Net',
  'Buat kategori': 'New category',
  'menu:Lainnya': 'More',
  'auth:Keluar': 'Sign out',
  'period:Semua': 'All time',
  'section:Kategori': 'Categories',
};
