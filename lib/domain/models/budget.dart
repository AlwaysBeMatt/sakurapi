import '../../core/money.dart';

/// Anggaran bulanan berulang. [categoryId] null berarti seluruh pengeluaran.
class Budget {
  const Budget({
    required this.id,
    required this.limitAmount,
    required this.createdAt,
    this.categoryId,
  });

  final String id;
  final String? categoryId;
  final int limitAmount;
  final DateTime createdAt;

  String? validate() {
    if (limitAmount <= 0) return 'Batas anggaran harus lebih dari Rp0.';
    if (limitAmount > Money.maxAmount) return 'Batas anggaran terlalu besar.';
    return null;
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'category_id': categoryId,
    'limit_amount': limitAmount,
    'created_at': createdAt.toIso8601String(),
  };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
    id: m['id']! as String,
    categoryId: m['category_id'] as String?,
    limitAmount: m['limit_amount']! as int,
    createdAt: DateTime.parse(m['created_at']! as String),
  );
}
