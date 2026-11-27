# Memulai

Terjemahan dari [getting-started.md](getting-started.md).

## 1. Prasyarat

- Flutter, channel stable (`flutter doctor` tidak menampilkan masalah untuk platform yang Anda pakai).
- Android: Android Studio dengan emulator, atau ponsel dengan USB debugging. iOS: Mac dengan Xcode.
- API dari [go-gin-tenant-template](https://github.com/fiankasepmantea/go-gin-tenant-template) sudah berjalan, lengkap
  dengan tenant, pengguna tenant, dan grup yang sudah diberi izin endpoint (`tenantctl group grant --all`).

## 2. Buat proyek native

```bash
bash tool/bootstrap.sh
```

Skrip ini menjalankan `flutter create` untuk Android dan iOS tanpa menimpa file kita, mengizinkan permission
`INTERNET` untuk build release, mengizinkan `http://` biasa untuk build debug di Android, mengatur `minSdk` Android ke
23 (dibutuhkan `flutter_secure_storage`), lalu menjalankan `flutter pub get`. Commit folder `android/` dan `ios/` yang
dihasilkan.

## 3. Arahkan aplikasi ke API Anda

```bash
cp config/dart_defines.example.json config/dart_defines.json
```

Ubah `API_BASE_URL`: `http://10.0.2.2:8080` (emulator Android), `http://localhost:8080` (simulator iOS), alamat LAN
komputer Anda (ponsel asli), atau URL `https://` Anda. Lalu:

```bash
flutter run --dart-define-from-file=config/dart_defines.json
```

## 4. Periksa

```bash
flutter analyze
flutter test
```

## 5. Rilis

Android: buat keystore, taruh pengaturannya di `android/key.properties` (diabaikan git), lalu ikuti
<https://docs.flutter.dev/deployment/android>. Atur `version:` di `pubspec.yaml` sebelum tiap rilis; pengecekan update
membandingkan versi itu dengan versi yang terdaftar di backend (`/api/v1/app-versions`, lihat `docs/app-versions.md`
di backend). iOS: <https://docs.flutter.dev/deployment/ios>.

Ganti application id (`com.example.go_gin_tenant_mobile`), nama aplikasi, dan ikon sebelum dipublikasikan. Untuk
mengganti warna, ubah `seed` di `lib/core/ui/theme.dart`.
