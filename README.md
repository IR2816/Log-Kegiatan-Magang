# 📔 Log Kegiatan Magang

<p align="center">
  <img src="assets/icon/Icon.png" width="120" alt="App Icon">
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="License"></a>
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Platform">
</p>

---

**Aplikasi Log Kegiatan Magang** adalah solusi digital modern yang dirancang khusus untuk mahasiswa perguruan tinggi dalam mendokumentasikan setiap aktivitas magang mereka secara elegan, terstruktur, dan profesional.

## 🌟 Fitur Unggulan

- **💎 Premium Dashboard**: Tampilan visual yang memukau dengan gradient header, grafik progres jam kerja, dan metrik instan.
- **📸 Visual Documentation**: Mendukung lampiran hingga 5 foto per aktivitas untuk bukti kegiatan yang lebih otentik.
- **⚡ Fluid Animations**: Pengalaman pengguna yang sangat halus dengan transisi halaman slide-fade dan counter angka yang dinamis.
- **🎨 Personalized Identity**: Kustomisasi profil lengkap mulai dari nama, NIM, instansi, hingga foto profil dan logo universitas sendiri.
- **📋 Management Activity**: Pengorganisasian log berdasarkan tanggal dengan fitur edit dan hapus yang intuitif.
- **📤 Pro-Grade Export**: Ekspor seluruh data kegiatan ke format CSV yang rapi dan siap dikirim ke pembimbing lapangan.

## 🛠️ Tech Stack

- **Core**: [Flutter](https://flutter.dev) (UI Framework)
- **Language**: [Dart](https://dart.dev)
- **Theming**: Material 3 Design System
- **Services**:
  - `path_provider`: Untuk manajemen penyimpanan lokal.
  - `share_plus`: Fitur berbagi file laporan.
  - `image_picker`: Integrasi galeri untuk dokumentasi kegiatan.
- **Custom Utils**:
  - `AnimatedCounter`: Counting-up stats.
  - `FadeSlideIn`: Staggered entrance animations.
  - `PressableCard`: Feedback haptic visual.

## 📁 Struktur Proyek

```text
lib/
├── main.dart             # Entry point aplikasi
├── app.dart              # Konfigurasi widget root & tema
├── home_page.dart        # Logika utama Dashboard & navigasi
├── editor_sheet.dart     # Panel input/edit kegiatan
├── profile_sheet.dart    # Panel pengaturan identitas mahasiswa
├── storage_service.dart  # Logika persistensi data & ekspor CSV
├── models.dart           # Struktur data (Profile, Entry, Settings)
├── animations.dart       # Kumpulan widget animasi reusable
└── helpers.dart          # Utility functions (Formatting, CSV generator)
```

## 🚀 Instalasi & Pengembangan

### 1. Persiapan
Pastikan Anda sudah menginstal Flutter SDK di sistem Anda.
```bash
flutter --version
```

### 2. Kloning Repositori
```bash
git clone https://github.com/username/log_kegiatan_magang.git
cd log_kegiatan_magang
```

### 3. Instalasi Dependensi
```bash
flutter pub get
```

### 4. Menjalankan Aplikasi
```bash
# Debug mode
flutter run

# Build release APK
flutter build apk --release --no-shrink
```

## 🛡️ Lisensi
Didistribusikan di bawah Lisensi MIT. Lihat `LICENSE` untuk informasi lebih lanjut.

---
<p align="center">
  Dibuat dengan ❤️ untuk mahasiswa magang Indonesia.
</p>
