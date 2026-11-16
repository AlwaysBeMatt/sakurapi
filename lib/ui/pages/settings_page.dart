import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/tx_category.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import 'accounts_page.dart';
import 'categories_page.dart';
import 'data_page.dart';
import 'preferences_page.dart';
import 'recurring_page.dart';

Future<void> openSettings(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
}

String _themeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Tema ikut sistem',
  ThemeMode.light => 'Tema terang',
  ThemeMode.dark => 'Tema gelap',
};

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(financeSnapshotProvider).value;
    final settings = ref.watch(settingsProvider);

    var accountsInfo = 'Dompet, rekening bank, e-wallet, dan tabungan';
    var categoriesInfo = 'Kategori pemasukan dan pengeluaran';
    var recurringInfo = 'Gaji, tagihan, dan transaksi rutin lainnya';
    if (data != null) {
      final active = data.accounts.where((a) => !a.archived).length;
      final archived = data.accounts.length - active;
      accountsInfo =
          '$active akun aktif${archived > 0 ? ' · $archived diarsipkan' : ''}';
      final expense = data.categories
          .where((c) => c.kind == CategoryKind.expense)
          .length;
      final income = data.categories.length - expense;
      categoriesInfo = '$expense pengeluaran · $income pemasukan';
      final running = data.recurringRules
          .where((r) => r.active && !r.isFinished)
          .length;
      recurringInfo = running == 0 ? 'Belum ada yang aktif' : '$running aktif';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [
                _SettingsTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Akun',
                  subtitle: accountsInfo,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AccountsPage(),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                _SettingsTile(
                  icon: Icons.category_outlined,
                  title: 'Kategori',
                  subtitle: categoriesInfo,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CategoriesPage(),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                _SettingsTile(
                  icon: Icons.event_repeat_outlined,
                  title: 'Transaksi berulang',
                  subtitle: recurringInfo,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecurringPage(),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Tampilan dan anggaran',
                  subtitle:
                      '${_themeLabel(settings.themeMode)} · '
                      'peringatan ${settings.cautionPercent}% dan ${settings.warningPercent}%',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PreferencesPage(),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                _SettingsTile(
                  icon: Icons.storage_outlined,
                  title: 'Data dan backup',
                  subtitle: 'Backup JSON, ekspor CSV, dan data demo',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const DataPage()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}