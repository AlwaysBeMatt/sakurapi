import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sakurapi/data/app_database.dart';
import 'package:sakurapi/data/finance_repository.dart';
import 'package:sakurapi/domain/errors.dart';
import 'package:sakurapi/domain/models/account.dart';
import 'package:sakurapi/domain/models/money_transaction.dart';
import 'package:sakurapi/domain/models/tx_category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const cash = AppDatabase.defaultCashAccountId;
final today = DateTime(2025, 1, 20);
final throwsValidation = throwsA(isA<ValidationException>());

void main() {
  sqfliteFfiInit();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sakurapi_phase7');
  });
  tearDown(() => dir.delete(recursive: true));

  Future<FinanceRepository> openRepo() async => FinanceRepository(
    await AppDatabase.open(
      path: p.join(dir.path, 'test.db'),
      factory: databaseFactoryFfi,
    ),
    clock: () => today,
  );

  test('ubah akun menyimpan nama, jenis, dan saldo awal', () async {
    final repo = await openRepo();
    final bank = await repo.createAccount(name: 'Bank', type: AccountType.cash);
    await repo.updateAccount(
      bank.copyWith(
        name: 'BCA',
        type: AccountType.bank,
        initialBalance: 100000,
      ),
    );

    final saved = (await repo.getAccounts()).firstWhere((a) => a.id == bank.id);
    expect(saved.name, 'BCA');
    expect(saved.type, AccountType.bank);
    expect(saved.initialBalance, 100000);
    await repo.close();
  });

  test('arsip akun: hilang dari daftar aktif tetapi tetap tersimpan', () async {
    final repo = await openRepo();
    final bank = await repo.createAccount(name: 'Bank', type: AccountType.bank);
    await repo.updateAccount(bank.copyWith(archived: true));

    final active = await repo.getAccounts(includeArchived: false);
    expect(active.map((a) => a.id), [cash]);
    expect(await repo.getAccounts(), hasLength(2));

    final archived = (await repo.getAccounts()).firstWhere(
      (a) => a.id == bank.id,
    );
    await repo.updateAccount(archived.copyWith(archived: false));
    expect(await repo.getAccounts(includeArchived: false), hasLength(2));
    await repo.close();
  });

  test(
    'hapus akun: ditolak jika punya transaksi, berhasil jika kosong',
    () async {
      final repo = await openRepo();
      final bank = await repo.createAccount(
        name: 'Bank',
        type: AccountType.bank,
      );
      await repo.addTransaction(
        TransactionInput(
          type: TransactionType.income,
          amount: 50000,
          accountId: bank.id,
          categoryId: 'inc_gift',
          date: DateTime(2025, 1, 5),
        ),
      );
      await expectLater(repo.deleteAccount(bank.id), throwsValidation);

      final empty = await repo.createAccount(
        name: 'E-wallet',
        type: AccountType.ewallet,
      );
      await repo.deleteAccount(empty.id);
      expect((await repo.getAccounts()).map((a) => a.name), [
        'Dompet Tunai',
        'Bank',
      ]);
      await repo.close();
    },
  );

  test('akun dengan nama kosong atau saldo negatif ditolak', () async {
    final repo = await openRepo();
    await expectLater(
      repo.createAccount(name: '   ', type: AccountType.cash),
      throwsValidation,
    );
    await expectLater(
      repo.createAccount(
        name: 'Minus',
        type: AccountType.cash,
        initialBalance: -1,
      ),
      throwsValidation,
    );
    expect(await repo.getAccounts(), hasLength(1));
    await repo.close();
  });

  test('kategori buatan sendiri: tambah, ubah, hapus', () async {
    final repo = await openRepo();
    final kopi = await repo.createCategory(
      name: 'Kopi',
      kind: CategoryKind.expense,
      iconKey: 'restaurant',
      color: 0xFFE6A23C,
    );
    await repo.updateCategory(
      TxCategory(
        id: kopi.id,
        name: 'Ngopi',
        kind: CategoryKind.expense,
        iconKey: 'bus',
        color: 0xFF4F8FD8,
      ),
    );

    final saved = (await repo.getCategories()).firstWhere(
      (c) => c.id == kopi.id,
    );
    expect(saved.name, 'Ngopi');
    expect(saved.iconKey, 'bus');
    expect(saved.color, 0xFF4F8FD8);
    expect(saved.isDefault, isFalse);

    await repo.deleteCategory(kopi.id);
    expect((await repo.getCategories()).any((c) => c.id == kopi.id), isFalse);
    await repo.close();
  });

  test('kategori: bawaan tidak bisa dihapus, nama kembar ditolak', () async {
    final repo = await openRepo();
    await expectLater(repo.deleteCategory('exp_food'), throwsValidation);
    await repo.createCategory(name: 'Kopi', kind: CategoryKind.expense);
    await expectLater(
      repo.createCategory(name: 'KOPI', kind: CategoryKind.expense),
      throwsValidation,
    );
    // Nama yang sama boleh dipakai di jenis yang berbeda.
    await repo.createCategory(name: 'Kopi', kind: CategoryKind.income);
    await repo.close();
  });

  test('kategori yang dipakai transaksi tidak bisa dihapus', () async {
    final repo = await openRepo();
    final kopi = await repo.createCategory(
      name: 'Kopi',
      kind: CategoryKind.expense,
    );
    await repo.addTransaction(
      TransactionInput(
        type: TransactionType.expense,
        amount: 20000,
        accountId: cash,
        categoryId: kopi.id,
        date: DateTime(2025, 1, 5),
      ),
    );
    await expectLater(repo.deleteCategory(kopi.id), throwsValidation);
    await repo.close();
  });

  test('menghapus kategori ikut menghapus anggarannya', () async {
    final repo = await openRepo();
    final kopi = await repo.createCategory(
      name: 'Kopi',
      kind: CategoryKind.expense,
    );
    await repo.saveBudget(categoryId: kopi.id, limitAmount: 100000);
    expect(await repo.getBudgets(), hasLength(1));

    await repo.deleteCategory(kopi.id);
    expect(await repo.getBudgets(), isEmpty);
    await repo.close();
  });
}
