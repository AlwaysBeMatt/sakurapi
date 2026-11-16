import '../../core/dates.dart';
import '../../core/money.dart';

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.accountId,
    required this.createdAt,
    this.initialAmount = 0,
    this.targetDate,
    this.iconKey = 'savings',
    this.color = 0xFF176B55,
    this.note,
  });

  final String id;
  final String name;
  final int targetAmount;

  /// Dana yang sudah dimiliki saat tujuan dibuat. Ikut dihitung dalam
  /// progres tujuan, tetapi tidak mengubah saldo akun.
  final int initialAmount;
  final DateTime? targetDate;
  final String iconKey;
  final int color;
  final String? note;

  /// Akun tempat dana tujuan disimpan. Setoran adalah transfer ke akun ini.
  final String accountId;
  final DateTime createdAt;

  String? validate() {
    if (name.trim().isEmpty) return 'Nama tujuan wajib diisi.';
    if (name.trim().length > 60) return 'Nama tujuan maksimal 60 karakter.';
    if (targetAmount <= 0) return 'Target nominal harus lebih dari Rp0.';
    if (targetAmount > Money.maxAmount) return 'Target nominal terlalu besar.';
    if (initialAmount < 0) return 'Nominal awal tidak boleh negatif.';
    if (initialAmount > Money.maxAmount) return 'Nominal awal terlalu besar.';
    return null;
  }

  SavingsGoal copyWith({
    String? name,
    int? targetAmount,
    int? initialAmount,
    DateTime? targetDate,
    bool clearTargetDate = false,
    String? iconKey,
    int? color,
    String? note,
    String? accountId,
  }) => SavingsGoal(
    id: id,
    name: name ?? this.name,
    targetAmount: targetAmount ?? this.targetAmount,
    initialAmount: initialAmount ?? this.initialAmount,
    targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
    iconKey: iconKey ?? this.iconKey,
    color: color ?? this.color,
    note: note ?? this.note,
    accountId: accountId ?? this.accountId,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name.trim(),
    'target_amount': targetAmount,
    'initial_amount': initialAmount,
    'target_date': targetDate == null ? null : toDbDate(targetDate!),
    'icon': iconKey,
    'color': color,
    'note': note,
    'account_id': accountId,
    'created_at': createdAt.toIso8601String(),
  };

  factory SavingsGoal.fromMap(Map<String, Object?> m) => SavingsGoal(
    id: m['id']! as String,
    name: m['name']! as String,
    targetAmount: m['target_amount']! as int,
    initialAmount: m['initial_amount']! as int,
    targetDate: switch (m['target_date']) {
      final String s => fromDbDate(s),
      _ => null,
    },
    iconKey: m['icon']! as String,
    color: m['color']! as int,
    note: m['note'] as String?,
    accountId: m['account_id']! as String,
    createdAt: DateTime.parse(m['created_at']! as String),
  );
}
