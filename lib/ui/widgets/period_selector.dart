import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../state/period_state.dart';
import '../../state/providers.dart';
import '../theme/tokens.dart';
import 'app_card.dart';

class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodProvider);
    final notifier = ref.read(periodProvider.notifier);
    final today = ref.watch(clockProvider)();
    final isCurrent = period.contains(today);
    final noun = period.kind.noun;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<PeriodKind>(
          showSelectedIcon: false,
          segments: [
            for (final kind in PeriodKind.values)
              ButtonSegment(value: kind, label: Text(kind.nounCapitalized)),
          ],
          selected: {period.kind},
          onSelectionChanged: (s) => notifier.setKind(s.first),
        ),
        const SizedBox(height: Space.sm),
        AppCard(
          padding: const EdgeInsets.all(Space.xs),
          child: Row(
            children: [
              IconButton(
                tooltip: '${period.kind.nounCapitalized} sebelumnya',
                onPressed: notifier.previous,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      period.label,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isCurrent)
                      TextButton(
                        onPressed: notifier.reset,
                        child: Text('Kembali ke $noun ini'),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '${period.kind.nounCapitalized} berikutnya',
                onPressed: notifier.next,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
