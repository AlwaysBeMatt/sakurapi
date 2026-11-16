import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../data/backup_codec.dart';
import '../../data/demo_data.dart';
import '../../domain/csv_export.dart';
import '../../domain/errors.dart';
import '../../state/file_service.dart';
import '../../state/providers.dart';
import '../../state/tx_filter.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/confirm_dialog.dart';

class DataPage extends ConsumerStatefulWidget {
  const DataPage({super.key});

  @override
  ConsumerState<DataPage> createState() => _DataPageState();
}

class _DataPageState extends ConsumerState<DataPage> {
  bool _busy = false;
  String _delimiter = ';';

  String get _today => toDbDate(dateOnly(ref.read(clockProvider)()));

  /// Menjalankan [action] dengan penanda sibuk dan pesan galat yang ramah.
  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on ValidationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on FormatException {
      messenger.showSnackBar(
        const SnackBar(content: Text('File tidak bisa dibaca sebagai teks.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan. Coba lagi.')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _say(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _backup() => _guard(() async {
    final json = await ref.read(financeRepositoryProvider).exportBackup();
    final saved = await ref.read(fileServiceProvider).saveText(
      fileName: 'sakurapi-backup-$_today.json',
      content: json,
      dialogTitle: 'Simpan backup SakuRapi',
    );
    if (!mounted) {
      return;
    }
    _say(saved ? 'Backup disimpan' : 'Dibatalkan. Tidak ada file yang dibuat.');
  });

  Future<void> _restore() => _guard(() async {
    final text = await ref.read(fileServiceProvider).pickText();
    if (!mounted) {
      return;
    }
    if (text == null) {
      _say('Pemulihan dibatalkan.');
      return;
    }
    final summary = BackupCodec.inspect(text, today: ref.read(clockProvider)());
    final ok = await confirmDialog(
      context,
      title: 'Ganti seluruh data?',
      message:
          'File ini berisi ${summary.description}.\n\n'
          'Semua data di aplikasi sekarang akan diganti. Simpan backup dulu '
          'bila perlu. Tindakan ini tidak bisa dibatalkan.',
      confirmLabel: 'Pulihkan',
    );
    if (!ok || !mounted) {
      if (mounted) {
        _say('Pemulihan dibatalkan.');
      }
      return;
    }
    final result = await ref.read(financeRepositoryProvider).restoreBackup(text);
    if (mounted) {
      _say('Data dipulihkan: ${result.description}.');
    }
  });

  Future<void> _exportCsv(FinanceSnapshot data) => _guard(() async {
    if (data.transactions.isEmpty) {
      _say('Belum ada transaksi untuk diekspor.');
      return;
    }
    final txs = const TxFilter().apply(data.transactions);
    final csv = CsvExport.transactions(
      txs,
      accounts: data.accountById,
      categories: data.categoryById,
      delimiter: _delimiter,
    );
    final saved = await ref.read(fileServiceProvider).saveText(
      fileName: 'sakurapi-transaksi-$_today.csv',
      // BOM supaya Excel membaca file sebagai UTF-8.
      content: '\uFEFF$csv',
      dialogTitle: 'Simpan ekspor transaksi',
    );
    if (!mounted) {
      return;
    }
    _say(
      saved
          ? 'CSV disimpan (${txs.length} transaksi)'
          : 'Dibatalkan. Tidak ada file yang dibuat.',
    );
  });

  Future<void> _loadDemo() => _guard(() async {
    final ok = await confirmDialog(
      context,
      title: 'Muat data demo?',
      message:
          'Akun, transaksi 3 bulan, anggaran, dan target tabungan contoh akan '
          'ditambahkan. Data demo ikut tampil di total saldo dan statistik '
          'sampai dihapus. Data Anda sendiri tidak diubah.',
      confirmLabel: 'Muat',
    );
    if (!ok || !mounted) {
      return;
    }
    await ref.read(financeRepositoryProvider).loadDemoData();
    if (mounted) {
      _say('Data demo dimuat');
    }
  });

  Future<void> _removeDemo() => _guard(() async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus data demo?',
      message:
          'Semua data demo dihapus. Transaksi Anda yang memakai akun atau '
          'target demo ikut terhapus. Data Anda yang lain tidak diubah.',
    );
    if (!ok || !mounted) {
      return;
    }
    await ref.read(financeRepositoryProvider).removeDemoData();
    if (mounted) {
      _say('Data demo dihapus');
    }
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final data = ref.watch(financeSnapshotProvider).value;
    final hasDemo =
        data != null && data.accounts.any((a) => DemoData.isDemoId(a.id));

    Widget body(String text) => Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(color: secondary),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Data dan backup')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Backup', style: theme.textTheme.titleMedium),
                      const SizedBox(height: Space.xs),
                      body(
                        'Simpan seluruh data ke satu file JSON. Anda memilih '
                        'lokasinya, misalnya Downloads atau Google Drive.',
                      ),
                      const SizedBox(height: Space.lg),
                      FilledButton.icon(
                        onPressed: _busy ? null : _backup,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Simpan backup'),
                      ),
                      const SizedBox(height: Space.sm),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _restore,
                        icon: const Icon(Icons.restore),
                        label: const Text('Pulihkan dari backup'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Ekspor CSV', style: theme.textTheme.titleMedium),
                      const SizedBox(height: Space.xs),
                      body('Semua transaksi, siap dibuka di Excel atau Google Sheets.'),
                      const SizedBox(height: Space.lg),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ';',
                            label: Text('Titik koma (;)'),
                          ),
                          ButtonSegment(value: ',', label: Text('Koma (,)')),
                        ],
                        selected: {_delimiter},
                        onSelectionChanged: (s) =>
                            setState(() => _delimiter = s.first),
                      ),
                      const SizedBox(height: Space.xs),
                      body('Titik koma cocok untuk Excel versi Indonesia.'),
                      const SizedBox(height: Space.lg),
                      OutlinedButton.icon(
                        onPressed: (_busy || data == null)
                            ? null
                            : () => _exportCsv(data),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Ekspor transaksi (CSV)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Data demo', style: theme.textTheme.titleMedium),
                      const SizedBox(height: Space.xs),
                      body(
                        hasDemo
                            ? 'Data demo sedang aktif dan ikut tampil di total saldo serta statistik.'
                            : 'Isi aplikasi dengan data contoh untuk mencoba fitur. '
                                  'Bisa dihapus kapan saja.',
                      ),
                      const SizedBox(height: Space.lg),
                      if (hasDemo)
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _removeDemo,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Hapus data demo'),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _loadDemo,
                          icon: const Icon(Icons.science_outlined),
                          label: const Text('Muat data demo'),
                        ),
                    ],
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