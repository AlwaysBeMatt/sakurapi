import 'models/account.dart';
import 'models/savings_goal.dart';

/// Aturan pengelolaan akun yang tidak butuh database, jadi mudah diuji.
abstract final class AccountRules {
  /// Alasan akun belum boleh diarsipkan, atau null jika boleh.
  static String? archiveBlocker({
    required Account account,
    required Iterable<Account> all,
    required Map<String, int> balances,
    required Iterable<SavingsGoal> goals,
  }) {
    final otherActive = all.where((a) => !a.archived && a.id != account.id);
    if (otherActive.isEmpty) {
      return 'Minimal harus ada satu akun aktif.';
    }
    if ((balances[account.id] ?? 0) != 0) {
      return 'Saldo akun harus Rp0 sebelum diarsipkan. '
          'Pindahkan dananya dengan transfer.';
    }
    for (final g in goals) {
      if (g.accountId == account.id) {
        return 'Akun ini dipakai target tabungan "${g.name}".';
      }
    }
    return null;
  }

  /// Alasan akun tidak boleh dihapus (selain yang diperiksa repository).
  static String? deleteBlocker({
    required Account account,
    required Iterable<Account> all,
  }) {
    if (all.length <= 1) {
      return 'Akun terakhir tidak bisa dihapus.';
    }
    return null;
  }

  /// Apakah nama sudah dipakai akun lain (tanpa membedakan huruf besar/kecil).
  static bool nameTaken(
    String name,
    Iterable<Account> all, {
    String? exceptId,
  }) {
    final n = name.trim().toLowerCase();
    return all.any((a) => a.id != exceptId && a.name.trim().toLowerCase() == n);
  }
}
