import 'package:sqflite/sqflite.dart';

import '../core/dates.dart';
import '../domain/errors.dart';
import '../domain/models/account.dart';
import '../domain/models/budget.dart';
import '../domain/models/money_transaction.dart';
import '../domain/models/savings_goal.dart';

/// Data contoh untuk mencoba aplikasi. Semua ID diawali "demo_", jadi mudah
/// dibedakan dan dihapus tanpa menyentuh data asli.
abstract final class DemoData {
  static const prefix = 'demo_';
  static const bankId = 'demo_acc_bank';
  static const savingsId = 'demo_acc_sav';
  static const goalId = 'demo_goal_laptop';

  static bool isDemoId(String id) => id.startsWith(prefix);

  // (hari, jenis, nominal, kategori, judul), berulang tiap bulan.
  static const _monthly = <(int, TransactionType, int, String, String)>[
    (1, TransactionType.income, 4000000, 'inc_salary', 'Gaji bulanan'),
    (3, TransactionType.expense, 45000, 'exp_food', 'Makan siang'),
    (5, TransactionType.expense, 30000, 'exp_transport', 'Ojek online'),
    (8, TransactionType.expense, 62000, 'exp_food', 'Makan malam'),
    (10, TransactionType.expense, 350000, 'exp_bills', 'Listrik dan internet'),
    (12, TransactionType.expense, 25000, 'exp_transport', 'Bensin'),
    (14, TransactionType.expense, 38000, 'exp_food', 'Kopi dan roti'),
    (16, TransactionType.expense, 120000, 'exp_fun', 'Nonton bioskop'),
    (19, TransactionType.expense, 40000, 'exp_transport', 'Parkir dan tol'),
    (21, TransactionType.expense, 75000, 'exp_food', 'Makan bersama'),
    (22, TransactionType.expense, 210000, 'exp_shopping', 'Belanja bulanan'),
  ];

  /// Tiga bulan terakhir sampai [today], hanya pada akun dan target demo.
  static Future<void> load(Database db, DateTime today) async {
    final now = dateOnly(today);
    var seq = 0;
    String nextId() => 'demo_tx_${++seq}';

    try {
      await db.transaction((txn) async {
        final exists =
            Sqflite.firstIntValue(
              await txn.rawQuery('SELECT COUNT(*) FROM accounts WHERE id = ?', [
                bankId,
              ]),
            ) ??
            0;
        if (exists > 0) {
          throw const ValidationException('Data demo sudah dimuat.');
        }

        await txn.insert(
          'accounts',
          Account(
            id: bankId,
            name: 'Rekening Demo',
            type: AccountType.bank,
            initialBalance: 1500000,
            createdAt: today,
          ).toMap(),
        );
        await txn.insert(
          'accounts',
          Account(
            id: savingsId,
            name: 'Tabungan Demo',
            type: AccountType.savings,
            createdAt: today,
          ).toMap(),
        );
        await txn.insert(
          'savings_goals',
          SavingsGoal(
            id: goalId,
            name: 'Laptop baru (demo)',
            targetAmount: 6000000,
            initialAmount: 1500000,
            targetDate: dateOnly(DateTime(now.year, now.month + 9, now.day)),
            accountId: savingsId,
            createdAt: today,
          ).toMap(),
        );

        for (var back = 2; back >= 0; back--) {
          final first = DateTime(now.year, now.month - back, 1);

          for (final (day, type, amount, category, title) in _monthly) {
            final date = DateTime(first.year, first.month, day);
            if (date.isAfter(now)) {
              continue;
            }
            await txn.insert(
              'transactions',
              MoneyTransaction(
                id: nextId(),
                type: type,
                amount: amount,
                title: title,
                categoryId: category,
                accountId: bankId,
                date: date,
                createdAt: today,
                updatedAt: today,
              ).toMap(),
            );
          }

          final depositDate = DateTime(first.year, first.month, 2);
          if (!depositDate.isAfter(now)) {
            await txn.insert(
              'transactions',
              MoneyTransaction(
                id: nextId(),
                type: TransactionType.transfer,
                amount: 500000,
                title: 'Setor: Laptop baru (demo)',
                accountId: bankId,
                toAccountId: savingsId,
                goalId: goalId,
                goalFlow: GoalFlow.deposit,
                date: depositDate,
                createdAt: today,
                updatedAt: today,
              ).toMap(),
            );
          }
        }

        // Anggaran demo hanya dibuat untuk kategori yang belum punya anggaran.
        for (final (id, category, limit) in const [
          ('demo_budget_food', 'exp_food', 600000),
          ('demo_budget_transport', 'exp_transport', 250000),
        ]) {
          final has =
              Sqflite.firstIntValue(
                await txn.rawQuery(
                  'SELECT COUNT(*) FROM budgets WHERE category_id = ?',
                  [category],
                ),
              ) ??
              0;
          if (has == 0) {
            await txn.insert(
              'budgets',
              Budget(
                id: id,
                categoryId: category,
                limitAmount: limit,
                createdAt: today,
              ).toMap(),
            );
          }
        }
      });
    } on DatabaseException {
      throw const ValidationException(
        'Data demo gagal dimuat karena kategori bawaan tidak lengkap.',
      );
    }
  }

  /// Menghapus semua data demo, termasuk transaksi apa pun yang memakai akun
  /// atau target demo.
  static Future<void> remove(Database db) async {
    await db.transaction((txn) async {
      await txn.delete(
        'transactions',
        where:
            r"id LIKE ? ESCAPE '\' OR account_id IN (?, ?) "
            'OR to_account_id IN (?, ?) OR goal_id = ?',
        whereArgs: [r'demo\_tx\_%', bankId, savingsId, bankId, savingsId, goalId],
      );
      await txn.delete(
        'budgets',
        where: r"id LIKE ? ESCAPE '\'",
        whereArgs: [r'demo\_budget\_%'],
      );
      await txn.delete('savings_goals', where: 'id = ?', whereArgs: [goalId]);
      await txn.delete(
        'accounts',
        where: 'id IN (?, ?)',
        whereArgs: [bankId, savingsId],
      );
    });
  }
}