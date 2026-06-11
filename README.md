# Log Kegiatan Magang

<img src="assets/icon/Icon.png" width="80">

Aplikasi pencatat kegiatan harian untuk mahasiswa magang. Dibuat pakai Flutter.

## Fitur

- Catat aktivitas harian (tanggal, jam masuk/keluar, deskripsi kegiatan)
- Lampiran foto (max 5 foto per kegiatan)
- Profil mahasiswa (nama, NIM, universitas, tempat magang, periode)
- Kalender bulanan untuk lihat aktivitas per tanggal
- Kategori aktivitas (administrasi, lapangan, meeting, dll)
- Refleksi harian (mood + pelajaran yang didapat)
- Laporan & statistik (total jam, rata-rata per hari, grafik per minggu/bulan)
- Ekspor ke CSV (format laporan lengkap, bisa dibuka di Excel)
- Ekspor ke PDF
- Import data dari file CSV
- Backup & restore data (format ZIP)
- Dark mode / light mode
- Kunci aplikasi dengan PIN
- Sistem badge/gamifikasi

## Cara Pakai

```bash
# Install dependencies
flutter pub get

# Jalankan (debug)
flutter run

# Build APK release
flutter build apk --release
```

## Struktur Folder

```
lib/
├── main.dart              # Entry point
├── app.dart               # Theme & routing
├── models/models.dart     # Model data (Profile, Entry, Settings, dll)
├── pages/                 # Halaman-halaman (home, calendar, analytics, settings)
├── widgets/               # Widget reusable (card, header, animation)
├── services/              # Storage, PDF export, notifikasi, gamifikasi
└── helpers/               # Utility (format tanggal, CSV builder, animasi)
```

## Tech

- Flutter + Dart
- Material 3
- `path_provider` - penyimpanan lokal
- `image_picker` - pilih foto dari galeri/kamera
- `share_plus` - share file
- `csv` - parse & generate CSV
- `pdf` - generate laporan PDF
- `file_picker` - pilih file untuk import/backup
