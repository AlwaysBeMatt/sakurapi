import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/errors.dart';
import '../domain/models/account.dart';
import '../domain/models/budget.dart';
import '../domain/models/money_transaction.dart';
import '../domain/models/recurring_rule.dart';
import '../domain/models/savings_goal.dart';
import '../domain/models/tx_category.dart';

class BackupSummary {
  const BackupSummary({
    required this.accounts,
    required this.categories,
    required this.goals,
    required this.transactions,
    required this.budgets,
    this.recurring = 0,
  });

  final int accounts;
  final int categories;
  final int goals;
  final int transactions;
  final int budgets;
  final int recurring;

  String get description =>
      '$accounts akun, $categories kategori, $transactions transaksi, '
      '$budgets anggaran, $goals target tabungan'
      '${recurring > 0 ? ', $recurring transaksi berulang' : ''}';
}

class _Parsed {
  const _Parsed({
    required this.accounts,
    required this.categories,
    required this.goals,
    required this.transactions,
    required this.budgets,
    required this.rules,
  });

  final List<Account> accounts;
  final List<TxCategory> categories;
  final List<SavingsGoal> goals;
  final List<MoneyTransaction> transactions;
  final List<Budget> budgets;
  final List<RecurringRule> rules;

  BackupSummary get summary => BackupSummary(
    accounts: accounts.length,
    categories: categories.length,
    goals: goals.length,
    transactions: transactions.length,
    budgets: budgets.length,
    recurring: rules.length,
  );
}

/// Membuat dan membaca file backup JSON.
abstract final class BackupCodec {
  static const formatName = 'sakurapi-backup';
  static const formatVersion = 1;

  static Future<String> export(
    DatabaseExecutor db, {
    required DateTime now,
  }) async {
    Future<List<Map<String, Object?>>> read(String table) async {
      final rows = await db.query(table, orderBy: 'rowid');
      return [for (final r in rows) Map<String, Object?>.of(r)];
    }

    final doc = <String, Object?>{
      'format': formatName,
      'version': formatVersion,
      'exported_at': now.toIso8601String(),
      'accounts': await read('accounts'),
      'categories': await read('categories'),
      'savings_goals': await read('savings_goals'),
      'transactions': await read('transactions'),
      'budgets': await read('budgets'),
      'recurring_rules': await read('recurring_rules'),
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  /// Memeriksa isi file tanpa menyentuh database. Melempar
  /// [ValidationException] dengan pesan yang bisa ditampilkan ke pengguna.
  static BackupSummary inspect(String text, {required DateTime today}) =>
      _parse(text, today: today).summary;

  /// Mengganti seluruh isi database dalam satu transaksi. Jika satu baris saja
  /// gagal (nilai tidak valid atau relasi tidak cocok), semuanya dibatalkan.
  static Future<BackupSummary> restore(
    Database db,
    String text, {
    required DateTime today,
  }) async {
    final p = _parse(text, today: today);
    try {
      await db.transaction((txn) async {
        // Urutan hapus kebalikan dari urutan isi, supaya relasi tidak putus.
        for (final table in const [
          'recurring_rules',
          'transactions',
          'budgets',
          'savings_goals',
          'categories',
          'accounts',
        ]) {
          await txn.delete(table);
        }
        for (final a in p.accounts) {
          await txn.insert('accounts', a.toMap());
        }
        for (final c in p.categories) {
          await txn.insert('categories', c.toMap());
        }
        for (final g in p.goals) {
          await txn.insert('savings_goals', g.toMap());
        }
        for (final t in p.transactions) {
          await txn.insert('transactions', t.toMap());
        }
        for (final b in p.budgets) {
          await txn.insert('budgets', b.toMap());
        }
        for (final r in p.rules) {
          await txn.insert('recurring_rules', r.toMap());
        }
      });
    } on DatabaseException {
      throw const ValidationException(
        'Isi file backup tidak konsisten (ada relasi atau nilai yang tidak '
        'cocok). Data Anda tidak diubah.',
      );
    }
    return p.summary;
  }

  static _Parsed _parse(String text, {required DateTime today}) {
    final source = text.startsWith('\uFEFF') ? text.substring(1) : text;
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const ValidationException('File bukan JSON yang valid.');
    }
    if (decoded is! Map || decoded['format'] != formatName) {
      throw const ValidationException('Ini bukan file backup SakuRapi.');
    }
    final Map<dynamic, dynamic> doc = decoded;

    final version = doc['version'];
    if (version is! int || version < 1) {
      throw const ValidationException('Versi file backup tidak dikenali.');
    }
    if (version > formatVersion) {
      throw const ValidationException(
        'File backup dibuat oleh versi aplikasi yang lebih baru. '
        'Perbarui SakuRapi lebih dulu.',
      );
    }

    List<Map<String, Object?>> table(String name, {bool optional = false}) {
      final raw = doc[name];
      if (raw == null && optional) {
        return const [];
      }
      if (raw is! List) {
        throw ValidationException(
          'Bagian "$name" tidak ditemukan di file backup.',
        );
      }
      final rows = <Map<String, Object?>>[];
      for (final row in raw) {
        if (row is! Map) {
          throw ValidationException('Bagian "$name" rusak.');
        }
        rows.add(Map<String, Object?>.from(row));
      }
      return rows;
    }

    try {
      final accounts = [for (final r in table('accounts')) Account.fromMap(r)];
      final categories = [
        for (final r in table('categories')) TxCategory.fromMap(r),
      ];
      final goals = [
        for (final r in table('savings_goals')) SavingsGoal.fromMap(r),
      ];
      final transactions = [
        for (final r in table('transactions')) MoneyTransaction.fromMap(r),
      ];
      final budgets = [for (final r in table('budgets')) Budget.fromMap(r)];
      // Backup dari versi lama belum punya bagian ini.
      final rules = [
        for (final r in table('recurring_rules', optional: true))
          RecurringRule.fromMap(r),
      ];

      if (accounts.isEmpty) {
        throw const ValidationException('File backup tidak berisi akun.');
      }
      for (final a in accounts) {
        final e = a.validate();
        if (e != null) {
          throw ValidationException('Akun "${a.name}": $e');
        }
      }
      for (final c in categories) {
        final e = c.validate();
        if (e != null) {
          throw ValidationException('Kategori "${c.name}": $e');
        }
      }
      for (final g in goals) {
        final e = g.validate();
        if (e != null) {
          throw ValidationException('Target "${g.name}": $e');
        }
      }
      for (final t in transactions) {
        final e = t.validate(today: today);
        if (e != null) {
          throw ValidationException(
            'Transaksi tanggal ${t.date.year}-${t.date.month}-${t.date.day}: $e',
          );
        }
      }
      for (final b in budgets) {
        final e = b.validate();
        if (e != null) {
          throw ValidationException('Anggaran: $e');
        }
      }
      for (final r in rules) {
        final e = r.validate(today: today, isNew: false);
        if (e != null) {
          throw ValidationException('Transaksi berulang: $e');
        }
      }
      return _Parsed(
        accounts: accounts,
        categories: categories,
        goals: goals,
        transactions: transactions,
        budgets: budgets,
        rules: rules,
      );
    } on ValidationException {
      rethrow;
    } catch (_) {
      throw const ValidationException(
        'Isi file backup rusak atau tidak lengkap.',
      );
    }
  }
}