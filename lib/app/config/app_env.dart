import 'package:flutter/foundation.dart';

/// Konfigurasi build lewat `--dart-define`. Semua boleh kosong saat
/// pengembangan: API kosong = backend palsu di memori, unit iklan kosong =
/// unit iklan default (uji di debug, asli di rilis). Client ID Google default ke project Firebase
/// `wister-lite-app`; `--dart-define=GOOGLE_SERVER_CLIENT_ID=` (kosong) =
/// akun demo tanpa dialog Google.
///
/// Contoh rilis:
/// ```
/// flutter build apk \
///   --dart-define=API_BASE_URL=https://api.wister.id \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com
/// ```
abstract final class AppEnv {
  /// Root API Laravel tanpa garis miring di akhir, mis. `https://api.wister.id`.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Web client ID (bukan Android client ID) agar Google mengembalikan idToken
  /// yang bisa diverifikasi server.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '407028479534-udha0taua19ul302a973io03ndpt687u.apps.googleusercontent.com',
  );

  /// iOS butuh client ID iOS sendiri (atau `GIDClientID` di Info.plist).
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '407028479534-ae3ug087ddqrfrrbeap57ee29d8009im.apps.googleusercontent.com',
  );

  static const admobInterstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    // Debug/profile pakai unit uji Google agar klik saat pengembangan tidak
    // melanggar kebijakan AdMob; rilis pakai unit asli.
    defaultValue: kReleaseMode
        ? 'ca-app-pub-1345642089171121/2606850525'
        : 'ca-app-pub-3940256099942544/1033173712',
  );

  static const admobInterstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910', // unit uji Google
  );

  static bool get useFakeApi => apiBaseUrl.isEmpty;

  static bool get useFakeGoogle => googleServerClientId.isEmpty;
}
