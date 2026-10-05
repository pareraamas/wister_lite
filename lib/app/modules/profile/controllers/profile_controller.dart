import 'dart:developer';

import 'package:get/get.dart';
import 'package:wister_lite/app/data/repositories/expense_repository.dart';
import 'package:wister_lite/app/data/services/ad_service.dart';
import 'package:wister_lite/app/data/services/auth_service.dart';
import 'package:wister_lite/app/data/services/sync_service.dart';
import 'package:wister_lite/app/modules/main_nav/controllers/main_nav_controller.dart';
import 'package:wister_lite/app/widgets/app_snackbar.dart';

class ProfileController extends GetxController {
  final auth = Get.find<AuthService>();
  final sync = Get.find<SyncService>();
  final ads = Get.find<AdService>();
  final _repository = Get.find<ExpenseRepository>();

  /// Masuk / keluar / hapus akun sedang berjalan.
  final isBusy = false.obs;

  bool get syncOn => auth.isSignedIn && ads.enabled.value;

  @override
  void onInit() {
    super.onInit();
    sync.refreshPending();
  }

  /// Masuk saja, tanpa menyalakan sync.
  Future<bool> signIn() async {
    if (isBusy.value) return false;
    isBusy.value = true;
    try {
      final ok = await auth.signInWithGoogle();
      if (ok) showAppSnackBar('Halo, @name!'.trParams({'name': auth.user.value!.name}));
      return ok;
    } catch (e) {
      log('Masuk gagal: $e');
      showAppSnackBar('Gagal masuk. Periksa koneksi lalu coba lagi.'.tr);
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  /// Iklan dan sync satu paket: menyalakan iklan = menyalakan sync.
  Future<void> toggleSync(bool on) async {
    if (!on) {
      await ads.setEnabled(false);
      showAppSnackBar('Sinkronisasi & iklan dimatikan'.tr);
      return;
    }
    if (!auth.isSignedIn && !await signIn()) return;
    await ads.setEnabled(true);
    final ok = await sync.syncNow();
    showAppSnackBar(ok ? 'Sinkronisasi aktif. Data kamu sudah dicadangkan.'.tr : 'Sinkronisasi aktif, tapi belum berhasil terkirim.'.tr);
  }

  Future<void> syncNow() async {
    if (await sync.syncNow()) showAppSnackBar('Data sudah tersinkron'.tr);
  }

  /// Kirim sisa perubahan dulu, lalu kembalikan pesan konfirmasi keluar.
  Future<String> prepareSignOut() async {
    if (sync.canSync) await sync.syncNow();
    await sync.refreshPending();
    final pending = sync.pendingCount.value;
    if (sync.lastSyncedAt.value == null) {
      return 'Data belum pernah disinkronkan, jadi semua transaksi di HP ini akan hilang permanen.'.tr;
    }
    if (pending > 0) {
      return '@n perubahan belum terkirim ke server dan akan hilang. Data lainnya kembali saat kamu masuk lagi.'.trParams({'n': '$pending'});
    }
    return 'Data di HP ini akan dihapus. Masuk lagi kapan saja untuk memulihkannya dari server.'.tr;
  }

  Future<void> signOut() async {
    isBusy.value = true;
    try {
      await auth.signOut();
      await _wipeLocal();
      showAppSnackBar('Kamu sudah keluar'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> deleteAccount() async {
    isBusy.value = true;
    try {
      await auth.deleteAccount();
      await _wipeLocal();
      showAppSnackBar('Akun dan datamu sudah dihapus'.tr);
    } catch (e) {
      log('Hapus akun gagal: $e');
      showAppSnackBar('Gagal menghapus akun. Periksa koneksi lalu coba lagi.'.tr);
    } finally {
      isBusy.value = false;
    }
  }

  /// Data lokal milik akun yang keluar tidak boleh tertinggal di HP.
  Future<void> _wipeLocal() async {
    await ads.setEnabled(false);
    await _repository.resetLocalData();
    await sync.reset();
    MainNavController.refreshAll();
  }
}
