import 'dart:convert';

import 'package:wister_lite/app/data/models/app_user.dart';

import 'wister_api.dart';

/// Server tiruan di memori untuk dipakai selama backend Laravel belum ada.
/// Aturannya sama dengan yang diharapkan dari server sungguhan (lihat
/// `docs/api/sync-api.md`), tetapi datanya hilang saat aplikasi ditutup.
class FakeWisterApi implements WisterApi {
  static const _latency = Duration(milliseconds: 700);

  /// entity → id → baris.
  final _store = <String, Map<String, _ServerRow>>{for (final e in SyncChanges.entities) e: {}};
  int _version = 0;

  @override
  Future<AuthSession> signInWithGoogle(String idToken) async {
    await Future.delayed(_latency);
    final claims = _jwtClaims(idToken);
    final user = AppUser(
      id: claims['sub']?.toString() ?? 'demo',
      name: claims['name'] as String? ?? 'Pengguna Demo',
      email: claims['email'] as String? ?? 'demo@wister.local',
      avatarUrl: claims['picture'] as String?,
    );
    return AuthSession(token: 'fake-token-${user.id}', user: user);
  }

  @override
  Future<void> signOut(String token) => Future.delayed(_latency);

  @override
  Future<void> deleteAccount(String token) async {
    await Future.delayed(_latency);
    for (final rows in _store.values) {
      rows.clear();
    }
  }

  @override
  Future<SyncResponse> sync(String token, {String? cursor, required SyncChanges changes}) async {
    await Future.delayed(_latency);
    final since = int.tryParse(cursor ?? '') ?? 0;

    for (final entity in SyncChanges.entities) {
      for (final row in changes.rows[entity] ?? const <Map<String, dynamic>>[]) {
        _upsert(entity, row);
      }
    }
    for (final d in changes.deletions) {
      _delete(d['entity'] as String, d['id'] as String, d['deleted_at'] as String);
    }

    final rows = <String, List<Map<String, dynamic>>>{};
    final deletions = <Map<String, dynamic>>[];
    _store.forEach((entity, byId) {
      for (final MapEntry(key: id, value: row) in byId.entries) {
        if (row.version <= since) continue;
        if (row.deleted) {
          deletions.add({'entity': entity, 'id': id, 'deleted_at': row.data['updated_at']});
        } else {
          (rows[entity] ??= []).add(row.data);
        }
      }
    });
    return SyncResponse(cursor: '$_version', changes: SyncChanges(rows: rows, deletions: deletions));
  }

  /// Last-write-wins berdasarkan `updated_at`.
  void _upsert(String entity, Map<String, dynamic> row) {
    final byId = _store[entity]!;
    final id = row['id'] as String;
    final existing = byId[id];
    if (existing != null && _newer(existing.data['updated_at'], row['updated_at'])) return;

    // Satu anggaran per kategori per bulan: id lain untuk slot yang sama dianggap terhapus.
    if (entity == 'budgets') {
      for (final other in byId.entries) {
        final o = other.value;
        if (other.key != id && !o.deleted && o.data['category_id'] == row['category_id'] && o.data['year_month'] == row['year_month']) {
          byId[other.key] = _ServerRow(o.data, ++_version, deleted: true);
        }
      }
    }
    byId[id] = _ServerRow(Map.of(row), ++_version);
  }

  void _delete(String entity, String id, String deletedAt) {
    final byId = _store[entity];
    if (byId == null) return;
    final existing = byId[id];
    if (existing != null && _newer(existing.data['updated_at'], deletedAt)) return;
    byId[id] = _ServerRow({...?existing?.data, 'id': id, 'updated_at': deletedAt}, ++_version, deleted: true);
  }

  static bool _newer(Object? a, Object? b) {
    final da = DateTime.tryParse('$a');
    final db = DateTime.tryParse('$b');
    return da != null && (db == null || da.isAfter(db));
  }

  /// Payload idToken Google (tanpa verifikasi; server sungguhan wajib memverifikasi).
  static Map<String, dynamic> _jwtClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return const {};
    try {
      return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }
}

class _ServerRow {
  _ServerRow(this.data, this.version, {this.deleted = false});

  final Map<String, dynamic> data;
  final int version;
  final bool deleted;
}
