# 💰 Financier

Aplikasi pencatatan keuangan modern, powerful, dan cepat. Tersedia untuk **Android** dan **Web**.

## 📥 Download APK

[![Download APK](https://img.shields.io/badge/Download-APK-brightgreen?style=for-the-badge&logo=android)](https://github.com/Ferdi-89/economic/releases/latest/download/app-release.apk)

> Klik badge di atas untuk download APK terbaru, atau kunjungi halaman [**Releases**](https://github.com/Ferdi-89/economic/releases) untuk melihat semua versi.

## ✨ Fitur

| Fitur | Status |
|-------|--------|
| ✅ Auth (Email + Google) | Aktif |
| ✅ Multi Rekening (Cash, Bank, E-Wallet) | Aktif |
| ✅ Kategori Pemasukan & Pengeluaran | Aktif |
| ✅ Transaksi + Catatan | Aktif |
| ✅ Transfer antar rekening | Aktif |
| ✅ Budget Bulanan + Progress Bar | Aktif |
| ✅ Laporan Grafik (Fl Chart) | Aktif |
| ✅ Dashboard Ringkasan | Aktif |
| ✅ Dark Mode / Light Mode | Aktif |
| ✅ PWA (Web) | Aktif |
| 🔄 Sinkronisasi Supabase Realtime | Aktif |
| 🔄 Offline-first (Hive) | Aktif |
| 📱 Android | Aktif |
| 🌐 Web | Aktif |

## 🏗️ Tech Stack

- **Flutter** — UI framework (Material 3)
- **Riverpod** — State management
- **GoRouter** — Navigation
- **Supabase** — Auth, Database (PostgreSQL), Realtime
- **Hive** — Local cache (offline-first)
- **Fl Chart** — Visualisasi grafik

## 🚀 Cara Memulai

### 1. Clone & Install

```bash
# Clone repo
git clone https://github.com/your-username/financier.git
cd financier

# Install dependencies
flutter pub get
```

### 2. Setup Supabase

1. Buat project di [supabase.com](https://supabase.com)
2. Jalankan migration:
   ```
   Buka Supabase SQL Editor → copy paste `supabase/migrations/00001_initial_schema.sql`
   ```
3. Copy `.env.example` ke `.env` dan isi kredensial

### 3. Jalankan

```bash
# Android
flutter run

# Web
flutter run -d chrome

# Build APK
flutter build apk --release

# Build Web
flutter build web
```

## 📱 Environment Variables

| Variable | Deskripsi |
|----------|-----------|
| `SUPABASE_URL` | URL project Supabase |
| `SUPABASE_ANON_KEY` | Anon key Supabase |

Set saat build:
```bash
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx
```

## 🗂️ Project Structure

```
financier/
├── lib/
│   ├── config/           # App config, env, supabase
│   ├── core/             # Theme, extensions, utils
│   ├── data/
│   │   ├── models/       # Freezed models (Account, Transaction, etc.)
│   │   ├── repositories/ # Auth, Transaction, Account, Category, Budget
│   │   └── datasources/  # Hive local storage
│   ├── domain/
│   │   ├── entities/     # Domain objects
│   │   └── usecases/     # Business logic
│   └── presentation/
│       ├── router/       # GoRouter config
│       ├── screens/      # Dashboard, Transaksi, Akun, Budget, Laporan, Settings
│       └── widgets/      # Shared widgets
├── supabase/migrations/  # Database schema SQL
├── web/                  # PWA config
└── android/              # Android config
```

## 📸 Screenshots

*(Coming soon)*

## 📄 Lisensi

MIT
