# SakuRapi

Aplikasi pencatatan keuangan pribadi berbasis **Flutter** untuk membantu mencatat arus kas harian, mengelola berbagai akun/dompet, memantau anggaran bulanan, menabung untuk target tertentu, serta mengotomatiskan transaksi berulang secara offline.

---

## Fitur Utama

* **Manajemen Multi-Akun & Saldo Real-Time**
  Pantau saldo per akun (Tunai, Rekening Bank, E-Wallet) maupun total saldo keseluruhan secara otomatis berdasarkan riwayat transaksi.
* **Pencatatan Transaksi & Kategori**
  Catat pemasukan dan pengeluaran dengan pengelompokan kategori yang rapi serta dukungan format lokal Indonesia (`id_ID`).
* **Transaksi Berulang Otomatis (*Recurring Rules*)**
  Atur jadwal transaksi rutin (seperti tagihan bulanan, langganan, atau gaji) yang otomatis dicatat saat aplikasi dibuka setelah melewati tanggal jatuh tempo.
* **Anggaran Bulanan (*Budgets*)**
  Tetapkan batas pengeluaran bulanan per kategori dan pantau status pemakaiannya berdasarkan bulan yang dipilih.
* **Target Tabungan (*Savings Goals*)**
  Buat dan pantau progres target tabungan untuk kebutuhan masa depan.
* **Penyimpanan Lokal & Offline-First**
  Seluruh data keuangan tersimpan langsung di perangkat menggunakan database lokal, lengkap dengan pengaturan ringan (tema aplikasi dan ambang batas peringatan anggaran) melalui `SharedPreferences`.

---

## Arsitektur & Tech Stack

* **Framework:** Flutter (Dart)
* **State Management:** Flutter Riverpod (`Provider`, `FutureProvider`, `NotifierProvider`)
* **Local Storage:** SQLite / AppDatabase & `SharedPreferences`
* **Lokalisasi & Format:** `intl` (`id_ID`)

### Struktur Direktori Utama

```text
lib/
├── core/                 # Utilitas inti & manajemen tanggal (MonthRef, dll.)
├── data/                 # Akses database lokal, repository, & penyimpanan pengaturan
│   ├── app_database.dart
│   ├── finance_repository.dart
│   └── prefs_settings_store.dart
├── domain/               # Logika bisnis, kalkulator keuangan, & model data
│   ├── finance_calculator.dart
│   └── models/
│       ├── account.dart
│       ├── budget.dart
│       ├── money_transaction.dart
│       ├── recurring_rule.dart
│       ├── savings_goal.dart
│       └── tx_category.dart
├── state/                # Riverpod providers & state pengaturan aplikasi
│   ├── providers.dart
│   └── settings.dart
├── ui/                   # Komponen antarmuka & tema aplikasi
│   ├── theme/
│   └── widgets/
├── app.dart              # Konfigurasi root widget SakuRapiApp
└── main.dart             # Entry point aplikasi & inisialisasi database
