import 'dart:async';
import 'dart:developer';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wister_lite/app/data/api/wister_api.dart';
import 'package:wister_lite/app/data/local/database_helper.dart';
import 'package:wister_lite/app/data/services/ad_service.dart';
import 'package:wister_lite/app/data/services/auth_service.dart';
import 'package:wister_lite/app/modules/main_nav/controllers/main_nav_controller.dart';

enum SyncState { idle, syncing, offline, error }

/// Sinkronisasi dua arah dengan server. Hanya berjalan bila user sudah
/// masuk DAN menyalakan iklan ([canSync]).
class SyncService extends GetxService {
  SyncService(this._prefs, this._api);

  final SharedPreferences _prefs;
  final WisterApi _api;
  final _db = DatabaseHelper.instance;

  static const _cursorKey = 'sync_cursor';
  static const _lastKey = 'sync_last_at';

  /// Jeda setelah perubahan terakhir sebelum sync otomatis.
  static const _debounce = Duration(seconds: 5);

  final state = SyncState.idle.obs;
  final lastSyncedAt = Rxn<DateTime>();
  final pendingCount = 0.obs;
  final errorMessage = RxnString();

  Timer? _timer;
  Future<bool>? _running;

  AuthService get _auth => Get.find<AuthService>();
  AdService get _ads => Get.find<AdService>();

  bool get canSync => _auth.isSignedIn && _ads.enabled.value;

  @override
  void onInit() {
    super.onInit();
    lastSyncedAt.value = DateTime.tryParse(_prefs.getString(_lastKey) ?? '');
    refreshPending();
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> refreshPending() async => pendingCount.value = await _db.pendingChangeCount();

  /// Dipanggil setelah data lokal berubah; sync menyusul setelah [_debounce].
  Future<void> scheduleSync() async {
    await refreshPending();
    if (!canSync || pendingCount.value == 0) return;
    _timer?.cancel();
    _timer = Timer(_debounce, syncNow);
  }

  /// True bila berhasil. Panggilan saat sync sedang jalan menunggu yang sama.
  Future<bool> syncNow() {
    _timer?.cancel();
    if (!canSync) return Future.value(false);
    return _running ??= _sync().whenComplete(() => _running = null);
  }

  Future<bool> _sync() async {
    state.value = SyncState.syncing;
    errorMessage.value = null;
    try {
      final token = await _auth.token();
      if (token == null) throw const ApiException('Sesi tidak ditemukan', statusCode: 401);

      final local = await _db.collectChanges();
      final response = await _api.sync(token, cursor: _prefs.getString(_cursorKey), changes: local);
      await _db.markSynced(local);
      await _db.applyRemote(response.changes);

      await _prefs.setString(_cursorKey, response.cursor);
      final now = DateTime.now();
      await _prefs.setString(_lastKey, now.toIso8601String());
      lastSyncedAt.value = now;
      state.value = SyncState.idle;
      if (!response.changes.isEmpty) MainNavController.refreshAll();
      return true;
    } on OfflineException {
      state.value = SyncState.offline;
      return false;
    } on ApiException catch (e) {
      log('Sync gagal: $e');
      state.value = SyncState.error;
      errorMessage.value = e.isUnauthorized ? 'Sesi berakhir. Keluar lalu masuk lagi, ya.' : 'Server sedang bermasalah. Coba lagi nanti.';
      return false;
    } catch (e) {
      log('Sync gagal: $e');
      state.value = SyncState.error;
      errorMessage.value = 'Sinkronisasi gagal. Coba lagi, ya.';
      return false;
    } finally {
      await refreshPending();
    }
  }

  /// Lupakan posisi sync (setelah keluar akun dan data lokal dihapus).
  Future<void> reset() async {
    _timer?.cancel();
    await _prefs.remove(_cursorKey);
    await _prefs.remove(_lastKey);
    lastSyncedAt.value = null;
    state.value = SyncState.idle;
    errorMessage.value = null;
    await refreshPending();
  }
}
