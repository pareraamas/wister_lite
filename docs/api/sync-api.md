# Wister Lite — Kontrak API (Laravel)

Kontrak backend untuk fitur **Login Google** dan **Sinkronisasi**. Aplikasi sudah memakai kontrak ini lewat `HttpWisterApi`; selama backend belum ada, aplikasi berjalan dengan `FakeWisterApi`, server tiruan di memori dengan aturan yang sama. Aturan sync juga ditulis sebagai test yang bisa dijalankan: `test/data/fake_wister_api_test.dart`.

- Format: JSON, header `Accept: application/json`.
- Auth: Laravel Sanctum, header `Authorization: Bearer <token>`.
- Waktu: semua `updated_at` / `deleted_at` dalam ISO-8601 UTC (`2026-10-05T08:00:00.000Z`).
- Error: status HTTP + `{"message": "..."}`. `401` membuat aplikasi meminta user masuk ulang.

## Aturan produk yang memengaruhi backend

- Sync hanya berjalan bila user **sudah masuk** dan **menyalakan iklan** (iklan sela, maksimal 2x sehari). Saklar ini hanya ada di aplikasi, jadi server tidak perlu tahu soal iklan.
- Saat user keluar, data lokal di HP dihapus. Data di server tetap ada dan kembali saat user masuk lagi.
- Hapus akun wajib tersedia (aturan Google Play): menghapus user beserta semua datanya.

## 1. Masuk dengan Google

`POST /api/auth/google`

```json
{ "id_token": "<idToken dari Google Sign-In>", "device_name": "android" }
```

Respons `200`:

```json
{
  "token": "1|abc...",
  "user": { "id": 42, "name": "Amas", "email": "amas@gmail.com", "avatar_url": "https://..." }
}
```

Implementasi:

1. Verifikasi token dengan `google/apiclient`: `(new Google\Client(['client_id' => WEB_CLIENT_ID]))->verifyIdToken($idToken)`. **Jangan** pakai Socialite `userFromToken`, karena method itu untuk access token, bukan idToken.
2. Pastikan `aud` sama dengan Web client ID dan `email_verified` bernilai true.
3. `User::updateOrCreate(['google_id' => $payload['sub']], [name, email, avatar])`.
4. Kembalikan `$user->createToken($deviceName)->plainTextToken`.

`401` bila token tidak valid.

## 2. Keluar

`POST /api/auth/logout` → `204`. Hapus token yang sedang dipakai (`currentAccessToken()->delete()`).

## 3. Hapus akun

`DELETE /api/account` → `204`. Hapus user, semua token, dan semua data sync miliknya.

## 4. Sync

`POST /api/sync`

Satu endpoint dua arah: aplikasi mengirim perubahan lokal (**push**), lalu server mengembalikan semua perubahan sejak `cursor` (**pull**).

Request:

```json
{
  "cursor": "1287",
  "changes": {
    "categories": [{ "id": "food", "label": "Makanan", "color_value": 4294940672, "icon": "assets/icon_category/uil_food.svg", "updated_at": "..." }],
    "budgets":    [{ "id": "uuid", "category_id": "food", "year_month": "2026-10", "amount": 500000, "updated_at": "..." }],
    "expenses":   [{ "id": "uuid", "name": "Kopi", "type": "food", "transaction_type": "expense", "date_time": "2026-10-05T08:00:00.000", "price": 18000, "updated_at": "..." }],
    "deletions":  [{ "entity": "expenses", "id": "uuid", "deleted_at": "..." }]
  }
}
```

- `cursor` bernilai `null` pada sync pertama, termasuk setelah user masuk lagi, sehingga server mengembalikan semua data.
- `expenses.type` = id kategori.
- `expenses.date_time` = waktu lokal HP **tanpa zona waktu**. Simpan apa adanya sebagai string.
- `entity` ∈ `categories | budgets | expenses`.

Respons `200`, dengan bentuk `changes` yang sama:

```json
{ "cursor": "1290", "changes": { "categories": [], "budgets": [], "expenses": [], "deletions": [] } }
```

### Aturan server

1. **Scope per user.** Primary key efektif adalah `(user_id, id)`. Id kategori bawaan (`food`, `internet`, …) sama untuk semua user.
2. **Last-write-wins.** Baris masuk hanya menimpa bila `updated_at`-nya ≥ `updated_at` di server. Deletion hanya berlaku bila `deleted_at` ≥ `updated_at` di server.
3. **Hapus = tombstone.** Jangan hard delete. Tandai `deleted_at` agar perangkat lain menerima penghapusannya lewat `deletions`.
4. **Anggaran unik per `(user_id, category_id, year_month)`.** Bila datang anggaran dengan id berbeda untuk slot yang sama, simpan yang `updated_at`-nya lebih baru dan tandai yang lain sebagai terhapus. Aplikasi juga membuang baris lokal yang bentrok saat menerima versi server.
5. **Cursor** adalah angka versi yang terus naik per user (`sync_version`). Setiap baris yang berubah (termasuk tombstone) mendapat versi baru. Pull = semua baris dengan `sync_version > cursor`. Respons boleh menyertakan kembali baris yang baru saja di-push.
6. Push dan pull dikerjakan dalam satu transaksi DB. `cursor` di respons adalah versi tertinggi setelah push diterapkan.

### Skema usulan

```php
// satu tabel per entity, contoh expenses
Schema::create('expenses', function (Blueprint $t) {
    $t->foreignId('user_id')->constrained()->cascadeOnDelete();
    $t->string('id');                       // UUID dari aplikasi
    $t->string('name');
    $t->string('type');                     // category id
    $t->string('transaction_type');
    $t->string('date_time');                // waktu lokal HP, string
    $t->decimal('price', 15, 2);
    $t->timestamp('updated_at', 3);         // dari klien, bukan dari Eloquent
    $t->timestamp('deleted_at', 3)->nullable();
    $t->unsignedBigInteger('sync_version')->index();
    $t->primary(['user_id', 'id']);
});
// users: + google_id (unique), avatar_url, sync_version (counter)
```

Matikan timestamp otomatis Eloquent (`public $timestamps = false`) agar `updated_at` dari klien tidak tertimpa.

## Konfigurasi aplikasi

```
flutter run \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<WEB client id>.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<iOS client id>.apps.googleusercontent.com \
  --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-xxx/yyy
```

Semua variabel opsional. Tanpa `API_BASE_URL` aplikasi memakai server palsu. Tanpa `GOOGLE_SERVER_CLIENT_ID` login memakai akun demo. Tanpa unit AdMob aplikasi memakai iklan uji Google.

Checklist Google Cloud / AdMob sebelum rilis:

- [ ] OAuth client **Web** (untuk `serverClientId`, dan untuk `client_id` di Laravel).
- [ ] OAuth client **Android** dengan SHA-1 debug, release, **dan Play App Signing**.
- [ ] OAuth client iOS + URL scheme `REVERSED_CLIENT_ID` di `ios/Runner/Info.plist`.
- [ ] Ganti AdMob App ID uji di `AndroidManifest.xml` dan `Info.plist`.
- [ ] Kebijakan privasi (Google login + AdMob) dan URL web untuk hapus akun di Play Console.
