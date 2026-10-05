import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wister_lite/app/config/app_env.dart';
import 'package:wister_lite/app/data/api/wister_api.dart';
import 'package:wister_lite/app/data/models/app_user.dart';

/// Masuk dengan Google. Profil disimpan di SharedPreferences agar langsung
/// tersedia saat start; token server di secure storage.
class AuthService extends GetxService {
  AuthService(this._prefs, this._api);

  final SharedPreferences _prefs;
  final WisterApi _api;
  final _secure = const FlutterSecureStorage();

  static const _userKey = 'auth_user';
  static const _tokenKey = 'auth_token';

  final user = Rxn<AppUser>();

  bool _googleReady = false;

  bool get isSignedIn => user.value != null;

  Future<String?> token() => _secure.read(key: _tokenKey);

  @override
  void onInit() {
    super.onInit();
    final raw = _prefs.getString(_userKey);
    if (raw != null) user.value = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// False bila user membatalkan dialog Google.
  Future<bool> signInWithGoogle() async {
    final idToken = await _googleIdToken();
    if (idToken == null) return false;
    final session = await _api.signInWithGoogle(idToken);
    await _secure.write(key: _tokenKey, value: session.token);
    await _prefs.setString(_userKey, jsonEncode(session.user.toJson()));
    user.value = session.user;
    return true;
  }

  /// Keluar di server (sebisanya) lalu lupakan sesi lokal.
  Future<void> signOut() async {
    final t = await token();
    if (t != null) {
      try {
        await _api.signOut(t);
      } catch (e) {
        log('Logout server gagal, lanjut keluar lokal: $e');
      }
    }
    await _forget();
  }

  /// Gagal = lempar error, sesi lokal tetap.
  Future<void> deleteAccount() async {
    final t = await token();
    if (t != null) await _api.deleteAccount(t);
    await _forget();
  }

  Future<void> _forget() async {
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.disconnect();
      } catch (_) {}
    }
    await _secure.delete(key: _tokenKey);
    await _prefs.remove(_userKey);
    user.value = null;
  }

  Future<String?> _googleIdToken() async {
    // Tanpa client ID: akun demo, cukup untuk mencoba alur dengan backend palsu.
    if (AppEnv.useFakeGoogle) return 'demo';

    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(
        clientId: Platform.isIOS && AppEnv.googleIosClientId.isNotEmpty ? AppEnv.googleIosClientId : null,
        serverClientId: AppEnv.googleServerClientId,
      );
      _googleReady = true;
    }
    try {
      final account = await google.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const ApiException('Google tidak mengembalikan idToken');
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}
