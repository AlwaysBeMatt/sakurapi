import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/section_label.dart';

class PreferencesPage extends ConsumerStatefulWidget {
  const PreferencesPage({super.key});

  @override
  ConsumerState<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends ConsumerState<PreferencesPage> {
  late double _caution;
  late double _warning;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _caution = s.cautionPercent.toDouble().clamp(50.0, 90.0);
    _warning = s.warningPercent.toDouble().clamp(55.0, 95.0);
    if (_warning <= _caution) {
      _warning = _caution + 5;
    }
  }

  void _persist() {
    ref
        .read(settingsProvider.notifier)
        .setThresholds(caution: _caution.round(), warning: _warning.round());
  }

  void _reset() {
    setState(() {
      _caution = AppSettings.defaultCaution.toDouble();
      _warning = AppSettings.defaultWarning.toDouble();
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Tampilan dan anggaran')),
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
                      Text('Tema', style: theme.textTheme.titleMedium),
                      const SizedBox(height: Space.md),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('Sistem'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Terang'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Gelap'),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (s) => notifier.setThemeMode(s.first),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        '"Sistem" mengikuti pengaturan tema HP Anda.',
                        style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ambang status anggaran',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        'Status anggaran berubah saat pengeluaran mencapai '
                        'persentase ini dari batasnya.',
                        style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                      ),
                      const SizedBox(height: Space.lg),
                      SectionLabel('Perhatian mulai ${_caution.round()}%'),
                      Slider(
                        value: _caution,
                        min: 50,
                        max: 90,
                        divisions: 8,
                        label: '${_caution.round()}%',
                        onChanged: (v) => setState(() {
                          _caution = v;
                          if (_warning <= _caution) {
                            _warning = _caution + 5;
                          }
                        }),
                        onChangeEnd: (_) => _persist(),
                      ),
                      SectionLabel('Hampir habis mulai ${_warning.round()}%'),
                      Slider(
                        value: _warning,
                        min: 55,
                        max: 95,
                        divisions: 8,
                        label: '${_warning.round()}%',
                        onChanged: (v) => setState(() {
                          _warning = v;
                          if (_caution >= _warning) {
                            _caution = _warning - 5;
                          }
                        }),
                        onChangeEnd: (_) => _persist(),
                      ),
                      Text(
                        'Terlampaui saat pengeluaran melebihi 100% dari batas.',
                        style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                      ),
                      const SizedBox(height: Space.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _reset,
                          child: const Text('Kembalikan ke 75% dan 90%'),
                        ),
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