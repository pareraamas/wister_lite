import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wister_lite/app/config/app_env.dart';

/// Iklan video sela (interstitial), maksimal [dailyLimit] kali sehari.
///
/// Iklan hanya tampil bila user menyalakannya di Profil; itulah "harga"
/// fitur sinkronisasi. SDK AdMob baru diinisialisasi setelah dinyalakan.
class AdService extends GetxService {
  AdService(this._prefs);

  final SharedPreferences _prefs;

  static const dailyLimit = 2;

  /// Jeda minimal antar-iklan agar dua jatah tidak habis berturut-turut.
  static const minGap = Duration(minutes: 30);

  static const _enabledKey = 'ads_enabled';
  static const _dayKey = 'ads_day';
  static const _countKey = 'ads_count';
  static const _lastKey = 'ads_last_at';

  final enabled = false.obs;
  final shownToday = 0.obs;

  bool _sdkReady = false;
  bool _loading = false;
  InterstitialAd? _ad;

  String get _unitId => Platform.isIOS ? AppEnv.admobInterstitialIos : AppEnv.admobInterstitialAndroid;

  @override
  void onInit() {
    super.onInit();
    enabled.value = _prefs.getBool(_enabledKey) ?? false;
    _rollDay();
    if (enabled.value) unawaited(_start());
  }

  @override
  void onClose() {
    _ad?.dispose();
    super.onClose();
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await _prefs.setBool(_enabledKey, value);
    if (value) {
      await _start();
    } else {
      _ad?.dispose();
      _ad = null;
    }
  }

  /// Dipanggil di jeda alami (mis. setelah transaksi tersimpan). Diam saja
  /// bila mati, jatah habis, terlalu dekat dengan iklan sebelumnya, atau
  /// iklan belum termuat.
  void maybeShow() {
    _rollDay();
    if (!enabled.value || shownToday.value >= dailyLimit) return;
    final last = DateTime.tryParse(_prefs.getString(_lastKey) ?? '');
    if (last != null && DateTime.now().difference(last) < minGap) return;
    final ad = _ad;
    if (ad == null) return _load();
    _ad = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _recordShown(),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        log('Iklan gagal tampil: $error');
        ad.dispose();
        _load();
      },
    );
    ad.show();
  }

  Future<void> _start() async {
    if (!_sdkReady) {
      if (!await _gatherConsent()) return;
      await MobileAds.instance.initialize();
      _sdkReady = true;
    }
    _load();
  }

  /// Formulir persetujuan UMP (wajib untuk pengguna EEA/UK).
  Future<bool> _gatherConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) => done.complete()),
      (error) {
        log('Info persetujuan iklan gagal: ${error.message}');
        done.complete();
      },
    );
    await done.future;
    return ConsentInformation.instance.canRequestAds();
  }

  void _load() {
    if (!_sdkReady || _loading || _ad != null || !enabled.value || shownToday.value >= dailyLimit) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          if (enabled.value) {
            _ad = ad;
          } else {
            ad.dispose();
          }
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          log('Iklan gagal dimuat: $error');
        },
      ),
    );
  }

  void _recordShown() {
    shownToday.value++;
    _prefs.setInt(_countKey, shownToday.value);
    _prefs.setString(_lastKey, DateTime.now().toIso8601String());
  }

  /// Jatah kembali penuh setiap ganti tanggal (waktu lokal).
  void _rollDay() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (_prefs.getString(_dayKey) != today) {
      _prefs.setString(_dayKey, today);
      _prefs.setInt(_countKey, 0);
    }
    shownToday.value = _prefs.getInt(_countKey) ?? 0;
  }
}
