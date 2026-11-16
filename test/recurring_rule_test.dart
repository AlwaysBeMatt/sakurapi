import 'package:flutter_test/flutter_test.dart';
import 'package:sakurapi/core/dates.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/recurring_rule.dart';

final _t0 = DateTime(2025, 1, 1);

RecurringRule _rule({
  RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
  required DateTime start,
  DateTime? end,
  TransactionType type = TransactionType.income,
  int amount = 4000000,
}) => RecurringRule(
  id: 'r1',
  type: type,
  amount: amount,
  categoryId: 'inc_salary',
  accountId: 'acc_cash',
  frequency: frequency,
  startDate: start,
  nextDate: start,
  endDate: end,
  createdAt: _t0,
);

List<DateTime> _next(RecurringRule rule, int count) {
  final out = <DateTime>[];
  var r = rule;
  for (var i = 0; i < count; i++) {
    r = r.advance();
    out.add(r.nextDate);
  }
  return out;
}

void main() {
  final today = DateTime(2025, 1, 20);

  group('tanggal berikutnya', () {
    test('mingguan melintasi akhir bulan', () {
      final r = _rule(frequency: RecurrenceFrequency.weekly, start: DateTime(2025, 1, 27));
      expect(_next(r, 2), [DateTime(2025, 2, 3), DateTime(2025, 2, 10)]);
    });

    test('bulanan tanggal 31 jatuh di akhir bulan lalu kembali ke 31', () {
      final r = _rule(start: DateTime(2025, 1, 31));
      expect(_next(r, 4), [
        DateTime(2025, 2, 28),
        DateTime(2025, 3, 31),
        DateTime(2025, 4, 30),
        DateTime(2025, 5, 31),
      ]);
    });

    test('bulanan tahun kabisat', () {
      final r = _rule(start: DateTime(2024, 1, 31));
      expect(_next(r, 1), [DateTime(2024, 2, 29)]);
    });

    test('bulanan melewati pergantian tahun', () {
      final r = _rule(start: DateTime(2025, 12, 15));
      expect(_next(r, 2), [DateTime(2026, 1, 15), DateTime(2026, 2, 15)]);
    });

    test('tahunan 29 Februari', () {
      final r = _rule(frequency: RecurrenceFrequency.yearly, start: DateTime(2024, 2, 29));
      expect(_next(r, 4), [
        DateTime(2025, 2, 28),
        DateTime(2026, 2, 28),
        DateTime(2027, 2, 28),
        DateTime(2028, 2, 29),
      ]);
    });
  });

  test('isFinished: setelah tanggal berakhir', () {
    final r = _rule(start: DateTime(2025, 1, 5), end: DateTime(2025, 2, 10));
    expect(r.isFinished, isFalse);
    expect(r.advance().isFinished, isFalse); // 5 Feb
    expect(r.advance().advance().isFinished, isTrue); // 5 Mar
    expect(_rule(start: DateTime(2025, 1, 5)).advance().isFinished, isFalse);
  });

  test('skipTo melewati kemunculan yang sudah lewat', () {
    final r = _rule(start: DateTime(2025, 1, 5));
    expect(r.skipTo(DateTime(2025, 3, 25)).nextDate, DateTime(2025, 4, 5));
    expect(r.skipTo(DateTime(2025, 1, 5)).nextDate, DateTime(2025, 1, 5));
    expect(r.skipTo(DateTime(2024, 12, 1)).nextDate, DateTime(2025, 1, 5));
  });

  group('validate', () {
    test('aturan yang benar', () {
      expect(_rule(start: today).validate(today: today), isNull);
    });

    test('transfer ditolak', () {
      expect(
        _rule(start: today, type: TransactionType.transfer).validate(today: today),
        isNotNull,
      );
    });

    test('nominal nol ditolak', () {
      expect(_rule(start: today, amount: 0).validate(today: today), contains('Rp0'));
    });

    test('tanggal berakhir sebelum mulai ditolak', () {
      final r = _rule(start: today, end: DateTime(2025, 1, 1));
      expect(r.validate(today: today), contains('berakhir'));
    });

    test('mulai terlalu lama atau terlalu jauh hanya dibatasi saat membuat', () {
      final old = _rule(start: DateTime(2023, 1, 1));
      expect(old.validate(today: today), contains('13 bulan'));
      expect(old.validate(today: today, isNew: false), isNull);

      final far = _rule(start: DateTime(2027, 1, 1));
      expect(far.validate(today: today), contains('satu tahun'));
    });
  });

  test('toMap dan fromMap bolak-balik', () {
    final r = RecurringRule(
      id: 'abc',
      type: TransactionType.expense,
      amount: 350000,
      title: 'Listrik',
      categoryId: 'exp_bills',
      accountId: 'acc_cash',
      frequency: RecurrenceFrequency.monthly,
      startDate: DateTime(2025, 1, 10),
      nextDate: DateTime(2025, 2, 10),
      endDate: DateTime(2025, 12, 10),
      note: 'PLN',
      active: false,
      createdAt: _t0,
    );
    final copy = RecurringRule.fromMap(r.toMap());
    expect(copy.toMap(), r.toMap());
    expect(copy.active, isFalse);
    expect(copy.endDate, DateTime(2025, 12, 10));
    expect(copy.nextDate, DateTime(2025, 2, 10));
  });
}