import '../../core/dates.dart';
import '../../core/money.dart';

enum TransactionType { income, expense, transfer }

/// Arah pergerakan dana tujuan tabungan pada transfer yang tertaut ke tujuan.
enum GoalFlow { deposit, withdrawal }

class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.categoryId,
    this.toAccountId,
    this.goalId,
    this.goalFlow,
    this.note,
  });

  final String id;
  final TransactionType type;

  /// Selalu > 0. Arah uang ditentukan oleh [type], bukan oleh tanda nominal.
  final int amount;
  final String title;
  final String? categoryId; // wajib untuk income/expense, null untuk transfer
  final String accountId; // income: akun penerima; expense/transfer: akun asal
  final String? toAccountId; // hanya untuk transfer
  final String? goalId;
  final GoalFlow? goalFlow;
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Pengaruh terhadap progres tujuan: setoran +, penarikan -, lainnya 0.
  int get goalSignedAmount => switch (goalFlow) {
    GoalFlow.deposit => amount,
    GoalFlow.withdrawal => -amount,
    null => 0,
  };

  /// Satu-satunya definisi pengaruh transaksi terhadap saldo sebuah akun.
  int balanceEffectOn(String account) {
    switch (type) {
      case TransactionType.income:
        return accountId == account ? amount : 0;
      case TransactionType.expense:
        return accountId == account ? -amount : 0;
      case TransactionType.transfer:
        var effect = 0;
        if (accountId == account) effect -= amount;
        if (toAccountId == account) effect += amount;
        return effect;
    }
  }

  /// Validasi yang tidak membutuhkan database.
  String? validate({required DateTime today}) {
    if (amount <= 0) return 'Nominal harus lebih dari Rp0.';
    if (amount > Money.maxAmount) return 'Nominal terlalu besar.';
    if (title.length > 100) return 'Nama transaksi maksimal 100 karakter.';
    if ((note?.length ?? 0) > 500) return 'Catatan maksimal 500 karakter.';
    final d = dateOnly(date);
    final t = dateOnly(today);
    if (d.isBefore(DateTime(2000))) return 'Tanggal tidak valid.';
    if (d.isAfter(DateTime(t.year + 1, t.month, t.day))) {
      return 'Tanggal tidak boleh lebih dari satu tahun ke depan.';
    }
    switch (type) {
      case TransactionType.income:
      case TransactionType.expense:
        if (categoryId == null) return 'Pilih kategori.';
        if (toAccountId != null || goalId != null || goalFlow != null) {
          return 'Data transaksi tidak konsisten.';
        }
      case TransactionType.transfer:
        if (toAccountId == null) return 'Pilih akun tujuan.';
        if (toAccountId == accountId)
          return 'Akun asal dan tujuan tidak boleh sama.';
        if (categoryId != null) return 'Transfer tidak memakai kategori.';
        if ((goalId == null) != (goalFlow == null))
          return 'Data tujuan tabungan tidak lengkap.';
    }
    return null;
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'title': title,
    'category_id': categoryId,
    'account_id': accountId,
    'to_account_id': toAccountId,
    'goal_id': goalId,
    'goal_flow': goalFlow?.name,
    'date': toDbDate(date),
    'note': note,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory MoneyTransaction.fromMap(Map<String, Object?> m) => MoneyTransaction(
    id: m['id']! as String,
    type: TransactionType.values.byName(m['type']! as String),
    amount: m['amount']! as int,
    title: m['title']! as String,
    categoryId: m['category_id'] as String?,
    accountId: m['account_id']! as String,
    toAccountId: m['to_account_id'] as String?,
    goalId: m['goal_id'] as String?,
    goalFlow: switch (m['goal_flow']) {
      final String s => GoalFlow.values.byName(s),
      _ => null,
    },
    date: fromDbDate(m['date']! as String),
    note: m['note'] as String?,
    createdAt: DateTime.parse(m['created_at']! as String),
    updatedAt: DateTime.parse(m['updated_at']! as String),
  );
}

/// Data dari form. ID dan waktu pencatatan diisi oleh repository.
class TransactionInput {
  const TransactionInput({
    required this.type,
    required this.amount,
    required this.accountId,
    required this.date,
    this.title = '',
    this.categoryId,
    this.toAccountId,
    this.goalId,
    this.goalFlow,
    this.note,
  });

  final TransactionType type;
  final int amount;
  final String accountId;
  final DateTime date;
  final String title;
  final String? categoryId;
  final String? toAccountId;
  final String? goalId;
  final GoalFlow? goalFlow;
  final String? note;

  MoneyTransaction build({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final trimmedNote = note?.trim();
    return MoneyTransaction(
      id: id,
      type: type,
      amount: amount,
      title: title.trim(),
      categoryId: categoryId,
      accountId: accountId,
      toAccountId: toAccountId,
      goalId: goalId,
      goalFlow: goalFlow,
      date: dateOnly(date),
      note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
