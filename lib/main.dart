import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/finance_repository.dart';
import 'data/prefs_settings_store.dart';
import 'state/providers.dart';
import 'state/settings.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/empty_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'id_ID';
  await initializeDateFormatting('id_ID');

  final FinanceRepository repo;
  try {
    repo = FinanceRepository(await AppDatabase.open());
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Gagal membuka database: $e');
    }
    runApp(const _StartupErrorApp());
    return;
  }

  // Mencatat transaksi berulang yang sudah jatuh tempo. Kegagalan di sini
  // tidak boleh menghalangi aplikasi terbuka.
  try {
    await repo.generateDueRecurring();
  } catch (_) {}

  // Pengaturan ringan (tema, ambang anggaran). Jika penyimpanannya gagal,
  // aplikasi tetap jalan dengan pengaturan bawaan.
  SettingsStore settingsStore;
  try {
    settingsStore = PrefsSettingsStore(await SharedPreferences.getInstance());
  } catch (_) {
    settingsStore = MemorySettingsStore();
  }

  runApp(
    ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(repo),
        settingsStoreProvider.overrideWithValue(settingsStore),
      ],
      child: const SakuRapiApp(),
    ),
  );
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'Penyimpanan gagal dibuka',
                message:
                    'SakuRapi tidak dapat membuka database lokal. Tutup aplikasi lalu buka kembali. '
                    'Jika masalah berlanjut, periksa ruang penyimpanan perangkat.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}