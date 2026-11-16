import 'package:flutter_test/flutter_test.dart';
import 'package:sakurapi/core/dates.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/period_report.dart';

final _t0 = DateTime(2025, 1, 1);

MoneyTransaction _tx(
  TransactionType type,
  int amount,
  DateTime date, {
  String? category,
  String? to,
}) => MoneyTransaction(
  id: '${type.name}-$amount-$date',
  type: type,
  amount: amount,
  accountId: 'cash',
  categoryId: category,
  toAccountId: to,
  date: date,
  createdAt: _t0,
  updatedAt: _t0,
);

void main() {
  group('Period', () {
    test('minggu dimulai Senin dan berakhir Minggu', () {
      final p = Period.containing(
        PeriodKind.week,
        DateTime(2025, 1, 22),
      ); // Rabu
      expect(p.start, DateTime(2025, 1, 20));
      expect(p.end, DateTime(2025, 1, 26));
      expect(p.label, '20 – 26 Jan 2025');

      final sunday = Period.containing(PeriodKind.week, DateTime(2025, 1, 26));
      expect(sunday.start, DateTime(2025, 1, 20));
    });

    test('minggu melintasi bulan dan tahun', () {
      final p = Period.containing(PeriodKind.week, DateTime(2025, 1, 1));
      expect(p.start, DateTime(2024, 12, 30));
      expect(p.end, DateTime(2025, 1, 5));
      expect(p.label, '30 Des 2024 – 5 Jan 2025');

      final q = Period.containing(PeriodKind.week, DateTime(2025, 2, 1));
      expect(q.label, '27 Jan – 2 Feb 2025');
    });

    test('bulan dan tahun, termasuk tahun kabisat', () {
      final feb = Period.containing(PeriodKind.month, DateTime(2024, 2, 10));
      expect(feb.end, DateTime(2024, 2, 29));
      expect(feb.label, 'Februari 2024');

      final year = Period.containing(PeriodKind.year, DateTime(2025, 6, 15));
      expect(year.start, DateTime(2025, 1, 1));
      expect(year.end, DateTime(2025, 12, 31));
      expect(year.label, '2025');
    });

    test('previous dan next', () {
      final week = Period.containing(PeriodKind.week, DateTime(2025, 1, 20));
      expect(week.previous.start, DateTime(2025, 1, 13));
      expect(week.next.start, DateTime(2025, 1, 27));

      final jan = Period.containing(PeriodKind.month, DateTime(2025, 1, 20));
      expect(jan.previous.label, 'Desember 2024');
      expect(jan.next.label, 'Februari 2025');

      final y = Period.containing(PeriodKind.year, DateTime(2025, 1, 20));
      expect(y.previous.label, '2024');
      expect(y.next.label, '2026');
    });

    test('contains dan referenceDate', () {
      final jan = Period.containing(PeriodKind.month, DateTime(2025, 1, 20));
      expect(jan.contains(DateTime(2025, 1, 31)), isTrue);
      expect(jan.contains(DateTime(2025, 2, 1)), isFalse);
      expect(jan.referenceDate(DateTime(2025, 1, 20)), DateTime(2025, 1, 20));
      expect(jan.referenceDate(DateTime(2025, 3, 5)), DateTime(2025, 1, 31));
      expect(jan.referenceDate(DateTime(2024, 11, 5)), DateTime(2025, 1, 1));
    });
  });

  group('PeriodReport.buckets', () {
    final txs = [
      _tx(
        TransactionType.income,
        3000000,
        DateTime(2025, 1, 1),
        category: 'inc_salary',
      ),
      _tx(
        TransactionType.expense,
        250000,
        DateTime(2025, 1, 5),
        category: 'exp_food',
      ),
      _tx(TransactionType.transfer, 500000, DateTime(2025, 1, 10), to: 'sav'),
    ];

    test('minggu: 7 kolom per hari', () {
      final p = Period.containing(PeriodKind.week, DateTime(2025, 1, 1));
      final b = PeriodReport.buckets(txs, p);
      expect(b.map((e) => e.label), [
        'Sen',
        'Sel',
        'Rab',
        'Kam',
        'Jum',
        'Sab',
        'Min',
      ]);
      expect(b[2].income, 3000000); // Rabu 1 Jan
      expect(b[6].expense, 250000); // Minggu 5 Jan
      expect(b[0].income + b[0].expense, 0);
    });

    test('bulan: kelompok 7 hari dan transfer tidak dihitung', () {
      final p = Period.containing(PeriodKind.month, DateTime(2025, 1, 15));
      final b = PeriodReport.buckets(txs, p);
      expect(b.map((e) => e.label), ['1–7', '8–14', '15–21', '22–28', '29–31']);
      expect(b[0].income, 3000000);
      expect(b[0].expense, 250000);
      expect(b[1].income + b[1].expense, 0); // transfer 10 Jan diabaikan
    });

    test('tahun: 12 kolom per bulan', () {
      final p = Period.containing(PeriodKind.year, DateTime(2025, 6, 1));
      final b = PeriodReport.buckets(txs, p);
      expect(b, hasLength(12));
      expect(b.first.label, 'Jan');
      expect(b.first.income, 3000000);
      expect(b.first.expense, 250000);
      expect(b.last.label, 'Des');
      expect(b.last.peak, 0);
    });

    test('Februari kabisat: kelompok terakhir 29', () {
      final p = Period.containing(PeriodKind.month, DateTime(2024, 2, 1));
      final b = PeriodReport.buckets(const [], p);
      expect(b.last.label, '29–29');
    });
  });
}
