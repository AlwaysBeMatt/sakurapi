import 'package:flutter_test/flutter_test.dart';
import 'package:sakurapi/domain/account_rules.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/savings_goal.dart';

final _t0 = DateTime(2025, 1, 1);

Account _acc(String id, String name, {bool archived = false}) => Account(
  id: id,
  name: name,
  type: AccountType.cash,
  createdAt: _t0,
  archived: archived,
);

SavingsGoal _goal(String accountId) => SavingsGoal(
  id: 'g1',
  name: 'Laptop',
  targetAmount: 1000000,
  accountId: accountId,
  createdAt: _t0,
);

void main() {
  final a = _acc('a', 'Dompet');
  final b = _acc('b', 'BCA');

  group('archiveBlocker', () {
    test('akun aktif terakhir tidak boleh diarsipkan', () {
      final result = AccountRules.archiveBlocker(
        account: a,
        all: [a],
        balances: {'a': 0},
        goals: const [],
      );
      expect(result, 'Minimal harus ada satu akun aktif.');
    });

    test(
      'akun yang sudah diarsipkan tidak dihitung sebagai akun aktif lain',
      () {
        final result = AccountRules.archiveBlocker(
          account: a,
          all: [a, _acc('b', 'BCA', archived: true)],
          balances: {'a': 0, 'b': 0},
          goals: const [],
        );
        expect(result, isNotNull);
      },
    );

    test('saldo tidak nol menghalangi, termasuk saldo minus', () {
      for (final balance in [500000, -1000]) {
        final result = AccountRules.archiveBlocker(
          account: a,
          all: [a, b],
          balances: {'a': balance, 'b': 0},
          goals: const [],
        );
        expect(result, contains('Rp0'));
      }
    });

    test('akun penyimpan target tabungan tidak boleh diarsipkan', () {
      final result = AccountRules.archiveBlocker(
        account: a,
        all: [a, b],
        balances: {'a': 0, 'b': 0},
        goals: [_goal('a')],
      );
      expect(result, contains('Laptop'));
    });

    test('boleh diarsipkan bila semua syarat terpenuhi', () {
      final result = AccountRules.archiveBlocker(
        account: a,
        all: [a, b],
        balances: {'a': 0, 'b': 100},
        goals: [_goal('b')],
      );
      expect(result, isNull);
    });
  });

  test('deleteBlocker: akun terakhir tidak bisa dihapus', () {
    expect(AccountRules.deleteBlocker(account: a, all: [a]), isNotNull);
    expect(AccountRules.deleteBlocker(account: a, all: [a, b]), isNull);
  });

  test(
    'nameTaken: tanpa membedakan huruf, dan bisa mengecualikan diri sendiri',
    () {
      expect(AccountRules.nameTaken('bca', [a, b]), isTrue);
      expect(AccountRules.nameTaken('  BCA  ', [a, b]), isTrue);
      expect(AccountRules.nameTaken('BCA', [a, b], exceptId: 'b'), isFalse);
      expect(AccountRules.nameTaken('Mandiri', [a, b]), isFalse);
    },
  );
}
