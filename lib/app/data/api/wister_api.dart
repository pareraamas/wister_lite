import 'package:wister_lite/app/data/models/app_user.dart';

/// Kontrak backend (Laravel). Detail endpoint: `docs/api/sync-api.md`.
/// Implementasi: [HttpWisterApi] (server sungguhan) dan [FakeWisterApi]
/// (di memori, selama backend belum siap).
abstract class WisterApi {
  /// Tukar idToken Google dengan token Sanctum.
  Future<AuthSession> signInWithGoogle(String idToken);

  Future<void> signOut(String token);

  /// Hapus akun beserta semua data di server (wajib ada menurut Play Store).
  Future<void> deleteAccount(String token);

  /// Kirim perubahan lokal, terima perubahan server sejak [cursor].
  Future<SyncResponse> sync(String token, {String? cursor, required SyncChanges changes});
}

class AuthSession {
  final String token;
  final AppUser user;

  const AuthSession({required this.token, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      AuthSession(token: json['token'] as String, user: AppUser.fromJson(json['user'] as Map<String, dynamic>));
}

/// Satu paket perubahan, dipakai dua arah (push dan pull).
///
/// Baris memakai nama kolom SQLite apa adanya plus `updated_at` (ISO-8601 UTC);
/// kolom `dirty` tidak pernah dikirim.
class SyncChanges {
  /// Urutan penting saat diterapkan: kategori dulu, transaksi terakhir.
  static const entities = ['categories', 'budgets', 'expenses'];

  final Map<String, List<Map<String, dynamic>>> rows;

  /// `{entity, id, deleted_at}`.
  final List<Map<String, dynamic>> deletions;

  const SyncChanges({this.rows = const {}, this.deletions = const []});

  bool get isEmpty => deletions.isEmpty && rows.values.every((r) => r.isEmpty);

  int get length => deletions.length + rows.values.fold(0, (sum, r) => sum + r.length);

  Map<String, dynamic> toJson() => {
    for (final e in entities) e: rows[e] ?? const [],
    'deletions': deletions,
  };

  factory SyncChanges.fromJson(Map<String, dynamic> json) => SyncChanges(
    rows: {
      for (final e in entities) e: [for (final r in (json[e] as List? ?? const [])) Map<String, dynamic>.from(r as Map)],
    },
    deletions: [for (final d in (json['deletions'] as List? ?? const [])) Map<String, dynamic>.from(d as Map)],
  );
}

class SyncResponse {
  /// Disimpan dan dikirim balik pada sync berikutnya.
  final String cursor;
  final SyncChanges changes;

  const SyncResponse({required this.cursor, required this.changes});

  factory SyncResponse.fromJson(Map<String, dynamic> json) => SyncResponse(
    cursor: json['cursor'].toString(),
    changes: SyncChanges.fromJson(json['changes'] as Map<String, dynamic>? ?? const {}),
  );
}

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  const ApiException(this.message, {this.statusCode});

  /// Token tidak berlaku lagi; user perlu masuk ulang.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Tidak ada koneksi atau server tidak terjangkau.
class OfflineException implements Exception {
  const OfflineException();
}
