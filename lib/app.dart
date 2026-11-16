import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'state/settings.dart';
import 'ui/shell/app_shell.dart';
import 'ui/theme/app_theme.dart';

class SakuRapiApp extends ConsumerStatefulWidget {
  const SakuRapiApp({super.key});

  @override
  ConsumerState<SakuRapiApp> createState() => _SakuRapiAppState();
}

class _SakuRapiAppState extends ConsumerState<SakuRapiApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Saat aplikasi kembali dari latar belakang, catat transaksi berulang yang
  /// jatuh tempo selama aplikasi tidak dibuka.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _generateRecurring();
    }
  }

  Future<void> _generateRecurring() async {
    try {
      await ref.read(financeRepositoryProvider).generateDueRecurring();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'SakuRapi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AppShell(),
    );
  }
}