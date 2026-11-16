
import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'backup_codec.dart';
import 'demo_data.dart';

import '../core/dates.dart';
import '../domain/errors.dart';
import '../domain/models/account.dart';
import '../domain/models/budget.dart';
import '../domain/models/money_transaction.dart';
import '../domain/models/recurring_rule.dart';
import '../domain/models/savings_goal.dart';
import '../domain/models/tx_category.dart';

enum TransactionSort { newest, oldest, largest, smallest }

class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.types = const {},
    this.categoryIds = const {},
    this.accountId,
    this.from,
    this.to,
    this.sort = TransactionSort.newest,
  });

  final String query;
  final Set<TransactionType> types;
  final Set<String> categoryIds;
  final String? accountId;
  final DateTime? from;
  final DateTime? to;
  final TransactionSort sort;
}

class FinanceRepository {
  FinanceRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Database _db;
  final DateTime Function() _clock;
  final _uuid = const Uuid();
  final _changes = StreamController<void>.broadcast();

  /// Dipancarkan setiap kali data berubah, supaya UI memuat ulang.
  Stream<void> get changes => _changes.stream;

  Future<void> close() async {
    await _changes.close();
    await _db.close();
  }

  // ---------- Akun ----------

  Future<List<Account>> getAccounts({bool includeArchived = true}) async {
    final rows = await _db.query(
      'accounts',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'rowid',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<Account> createAccount({
    required String name,
    required AccountType type,
    int initialBalance = 0,
  }) async {
    final account = Account(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      initialBalance: initialBalance,
      createdAt: _clock(),
    );
    _check(account.validate());
    await _db.insert('accounts', account.toMap());
    _notify();
    return account;
  }

  Future<void> updateAccount(Account account) async {
    _check(account.validate());
    final n = await _db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
    if (n == 0) throw const ValidationException('Akun tidak ditemukan.');
    _notify();
  }

  Future<void> deleteAccount(String id) async {
    await _db.transaction((txn) async {
      final used = await _count(
        txn,
        'SELECT COUNT(*) FROM transactions WHERE account_id = ? OR to_account_id = ?',
        [id, id],
      );
      if (used > 0) {
        throw ValidationException(
          'Akun ini dipakai oleh $used transaksi. Arsipkan akun sebagai gantinya.',
        );
      }
      final goals = await _count(
        txn,
        'SELECT COUNT(*) FROM savings_goals WHERE account_id = ?',
        [id],
      );
      if (goals > 0) {
        throw const ValidationException(
          'Akun ini masih dipakai oleh tujuan tabungan.',
        );
      }
      await txn.delete('accounts', where: 'id = ?', whereArgs: [id]);
    });
    _notify();
  }

  // ---------- Kategori ----------

  Future<List<TxCategory>> getCategories({CategoryKind? kind}) async {
    final rows = await _db.query(
      'categories',
      where: kind == null ? null : 'kind = ?',
      whereArgs: kind == null ? null : [kind.name],
      orderBy: 'is_default DESC, rowid',
    );
    return rows.map(TxCategory.fromMap).toList();
  }

  Future<TxCategory> createCategory({
    required String name,
    required CategoryKind kind,
    String iconKey = 'more',
    int color = 0xFF8A9690,
  }) async {
    final category = TxCategory(
      id: _uuid.v4(),
      name: name.trim(),
      kind: kind,
      iconKey: iconKey,
      color: color,
    );
    _check(category.validate());
    await _guardUnique(() => _db.insert('categories', category.toMap()));
    _notify();
    return category;
  }

  /// Hanya nama, ikon, dan warna yang bisa diubah. Jenis kategori tetap.
  Future<void> updateCategory(TxCategory category) async {
    _check(category.validate());
    final n = await _guardUnique(
      () => _db.update(
        'categories',
        {
          'name': category.name.trim(),
          'icon': category.iconKey,
          'color': category.color,
        },
        where: 'id = ?',
        whereArgs: [category.id],
      ),
    );
    if (n == 0) throw const ValidationException('Kategori tidak ditemukan.');
    _notify();
  }

  Future<void> deleteCategory(String id) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'categories',
        columns: ['is_default'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return;
      if (rows.first['is_default'] == 1) {
        throw const ValidationException('Kategori bawaan tidak bisa dihapus.');
      }
      final used = await _count(
        txn,
        'SELECT COUNT(*) FROM transactions WHERE category_id = ?',
        [id],
      );
      if (used > 0) {
        throw ValidationException('Kategori ini dipakai oleh $used transaksi.');
      }
      await txn.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      ); // anggaran ikut terhapus
    });
    _notify();
  }

  // ---------- Transaksi ----------

  static const _orderBy = {
    TransactionSort.newest: 'date DESC, created_at DESC',
    TransactionSort.oldest: 'date ASC, created_at ASC',
    TransactionSort.largest: 'amount DESC, date DESC',
    TransactionSort.smallest: 'amount ASC, date DESC',
  };

  Future<List<MoneyTransaction>> getTransactions([
    TransactionFilter filter = const TransactionFilter(),
  ]) async {
    final where = <String>[];
    final args = <Object?>[];
    final q = filter.query.trim();
    if (q.isNotEmpty) {
      final pattern = '%${_escapeLike(q)}%';
      where.add(
        r"(title LIKE ? ESCAPE '\' OR IFNULL(note, '') LIKE ? ESCAPE '\')",
      );
      args.addAll([pattern, pattern]);
    }
    if (filter.types.isNotEmpty) {
      where.add('type IN (${_placeholders(filter.types.length)})');
      args.addAll(filter.types.map((t) => t.name));
    }
    if (filter.categoryIds.isNotEmpty) {
      where.add('category_id IN (${_placeholders(filter.categoryIds.length)})');
      args.addAll(filter.categoryIds);
    }
    if (filter.accountId != null) {
      where.add('(account_id = ? OR to_account_id = ?)');
      args.addAll([filter.accountId, filter.accountId]);
    }
    if (filter.from != null) {
      where.add('date >= ?');
      args.add(toDbDate(filter.from!));
    }
    if (filter.to != null) {
      where.add('date <= ?');
      args.add(toDbDate(filter.to!));
    }
    final rows = await _db.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: _orderBy[filter.sort],
    );
    return rows.map(MoneyTransaction.fromMap).toList();
  }

  Future<MoneyTransaction?> getTransaction(String id) =>
      _findTransaction(_db, id);

  Future<MoneyTransaction> addTransaction(TransactionInput input) async {
    final now = _clock();
    final tx = input.build(id: _uuid.v4(), createdAt: now, updatedAt: now);
    await _db.transaction((txn) async {
      await _validateTransaction(txn, tx);
      await txn.insert('transactions', tx.toMap());
    });
    _notify();
    return tx;
  }

  /// Memperbarui baris yang sama (tidak membuat duplikat). created_at tetap.
  Future<MoneyTransaction> updateTransaction(
    String id,
    TransactionInput input,
  ) async {
    late MoneyTransaction updated;
    await _db.transaction((txn) async {
      final existing = await _findTransaction(txn, id);
      if (existing == null) {
        throw const ValidationException('Transaksi tidak ditemukan.');
      }
      updated = input.build(
        id: id,
        createdAt: existing.createdAt,
        updatedAt: _clock(),
      );
      await _validateTransaction(txn, updated, previous: existing);
      await txn.update(
        'transactions',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    _notify();
    return updated;
  }

  Future<void> deleteTransaction(String id) async {
    await _db.transaction((txn) async {
      final existing = await _findTransaction(txn, id);
      if (existing == null) return;
      if (existing.goalId != null) {
        await _ensureGoalNotNegative(
          txn,
          existing.goalId!,
          excludeTxId: id,
          extra: 0,
        );
      }
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
    _notify();
  }

  // ---------- Anggaran ----------

  Future<List<Budget>> getBudgets() async => (await _db.query(
    'budgets',
    orderBy: 'category_id IS NOT NULL, rowid',
  )).map(Budget.fromMap).toList();

  /// Membuat anggaran baru jika [id] null, atau memperbarui yang ada.
  Future<Budget> saveBudget({
    String? id,
    String? categoryId,
    required int limitAmount,
  }) async {
    late Budget budget;
    await _db.transaction((txn) async {
      if (categoryId != null) {
        final rows = await txn.query(
          'categories',
          columns: ['kind'],
          where: 'id = ?',
          whereArgs: [categoryId],
        );
        if (rows.isEmpty || rows.first['kind'] != CategoryKind.expense.name) {
          throw const ValidationException(
            'Anggaran hanya untuk kategori pengeluaran.',
          );
        }
      }
      final dup = await _count(
        txn,
        'SELECT COUNT(*) FROM budgets WHERE category_id IS ? AND id <> ?',
        [categoryId, id ?? ''],
      );
      if (dup > 0) {
        throw const ValidationException(
          'Anggaran untuk kategori ini sudah ada.',
        );
      }
      final existing = id == null
          ? null
          : (await txn.query(
              'budgets',
              where: 'id = ?',
              whereArgs: [id],
            )).map(Budget.fromMap).firstOrNull;
      budget = Budget(
        id: existing?.id ?? _uuid.v4(),
        categoryId: categoryId,
        limitAmount: limitAmount,
        createdAt: existing?.createdAt ?? _clock(),
      );
      _check(budget.validate());
      await txn.insert(
        'budgets',
        budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    _notify();
    return budget;
  }

  Future<void> deleteBudget(String id) async {
    await _db.delete('budgets', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  // ---------- Tujuan tabungan ----------

  Future<List<SavingsGoal>> getGoals() async => (await _db.query(
    'savings_goals',
    orderBy: 'rowid',
  )).map(SavingsGoal.fromMap).toList();

  Future<SavingsGoal?> getGoal(String id) => _findGoal(_db, id);

  Future<SavingsGoal> createGoal({
    required String name,
    required int targetAmount,
    required String accountId,
    int initialAmount = 0,
    DateTime? targetDate,
    String iconKey = 'savings',
    int color = 0xFF176B55,
    String? note,
  }) async {
    final goal = SavingsGoal(
      id: _uuid.v4(),
      name: name.trim(),
      targetAmount: targetAmount,
      initialAmount: initialAmount,
      targetDate: targetDate == null ? null : dateOnly(targetDate),
      iconKey: iconKey,
      color: color,
      note: note,
      accountId: accountId,
      createdAt: _clock(),
    );
    _check(goal.validate());
    await _db.transaction((txn) async {
      if (!await _exists(txn, 'accounts', accountId)) {
        throw const ValidationException('Akun tabungan tidak ditemukan.');
      }
      await txn.insert('savings_goals', goal.toMap());
    });
    _notify();
    return goal;
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    _check(goal.validate());
    await _db.transaction((txn) async {
      final old =
          await _findGoal(txn, goal.id) ??
          (throw const ValidationException('Tujuan tabungan tidak ditemukan.'));
      if (old.accountId != goal.accountId &&
          await _count(
                txn,
                'SELECT COUNT(*) FROM transactions WHERE goal_id = ?',
                [goal.id],
              ) >
              0) {
        throw const ValidationException(
          'Akun tabungan tidak bisa diganti karena tujuan ini sudah punya riwayat setoran.',
        );
      }
      if (!await _exists(txn, 'accounts', goal.accountId)) {
        throw const ValidationException('Akun tabungan tidak ditemukan.');
      }
      await txn.update(
        'savings_goals',
        goal.toMap(),
        where: 'id = ?',
        whereArgs: [goal.id],
      );
      await _ensureGoalNotNegative(txn, goal.id, excludeTxId: '', extra: 0);
    });
    _notify();
  }

  /// Menghapus tujuan. Riwayat setoran tetap ada sebagai transfer biasa,
  /// sehingga saldo akun tidak berubah.
  Future<void> deleteGoal(String id) async {
    await _db.transaction((txn) async {
      await txn.update(
        'transactions',
        {'goal_id': null, 'goal_flow': null},
        where: 'goal_id = ?',
        whereArgs: [id],
      );
      await txn.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
    });
    _notify();
  }

  Future<MoneyTransaction> depositToGoal({
    required String goalId,
    required String fromAccountId,
    required int amount,
    required DateTime date,
    String? note,
  }) async {
    final goal =
        await getGoal(goalId) ??
        (throw const ValidationException('Tujuan tabungan tidak ditemukan.'));
    return addTransaction(
      TransactionInput(
        type: TransactionType.transfer,
        amount: amount,
        title: 'Setor: ${goal.name}',
        accountId: fromAccountId,
        toAccountId: goal.accountId,
        goalId: goalId,
        goalFlow: GoalFlow.deposit,
        date: date,
        note: note,
      ),
    );
  }

  Future<MoneyTransaction> withdrawFromGoal({
    required String goalId,
    required String toAccountId,
    required int amount,
    required DateTime date,
    String? note,
  }) async {
    final goal =
        await getGoal(goalId) ??
        (throw const ValidationException('Tujuan tabungan tidak ditemukan.'));
    return addTransaction(
      TransactionInput(
        type: TransactionType.transfer,
        amount: amount,
        title: 'Tarik: ${goal.name}',
        accountId: goal.accountId,
        toAccountId: toAccountId,
        goalId: goalId,
        goalFlow: GoalFlow.withdrawal,
        date: date,
        note: note,
      ),
    );
  }

  // ---------- Transaksi berulang ----------

  Future<List<RecurringRule>> getRecurringRules() async => (await _db.query(
    'recurring_rules',
    orderBy: 'active DESC, next_date, rowid',
  )).map(RecurringRule.fromMap).toList();

  Future<RecurringRule> createRecurringRule({
    required TransactionType type,
    required int amount,
    required String categoryId,
    required String accountId,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    String title = '',
    String? note,
  }) async {
    final start = dateOnly(startDate);
    final trimmedNote = note?.trim();
    final rule = RecurringRule(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      title: title.trim(),
      categoryId: categoryId,
      accountId: accountId,
      frequency: frequency,
      startDate: start,
      nextDate: start,
      endDate: endDate == null ? null : dateOnly(endDate),
      note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
      createdAt: _clock(),
    );
    _check(rule.validate(today: _clock()));
    await _db.transaction((txn) async {
      await _checkRuleReferences(txn, rule);
      await txn.insert('recurring_rules', rule.toMap());
    });
    _notify();
    await generateDueRecurring();
    return rule;
  }

  Future<void> updateRecurringRule(RecurringRule rule) async {
    _check(rule.validate(today: _clock(), isNew: false));
    await _db.transaction((txn) async {
      final existing = await txn.query(
        'recurring_rules',
        where: 'id = ?',
        whereArgs: [rule.id],
      );
      if (existing.isEmpty) {
        throw const ValidationException('Transaksi berulang tidak ditemukan.');
      }
      await _checkRuleReferences(txn, rule);
      await txn.update(
        'recurring_rules',
        rule.toMap(),
        where: 'id = ?',
        whereArgs: [rule.id],
      );
    });
    _notify();
    if (rule.active) {
      await generateDueRecurring();
    }
  }

  /// Menghapus aturan. Transaksi yang sudah tercatat tidak ikut terhapus.
  Future<void> deleteRecurringRule(String id) async {
    await _db.delete('recurring_rules', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  /// Mencatat semua transaksi berulang yang sudah jatuh tempo sampai hari ini.
  /// Aman dipanggil berulang kali. Mengembalikan jumlah transaksi baru.
  Future<int> generateDueRecurring() async {
    final today = dateOnly(_clock());
    var created = 0;
    await _db.transaction((txn) async {
      final rows = await txn.query('recurring_rules', where: 'active = 1');
      for (final row in rows) {
        var rule = RecurringRule.fromMap(row);
        var changed = false;
        var guard = 0;
        while (!rule.nextDate.isAfter(today) &&
            !rule.isFinished &&
            guard < 400) {
          final now = _clock();
          final tx = MoneyTransaction(
            id: _uuid.v4(),
            type: rule.type,
            amount: rule.amount,
            title: rule.title,
            categoryId: rule.categoryId,
            accountId: rule.accountId,
            date: rule.nextDate,
            note: rule.note,
            createdAt: now,
            updatedAt: now,
          );
          try {
            await _validateTransaction(txn, tx);
          } on ValidationException {
            break;
          }
          await txn.insert('transactions', tx.toMap());
          rule = rule.advance();
          changed = true;
          created++;
          guard++;
        }
        if (rule.isFinished && rule.active) {
          rule = rule.copyWith(active: false);
          changed = true;
        }
        if (changed) {
          await txn.update(
            'recurring_rules',
            rule.toMap(),
            where: 'id = ?',
            whereArgs: [rule.id],
          );
        }
      }
    });
    if (created > 0) {
      _notify();
    }
    return created;
  }

  Future<void> _checkRuleReferences(
    DatabaseExecutor ex,
    RecurringRule rule,
  ) async {
    if (!await _exists(ex, 'accounts', rule.accountId)) {
      throw const ValidationException('Akun tidak ditemukan.');
    }
    final rows = await ex.query(
      'categories',
      columns: ['kind'],
      where: 'id = ?',
      whereArgs: [rule.categoryId],
    );
    if (rows.isEmpty) {
      throw const ValidationException('Kategori tidak ditemukan.');
    }
    final expected = rule.type == TransactionType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    if (rows.first['kind'] != expected.name) {
      throw const ValidationException(
        'Kategori tidak sesuai dengan jenis transaksi.',
      );
    }
  }

  // ---------- Internal ----------

  Future<void> _validateTransaction(
    DatabaseExecutor ex,
    MoneyTransaction tx, {
    MoneyTransaction? previous,
  }) async {
    _check(tx.validate(today: _clock()));
    if (!await _exists(ex, 'accounts', tx.accountId)) {
      throw const ValidationException('Akun tidak ditemukan.');
    }
    if (tx.toAccountId != null &&
        !await _exists(ex, 'accounts', tx.toAccountId!)) {
      throw const ValidationException('Akun tujuan tidak ditemukan.');
    }
    if (tx.categoryId != null) {
      final rows = await ex.query(
        'categories',
        columns: ['kind'],
        where: 'id = ?',
        whereArgs: [tx.categoryId],
      );
      if (rows.isEmpty) {
        throw const ValidationException('Kategori tidak ditemukan.');
      }
      final expected = tx.type == TransactionType.income
          ? CategoryKind.income
          : CategoryKind.expense;
      if (rows.first['kind'] != expected.name) {
        throw const ValidationException(
          'Kategori tidak sesuai dengan jenis transaksi.',
        );
      }
    }
    if (tx.goalId != null) {
      final goal =
          await _findGoal(ex, tx.goalId!) ??
          (throw const ValidationException('Tujuan tabungan tidak ditemukan.'));
      final matches = tx.goalFlow == GoalFlow.deposit
          ? tx.toAccountId == goal.accountId
          : tx.accountId == goal.accountId;
      if (!matches) {
        throw const ValidationException(
          'Setoran harus masuk ke akun tabungan tujuan, dan penarikan harus keluar dari akun tersebut.',
        );
      }
      await _ensureGoalNotNegative(
        ex,
        goal.id,
        excludeTxId: tx.id,
        extra: tx.goalSignedAmount,
      );
    }
    final oldGoal = previous?.goalId;
    if (oldGoal != null && oldGoal != tx.goalId) {
      await _ensureGoalNotNegative(ex, oldGoal, excludeTxId: tx.id, extra: 0);
    }
  }

  /// Dana terkumpul tidak boleh negatif setelah perubahan.
  Future<void> _ensureGoalNotNegative(
    DatabaseExecutor ex,
    String goalId, {
    required String excludeTxId,
    required int extra,
  }) async {
    final goal = await _findGoal(ex, goalId);
    if (goal == null) return;
    final rows = await ex.rawQuery(
      "SELECT COALESCE(SUM(CASE goal_flow WHEN 'deposit' THEN amount ELSE -amount END), 0) AS net "
      'FROM transactions WHERE goal_id = ? AND id <> ?',
      [goalId, excludeTxId],
    );
    final net = (rows.first['net'] as int?) ?? 0;
    if (goal.initialAmount + net + extra < 0) {
      throw const ValidationException(
        'Perubahan ini membuat dana tujuan menjadi minus. Periksa riwayat penarikan.',
      );
    }
  }

  Future<MoneyTransaction?> _findTransaction(
    DatabaseExecutor ex,
    String id,
  ) async =>
      (await ex.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      )).map(MoneyTransaction.fromMap).firstOrNull;

  Future<SavingsGoal?> _findGoal(DatabaseExecutor ex, String id) async =>
      (await ex.query(
        'savings_goals',
        where: 'id = ?',
        whereArgs: [id],
      )).map(SavingsGoal.fromMap).firstOrNull;

  /// [table] selalu konstanta dari kode ini, tidak pernah dari input pengguna.
  Future<bool> _exists(DatabaseExecutor ex, String table, String id) async =>
      await _count(ex, 'SELECT COUNT(*) FROM $table WHERE id = ?', [id]) > 0;

  Future<int> _count(
    DatabaseExecutor ex,
    String sql,
    List<Object?> args,
  ) async => Sqflite.firstIntValue(await ex.rawQuery(sql, args)) ?? 0;

  Future<T> _guardUnique<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const ValidationException('Kategori dengan nama ini sudah ada.');
      }
      rethrow;
    }
  }

  void _check(String? error) {
    if (error != null) throw ValidationException(error);
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  static String _placeholders(int n) => List.filled(n, '?').join(', ');

  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  // ---------- Backup dan data demo ----------

  /// Seluruh data sebagai teks JSON.
  Future<String> exportBackup() => BackupCodec.export(_db, now: _clock());

  /// Mengganti seluruh data dengan isi [json]. Semua-atau-tidak-sama-sekali:
  /// jika ada yang tidak cocok, data yang ada tidak berubah.
  Future<BackupSummary> restoreBackup(String json) async {
    final summary = await BackupCodec.restore(_db, json, today: _clock());
    _notify();
    return summary;
  }

  Future<void> loadDemoData() async {
    await DemoData.load(_db, _clock());
    _notify();
  }

  /// Menghapus data demo. Data Anda sendiri tidak disentuh, kecuali transaksi
  /// yang memakai akun atau target demo.
  Future<void> removeDemoData() async {
    await DemoData.remove(_db);
    _notify();
  }
}
