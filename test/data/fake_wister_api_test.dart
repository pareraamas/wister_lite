import 'package:flutter_test/flutter_test.dart';
import 'package:wister_lite/app/data/api/fake_wister_api.dart';
import 'package:wister_lite/app/data/api/wister_api.dart';

/// Aturan sync yang juga harus dipenuhi server Laravel (docs/api/sync-api.md).
void main() {
  Map<String, dynamic> expense(String id, String at, {double price = 1000}) => {
    'id': id,
    'name': 'Kopi',
    'type': 'food',
    'transaction_type': 'expense',
    'date_time': '2026-10-05T08:00:00.000',
    'price': price,
    'updated_at': at,
  };

  Map<String, dynamic> budget(String id, String at) => {
    'id': id,
    'category_id': 'food',
    'year_month': '2026-10',
    'amount': 500000.0,
    'updated_at': at,
  };

  late FakeWisterApi api;
  setUp(() => api = FakeWisterApi());

  Future<SyncResponse> sync(String? cursor, {Map<String, List<Map<String, dynamic>>> rows = const {}, List<Map<String, dynamic>> deletions = const []}) =>
      api.sync('t', cursor: cursor, changes: SyncChanges(rows: rows, deletions: deletions));

  test('HP kedua menerima transaksi dari HP pertama', () async {
    await sync(null, rows: {'expenses': [expense('a', '2026-10-05T01:00:00Z')]});
    final b = await sync(null);
    expect(b.changes.rows['expenses']!.single['id'], 'a');
  });

  test('cursor hanya mengembalikan perubahan sesudahnya', () async {
    final first = await sync(null, rows: {'expenses': [expense('a', '2026-10-05T01:00:00Z')]});
    final again = await sync(first.cursor);
    expect(again.changes.isEmpty, isTrue);
  });

  test('last-write-wins: versi lama tidak menimpa yang baru', () async {
    await sync(null, rows: {'expenses': [expense('a', '2026-10-05T02:00:00Z', price: 2000)]});
    await sync(null, rows: {'expenses': [expense('a', '2026-10-05T01:00:00Z', price: 1000)]});
    final all = await sync(null);
    expect(all.changes.rows['expenses']!.single['price'], 2000);
  });

  test('hapus diteruskan sebagai deletions', () async {
    final first = await sync(null, rows: {'expenses': [expense('a', '2026-10-05T01:00:00Z')]});
    await sync(first.cursor, deletions: [{'entity': 'expenses', 'id': 'a', 'deleted_at': '2026-10-05T02:00:00Z'}]);
    final other = await sync(first.cursor);
    expect(other.changes.deletions.single['id'], 'a');
    expect(other.changes.rows['expenses'], isNull);
  });

  test('anggaran: satu slot kategori+bulan, id lama dianggap terhapus', () async {
    await sync(null, rows: {'budgets': [budget('b1', '2026-10-05T01:00:00Z')]});
    final res = await sync(null, rows: {'budgets': [budget('b2', '2026-10-05T02:00:00Z')]});
    expect(res.changes.rows['budgets']!.map((b) => b['id']), ['b2']);
    expect(res.changes.deletions.map((d) => d['id']), ['b1']);
  });

  test('masuk dengan idToken Google membaca nama & email dari payload', () async {
    // {"sub":"42","name":"Amas","email":"a@b.c"}
    const token = 'x.eyJzdWIiOiI0MiIsIm5hbWUiOiJBbWFzIiwiZW1haWwiOiJhQGIuYyJ9.y';
    final session = await api.signInWithGoogle(token);
    expect(session.user.name, 'Amas');
    expect(session.user.email, 'a@b.c');
  });
}
